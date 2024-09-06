//
//  FileManager+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import Crypto
import Foundation
import InternalUtilities

public extension FileManager {
  func sha(file: String) -> String? {
    guard file.isFile else {
      return nil
    }

    guard let data = try? Data(contentsOf: file.fileURL()) else {
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
      guard !(file.hasPrefix(".") || file.hasPrefix("Package")) else {
        continue
      }

      let filePath = file.prepending(path: directory)
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
}
