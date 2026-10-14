// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import A2UICore
import Combine

/// The view model tree of one surface.
///
/// Holds the surface's root ``ComponentNode``. When components change, the surface resolves the
/// whole tree and this passes it down from the root. When only data changes, each view model
/// resolves its own node again if it read that data, so the surface doesn't resolve the tree.
@MainActor
public final class ComponentNodeTree: ObservableObject {

  /// The view model of the root component, or `nil` while the surface has no root.
  @Published public private(set) var root: ComponentNode?

  private let surface: SurfaceViewModel
  private var cancellable: AnyCancellable?

  /// Creates the view model tree of a surface.
  ///
  /// Turns off ``SurfaceViewModel/resolvesTreeOnDataChange``, so the surface's
  /// ``SurfaceViewModel/rootNode`` no longer updates when only data changes.
  public init(surface: SurfaceViewModel) {
    self.surface = surface
    surface.resolvesTreeOnDataChange = false
    cancellable = surface.$rootNode.sink { [weak self] rootNode in
      self?.update(rootNode)
    }
  }

  private func update(_ rootNode: Node?) {
    guard let rootNode else {
      root = nil
      return
    }
    if let root, root.id == rootNode.id, root.node.type == rootNode.type {
      root.update(rootNode)
    } else {
      root = ComponentNode(node: rootNode, surface: surface)
    }
  }
}
