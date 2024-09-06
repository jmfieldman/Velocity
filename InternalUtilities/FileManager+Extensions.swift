//
//  FileManager+Extensions.swift
//  Copyright © 2020 Jason Fieldman.
//

import Foundation

public extension FileManager {
  func directoryExists(atPath path: String) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = fileExists(atPath: path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }

  @discardableResult func enumerateMap<T>(
    path: String,
    includingPropertiesForKeys properties: [URLResourceKey]? = nil,
    options: FileManager.DirectoryEnumerationOptions = [],
    errorHandler: ((URL, Error) -> Bool)? = nil,
    itemHandler: (String, FileManager.DirectoryEnumerator?) -> T?
  ) -> [T]? {
    let fullPath = path.prependingCurrentDirectory()
    guard directoryExists(atPath: fullPath) else {
      return nil
    }

    guard let enumerator = enumerator(
      at: URL(fileURLWithPath: fullPath),
      includingPropertiesForKeys: properties,
      options: options,
      errorHandler: errorHandler
    ) else {
      return nil
    }

    return enumerator.compactMap {
      ($0 as? URL).flatMap { url in itemHandler(url.path, enumerator) }
    }
  }
}
