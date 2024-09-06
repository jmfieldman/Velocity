//
//  WorkspaceState.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

struct WorkspaceState: Decodable {
  let object: WorkspaceStateObject?
}

struct WorkspaceStateObject: Decodable {
  let dependencies: [WorkspaceStateDependency]?
}

struct WorkspaceStateDependency: Decodable {
  let packageRef: WorkspaceStatePackageRef?
  let state: WorkspaceStateState?
  let subpath: String?
}

struct WorkspaceStatePackageRef: Decodable {
  let identity: String?
  let location: String?
  let name: String?
}

struct WorkspaceStateState: Decodable {
  let checkoutState: WorkspaceStateCheckoutState?
}

struct WorkspaceStateCheckoutState: Decodable {
  let revision: String?
  let version: String?
}
