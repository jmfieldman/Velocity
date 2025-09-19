//
//  ModulePackageConfig.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

/// Represents the Codable format of package.yml files.
/// All fields are optional. It is valid/expected that package.yml files are
/// normally empty.
public class ModulePackageConfig: Codable {
    /// Optional description that can be used in debug/tooling output; not required
    public let description: String?

    /// If true, the module will be completely disabled and not included into any
    /// production project output.
    public let disable: Bool?

    /// If true, will disable test modules from being produced. Useful as a safety
    /// valve to turn off faulty tests while they can be repaired.
    public let disableTests: Bool?

    /// Allows subdirectory override. The key is the Module type (main, impl, etc).
    public let directoryOverrides: [String: String]?

    /// Any special build settings for modules in the package, keyed by module type.
    public let settingsOverrides: [String: [String: String]]?

    /// A list of files to exclude, keyed by module type.
    public let fileExclusions: [String: [String]]?

    /// A list of resources to include for a module
    public let resources: [String: [String]]?

    /// Set this to true to force the framework to a dynamic (non-static) framework
    /// type; this is only necessary when using the --default-static argument during
    /// module generation.
    public let dynamic: Bool?

    /// An override for mock generation. If the module generation command is told
    /// to create mocks, it will generally create mocks for any module that declares
    /// some kind of injection (injection or builder map). You can force the decision
    /// to be yes or no with this override.
    ///
    /// Note: even if this is set to true, mocks will only be generated if the top-level
    /// command is told to generate mocks.
    public let generateMocks: Bool?

    // MARK: Injection

    /// The name of the protocol this module provides an Inject implementation for.
    /// The value should be the name of the protocol, and it automatically appends
    /// 'Impl' for the implementation name.
    ///
    /// You can use a single underscore character to automatically use the Package
    /// name as the injection class name
    ///
    /// Best practice is that each package only provides a single Inject implementation
    /// named after itself, so a single underscore should work in most scenarios.
    /// This value is ignored if `injectMap` is defined.
    public let injects: String?

    /// In more complex inject scenarios, you can define the full inject map, where
    /// the key is the protocol name and the value is the corresponding implementation
    /// name. If this value is defined it will override the `injects` value.
    public let injectMap: [String: String]?

    // MARK: Builders

    /// A list of builders to register for this package. The standard builder naming
    /// pattern for (builder) -> (implementation) is:
    ///  - SomeTypeNameBuilder -> SomeTypeNameImpl
    /// So this array should only contain strings like "SomeTypeName" (without any suffix).
    ///
    /// This array is ignored if the `builderMap` value is defined.
    public let builders: [String]?

    /// Packages that provide more complex naming patterns for their builders will
    /// need to defined the explicit builderMap of [BuilderName: ImplementationName]
    public let builderMap: [String: String]?
}
