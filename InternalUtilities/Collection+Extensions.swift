//
//  Collection+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

public extension Collection {
  func firstMap<T>(_ transform: (Element) -> T?) -> T? {
    for e in self {
      if let t = transform(e) {
        return t
      }
    }

    return nil
  }
}
