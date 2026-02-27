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

struct A2UICheckBox: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(CheckBoxProperties.self) {
            let label = viewModel.resolveString(
                props.label, dataContextPath: dataContextPath
            )
            let cbStyle = style.checkBoxStyle
            let _ = viewModel.resolveBoolean(props.value, dataContextPath: dataContextPath)
            let msgs = a2uiChecksMessages(for: props.checks, viewModel: viewModel, dataContextPath: dataContextPath)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: a2uiBoolBinding(for: props.value, viewModel: viewModel, dataContextPath: dataContextPath)) {
                    Text(label)
                        .font(cbStyle.labelFont)
                        .foregroundStyle(cbStyle.labelColor ?? .primary)
                }
                .tint(cbStyle.tintColor)

                ForEach(msgs, id: \.self) { msg in
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("CheckBox") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["cb1","cb2"]}}}},{"id":"cb1","component":{"CheckBox":{"label":{"literalString":"Accept Terms"},"value":{"path":"/terms"}}}},{"id":"cb2","component":{"CheckBox":{"label":{"literalString":"Subscribe to Newsletter"},"value":{"path":"/newsletter"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"terms","valueBool":true},{"key":"newsletter","valueBool":false}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
