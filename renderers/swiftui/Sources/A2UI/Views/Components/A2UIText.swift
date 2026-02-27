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

struct A2UIText: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(TextProperties.self) {
            let resolved = viewModel.resolveString(
                props.text, dataContextPath: dataContextPath
            )
            let hint = props.variant
            let override = style.textStyles[hint ?? "body"]
            let base = Text(markdownAttributedString(resolved))
                .font(override?.font ?? defaultFontForVariant(hint))
                .fontWeight(override?.weight ?? defaultWeightForVariant(hint))

            if let color = override?.color ?? optionalColorForVariant(hint) {
                base.foregroundStyle(color)
            } else {
                base
            }
        }
    }

    private func defaultFontForVariant(_ hint: String?) -> Font {
        switch hint {
        case "h1": return .largeTitle
        case "h2": return .title
        case "h3": return .title2
        case "h4": return .title3
        case "h5": return .headline
        case "caption": return .caption
        default: return .body
        }
    }

    private func defaultWeightForVariant(_ hint: String?) -> Font.Weight? {
        switch hint {
        case "h1", "h2", "h3": return .semibold
        case "h4", "h5": return .medium
        default: return nil
        }
    }

    private func optionalColorForVariant(_ hint: String?) -> Color? {
        hint == "caption" ? .secondary : nil
    }

    private func markdownAttributedString(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(string)
    }
}

// MARK: - Previews

#Preview("Text - Body") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello, World!"}}}}]}}
    """) {
        A2UIText(node: root, viewModel: vm).padding()
    }
}

#Preview("Text - Headings") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["h1","h2","h3","h4","h5"]}}}},{"id":"h1","component":{"Text":{"text":{"literalString":"Heading 1"},"variant":"h1"}}},{"id":"h2","component":{"Text":{"text":{"literalString":"Heading 2"},"variant":"h2"}}},{"id":"h3","component":{"Text":{"text":{"literalString":"Heading 3"},"variant":"h3"}}},{"id":"h4","component":{"Text":{"text":{"literalString":"Heading 4"},"variant":"h4"}}},{"id":"h5","component":{"Text":{"text":{"literalString":"Heading 5"},"variant":"h5"}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Text - Caption") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Text":{"text":{"literalString":"This is a caption"},"variant":"caption"}}}]}}
    """) {
        A2UIText(node: root, viewModel: vm).padding()
    }
}

#Preview("Text - Markdown") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Text":{"text":{"literalString":"**Bold**, *italic*, and [a link](https://example.com)"}}}}]}}
    """) {
        A2UIText(node: root, viewModel: vm).padding()
    }
}
