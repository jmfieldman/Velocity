//
//  ModulePackageManager.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import InternalUtilities

public final class ModulePackageManager {
  /// A list of all packages
  public let packages: [ModulePackage]

  /// Module imports, keyed by Module name
  public private(set) lazy var importGraph: [String: Set<ModuleImport>] = Self.importGraph(packages: packages)

  public init(packages: [ModulePackage]) {
    self.packages = packages
  }

  /// Given a starting set of modules, returns all modules in the dependency tree
  /// beneath them (including the starting dependencies).
  public func fullDependencyList(for modules: [String]) -> Set<String> {
    // This operates essentially as an iterative BFS. Each module inserts its
    // unvisited dependencies into the to-check list.
    var toCheck = Set<String>(modules)
    var resultSet = Set<String>([])
    while let module = toCheck.first {
      toCheck.remove(module)
      resultSet.insert(module)

      guard let dependencySet = importGraph[module] else { continue }

      let dependencyNames = Set<String>(dependencySet.map(\.name))
      toCheck.formUnion(dependencyNames.subtracting(resultSet))
      resultSet.formUnion(dependencyNames)
    }
    return resultSet
  }
}

public extension ModulePackageManager {
  static func packages(named: String, root: String, absoluteProjectPath: String) -> [ModulePackage] {
    let nameSuffix = "/\(named)"

    return FileManager.default.enumerateMap(
      path: root,
      includingPropertiesForKeys: nil,
      options: [],
      errorHandler: nil
    ) { path, _ in
      guard path.hasSuffix(nameSuffix) else { return nil }

      guard let package = ModulePackage(packageFilePath: path, absoluteProjectPath: absoluteProjectPath) else {
        fatalError("Error creating ModulePackage from: \(path)")
      }

      return package
    } ?? []
  }
}

public class ModuleImport: Hashable {
  public let name: String
  public var bridge: ModuleType?

  init(name: String, bridge: ModuleType?) {
    self.name = name
    self.bridge = bridge
  }

  public static func == (lhs: ModuleImport, rhs: ModuleImport) -> Bool {
    lhs.name == rhs.name
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }
}

extension ModulePackageManager {
  static func importGraph(packages: [ModulePackage]) -> [String: Set<ModuleImport>] {
    var result: [String: Set<ModuleImport>] = [:]

    for package in packages {
      for module in package.modules.values {
        guard !result.keys.contains(module.name) else {
          fatalError("Import graph generation found invalid duplicate module: \(module.name)")
        }

        // Defer to primary imports; add bridge imports after
        var importSet = Set<ModuleImport>(module.importedModules.map { ModuleImport(name: $0, bridge: nil) })

        for bridgedType in module.type.bridgedSiblingImports {
          guard let bridgedModule = package.modules[bridgedType] else { continue }

          bridgedModule.importedModules
            .map { ModuleImport(name: $0, bridge: bridgedType) }
            .filter { $0.name != module.name && !importSet.contains($0) }
            .forEach { importSet.insert($0) }
        }

        result[module.name] = importSet
      }
    }

    return result
  }

  public func importCycle() -> [(String, ModuleImport)]? {
    let state = CycleEdgeState(modules: importGraph.keys.map { $0 })
    return importGraph
      .keys
      .firstMap {
        state.cycleEdges(module: $0, importGraph: importGraph)
      }
  }

  private class CycleEdgeState {
    var hasVisited: [String: Bool]
    var recursionStack: [String: Bool]

    init(modules: [String]) {
      self.hasVisited = .init(uniqueKeysWithValues: modules.map { ($0, false) })
      self.recursionStack = .init(uniqueKeysWithValues: modules.map { ($0, false) })
    }

    func cycleEdges(module: String, importGraph: [String: Set<ModuleImport>]) -> [(String, ModuleImport)]? {
      defer { recursionStack[module] = false }
      guard !hasVisited[module, default: false] else { return nil }

      hasVisited[module] = true
      recursionStack[module] = true

      return importGraph[module, default: []]
        .firstMap { moduleImport -> [(String, ModuleImport)]? in
          if !hasVisited[moduleImport.name, default: false] {
            return cycleEdges(module: moduleImport.name, importGraph: importGraph).map { [(module, moduleImport)] + $0 }
          } else if recursionStack[moduleImport.name, default: false] {
            return [(module, moduleImport)]
          } else {
            return nil
          }
        }
    }
  }
}
