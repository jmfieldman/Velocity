//
//  Dictionary+Extensions.swift
//  Copyright © 2021 Jason Fieldman.
//

import CommonCrypto
import Foundation

public extension Dictionary {
  func mapKeys<T>(_ keyBlock: (Key) -> T?) -> [T: Value] {
    var result: [T: Value] = [:]
    for key in keys {
      if let newKey = keyBlock(key) {
        result[newKey] = self[key]
      }
    }
    return result
  }
}
