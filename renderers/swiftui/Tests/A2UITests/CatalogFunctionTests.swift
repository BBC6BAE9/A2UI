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

final class CatalogFunctionTests: XCTestCase {

    // MARK: - Catalog Function Evaluation

    func testFormatNumberLiteral() {
        let vm = SurfaceViewModel()
        let call: AnyCodable = .dictionary([
            "call": .string("formatNumber"),
            "args": .dictionary(["value": .number(1234.5)])
        ])
        let result = CatalogFunctionEvaluator.evaluate(call, viewModel: vm, dataContextPath: "/")
        XCTAssertNotNil(result.stringValue)
    }

    func testFormatCurrencyWithCode() {
        let vm = SurfaceViewModel()
        let call: AnyCodable = .dictionary([
            "call": .string("formatCurrency"),
            "args": .dictionary([
                "value": .number(9.99),
                "currency": .string("USD")
            ])
        ])
        let result = CatalogFunctionEvaluator.evaluate(call, viewModel: vm, dataContextPath: "/")
        XCTAssertNotNil(result.stringValue)
        XCTAssertTrue(result.stringValue!.contains("9.99") || result.stringValue!.contains("9,99"))
    }

    func testFormatDateISO() {
        let vm = SurfaceViewModel()
        let call: AnyCodable = .dictionary([
            "call": .string("formatDate"),
            "args": .dictionary([
                "value": .string("2026-01-15T10:30:00Z"),
                "format": .string("yyyy-MM-dd")
            ])
        ])
        let result = CatalogFunctionEvaluator.evaluate(call, viewModel: vm, dataContextPath: "/")
        XCTAssertEqual(result.stringValue, "2026-01-15")
    }

    func testPluralizeZeroOneOther() {
        let vm = SurfaceViewModel()
        func plural(_ count: Double) -> String {
            let call: AnyCodable = .dictionary([
                "call": .string("pluralize"),
                "args": .dictionary([
                    "value": .number(count),
                    "zero": .string("no items"),
                    "one": .string("1 item"),
                    "other": .string("\(Int(count)) items")
                ])
            ])
            return CatalogFunctionEvaluator.evaluateAsString(call, viewModel: vm, dataContextPath: "/")
        }
        XCTAssertEqual(plural(0), "no items")
        XCTAssertEqual(plural(1), "1 item")
        XCTAssertEqual(plural(5), "5 items")
    }

    func testUnknownFunctionReturnsNull() {
        let vm = SurfaceViewModel()
        let call: AnyCodable = .dictionary([
            "call": .string("nonExistentFunction"),
            "args": .dictionary([:])
        ])
        let result = CatalogFunctionEvaluator.evaluate(call, viewModel: vm, dataContextPath: "/")
        XCTAssertTrue({ if case .null = result { return true }; return false }(), "Unknown function should return null")
    }

    func testMalformedFunctionCallReturnsNull() {
        let vm = SurfaceViewModel()
        let result = CatalogFunctionEvaluator.evaluate(.string("not a dict"), viewModel: vm, dataContextPath: "/")
        XCTAssertTrue({ if case .null = result { return true }; return false }(), "Malformed call should return null")
    }

    // MARK: - InterpolateTemplate

    func testInterpolateTemplatePath() {
        let vm = SurfaceViewModel()
        vm.dataModel["name"] = .string("World")
        let result = CatalogFunctionEvaluator.interpolateTemplate("Hello ${/name}!", viewModel: vm, ctx: "/")
        XCTAssertEqual(result, "Hello World!")
    }

    func testInterpolateTemplateEscaped() {
        let vm = SurfaceViewModel()
        let result = CatalogFunctionEvaluator.interpolateTemplate("Price: \\${100}", viewModel: vm, ctx: "/")
        XCTAssertEqual(result, "Price: ${100}")
    }

    func testInterpolateTemplateMissingPath() {
        let vm = SurfaceViewModel()
        let result = CatalogFunctionEvaluator.interpolateTemplate("Hi ${/unknown}!", viewModel: vm, ctx: "/")
        XCTAssertEqual(result, "Hi !")
    }

    // MARK: - ParseDate

    func testParseDateFormats() {
        XCTAssertNotNil(CatalogFunctionEvaluator.parseDate("2026-01-15"))
        XCTAssertNotNil(CatalogFunctionEvaluator.parseDate("2026-01-15T10:30:00Z"))
        XCTAssertNotNil(CatalogFunctionEvaluator.parseDate("2026-01-15T10:30:00.000Z"))
        XCTAssertNotNil(CatalogFunctionEvaluator.parseDate("2026-01-15T10:30:00"))
        XCTAssertNil(CatalogFunctionEvaluator.parseDate(""))
        XCTAssertNil(CatalogFunctionEvaluator.parseDate("not-a-date"))
    }
}
