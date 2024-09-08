//
//  WorkspaceState+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import InternalUtilities

extension WorkspaceState {
  func dependency(withIdentifier id: String?) -> WorkspaceStateDependency? {
    guard let id else { return nil }
    return object?.dependencies?.first {
      $0.packageRef?.identity == id
    }
  }

  public static func from(workspacePath: String) -> WorkspaceState? {
    let workspaceStateJSONPath = kWorkspaceStateJsonPath.prepending(path: workspacePath)

    do {
      let data = try Data(contentsOf: workspaceStateJSONPath.prependingCurrentDirectory().fileURL())
      return try JSONDecoder().decode(WorkspaceState.self, from: data)
    } catch {
      return nil
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
