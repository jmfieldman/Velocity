//
//  FileManager+Extensions.swift
//  Copyright © 2020 Jason Fieldman.
//

import Crypto
import Foundation

public extension FileManager {
  func sha(file: String) -> String? {
    guard file.isFile else {
      return nil
    }

    guard let data = try? Data(contentsOf: file.asFileURL()) else {
      return nil
    }

    let sha = SHA256.hash(data: data)
    return sha.compactMap { String(format: "%02x", $0) }.joined()
  }

  func sha(contentsOf directory: String) -> String? {
    guard directory.isDirectory else {
      return nil
    }

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
      return nil
    }

    var shasum = ""
    for file in files.sorted() {
      guard !file.hasPrefix(".") else {
        continue
      }

      let filePath = file.prepending(directoryPath: directory)
      guard !filePath.isDirectory else {
        continue
      }

      guard let filesha = sha(file: filePath) else {
        return nil
      }

      shasum += filesha
    }

    guard let shasumData = shasum.data(using: .utf8) else {
      return nil
    }

    return SHA256.hash(data: shasumData).compactMap { String(format: "%02x", $0) }.joined()
  }

  /// Enumerate directory trees using a modern callback approach.
  ///
  /// The path string can be relative (not prepended by slash) or
  /// absolute (prepended by slash).  In the relative case, this enumerator
  /// will internally prepend the working directory to path for enumeration.
  ///
  /// Each String parameter to the itemHandler will match the URL passed
  /// from the DirectoryEnumerator (it will be the pull).
  ///
  /// The function returns false if path is not a directory, or if the
  /// enumerator failed to instantiate.
  @discardableResult func enumerate(
    path: String,
    includingPropertiesForKeys properties: [URLResourceKey]? = nil,
    options: FileManager.DirectoryEnumerationOptions = [],
    errorHandler: ((URL, Error) -> Bool)? = nil,
    itemHandler: (String, FileManager.DirectoryEnumerator?) -> Void
  ) -> Bool {
    let fullPath = path.prependingCurrentDirectoryPath()
    let url = URL(fileURLWithPath: fullPath)
    guard fullPath.isDirectory else { return false }

    guard let enumerator = enumerator(
      at: url,
      includingPropertiesForKeys: properties,
      options: options,
      errorHandler: errorHandler
    ) else { return false }

    while let subPath = enumerator.nextObject() as? URL {
      itemHandler(subPath.path, enumerator)
    }

    return true
  }
}
