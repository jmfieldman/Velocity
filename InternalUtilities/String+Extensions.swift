//
//  String+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import CommonCrypto
import Foundation

public extension String {
  /// Returns a version of the string that is safe to use as a directory name.
  /// Replaces all non-alphanumeric characters with underscore (_).
  ///
  /// Note this is only an appropriate mechanism for strings that are mostly
  /// appropriate already and will have a high degree of uniqueness after
  /// filtering.
  ///
  /// e.g. "https://github.com/test.git" -> "https___github_com_test_git"
  func safeDirectoryName() -> String {
    map { char -> String in
      guard let firstScalar = char.unicodeScalars.first else { return "_" }
      if CharacterSet.alphanumerics.contains(firstScalar) {
        return String(char)
      } else {
        return "_"
      }
    }.joined().lowercased()
  }

  /// Creates the directory specified by the receiver if it doesn't already exist.
  func createDirectory() throws {
    try FileManager.default.createDirectory(atPath: self, withIntermediateDirectories: true)
  }

  /// Returns true if this path is an existing file
  var isFile: Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: self, isDirectory: &isDirectory)
    return exists && !isDirectory.boolValue
  }

  /// Returns true if this path is an existing directory
  var isDirectory: Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: self, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }

  func fileURL() -> URL {
    URL(fileURLWithPath: self, isDirectory: false, relativeTo: nil)
  }

  func directoryURL() -> URL {
    URL(fileURLWithPath: self, isDirectory: true, relativeTo: nil)
  }

  var fileName: String {
    (self as NSString).lastPathComponent
  }

  func prepending(path: String) -> String {
    hasPrefix("/") ? self : "\(path.appendingMissingSlash())\(self)"
  }

  func prependingCurrentDirectory() -> String {
    prepending(path: FileManager.default.currentDirectoryPath)
  }

  func appendingMissingSlash() -> String {
    hasSuffix("/") ? self : "\(self)/"
  }

  func removingSlash() -> String {
    hasSuffix("/") ? String(dropLast()) : self
  }

  func removingSuffix(_ suffix: String) -> String {
    hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
  }

  var basePath: String {
    (self as NSString).deletingLastPathComponent
  }

  var lastPathComponent: String {
    (self as NSString).lastPathComponent
  }

  func shaHash() -> String {
    shaData().map { String(format: "%02hhx", $0) }.joined()
  }

  func shaData() -> Data {
    let length = Int(CC_SHA256_DIGEST_LENGTH)
    let data = data(using: .utf8)!
    var result = Data(count: length)

    _ = result.withUnsafeMutableBytes { digest -> UInt8 in
      data.withUnsafeBytes { message -> UInt8 in
        if let addr = message.baseAddress, let bindMem = digest.bindMemory(to: UInt8.self).baseAddress {
          let len = CC_LONG(data.count)
          CC_SHA256(addr, len, bindMem)
        }
        return 0
      }
    }

    return result
  }

  func relative(to path: String) -> String {
    guard hasPrefix("/") else {
      fatalError("asRelativePath used on a non-absolute receiver: \(self)")
    }

    guard path.hasPrefix("/") else {
      fatalError("asRelativePath used on a non-absolute argument: \(path)")
    }

    let receiverComponents = split(separator: "/")
    let pathComponents = path.split(separator: "/")
    var similarComponentCount = 0

    while
      receiverComponents.count > similarComponentCount,
      pathComponents.count > similarComponentCount,
      receiverComponents[similarComponentCount] == pathComponents[similarComponentCount]
    {
      similarComponentCount += 1
    }

    if similarComponentCount == receiverComponents.count {
      return ""
    }

    let remainingSelfItems = receiverComponents[similarComponentCount ..< receiverComponents.count]
    let remainingSelfPath = remainingSelfItems.joined(separator: "/")

    let remainingPathItems = pathComponents.count - similarComponentCount
    if remainingPathItems > 0 {
      let backPath = [String](repeating: "..", count: remainingPathItems).joined(separator: "/")
      return "\(backPath)/\(remainingSelfPath)"
    } else {
      return remainingSelfPath
    }
  }
}
