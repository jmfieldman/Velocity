//
//  ErrorHandling.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

public enum CommandError: Error {
    case configNotFound
    case configNotDecodable
    case noDependencies
    case duplicateDependencies
    case noDependencyQualifier
    case fileError
    case swiftPackageManager
    case invalidDate
    case pathNotFound
    case invalidArgument
    case dependencyCycle
    case duplicateInjections
}

public func throwError(_ error: CommandError, _ additionalDesc: String?) throws -> Never {
    if let additionalDesc {
        vprint(.error, additionalDesc)
    }
    throw error
}
