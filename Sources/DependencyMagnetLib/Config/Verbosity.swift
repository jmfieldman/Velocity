//
//  Verbosity.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

var gVerbosityLevel: Verbosity = .normal

public enum Verbosity: Int {
  case error = -1
  case quiet = 0
  case normal = 1
  case verbose = 2
  case debug = 3

  var name: String {
    switch self {
    case .error: "error"
    case .quiet: "quiet"
    case .normal: "normal"
    case .verbose: "verbose"
    case .debug: "debug"
    }
  }
}

public func setVerbosity(_ verbosity: Verbosity) {
  gVerbosityLevel = verbosity
  vprint(.verbose, "Verbosity: \(gVerbosityLevel.name)")
}

func vprint(_ verboseness: Verbosity, _ str: String) {
  if verboseness == .error {
    fputs(str + "\n", stderr)
    return
  }

  if verboseness.rawValue <= gVerbosityLevel.rawValue {
    print(str)
  }
}
