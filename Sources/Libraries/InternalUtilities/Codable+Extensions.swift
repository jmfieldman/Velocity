//
//  Codable+Extensions.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

public extension NSDictionary {
    /// Converts the dictionary to a deterministic string representation.
    /// Keys are sorted alphabetically, and nested dictionaries/arrays are recursively processed.
    func deterministicString() -> String {
        // Get and sort string keys
        guard let stringKeys = allKeys as? [String] else {
            fatalError("Dictionary keys are not strings")
        }

        let sortedKeys = stringKeys.sorted(by: <)
        var result = ""

        // Process each key-value pair in sorted order
        for key in sortedKeys {
            guard let item = value(forKey: key) else { continue }

            // Handle nested structures recursively
            switch item {
            case let dict as NSDictionary:
                result += "[\(key): \(dict.deterministicString())]"
            case let arr as NSArray:
                result += "[\(key): \(arr.deterministicString())]"
            default:
                result += "[\(key): \(item)]"
            }

            result += ","
        }

        return result
    }
}

public extension NSArray {
    /// Converts the array to a deterministic string representation.
    /// Nested dictionaries/arrays are recursively processed.
    func deterministicString() -> String {
        var result = "["

        // Process each item in the array
        for item in self {
            switch item {
            case let dict as NSDictionary:
                result += dict.deterministicString()
            case let arr as NSArray:
                result += arr.deterministicString()
            default:
                result += "\(item)"
            }

            result += ","
        }

        result += "]"
        return result
    }
}

public extension Encodable {
    /// Outputs a deterministic SHA1 hash for the contents of the Codable.
    /// The Codable is converted to a dictionary/array which is then string-ified
    /// in a deterministic fashion. This returns the hash of that string.
    func deterministicHash() -> String? {
        // Encode the Codable to JSON data
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }

        // Convert JSON data back to a dictionary or array
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }

        // Convert to deterministic string and hash it
        let stringToHash: String

        switch jsonObject {
        case let dict as NSDictionary:
            stringToHash = dict.deterministicString()
        case let arr as NSArray:
            stringToHash = arr.deterministicString()
        default:
            fatalError("JSON object is neither a dictionary nor an array")
        }

        return stringToHash.shaHash()
    }
}
