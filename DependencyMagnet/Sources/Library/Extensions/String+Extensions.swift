//
//  String+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

extension String {
  func dependencyUrlMatch(other: String) -> Bool {
    let selfLower = lowercased()
    let otherLower = other.lowercased()

    if selfLower == otherLower { return true }
    if otherLower == "\(selfLower).git" { return true }
    if selfLower == "\(otherLower).git" { return true }
    return false
  }
}

extension String {
  func firstNeedleValue(
    needleMap: [String: String]
  ) -> String? {
    let lowercaseHaystack = lowercased()
    return needleMap.keys
      .sorted(by: { $0.count > $1.count })
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
      let innerParens = matchedString
        .replacingOccurrences(of: "package(", with: "")
        .contains("(")

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
