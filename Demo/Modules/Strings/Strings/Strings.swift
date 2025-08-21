//
//  Strings.swift
//  Copyright © 2025 Jason Fieldman.
//

// This file was auto-generated with https://github.com/yonaskolb/Stringly
// swiftlint:disable all

import Foundation

public enum Z {
    public enum general: StringGroup {
        public static let localizationKey = "general"
        /// Coaster Pal
        public static let coasterPal = Z.localized("coasterPal", in: localizationKey)
    }

    public enum parks: StringGroup {
        public static let localizationKey = "parks"
        /// Parks
        public static let navigationTitle = Z.localized("navigationTitle", in: localizationKey)
    }
}

public protocol StringGroup {
    static var localizationKey: String { get }
}

public extension StringGroup {
    static func string(for key: String, _ args: CVarArg...) -> String {
        Z.localized(key: "\(localizationKey).\(key)", args: args)
    }
}

extension Z {
    /// The bundle uses for localization
    public static let bundle: Bundle = .init(for: BundleToken.self)

    /// Allows overriding any particular key, for A/B tests for example. Values need to be correct for the current language
    public static let overrides: [String: String] = [:]

    fileprivate static func localized(_ key: String, in group: String, _ args: CVarArg...) -> String {
        Z.localized(key: "\(group).\(key)", args: args)
    }

    fileprivate static func localized(_ key: String, _ args: CVarArg...) -> String {
        Z.localized(key: key, args: args)
    }

    fileprivate static func localized(key: String, args: [CVarArg]) -> String {
        let format = overrides[key] ?? NSLocalizedString(key, tableName: "Strings", bundle: bundle, comment: "")
        return String(format: format, locale: Locale.current, arguments: args)
    }
}

private final class BundleToken {}
