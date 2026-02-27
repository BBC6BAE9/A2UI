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

struct A2UISlider: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(SliderProperties.self) {
            let minVal = props.min
            let maxVal = props.max
            let sliderStyle = style.sliderStyle
            let _ = viewModel.resolveNumber(props.value, dataContextPath: dataContextPath)
            let binding = a2uiDoubleBinding(for: props.value, fallback: minVal, viewModel: viewModel, dataContextPath: dataContextPath)
            let msgs = a2uiChecksMessages(for: props.checks, viewModel: viewModel, dataContextPath: dataContextPath)

            VStack(alignment: .leading, spacing: 4) {
                if let labelValue = props.label {
                    let labelText = viewModel.resolveString(
                        labelValue, dataContextPath: dataContextPath
                    )
                    HStack {
                        Text(labelText)
                            .font(sliderStyle.labelFont)
                            .foregroundStyle(sliderStyle.labelColor ?? .primary)
                        Spacer()
                        Text(sliderStyle.valueFormatter(binding.wrappedValue))
                            .font(sliderStyle.valueFont ?? .body.monospacedDigit())
                            .foregroundStyle(sliderStyle.valueColor ?? .secondary)
                    }
                }
                #if os(tvOS)
                HStack {
                    Button {
                        binding.wrappedValue = max(minVal, binding.wrappedValue - (maxVal - minVal) / 20)
                    } label: {
                        Image(systemName: "minus")
                    }
                    ProgressView(value: binding.wrappedValue, total: maxVal - minVal)
                    Button {
                        binding.wrappedValue = min(maxVal, binding.wrappedValue + (maxVal - minVal) / 20)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #else
                SwiftUI.Slider(value: binding, in: minVal...maxVal)
                    .tint(sliderStyle.tintColor)
                #endif

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

#Preview("Slider - Basic") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Slider":{"value":{"path":"/val"},"min":0,"max":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"val","valueNumber":50}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Slider - With Label") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Slider":{"label":{"literalString":"Volume"},"value":{"path":"/volume"},"min":0,"max":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"volume","valueNumber":50}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
