//
//  SwiftImportDetector.swift
//  Copyright © 2021 Jason Fieldman.
//

import Foundation

private extension String {
  var isSwift: Bool {
    hasSuffix(".swift")
  }
}

public enum SwiftImportDetector {
  public static func execute(
    path: String,
    deepSearch: Bool,
    ignoreFilenames: Set<String>
  ) -> Set<String>? {
    var isDirectory: ObjCBool = true
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
      return nil
    }

    guard isDirectory.boolValue else {
      return (path.isSwift && !ignoreFilenames.contains(path.fileName)) ? imports(at: path) : nil
    }

    return FileManager.default.enumerateMap(
      path: path,
      options: deepSearch ? [] : [.skipsSubdirectoryDescendants]
    ) { file, _ in
      file.isSwift && !ignoreFilenames.contains(file.fileName) ? imports(at: file) : nil
    }?.reduce(into: Set<String>()) { accumulator, next in
      accumulator.formUnion(next)
    }
  }

  private static func imports(at path: String) -> Set<String> {
    guard let lineReader = LineReader(path: path) else {
      return []
    }

    let whitespacesAndNewlines = CharacterSet.whitespacesAndNewlines
    var results: Set<String> = []
    for line in lineReader {
      let cleanLine = line.trimmingCharacters(in: whitespacesAndNewlines)

      if cleanLine.hasPrefix("/") || cleanLine.hasPrefix(" ") || cleanLine.count == 0 {
        continue
      }

      if !cleanLine.hasPrefix("import"), !cleanLine.hasPrefix("@testable"), !cleanLine.hasPrefix("@_exported") {
        return results
      }

      results.insert(cleanLine.components(separatedBy: " ").last!)
    }

    return results
  }
}
