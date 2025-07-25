//
//  Inject.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

public enum InjectionResolutionError: Error {
    case cycleDetected(stack: [String], keyName: String)
    case noResolutionBlock(type: String)
    case invalidReturnType(type: String)
    case unknown(error: Error)
}

/// This is the primary function to inject values into ivars:
///   `let myObj = Inject(SomeType.self)`
///   `let myObj: SomeType = Inject()`
public func Inject<T>(_ type: T.Type = T.self) -> T {
    do {
        return try InjectionManager.resolve(type)
    } catch {
        switch error {
        case let .cycleDetected(stack, keyName):
            fatalError("Resolution cycle detected: \(stack) -> \(keyName)")
        case let .noResolutionBlock(type):
            fatalError("No resolution block registered for type: \(type)")
        case let .invalidReturnType(type):
            fatalError("The resolution block for type [\(type)] did not return an instance of that type")
        case let .unknown(error):
            fatalError("Unexpected InjectError: \(error)")
        }
    }
}

public enum InjectionManager {
    /// This map contains the specified singleton generator functions
    /// for Injectable objects.
    private(set) static var injectableResolutionMap: [ObjectIdentifier: () -> Any] = [:]

    /// Contains the current container of resolved Injectables.
    private(set) static var currentInjectableContainer: [ObjectIdentifier: Any] = [:]

    /// A recursive lock protects Injectable resolution and allows
    /// arbitrarily deep re-entrant resolution
    static let injectableLock = NSRecursiveLock()

    /// Contains the current stack of actively resolving Injectables (to
    /// detect infinite-cycles during resolution)
    private(set) static var resolutionStack: [String] = []
    private(set) static var resolutionStackSet: Set<ObjectIdentifier> = []

    /// Set this to true to detect resolution cycles during the `resolve`
    /// function. Useful in debug builds.
    public static var detectResolutionCycles: Bool = false

    /// Register a resolution function for the specified type.
    public static func register<T>(_ type: T.Type, _ resolutionFunction: @escaping () -> T) {
        injectableLock.withLock {
            injectableResolutionMap[ObjectIdentifier(type)] = resolutionFunction
        }
    }

    /// Resolve the specified type into its singleton instance contained
    /// in the current injectable container. Optionally performs resolution
    /// cycle detection if `detectResolutionCycles` is true.
    public static func resolve<T>(_ type: T.Type) throws(InjectionResolutionError) -> T {
        let key = ObjectIdentifier(type)

        do {
            return try injectableLock.withLock {
                if detectResolutionCycles {
                    if resolutionStackSet.contains(key) {
                        throw InjectionResolutionError.cycleDetected(stack: resolutionStack, keyName: String(describing: type))
                    }

                    resolutionStack.append(String(describing: type))
                    resolutionStackSet.insert(key)
                }

                if let cached = currentInjectableContainer[key] as? T {
                    if detectResolutionCycles {
                        resolutionStack.removeLast()
                        resolutionStackSet.remove(key)
                    }

                    return cached
                }

                guard let resolutionBlock = injectableResolutionMap[key] else {
                    throw InjectionResolutionError.noResolutionBlock(type: String(describing: type))
                }

                guard let newObject = resolutionBlock() as? T else {
                    throw InjectionResolutionError.invalidReturnType(type: String(describing: type))
                }
                currentInjectableContainer[key] = newObject

                if detectResolutionCycles {
                    resolutionStack.removeLast()
                    resolutionStackSet.remove(key)
                }

                return newObject
            }
        } catch {
            if let error = error as? InjectionResolutionError {
                throw error
            } else {
                throw InjectionResolutionError.unknown(error: error)
            }
        }
    }

    /// Removes all instances for the current container.
    public static func resetCurrentContainer() {
        injectableLock.withLock {
            currentInjectableContainer = [:]
        }
    }

    static func resetResolutionMap() {
        injectableLock.withLock {
            injectableResolutionMap = [:]
        }
    }
}
