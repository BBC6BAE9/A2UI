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

struct A2UICard: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    var body: some View {
        if let child = node.children.first {
            let card = style.cardStyle
            A2UIComponentView(node: child, viewModel: viewModel)
                .padding(card.padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if let bg = card.backgroundColor {
                        RoundedRectangle(cornerRadius: card.cornerRadius).fill(bg)
                    } else {
                        RoundedRectangle(cornerRadius: card.cornerRadius).fill(.background)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: card.cornerRadius))
                .shadow(color: card.shadowColor, radius: card.shadowRadius, y: card.shadowY)
        }
    }
}

// MARK: - Previews

#Preview("Card") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Card":{"child":"content"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["title","desc"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Card Title"},"variant":"h4"}}},{"id":"desc","component":{"Text":{"text":{"literalString":"This is a card with some content inside."}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
