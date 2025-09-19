//
//  GenerateXcodegenModules.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import XcodeProj
import Yams

public struct GenerateXcodegenModulesOptions {
    public let rootPath: String
    public let regenImports: Bool
    public let regenInfoPlists: Bool
    public let outputFilename: String
    public let platforms: String
    public let dependenciesConfig: String
    public let packageFileName: String
    public let cuckooOutputFile: String?
    public let defaultStatic: Bool

    public init(
        rootPath: String,
        regenImports: Bool = false,
        regenInfoPlists: Bool = false,
        outputFilename: String = "project-modules.yml",
        platforms: String = "iOS",
        dependenciesConfig: String = kPathDependencyConfig,
        packageFileName: String = kPathPackageYml,
        cuckooOutputFile: String? = nil,
        defaultStatic: Bool = false
    ) {
        self.regenImports = regenImports
        self.regenInfoPlists = regenInfoPlists
        self.rootPath = rootPath
        self.outputFilename = outputFilename
        self.platforms = platforms
        self.dependenciesConfig = dependenciesConfig
        self.packageFileName = packageFileName
        self.cuckooOutputFile = cuckooOutputFile
        self.defaultStatic = defaultStatic
    }
}

public enum GenerateXcodegenModules {
    public static func execute(with options: GenerateXcodegenModulesOptions) throws {
        let absoluteModuleBasePath = options.rootPath.prependingCurrentDirectory()
        let absoluteProjectPath = FileManager.default.currentDirectoryPath

        // Start the cuckoo toml generation; this will only output if non-empty
        var generatedCuckooToml = ""
        let generateCuckoo = options.cuckooOutputFile != nil

        // Verify root path exists
        guard FileManager.default.directoryExists(atPath: absoluteModuleBasePath) else {
            try throwError(.pathNotFound, "Module directory not found at path: \(options.rootPath)")
        }

        let supportedDestinations: [ProjectSpec.SupportedDestination] = try options.platforms
            .components(separatedBy: ",")
            .map {
                guard let dest = ProjectSpec.SupportedDestination(rawValue: $0) else {
                    try throwError(.invalidArgument, "\($0) is not a valid platform -- options are (iOS, tvOS, watchOS, visionOS, macOS, macCatalyst)")
                }
                return dest
            }

        var packages = ModulePackageManager.packages(
            named: options.packageFileName,
            root: options.rootPath,
            absoluteProjectPath: absoluteProjectPath
        )

        let packageManager = ModulePackageManager(packages: packages)

        if let cycles = packageManager.importCycle(), let last = cycles.last {
            for cycle in cycles {
                vprint(.normal, "> \(cycle.0) -> \(cycle.1.name)\(cycle.1.bridge.flatMap { ":\($0)" } ?? "")")
            }
            try throwError(.dependencyCycle, "Found dependency cycle: \(last.0) -> \(last.1.name)\(last.1.bridge.flatMap { ":\($0)" } ?? "")")
        } else {
            vprint(.verbose, "No dependency cycles found")
        }

        var dependencyLookup: [String: DependencyConfig] = [:]
        do {
            let dependenciesConfig = try DependenciesConfig.from(filePath: options.dependenciesConfig)
            dependenciesConfig.dependencies?.forEach { pkg in
                if let libs = pkg.libraries, libs.count > 0 {
                    libs.forEach { dependencyLookup[$0] = pkg }
                } else {
                    dependencyLookup[pkg.inferredPackageName] = pkg
                }
            }
            dependenciesConfig.projectPackages?.forEach { projectPkg in
                if let libs = projectPkg.libraries, libs.count > 0 {
                    libs.forEach { dependencyLookup[$0] = projectPkg.dependencyConfig() }
                } else {
                    dependencyLookup[projectPkg.name] = projectPkg.dependencyConfig()
                }
            }
            if dependencyLookup.count == 0 {
                vprint(.verbose, "No external dependencies were detected at \(options.dependenciesConfig)")
            }
        } catch {
            guard let cmdError = error as? CommandError else {
                return
            }
            switch cmdError {
            case .configNotFound:
                vprint(.verbose, "No dependency config file detected at \(options.dependenciesConfig)")
            case .configNotDecodable:
                vprint(.verbose, "Malformed/unparsable dependency config file at \(options.dependenciesConfig)")
            default:
                vprint(.error, "Failed to parse dependency config file at \(options.dependenciesConfig): \(error)")
            }
        }

        guard packages.count > 0 else {
            vprint(.normal, "No packages found at root path: \(options.rootPath)")
            return
        }

        if options.regenImports {
            vprint(.normal, "Regenerate imports for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")
            packages.sorted { $0.name < $1.name }.forEach { package in
                package.modules.values.sorted { $0.name < $1.name }.forEach { module in
                    vprint(.debug, "Regenerate imports for \(module.name)", "🔧")
                    module.regenerateImportsFile(ignoreFilenames: [])
                }
            }

            // Packages needs to reload
            packages = ModulePackageManager.packages(
                named: options.packageFileName,
                root: options.rootPath,
                absoluteProjectPath: absoluteProjectPath
            )
        }

        if options.regenInfoPlists {
            vprint(.normal, "Regenerate Info.plist for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")
            try packages.sorted { $0.name < $1.name }.forEach { package in
                try package.modules.values.sorted { $0.name < $1.name }.forEach { module in
                    vprint(.debug, "Regenerate Info.plist for \(module.name)", "🔧")
                    try module.regenInfoPlists()
                }
            }
        }

        // Load our internal module set
        let internalModuleSet = Set(packages.flatMap { package in
            package.modules.values.map(\.name)
        })

        vprint(.normal, "Generating \(options.outputFilename)", "🔧")

        // Checking dynamic -> static deps
        var dynamicInternalModules: [String: Bool] = [:]
        var internalDepMap: [String: [String]] = [:]

        var targets: [String: TargetEnc] = [:]
        var templateDeps: [DependencyEnc] = []
        try packages.sorted { $0.name < $1.name }.forEach { package in
            if generateCuckoo, package.generateMocks {
                generatedCuckooToml += try appendCuckooToml(package: package)
            }

            package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { moduleType in
                let module = package.modules[moduleType]!

                // Determine dependencies

                // Process the imported modules to generate internal and external dependencies
                let (internalDependencies, externalRefs, xcodeSdks) = module.importedModules.sorted().reduce(into: ([DependencyEnc](), [String: [String]](), Set<String>())) { result, depName in
                    if internalModuleSet.contains(depName) {
                        // Append internal dependencies
                        result.0.append(DependencyEnc(target: depName))
                        internalDepMap[module.name] = (internalDepMap[module.name] ?? []) + [depName]
                    } else if let depConfig = dependencyLookup[depName] {
                        // Build external references
                        result.1[depConfig.inferredPackageName, default: []].append(depName)
                    } else if let xcodeSdk = kXcodeSDKs[depName] {
                        result.2.insert(xcodeSdk)
                    }
                }

                // Convert external references into dependencies and log them
                let externalDependencies = externalRefs
                    .sorted(by: { $0.key < $1.key })
                    .map { ref -> DependencyEnc in
                        DependencyEnc(package: ref.key, products: ref.value)
                    }

                // Convert Xcode SDKs to xcodegen dependencies
                let XcodeDependencies = xcodeSdks
                    .sorted()
                    .map { framework -> DependencyEnc in
                        DependencyEnc(sdk: framework)
                    }

                // Combine internal and external dependencies
                let dependencies = internalDependencies + externalDependencies + XcodeDependencies

                // dynamic vs. static

                let useDynamic = package.forceDynamicFramework.flatMap { $0 } ?? !options.defaultStatic
                dynamicInternalModules[module.name] = useDynamic

                // Additional resources

                let additionalResources: [TargetSource] = []
                /*
                   xcodegen seems to be able to auto-detect the resource phase for files at the root path.
                   leaving this out for now unless it becomes apparent that we'd want to include resources
                   outside of the main module directory

                 let additionalResources: [TargetSource] = module.resources.map { resources in
                     resources.map {
                         TargetSource(
                             path: module.projectBasePath.appendingMissingSlash() + $0,
                             buildPhase: .resources
                         )
                     }
                 } ?? []
                  */

                // Generate Target object

                let target = ProjectSpec.Target(
                    name: module.name,
                    type: module.type.xcodeProductType(dynamicPackage: useDynamic),
                    platform: .auto,
                    supportedDestinations: supportedDestinations,
                    sources: [.init(
                        path: module.projectBasePath,
                        excludes: module.fileExclusions
                    )] + additionalResources
                )

                targets[module.name] = TargetEnc(
                    type: target.type.rawValue.replacingOccurrences(of: "com.apple.product-type.", with: ""),
                    platform: target.platform.rawValue,
                    supportedDestinations: supportedDestinations.map(\.rawValue),
                    dependencies: dependencies,
                    sources: target.sources.map {
                        SourceEnc(
                            path: $0.path,
                            excludes: $0.excludes,
                            buildPhase: $0.buildPhase?.toJSONValue() as? String
                        )
                    }
                )

                // Include in main app template

                if moduleType.includeInAppTemplate {
                    templateDeps.append(DependencyEnc(target: module.name))
                }

                // Resource warning + extensions

                if module.resources.count > 0, !moduleType.mayContainResources {
                    vprint(.normal, "WARNING: module [\(module.name)] contains resources, but is not a resource module type.")
                    for resource in module.resources {
                        vprint(.normal, " > \(resource)")
                    }
                }

                if module.resources.count == 0, moduleType.mustContainResources {
                    vprint(.normal, "WARNING: resource module [\(module.name)] does not contain any resources.")
                }
            }
        }

        let targetsEnc = TargetsEnc(
            targets: targets,
            targetTemplates: ["ModuleInclusionTemplate": TargetTemplateEnc(dependencies: templateDeps)]
        )
        let encoder = YAMLEncoder()
        encoder.options = Emitter.Options(sortKeys: true, sequenceStyle: .block, mappingStyle: .block)
        let encodedString = try encoder.encode(targetsEnc)

        try encodedString.removingEmptyYml().write(
            toFile: options.outputFilename,
            atomically: true,
            encoding: .utf8
        )

        // Potentially write the Cuckoo toml
        if generateCuckoo, generatedCuckooToml.count > 0, let path = options.cuckooOutputFile {
            try "# This Cuckoo config file was autogenerated by Velocity.\n# Any changes to this file will be overwritten automatically.\n\n\(generatedCuckooToml)"
                .write(
                    toFile: path,
                    atomically: true,
                    encoding: .utf8
                )
        }

        // Throw warning if dynamic -> static dependency is detected
        var dynamicViolationsDetected = false
        for (module, dynamic) in dynamicInternalModules {
            guard dynamic, let moduleDeps = internalDepMap[module] else { continue }
            for moduleDep in moduleDeps {
                if dynamicInternalModules[moduleDep] == false {
                    vprint(.normal, "Dynamic module [\(module)] depends on static module [\(moduleDep)]", "⚠️ ")
                    dynamicViolationsDetected = true
                }
            }
        }

        if dynamicViolationsDetected {
            vprint(.normal, "It is incorrect practice to have a dynamic framework depend on a static framework. This can lead to duplicate symbol problems, and framework size bloat. Refactor your dependency graph so that dynamic frameworks are only dependent on other dynamic frameworks.", "⚠️ ")
        }
    }
}

private extension GenerateXcodegenModules {
    static func appendCuckooToml(package: ModulePackage) throws -> String {
        guard let mainModule = package.modules[.main] else {
            return ""
        }

        let testHelperPath = mainModule.projectBasePath.removingSlash() + "TestHelpers"
        try FileManager.default.createDirectory(atPath: testHelperPath, withIntermediateDirectories: true)

        return """
        [modules.{MODULE_NAME}]
        imports = ["Foundation", "Testing", "XCTest"]
        testableImports = ["{MODULE_NAME}"]
        sources = [
            "{MODULE_PATH}/*.swift",
        ]
        output = "{MODULE_PATH}TestHelpers/GeneratedMocks.swift"

        [modules.{MODULE_NAME}.options]
        glob = true
        keepDocumentation = true


        """
        .replacingOccurrences(of: "{MODULE_NAME}", with: mainModule.name)
        .replacingOccurrences(of: "{MODULE_PATH}", with: mainModule.projectBasePath.removingSlash())
    }
}

private extension String {
    func removingEmptyYml() -> String {
        components(separatedBy: .newlines)
            .filter { !($0.contains(": null") || $0.contains(": []") || $0.contains(": {}")) }
            .joined(separator: "\n")
    }
}

// MARK: Encodable Objects for YAML Output

private struct TargetsEnc: Encodable {
    var targets: [String: TargetEnc]
    var targetTemplates: [String: TargetTemplateEnc]
}

private struct TargetEnc: Encodable {
    var type: String
    var platform: String
    var supportedDestinations: [String]
    var dependencies: [DependencyEnc]
    var sources: [SourceEnc]
}

private struct DependencyEnc: Encodable {
    var target: String?
    var embed: Bool?
    var framework: String?
    var sdk: String?

    var package: String?
    var products: [String]?
}

private struct SourceEnc: Encodable {
    var path: String
    var excludes: [String]
    var buildPhase: String?
}

private struct TargetTemplateEnc: Encodable {
    var dependencies: [DependencyEnc]
}

private extension ModuleType {
    var includeInAppTemplate: Bool {
        switch self {
        case .main, .impl, .resources:
            true
        case .tests, .testHelpers:
            false
        }
    }
}

// MARK: Bundle+ResourceExtension

let kBundleResourceExtensionTemplate = """
import Foundation

// This file is autogenerated by Velocity to provide a way to programmatically
// access this Bundle

public extension Bundle {
    /// Access the {MODULE_NAME} bundle 
    static let {MODULE_NAME} = Bundle(for: {MODULE_NAME}Beacon.self)
    private class {MODULE_NAME}Beacon {}
}
"""

// MARK: Xcode SDKs

private let kXcodeSDKs: [String: String] = {
    var result: [String: String] = [:]
    for sdk in _kXcodeSDKList {
        result[sdk.replacingOccurrences(of: ".framework", with: "")] = sdk
    }
    return result
}()

// This is a list of `sdk` dependencies available in Xcode. These will be imported into modules
// if they declare imports that are not found in other project or dependency module lists.
//
// To get testing frameworks:
// > ls -1 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Frameworks | awk '{ print "\""$0"\"," }'
//
// To get general frameworks:
// > ls -1 /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks | awk '{ print "\""$0"\"," }'
//
private let _kXcodeSDKList: [String] = [
    "LiveExecutionResultsLogger.framework",
    "StoreKitTest.framework",
    "Testing.framework",
    "XCTest.framework",
    "XCUIAutomation.framework",

    "Accelerate.framework",
    "Accessibility.framework",
    "AccessorySetupKit.framework",
    "Accounts.framework",
    "ActivityKit.framework",
    "AdAttributionKit.framework",
    "AddressBook.framework",
    "AddressBookUI.framework",
    "AdServices.framework",
    "AdSupport.framework",
    "AppClip.framework",
    "AppIntents.framework",
    "AppTrackingTransparency.framework",
    "ARKit.framework",
    "AssetsLibrary.framework",
    "Assignables.framework",
    "AudioToolbox.framework",
    "AudioUnit.framework",
    "AuthenticationServices.framework",
    "AutomatedDeviceEnrollment.framework",
    "AutomaticAssessmentConfiguration.framework",
    "AVFAudio.framework",
    "AVFoundation.framework",
    "AVKit.framework",
    "AVRouting.framework",
    "BackgroundAssets.framework",
    "BackgroundTasks.framework",
    "BrowserEngineCore.framework",
    "BrowserEngineKit.framework",
    "BrowserKit.framework",
    "BusinessChat.framework",
    "CallKit.framework",
    "CarKey.framework",
    "CarPlay.framework",
    "CFNetwork.framework",
    "Charts.framework",
    "Cinematic.framework",
    "ClassKit.framework",
    "ClockKit.framework",
    "CloudKit.framework",
    "ColorSync.framework",
    "Combine.framework",
    "ContactProvider.framework",
    "Contacts.framework",
    "ContactsUI.framework",
    "CoreAudio.framework",
    "CoreAudioKit.framework",
    "CoreAudioTypes.framework",
    "CoreBluetooth.framework",
    "CoreData.framework",
    "CoreFoundation.framework",
    "CoreGraphics.framework",
    "CoreHaptics.framework",
    "CoreImage.framework",
    "CoreLocation.framework",
    "CoreLocationUI.framework",
    "CoreMedia.framework",
    "CoreMediaIO.framework",
    "CoreMIDI.framework",
    "CoreML.framework",
    "CoreMotion.framework",
    "CoreNFC.framework",
    "CoreServices.framework",
    "CoreSpotlight.framework",
    "CoreTelephony.framework",
    "CoreText.framework",
    "CoreTransferable.framework",
    "CoreVideo.framework",
    "CreateML.framework",
    "CreateMLComponents.framework",
    "CryptoKit.framework",
    "CryptoTokenKit.framework",
    "DataDetection.framework",
    "DeveloperToolsSupport.framework",
    "DeviceActivity.framework",
    "DeviceCheck.framework",
    "DeviceDiscoveryExtension.framework",
    "DockKit.framework",
    "EventKit.framework",
    "EventKitUI.framework",
    "ExposureNotification.framework",
    "ExtensionFoundation.framework",
    "ExtensionKit.framework",
    "ExternalAccessory.framework",
    "FamilyControls.framework",
    "FileProvider.framework",
    "FileProviderUI.framework",
    "FinanceKit.framework",
    "FinanceKitUI.framework",
    "Foundation.framework",
    "GameController.framework",
    "GameKit.framework",
    "GameplayKit.framework",
    "GLKit.framework",
    "GroupActivities.framework",
    "GSS.framework",
    "HealthKit.framework",
    "HealthKitUI.framework",
    "HomeKit.framework",
    "iAd.framework",
    "IdentityLookup.framework",
    "IdentityLookupUI.framework",
    "ImageCaptureCore.framework",
    "ImageIO.framework",
    "ImagePlayground.framework",
    "Intents.framework",
    "IntentsUI.framework",
    "IOKit.framework",
    "IOSurface.framework",
    "JavaScriptCore.framework",
    "JournalingSuggestions.framework",
    "LightweightCodeRequirements.framework",
    "LinkPresentation.framework",
    "LiveCommunicationKit.framework",
    "LocalAuthentication.framework",
    "LocalAuthenticationEmbeddedUI.framework",
    "LockedCameraCapture.framework",
    "ManagedApp.framework",
    "ManagedAppDistribution.framework",
    "ManagedSettings.framework",
    "ManagedSettingsUI.framework",
    "MapKit.framework",
    "MarketplaceKit.framework",
    "Matter.framework",
    "MatterSupport.framework",
    "MediaAccessibility.framework",
    "MediaPlayer.framework",
    "MediaSetup.framework",
    "MediaToolbox.framework",
    "Messages.framework",
    "MessageUI.framework",
    "Metal.framework",
    "MetalFX.framework",
    "MetalKit.framework",
    "MetalPerformanceShaders.framework",
    "MetalPerformanceShadersGraph.framework",
    "MetricKit.framework",
    "MLCompute.framework",
    "MobileCoreServices.framework",
    "ModelIO.framework",
    "MultipeerConnectivity.framework",
    "MusicKit.framework",
    "NaturalLanguage.framework",
    "NearbyInteraction.framework",
    "Network.framework",
    "NetworkExtension.framework",
    "NotificationCenter.framework",
    "OpenAL.framework",
    "OpenGLES.framework",
    "OSLog.framework",
    "PassKit.framework",
    "PDFKit.framework",
    "PencilKit.framework",
    "PHASE.framework",
    "Photos.framework",
    "PhotosUI.framework",
    "ProximityReader.framework",
    "PushKit.framework",
    "PushToTalk.framework",
    "QuartzCore.framework",
    "QuickLook.framework",
    "QuickLookThumbnailing.framework",
    "RealityFoundation.framework",
    "RealityKit.framework",
    "ReplayKit.framework",
    "RoomPlan.framework",
    "SafariServices.framework",
    "SafetyKit.framework",
    "SceneKit.framework",
    "ScreenTime.framework",
    "SecureElementCredential.framework",
    "Security.framework",
    "SecurityUI.framework",
    "SensitiveContentAnalysis.framework",
    "SensorKit.framework",
    "SharedWithYou.framework",
    "SharedWithYouCore.framework",
    "ShazamKit.framework",
    "Social.framework",
    "SoundAnalysis.framework",
    "Speech.framework",
    "SpriteKit.framework",
    "StickerFoundation.framework",
    "StickerKit.framework",
    "StoreKit.framework",
    "SwiftData.framework",
    "SwiftUI.framework",
    "SwiftUICore.framework",
    "Symbols.framework",
    "SystemConfiguration.framework",
    "SystemExtensions.framework",
    "TabularData.framework",
    "ThreadNetwork.framework",
    "TipKit.framework",
    "Translation.framework",
    "TranslationUIProvider.framework",
    "Twitter.framework",
    "UIKit.framework",
    "UniformTypeIdentifiers.framework",
    "UserNotifications.framework",
    "UserNotificationsUI.framework",
    "VideoSubscriberAccount.framework",
    "VideoToolbox.framework",
    "Vision.framework",
    "VisionKit.framework",
    "WatchConnectivity.framework",
    "WeatherKit.framework",
    "WebKit.framework",
    "WidgetKit.framework",
    "WorkoutKit.framework",
]
