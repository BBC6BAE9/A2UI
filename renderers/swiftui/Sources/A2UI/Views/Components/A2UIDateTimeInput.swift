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

struct A2UIDateTimeInput: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(DateTimeInputProperties.self) {
            let _ = viewModel.resolveString(props.value, dataContextPath: dataContextPath)
            let enableDate = props.enableDate ?? true
            let enableTime = props.enableTime ?? true

            let labelText: String = {
                if let labelValue = props.label {
                    return viewModel.resolveString(labelValue, dataContextPath: dataContextPath)
                }
                if enableDate && enableTime { return "Date & Time" }
                if enableDate { return "Date" }
                if enableTime { return "Time" }
                return "Date & Time"
            }()

            let dtStyle = style.dateTimeInputStyle
            let msgs = a2uiChecksMessages(for: props.checks, viewModel: viewModel, dataContextPath: dataContextPath)

            #if os(tvOS)
            VStack(alignment: .leading, spacing: 4) {
                Text(labelText)
                    .font(dtStyle.labelFont)
                    .foregroundStyle(dtStyle.labelColor ?? .primary)
                Text(viewModel.resolveString(props.value, dataContextPath: dataContextPath))
                    .foregroundStyle(.secondary)

                ForEach(msgs, id: \.self) { msg in
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            #else
            let components: DatePicker.Components = {
                var c: DatePicker.Components = []
                if enableDate { c.insert(.date) }
                if enableTime { c.insert(.hourAndMinute) }
                if c.isEmpty { c = [.date, .hourAndMinute] }
                return c
            }()

            VStack(alignment: .leading, spacing: 4) {
                DatePicker(
                    selection: a2uiDateBinding(for: props.value, viewModel: viewModel, dataContextPath: dataContextPath),
                    displayedComponents: components
                ) {
                    Text(labelText)
                        .font(dtStyle.labelFont)
                        .foregroundStyle(dtStyle.labelColor ?? .primary)
                }
                .tint(dtStyle.tintColor)

                ForEach(msgs, id: \.self) { msg in
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            #endif
        }
    }
}

// MARK: - Previews

#Preview("DateTimeInput") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["dt1","dt2","dt3"]}}}},{"id":"dt1","component":{"DateTimeInput":{"label":{"literalString":"Date only"},"value":{"path":"/date"},"enableDate":true,"enableTime":false}}},{"id":"dt2","component":{"DateTimeInput":{"label":{"literalString":"Time only"},"value":{"path":"/time"},"enableDate":false,"enableTime":true}}},{"id":"dt3","component":{"DateTimeInput":{"label":{"literalString":"Date & Time"},"value":{"path":"/datetime"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"date","valueString":"2025-12-09"},{"key":"time","valueString":"14:30:00"},{"key":"datetime","valueString":"2025-12-09T14:30:00"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
