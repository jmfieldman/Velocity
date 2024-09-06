//
//  WorkspaceState+Extensions.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

extension WorkspaceState {
  func dependency(withIdentifier id: String?) -> WorkspaceStateDependency? {
    guard let id else { return nil }
    return object?.dependencies?.first {
      $0.packageRef?.identity == id
    }
  }
}

extension WorkspaceStateDependency {
  var displayName: String {
    packageRef?.name ?? packageRef?.identity ?? "??"
  }

  var displayVersion: String {
    state?.checkoutState?.version ?? state?.checkoutState?.revision ?? "??"
  }

  var displayTuple: String {
    "[\(displayName) @ \(displayVersion)]"
  }

  var versionForEquality: String {
    state?.checkoutState?.revision ?? state?.checkoutState?.version ?? "??"
  }
}

extension WorkspaceStateDependency: Comparable {
  static func < (lhs: WorkspaceStateDependency, rhs: WorkspaceStateDependency) -> Bool {
    lhs.displayTuple.lowercased() < rhs.displayTuple.lowercased()
  }

  static func == (lhs: WorkspaceStateDependency, rhs: WorkspaceStateDependency) -> Bool {
    lhs.displayTuple.lowercased() == rhs.displayTuple.lowercased()
  }
}
