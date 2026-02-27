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

struct A2UIRow: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        if let props = try? node.payload.typedProperties(RowProperties.self) {
            let crossStretch = props.align == "stretch"
            HStack(alignment: a2uiVerticalAlignment(props.align), spacing: 16) {
                a2uiDistributedContent(
                    node.children, justify: props.justify,
                    stretchWidth: false, stretchHeight: crossStretch,
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Row - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["a","b","c"]}}}},{"id":"a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Row - Space Between") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["a","b","c"]},"justify":"spaceBetween"}}},{"id":"a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
