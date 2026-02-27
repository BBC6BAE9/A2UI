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

struct A2UIColumn: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        if let props = try? node.payload.typedProperties(ColumnProperties.self) {
            let crossStretch = props.align == "stretch"
            VStack(alignment: a2uiHorizontalAlignment(props.align), spacing: 8) {
                a2uiDistributedContent(
                    node.children, justify: props.justify,
                    stretchWidth: crossStretch, stretchHeight: false,
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Column - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["a","b","c"]}}}},{"id":"a","component":{"Text":{"text":{"literalString":"Item A"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"Item B"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"Item C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Column - Center Aligned") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["a","b"]},"align":"center"}}},{"id":"a","component":{"Text":{"text":{"literalString":"Short"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"A longer text to show centering"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
