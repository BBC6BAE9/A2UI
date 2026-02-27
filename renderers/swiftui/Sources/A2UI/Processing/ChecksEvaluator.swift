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

import Foundation

/// Evaluates v0.9 `checks` conditions against the current data model.
///
/// Supports the standard validation functions defined in the A2UI spec:
/// `required`, `email`, `regex`, `length`, `numeric`, `and`, `or`, `not`.
public enum ChecksEvaluator {

    /// Returns the error messages for all checks that **fail**.
    /// An empty array means all checks pass.
    public static func failedMessages(
        checks: [CheckRule],
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> [String] {
        checks.compactMap { check in
            let passed = evaluateCondition(
                check.condition,
                viewModel: viewModel,
                dataContextPath: dataContextPath
            )
            return passed ? nil : check.message
        }
    }

    /// Returns `true` when **all** checks pass (or when the array is empty).
    public static func allPass(
        checks: [CheckRule],
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> Bool {
        checks.allSatisfy { check in
            evaluateCondition(
                check.condition,
                viewModel: viewModel,
                dataContextPath: dataContextPath
            )
        }
    }

    // MARK: - Condition Evaluation

    /// Recursively evaluate a condition (function call) and return a boolean.
    /// Unknown functions or malformed structures are treated as passing.
    static func evaluateCondition(
        _ condition: AnyCodable,
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> Bool {
        guard case .dictionary(let dict) = condition,
              let callName = dict["call"]?.stringValue else {
            return true
        }
        let args = dict["args"]?.dictionaryValue ?? [:]

        switch callName {
        case "required":
            return evalRequired(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "email":
            return evalEmail(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "regex":
            return evalRegex(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "length":
            return evalLength(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "numeric":
            return evalNumeric(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "and":
            return evalAnd(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "or":
            return evalOr(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "not":
            return evalNot(args: args, viewModel: viewModel, ctx: dataContextPath)
        default:
            return true
        }
    }

    // MARK: - Dynamic Value Resolution

    /// Resolve a dynamic value from a check arg.
    /// Handles: path references, literal values, nested function calls.
    private static func resolveValue(
        _ value: AnyCodable,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable? {
        switch value {
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                let fullPath = viewModel.resolvePath(path, context: ctx)
                return viewModel.getDataByPath(fullPath)
            }
            if dict["call"] != nil {
                return .bool(evaluateCondition(value, viewModel: viewModel, dataContextPath: ctx))
            }
            if let s = dict["literalString"]?.stringValue { return .string(s) }
            if let n = dict["literalNumber"]?.numberValue { return .number(n) }
            if let b = dict["literalBoolean"]?.boolValue { return .bool(b) }
            return nil
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        default: return nil
        }
    }

    private static func resolveStringValue(
        _ value: AnyCodable,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> String? {
        resolveValue(value, viewModel: viewModel, ctx: ctx)?.stringValue
    }

    // MARK: - Function Implementations

    /// `required`: value must not be nil, empty string, or empty array.
    private static func evalRequired(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let valueArg = args["value"] else { return true }
        guard let resolved = resolveValue(valueArg, viewModel: viewModel, ctx: ctx) else {
            return false
        }
        switch resolved {
        case .null: return false
        case .string(let s): return !s.isEmpty
        case .bool(let b): return b
        case .array(let arr): return !arr.isEmpty
        case .dictionary(let dict): return !dict.isEmpty
        case .number: return true
        }
    }

    /// `email`: value must match a basic email pattern.
    private static func evalEmail(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let valueArg = args["value"],
              let str = resolveStringValue(valueArg, viewModel: viewModel, ctx: ctx) else {
            return true
        }
        if str.isEmpty { return true }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return (try? Regex(pattern).wholeMatch(in: str)) != nil
    }

    /// `regex`: value must match the given pattern.
    private static func evalRegex(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let valueArg = args["value"],
              let patternArg = args["pattern"]?.stringValue,
              let str = resolveStringValue(valueArg, viewModel: viewModel, ctx: ctx) else {
            return true
        }
        if str.isEmpty { return true }
        return (try? Regex(patternArg).wholeMatch(in: str)) != nil
    }

    /// `length`: string length or array count must be within min/max bounds.
    private static func evalLength(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let valueArg = args["value"],
              let resolved = resolveValue(valueArg, viewModel: viewModel, ctx: ctx) else {
            return true
        }
        let count: Int
        switch resolved {
        case .string(let s): count = s.count
        case .array(let arr): count = arr.count
        default: return true
        }
        if let min = args["min"]?.numberValue, Double(count) < min { return false }
        if let max = args["max"]?.numberValue, Double(count) > max { return false }
        return true
    }

    /// `numeric`: number must be within min/max bounds.
    private static func evalNumeric(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let valueArg = args["value"],
              let resolved = resolveValue(valueArg, viewModel: viewModel, ctx: ctx),
              let num = resolved.numberValue else {
            return true
        }
        if let min = args["min"]?.numberValue, num < min { return false }
        if let max = args["max"]?.numberValue, num > max { return false }
        return true
    }

    /// `and`: all sub-conditions must be true.
    private static func evalAnd(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let values = args["values"]?.arrayValue else { return true }
        return values.allSatisfy { evaluateCondition($0, viewModel: viewModel, dataContextPath: ctx) }
    }

    /// `or`: at least one sub-condition must be true.
    private static func evalOr(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let values = args["values"]?.arrayValue else { return true }
        return values.contains { evaluateCondition($0, viewModel: viewModel, dataContextPath: ctx) }
    }

    /// `not`: inverts a single sub-condition.
    private static func evalNot(
        args: [String: AnyCodable], viewModel: SurfaceViewModel, ctx: String
    ) -> Bool {
        guard let valueArg = args["value"] else { return true }
        if case .dictionary(let dict) = valueArg, dict["call"] != nil {
            return !evaluateCondition(valueArg, viewModel: viewModel, dataContextPath: ctx)
        }
        guard let resolved = resolveValue(valueArg, viewModel: viewModel, ctx: ctx) else {
            return true
        }
        if let b = resolved.boolValue { return !b }
        return true
    }
}
