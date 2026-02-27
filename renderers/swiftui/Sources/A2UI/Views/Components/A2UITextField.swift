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

import SwiftUI

struct A2UITextField: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(TextFieldProperties.self) {
            let label = viewModel.resolveString(
                props.label, dataContextPath: dataContextPath
            )
            let binding = a2uiStringBinding(for: props.value, viewModel: viewModel, dataContextPath: dataContextPath)
            let fieldVariant = props.variant
            let msgs = a2uiChecksMessages(for: props.checks, viewModel: viewModel, dataContextPath: dataContextPath)

            A2UITextFieldView(
                label: label,
                text: binding,
                variant: fieldVariant,
                validationRegexp: props.validationRegexp,
                checkMessages: msgs
            )
        }
    }
}

// MARK: - A2UITextFieldView

/// Renders a TextField with variant support and regex validation.
/// Uses native SwiftUI controls: `TextField`, `SecureField`, `TextEditor`.
struct A2UITextFieldView: View {
    let label: String
    @Binding var text: String
    let variant: String?
    let validationRegexp: String?
    var checkMessages: [String] = []

    @Environment(\.a2uiStyle) private var style
    @State private var isValid = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldForVariant
                .focused($isFocused)
                .onChange(of: text) { validate($1) }
                .onChange(of: isFocused) { _, focused in
                    if !focused { validate(text) }
                }

            if !isValid {
                Text("Input does not match required format")
                    .font(.caption)
                    .foregroundStyle(style.textFieldStyle.errorColor)
            }

            ForEach(checkMessages, id: \.self) { msg in
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(style.textFieldStyle.errorColor)
            }
        }
    }

    @ViewBuilder
    private var fieldForVariant: some View {
        let tfStyle = style.textFieldStyle
        switch variant {
        case "obscured":
            SecureField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
        case "longText":
            #if os(watchOS) || os(tvOS)
            SwiftUI.TextField(label, text: $text)
            #else
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .frame(minHeight: tfStyle.longTextMinHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background {
                        if let bg = tfStyle.longTextBackgroundColor {
                            RoundedRectangle(cornerRadius: tfStyle.longTextCornerRadius, style: .continuous).fill(bg)
                        } else {
                            RoundedRectangle(cornerRadius: tfStyle.longTextCornerRadius, style: .continuous).fill(.fill.quaternary)
                        }
                    }
                    .clipShape(RoundedRectangle(
                        cornerRadius: tfStyle.longTextCornerRadius,
                        style: .continuous
                    ))
            }
            #endif
        case "number":
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        default:
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
        }
    }

    private func validate(_ value: String) {
        guard let pattern = validationRegexp, !pattern.isEmpty else {
            isValid = true
            return
        }
        isValid = value.isEmpty || (try? Regex(pattern).wholeMatch(in: value)) != nil
    }
}

// MARK: - Previews

#Preview("TextField - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Name"},"value":{"path":"/name"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"name","valueString":"Jane Doe"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Password") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Password"},"value":{"path":"/pw"},"variant":"obscured"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"pw","valueString":"secret"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Long Text") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Bio"},"value":{"path":"/bio"},"variant":"longText"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"bio","valueString":"Hello world"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Validation") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Email"},"value":{"path":"/email"},"validationRegexp":"^[\\\\w.+-]+@[\\\\w-]+\\\\.[a-zA-Z]{2,}$"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"email","valueString":"jane@example.com"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
