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

struct A2UIDivider: View {
    let node: ComponentNode

    var body: some View {
        let vertical = (try? node.payload.typedProperties(DividerProperties.self))?.axis == "vertical"
        if vertical {
            #if canImport(UIKit) && !os(watchOS)
            Color(uiColor: .separator).frame(width: 1)
            #elseif canImport(AppKit)
            Color(nsColor: .separatorColor).frame(width: 1)
            #else
            Color.gray.opacity(0.3).frame(width: 1)
            #endif
        } else {
            SwiftUI.Divider()
        }
    }
}

// MARK: - Previews

#Preview("Divider - Horizontal") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["t1","d","t2"]}}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Above"}}}},{"id":"d","component":{"Divider":{}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Below"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
