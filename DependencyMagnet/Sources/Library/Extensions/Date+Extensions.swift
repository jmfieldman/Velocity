//
//  Date+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

extension Date {
    func iso8601() -> String {
        ISO8601DateFormatter().string(for: self) ?? "??"
    }
}
