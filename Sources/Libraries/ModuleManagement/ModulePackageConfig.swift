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

    /// Set this to true to force the framework to a dynamic (non-static) framework
    /// type; this is only necessary when using the --default-static argument during
    /// module generation.
    public let dynamic: Bool?

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
}
