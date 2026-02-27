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

struct A2UIChoicePicker: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(ChoicePickerProperties.self) {
            ChoicePickerNodeView(
                properties: props,
                uiState: node.uiState as? ChoicePickerUIState ?? ChoicePickerUIState(),
                viewModel: viewModel,
                dataContextPath: dataContextPath,
                checkMessages: a2uiChecksMessages(for: props.checks, viewModel: viewModel, dataContextPath: dataContextPath)
            )
        }
    }
}

// MARK: - ChoicePickerNodeView

/// Choice picker that reads filterText from `ChoicePickerUIState`.
struct ChoicePickerNodeView: View {
    let properties: ChoicePickerProperties
    var uiState: ChoicePickerUIState
    var viewModel: SurfaceViewModel
    var dataContextPath: String
    var checkMessages: [String] = []

    private var currentSelections: [String] {
        guard let val = properties.value else { return [] }
        return viewModel.resolveStringArray(val, dataContextPath: dataContextPath)
    }

    private var resolvedOptions: [(label: String, value: String)] {
        (properties.options ?? []).map { option in
            (
                label: viewModel.resolveString(option.label, dataContextPath: dataContextPath),
                value: option.value
            )
        }
    }

    private var filteredOptions: [(label: String, value: String)] {
        guard properties.filterable == true, !uiState.filterText.isEmpty else {
            return resolvedOptions
        }
        let query = uiState.filterText.lowercased()
        return resolvedOptions.filter { $0.label.lowercased().contains(query) }
    }

    private var isChips: Bool { properties.displayStyle == "chips" }
    private var isMutuallyExclusive: Bool { properties.variant == "mutuallyExclusive" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let labelVal = properties.label {
                let resolved = viewModel.resolveString(labelVal, dataContextPath: dataContextPath)
                if !resolved.isEmpty {
                    Text(resolved)
                        .font(.body.weight(.semibold))
                        .padding(.bottom, 8)
                        .padding(.leading, 16)
                }
            }

            if properties.filterable == true {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    SwiftUI.TextField("Filter options", text: Binding(
                        get: { uiState.filterText },
                        set: { uiState.filterText = $0 }
                    ))
                    .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if isChips {
                chipsLayout
            } else {
                checkboxLayout
            }

            ForEach(checkMessages, id: \.self) { msg in
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private var chipsLayout: some View {
        FlowLayout(spacing: 8) {
            ForEach(filteredOptions, id: \.value) { option in
                let selected = currentSelections.contains(option.value)
                Button {
                    toggle(option.value)
                } label: {
                    HStack(spacing: 4) {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                        }
                        Text(option.label)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(selected ? .accentColor : .secondary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var checkboxLayout: some View {
        selectionListLayout
    }

    /// Settings App style: text row with trailing checkmark for selected items.
    /// Used by both radio (mutuallyExclusive) and multi-select modes.
    @ViewBuilder
    private var selectionListLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredOptions, id: \.value) { option in
                let selected = currentSelections.contains(option.value)
                Button {
                    toggle(option.value)
                } label: {
                    HStack {
                        Text(option.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ value: String) {
        var selections = currentSelections
        if let idx = selections.firstIndex(of: value) {
            selections.remove(at: idx)
        } else {
            if isMutuallyExclusive {
                selections = [value]
            } else {
                if let max = properties.maxAllowedSelections, selections.count >= max {
                    return
                }
                selections.append(value)
            }
        }
        guard let path = properties.value?.path else { return }
        viewModel.setStringArray(
            path: path, values: selections, dataContextPath: dataContextPath
        )
    }
}

// MARK: - FlowLayout (Chips)

/// A simple wrapping horizontal layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions
        )
    }
}

// MARK: - Previews

#Preview("ChoicePicker - Chips") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Select tags"},"value":{"path":"/tags"},"displayStyle":"chips","options":[{"label":{"literalString":"Work"},"value":"work"},{"label":{"literalString":"Home"},"value":"home"},{"label":{"literalString":"Urgent"},"value":"urgent"},{"label":{"literalString":"Later"},"value":"later"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"tags","valueMap":[{"key":"0","valueString":"work"},{"key":"1","valueString":"urgent"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("ChoicePicker - Radio") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Choose one"},"value":{"path":"/pick"},"variant":"mutuallyExclusive","options":[{"label":{"literalString":"Option A"},"value":"A"},{"label":{"literalString":"Option B"},"value":"B"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"pick","valueMap":[{"key":"0","valueString":"A"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("ChoicePicker - Multi-select") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Fruits"},"value":{"path":"/favorites"},"options":[{"label":{"literalString":"Apple"},"value":"A"},{"label":{"literalString":"Banana"},"value":"B"},{"label":{"literalString":"Cherry"},"value":"C"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"favorites","valueMap":[{"key":"0","valueString":"A"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("ChoicePicker - Filterable") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Fruits"},"value":{"path":"/favorites"},"options":[{"label":{"literalString":"Apple"},"value":"A"},{"label":{"literalString":"Banana"},"value":"B"},{"label":{"literalString":"Cherry"},"value":"C"},{"label":{"literalString":"Date"},"value":"D"},{"label":{"literalString":"Elderberry"},"value":"E"}],"filterable":true}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"favorites","valueMap":[{"key":"0","valueString":"A"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
