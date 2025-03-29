//
//  ErrorHandling.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

public enum CommandErrorType: Int {
    case configNotFound = 1
    case configNotDecodable
    case noDependencies
    case duplicateDependencies
    case noDependencyQualifier
    case fileError
    case swiftPackageManager
    case invalidDate
    case pathNotFound
    case invalidArgument
}

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
}

public func throwError(_ error: CommandError, _ additionalDesc: String?) throws -> Never {
    if let additionalDesc {
        vprint(.error, additionalDesc)
    }
    throw error
}

public func exitWithErrorType(_ error: CommandErrorType, _ additionalDesc: String?) -> Never {
    if let additionalDesc {
        vprint(.error, additionalDesc)
    }
    exit(Int32(error.rawValue))
}
