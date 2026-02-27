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

struct A2UIModal: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        // children[0] = entryPoint, children[1] = content
        if node.children.count >= 2 {
            ModalNodeView(
                entryPointNode: node.children[0],
                contentNode: node.children[1],
                uiState: node.uiState as? ModalUIState ?? ModalUIState(),
                viewModel: viewModel
            )
        }
    }
}

// MARK: - ModalNodeView

/// Modal that reads isPresented from `ModalUIState`.
struct ModalNodeView: View {
    let entryPointNode: ComponentNode
    let contentNode: ComponentNode
    var uiState: ModalUIState
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiActionHandler) private var parentActionHandler
    @Environment(\.a2uiStyle) private var style

    var body: some View {
        let modalStyle = style.modalStyle

        A2UIComponentView(
            node: entryPointNode,
            viewModel: viewModel
        )
        .environment(\.a2uiActionHandler) { action in
            uiState.isPresented = true
            parentActionHandler?(action)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            uiState.isPresented = true
        }
        .sheet(isPresented: Binding(
            get: { uiState.isPresented },
            set: { uiState.isPresented = $0 }
        )) {
            NavigationStack {
                ScrollView {
                    A2UIComponentView(
                        node: contentNode,
                        viewModel: viewModel
                    )
                    .padding(modalStyle.contentPadding ?? 16)
                }
                .toolbar {
                    if modalStyle.showCloseButton {
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                uiState.isPresented = false
                            } label: {
                                Image(systemName: "xmark")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            #if os(iOS) || os(macOS) || os(visionOS)
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
            #endif
        }
    }
}

// MARK: - Previews

#Preview("Modal") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Modal":{"trigger":"mbtn","content":"mcol"}}},{"id":"mbtn","component":{"Button":{"child":"mbtn-text","action":{"name":"open_modal"}}}},{"id":"mbtn-text","component":{"Text":{"text":{"literalString":"Open Modal"}}}},{"id":"mcol","component":{"Column":{"children":{"explicitList":["mh","mp"]}}}},{"id":"mh","component":{"Text":{"text":{"literalString":"Modal Title"},"variant":"h3"}}},{"id":"mp","component":{"Text":{"text":{"literalString":"This is a modal dialog."}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
