//
//  String+Extensions.swift
//  Copyright © 2023 Jason Fieldman.
//

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

  /// Prepends the receiver with the path argument.
  ///
  /// e.g. receiver = "info.txt"
  ///      path = "/tmp"
  ///      returns = "/tmp/info.txt"
  ///
  /// If the receiver already has a / prefix this command is ignored
  func prepending(directoryPath: String) -> String {
    guard !hasPrefix("/") else { return self }
    return "\(directoryPath.appendingSlashIfRequired())\(self)"
  }

  /// Prepends the current working directory to the receiver.
  /// If the receiver already has a / prefix this function is ignored.
  func prependingCurrentDirectoryPath() -> String {
    prepending(directoryPath: FileManager.default.currentDirectoryPath)
  }

  /// Appends a slash to the end of the string if it is not present.
  func appendingSlashIfRequired() -> String {
    hasSuffix("/") ? self : "\(self)/"
  }

  /// Removes a trailing slash if present
  func deletingTrailingSlash() -> String {
    if hasSuffix("/") {
      return String(dropLast(1))
    }
    return self
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

  /// Creates the directory specified by the receiver if it doesn't already exist.
  func createDirectory() {
    do {
      try FileManager.default.createDirectory(atPath: self, withIntermediateDirectories: true)
    } catch {
      throwError(.fileError, "Could not create directory \(self): \(error.localizedDescription)")
    }
  }

  func asFileURL() -> URL {
    URL(fileURLWithPath: self, isDirectory: false, relativeTo: nil)
  }

  func asDirectoryURL() -> URL {
    URL(fileURLWithPath: self, isDirectory: true, relativeTo: nil)
  }
}

extension String {
  func dependencyUrlMatch(other: String) -> Bool {
    lowercased().hasPrefix(other.lowercased()) || other.lowercased().hasPrefix(lowercased())
  }
}

extension String {
  func firstNeedleValue(
    needleMap: [String: String]
  ) -> String? {
    let lowercaseHaystack = lowercased()
    return needleMap.keys
      .first { lowercaseHaystack.contains($0.lowercased()) }
      .flatMap { needleMap[$0] }
  }

  func replacePackageUrls(
    needleMap: [String: String]
  ) -> String {
    let separator = "|#!@"
    var linifiedString = components(separatedBy: .newlines).joined(separator: separator)

    let packageRegex = try! NSRegularExpression(pattern: "\\.package\\(.*?url:.*?\\)")
    let nameRegex = try! NSRegularExpression(pattern: "name: \".*?\"")

    let matches = packageRegex.matches(in: linifiedString, range: NSRange(linifiedString.startIndex..., in: linifiedString))
    for match in matches.reversed() {
      let matchedString = String(linifiedString[Range(match.range, in: linifiedString)!])
      let innerParens = matchedString.contains("(\"")

      let nameMatches = nameRegex.matches(in: matchedString, range: NSRange(matchedString.startIndex..., in: matchedString))
      var name = ""
      if nameMatches.count > 0 {
        name = String(matchedString[Range(nameMatches[0].range, in: matchedString)!])
        name = "\(name), "
      }

      if let replacementNeedle = matchedString.firstNeedleValue(needleMap: needleMap) {
        linifiedString = linifiedString.replacingCharacters(
          in: Range(match.range, in: linifiedString)!,
          with: ".package(\(name)path: \"\(replacementNeedle)\"\(innerParens ? "" : ")")"
        )
      }
    }

    return linifiedString.replacingOccurrences(of: separator, with: "\n")
  }

  func locationVariants() -> [String] {
    if hasPrefix("git") {
      return [self]
    }

    guard hasPrefix("http") else {
      return []
    }

    if hasSuffix(".git") {
      return [self, replacingOccurrences(of: ".git", with: "", options: [.anchored, .backwards])]
    }

    if hasSuffix("/") {
      return [self]
    }

    return [self, "\(self).git"]
  }
}
