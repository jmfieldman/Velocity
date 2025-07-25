//
//  InjectTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import Inject
import XCTest

final class InjectTests: XCTestCase {
    override func setUp() {
        InjectionManager.resetCurrentContainer()
        InjectionManager.resetResolutionMap()
    }

    func testBasicResolution() {
        InjectionManager.register(ProtoA.self) { ClassA() }
        InjectionManager.register(ProtoB.self) { ClassB() }
        InjectionManager.register(ProtoC.self) { ClassC() }

        let i = Inject(ProtoC.self)
        XCTAssertNotNil(i)
    }

    func testNoResolutionBlock() {
        InjectionManager.register(ProtoA.self) { ClassA() }
        InjectionManager.register(ProtoC.self) { ClassC() }

        var testError: InjectionResolutionError?
        do {
            let _ = try InjectionManager.resolve(ProtoB.self)
        } catch {
            testError = error
        }

        if case let .noResolutionBlock(type) = testError {
            XCTAssertEqual(type, "ProtoB")
        } else {
            XCTFail("No error")
        }
    }
}

private protocol ProtoA {}
private class ClassA: ProtoA {}

private protocol ProtoB {}
private class ClassB: ProtoB {
    private let classA = Inject(ProtoA.self)
}

private protocol ProtoC {}
private class ClassC: ProtoC {
    private let classA = Inject(ProtoA.self)
    private let classB = Inject(ProtoB.self)
}
