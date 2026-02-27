// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import A2UI

final class ValidationTests: XCTestCase {

    // MARK: - Checks / Validation Evaluation

    func testCheckRequired() {
        let vm = SurfaceViewModel()
        vm.dataModel["name"] = .string("Alice")
        vm.dataModel["empty"] = .string("")

        let filled: AnyCodable = .dictionary([
            "call": .string("required"),
            "args": .dictionary(["value": .dictionary(["path": .string("/name")])])
        ])
        XCTAssertTrue(ChecksEvaluator.evaluateCondition(filled, viewModel: vm, dataContextPath: "/"))

        let empty: AnyCodable = .dictionary([
            "call": .string("required"),
            "args": .dictionary(["value": .dictionary(["path": .string("/empty")])])
        ])
        XCTAssertFalse(ChecksEvaluator.evaluateCondition(empty, viewModel: vm, dataContextPath: "/"))
    }

    func testCheckEmail() {
        let vm = SurfaceViewModel()

        let valid: AnyCodable = .dictionary([
            "call": .string("email"),
            "args": .dictionary(["value": .string("user@example.com")])
        ])
        XCTAssertTrue(ChecksEvaluator.evaluateCondition(valid, viewModel: vm, dataContextPath: "/"))

        let invalid: AnyCodable = .dictionary([
            "call": .string("email"),
            "args": .dictionary(["value": .string("not-an-email")])
        ])
        XCTAssertFalse(ChecksEvaluator.evaluateCondition(invalid, viewModel: vm, dataContextPath: "/"))
    }

    func testCheckLength() {
        let vm = SurfaceViewModel()

        let tooShort: AnyCodable = .dictionary([
            "call": .string("length"),
            "args": .dictionary([
                "value": .string("ab"),
                "min": .number(3)
            ])
        ])
        XCTAssertFalse(ChecksEvaluator.evaluateCondition(tooShort, viewModel: vm, dataContextPath: "/"))

        let ok: AnyCodable = .dictionary([
            "call": .string("length"),
            "args": .dictionary([
                "value": .string("abc"),
                "min": .number(3), "max": .number(10)
            ])
        ])
        XCTAssertTrue(ChecksEvaluator.evaluateCondition(ok, viewModel: vm, dataContextPath: "/"))
    }

    func testCheckAndOr() {
        let vm = SurfaceViewModel()
        let t: AnyCodable = .dictionary(["call": .string("required"), "args": .dictionary(["value": .string("x")])])
        let f: AnyCodable = .dictionary(["call": .string("required"), "args": .dictionary(["value": .string("")])])

        let andBoth: AnyCodable = .dictionary([
            "call": .string("and"),
            "args": .dictionary(["values": .array([t, t])])
        ])
        XCTAssertTrue(ChecksEvaluator.evaluateCondition(andBoth, viewModel: vm, dataContextPath: "/"))

        let andMixed: AnyCodable = .dictionary([
            "call": .string("and"),
            "args": .dictionary(["values": .array([t, f])])
        ])
        XCTAssertFalse(ChecksEvaluator.evaluateCondition(andMixed, viewModel: vm, dataContextPath: "/"))

        let orMixed: AnyCodable = .dictionary([
            "call": .string("or"),
            "args": .dictionary(["values": .array([t, f])])
        ])
        XCTAssertTrue(ChecksEvaluator.evaluateCondition(orMixed, viewModel: vm, dataContextPath: "/"))
    }

    func testCheckNot() {
        let vm = SurfaceViewModel()
        let inner: AnyCodable = .dictionary(["call": .string("required"), "args": .dictionary(["value": .string("x")])])
        let notCall: AnyCodable = .dictionary([
            "call": .string("not"),
            "args": .dictionary(["value": inner])
        ])
        XCTAssertFalse(ChecksEvaluator.evaluateCondition(notCall, viewModel: vm, dataContextPath: "/"))
    }

    func testFailedMessagesIntegration() {
        let vm = SurfaceViewModel()
        vm.dataModel["email"] = .string("bad")
        let checks: [CheckRule] = [
            CheckRule(
                condition: .dictionary([
                    "call": .string("email"),
                    "args": .dictionary(["value": .dictionary(["path": .string("/email")])])
                ]),
                message: "Invalid email"
            )
        ]
        let msgs = ChecksEvaluator.failedMessages(checks: checks, viewModel: vm, dataContextPath: "/")
        XCTAssertEqual(msgs, ["Invalid email"])
    }
}
