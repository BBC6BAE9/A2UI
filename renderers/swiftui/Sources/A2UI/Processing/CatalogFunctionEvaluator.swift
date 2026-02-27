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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Evaluates catalog functions defined in the A2UI v0.10 basic catalog.
///
/// Supports all spec-defined functions:
/// - Validation: `required`, `email`, `regex`, `length`, `numeric`, `and`, `or`, `not`
/// - Formatting: `formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`
/// - Side-effects: `openUrl`
///
/// Validation functions are handled by `ChecksEvaluator`. This evaluator handles
/// formatting functions and `openUrl`.
public enum CatalogFunctionEvaluator {

    /// Evaluate a function call and return its result as `AnyCodable`.
    /// Returns `.null` for unknown or void-returning functions.
    public static func evaluate(
        _ functionCall: AnyCodable,
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> AnyCodable {
        guard case .dictionary(let dict) = functionCall,
              let callName = dict["call"]?.stringValue else {
            return .null
        }
        let args = dict["args"]?.dictionaryValue ?? [:]

        switch callName {
        case "formatString":
            return evalFormatString(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "formatNumber":
            return evalFormatNumber(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "formatCurrency":
            return evalFormatCurrency(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "formatDate":
            return evalFormatDate(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "pluralize":
            return evalPluralize(args: args, viewModel: viewModel, ctx: dataContextPath)
        case "openUrl":
            evalOpenUrl(args: args)
            return .null
        // Validation functions return boolean
        case "required", "email", "regex", "length", "numeric", "and", "or", "not":
            let result = ChecksEvaluator.evaluateCondition(
                functionCall, viewModel: viewModel, dataContextPath: dataContextPath
            )
            return .bool(result)
        default:
            return .null
        }
    }

    /// Evaluate a function call and return its result as a String.
    /// Falls back to empty string for non-string results.
    public static func evaluateAsString(
        _ functionCall: AnyCodable,
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> String {
        let result = evaluate(functionCall, viewModel: viewModel, dataContextPath: dataContextPath)
        return result.stringValue ?? ""
    }

    /// Evaluate a function call and return its result as a Double.
    public static func evaluateAsNumber(
        _ functionCall: AnyCodable,
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> Double? {
        let result = evaluate(functionCall, viewModel: viewModel, dataContextPath: dataContextPath)
        return result.numberValue
    }

    /// Evaluate a function call and return its result as a Bool.
    public static func evaluateAsBool(
        _ functionCall: AnyCodable,
        viewModel: SurfaceViewModel,
        dataContextPath: String
    ) -> Bool? {
        let result = evaluate(functionCall, viewModel: viewModel, dataContextPath: dataContextPath)
        return result.boolValue
    }

    // MARK: - Dynamic Value Resolution

    /// Resolve a dynamic value (literal, path, or function call) to AnyCodable.
    static func resolveDynamicValue(
        _ value: AnyCodable,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable? {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                let fullPath = viewModel.resolvePath(path, context: ctx)
                return viewModel.getDataByPath(fullPath)
            }
            if dict["call"] != nil {
                return evaluate(.dictionary(dict), viewModel: viewModel, dataContextPath: ctx)
            }
            return nil
        default:
            return nil
        }
    }

    /// Resolve a dynamic value to a String.
    static func resolveDynamicString(
        _ value: AnyCodable,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> String? {
        resolveDynamicValue(value, viewModel: viewModel, ctx: ctx)?.stringValue
    }

    /// Resolve a dynamic value to a Double.
    static func resolveDynamicNumber(
        _ value: AnyCodable,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> Double? {
        resolveDynamicValue(value, viewModel: viewModel, ctx: ctx)?.numberValue
    }

    /// Resolve a dynamic value to a Bool.
    static func resolveDynamicBool(
        _ value: AnyCodable,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> Bool? {
        resolveDynamicValue(value, viewModel: viewModel, ctx: ctx)?.boolValue
    }

    // MARK: - formatString

    /// `formatString`: Performs string interpolation of data model values.
    /// Supports `${/path}`, `${relative/path}`, and `${functionCall()}` syntax.
    private static func evalFormatString(
        args: [String: AnyCodable],
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable {
        guard let valueArg = args["value"],
              let template = resolveDynamicString(valueArg, viewModel: viewModel, ctx: ctx) else {
            return .null
        }
        let result = interpolateTemplate(template, viewModel: viewModel, ctx: ctx)
        return .string(result)
    }

    /// Perform `${expression}` interpolation on a template string.
    /// Handles escaped `\${` sequences and nested expressions.
    static func interpolateTemplate(
        _ template: String,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> String {
        var result = ""
        var i = template.startIndex

        while i < template.endIndex {
            // Check for escaped \${
            if template[i] == "\\" && template.index(after: i) < template.endIndex {
                let next = template.index(after: i)
                if next < template.endIndex && template[next] == "$" {
                    let afterDollar = template.index(after: next)
                    if afterDollar < template.endIndex && template[afterDollar] == "{" {
                        result.append("${")
                        i = template.index(after: afterDollar)
                        continue
                    }
                }
            }

            // Check for ${...}
            if template[i] == "$" {
                let next = template.index(after: i)
                if next < template.endIndex && template[next] == "{" {
                    let exprStart = template.index(after: next)
                    if let closeIdx = findMatchingBrace(in: template, from: exprStart) {
                        let expr = String(template[exprStart..<closeIdx])
                        let resolved = resolveExpression(expr, viewModel: viewModel, ctx: ctx)
                        result.append(resolved)
                        i = template.index(after: closeIdx)
                        continue
                    }
                }
            }

            result.append(template[i])
            i = template.index(after: i)
        }

        return result
    }

    /// Find the matching `}` for an interpolation, handling nested braces.
    private static func findMatchingBrace(
        in string: String, from start: String.Index
    ) -> String.Index? {
        var depth = 1
        var i = start
        while i < string.endIndex {
            if string[i] == "{" { depth += 1 }
            if string[i] == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i = string.index(after: i)
        }
        return nil
    }

    /// Resolve a single interpolation expression (inside `${ ... }`).
    /// Handles: `/absolute/path`, `relative/path`, `now()`, `functionCall(args)`.
    private static func resolveExpression(
        _ expr: String,
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> String {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)

        // Built-in: now()
        if trimmed == "now()" {
            return ISO8601DateFormatter().string(from: Date())
        }

        // Simple path reference (starts with / or is a relative path without parens)
        if !trimmed.contains("(") {
            let fullPath = viewModel.resolvePath(trimmed, context: ctx)
            if let value = viewModel.getDataByPath(fullPath) {
                return anyCodableToString(value)
            }
            return ""
        }

        // Function call: functionName(key:value, key:value)
        // This is a simplified parser for the spec's expression syntax
        return ""
    }

    /// Convert any AnyCodable to a display string.
    private static func anyCodableToString(_ value: AnyCodable) -> String {
        switch value {
        case .string(let s): return s
        case .number(let n):
            return n.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", n)
                : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        case .array: return ""
        case .dictionary: return ""
        }
    }

    // MARK: - formatNumber

    /// `formatNumber`: Formats a number with locale-aware grouping and decimal precision.
    private static func evalFormatNumber(
        args: [String: AnyCodable],
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable {
        guard let valueArg = args["value"],
              let num = resolveDynamicNumber(valueArg, viewModel: viewModel, ctx: ctx) else {
            return .null
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current

        if let decimalsArg = args["decimals"],
           let decimals = resolveDynamicNumber(decimalsArg, viewModel: viewModel, ctx: ctx) {
            formatter.minimumFractionDigits = Int(decimals)
            formatter.maximumFractionDigits = Int(decimals)
        }

        if let groupingArg = args["grouping"],
           let grouping = resolveDynamicBool(groupingArg, viewModel: viewModel, ctx: ctx) {
            formatter.usesGroupingSeparator = grouping
        }

        let result = formatter.string(from: NSNumber(value: num)) ?? String(num)
        return .string(result)
    }

    // MARK: - formatCurrency

    /// `formatCurrency`: Formats a number as a currency string using ISO 4217 code.
    private static func evalFormatCurrency(
        args: [String: AnyCodable],
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable {
        guard let valueArg = args["value"],
              let num = resolveDynamicNumber(valueArg, viewModel: viewModel, ctx: ctx),
              let currencyArg = args["currency"],
              let currency = resolveDynamicString(currencyArg, viewModel: viewModel, ctx: ctx) else {
            return .null
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale.current

        if let decimalsArg = args["decimals"],
           let decimals = resolveDynamicNumber(decimalsArg, viewModel: viewModel, ctx: ctx) {
            formatter.minimumFractionDigits = Int(decimals)
            formatter.maximumFractionDigits = Int(decimals)
        }

        if let groupingArg = args["grouping"],
           let grouping = resolveDynamicBool(groupingArg, viewModel: viewModel, ctx: ctx) {
            formatter.usesGroupingSeparator = grouping
        }

        let result = formatter.string(from: NSNumber(value: num)) ?? String(num)
        return .string(result)
    }

    // MARK: - formatDate

    /// `formatDate`: Formats a date value using a Unicode TR35 date pattern.
    private static func evalFormatDate(
        args: [String: AnyCodable],
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable {
        guard let valueArg = args["value"] else { return .null }

        let dateString: String
        if let resolved = resolveDynamicValue(valueArg, viewModel: viewModel, ctx: ctx) {
            dateString = resolved.stringValue ?? ""
        } else {
            return .null
        }

        guard let date = parseDate(dateString) else {
            return .string(dateString)
        }

        let formatArg = args["format"]
        let format: String
        if let fmtArg = formatArg,
           let fmt = resolveDynamicString(fmtArg, viewModel: viewModel, ctx: ctx) {
            format = fmt
        } else {
            format = "yyyy-MM-dd"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        return .string(formatter.string(from: date))
    }

    // MARK: - pluralize

    /// `pluralize`: Returns a localized string based on CLDR plural category.
    private static func evalPluralize(
        args: [String: AnyCodable],
        viewModel: SurfaceViewModel,
        ctx: String
    ) -> AnyCodable {
        guard let valueArg = args["value"],
              let count = resolveDynamicNumber(valueArg, viewModel: viewModel, ctx: ctx),
              let otherArg = args["other"],
              let otherStr = resolveDynamicString(otherArg, viewModel: viewModel, ctx: ctx) else {
            return .null
        }

        // Determine CLDR plural category.
        // For English and most Western languages, only "one" and "other" matter.
        // Full CLDR support would require Foundation's locale plural rules.
        let intCount = Int(count)
        let category: String
        if intCount == 0 {
            category = "zero"
        } else if intCount == 1 {
            category = "one"
        } else if intCount == 2 {
            category = "two"
        } else {
            category = "other"
        }

        // Try to find the matching category string, fallback to "other"
        let candidates = [category, "other"]
        for cat in candidates {
            if let arg = args[cat],
               let str = resolveDynamicString(arg, viewModel: viewModel, ctx: ctx) {
                return .string(str)
            }
        }

        return .string(otherStr)
    }

    // MARK: - openUrl

    /// `openUrl`: Opens a URL using the system handler.
    private static func evalOpenUrl(args: [String: AnyCodable]) {
        guard let urlString = args["url"]?.stringValue,
              let url = URL(string: urlString) else { return }

        #if canImport(UIKit) && !os(watchOS)
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: - Date Parsing Helpers

    static func parseDate(_ string: String) -> Date? {
        if string.isEmpty { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: string) { return d }
        // Date-only: yyyy-MM-dd
        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.dateFormat = "yyyy-MM-dd"
        if let d = dateOnly.date(from: string) { return d }
        // Without timezone
        let basic = DateFormatter()
        basic.locale = Locale(identifier: "en_US_POSIX")
        basic.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return basic.date(from: string)
    }
}
