//
//  ErrorHandling.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

public enum CommandError: Int {
  case configNotFound = 1
  case configNotDecodable
  case noDependencies
  case duplicateDependencies
  case noDependencyQualifier
  case fileError
  case swiftPackageManager
}

public func throwError(_ error: CommandError, _ additionalDesc: String?) -> Never {
  if let additionalDesc {
    vprint(.error, additionalDesc)
  }
  exit(Int32(error.rawValue))
}
