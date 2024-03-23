//
//  DependenciesConfig+Extensions.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

extension Dependency {
  private var packageQualifier: (label: String, value: String) {
    if let from {
      return ("from: ", from)
    }
    if let range {
      return ("", range)
    }
    if let closedRange {
      return ("", closedRange)
    }
    if let branch {
      return ("branch: ", branch)
    }
    if let revision {
      return ("revision: ", revision)
    }
    if let exact {
      return ("exact: ", exact)
    }
    throwError(.noDependencyQualifier, "Dependency \(url) does not have a qualifier")
  }

  var packageString: String {
    let qualifier = packageQualifier
    return ".package(url: \"\(url)\", \(qualifier.label)\"\(qualifier.value)\")"
  }
}
