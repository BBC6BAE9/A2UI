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

/// The view model of one rendered component.
///
/// Holds the component's latest resolved ``Node`` and the view models of its children, and
/// publishes only when the component's own properties change, so a change inside a child
/// re-renders that child alone.
///
/// Given its surface, a view model also keeps itself up to date: it watches the data its node
/// read and, when that data changes, resolves its node again on its own with
/// ``NodeResolver/resolveNode(_:)`` instead of the whole tree being resolved.
@MainActor
public final class ComponentNode: ObservableObject, Identifiable {

  /// The instance ID of the component.
  public nonisolated let id: String

  /// The latest resolved snapshot of the component.
  @Published public private(set) var node: Node

  /// The view models of the component's children, in the order the node lists them.
  ///
  /// It only changes along with ``node``, which publishes the change.
  public private(set) var children: [ComponentNode]

  private var childrenByID: [String: ComponentNode]
  private weak var surface: SurfaceViewModel?
  private var context: NodeContext?
  private var dependencies = NodeDependencies()
  private var listLengths: [String: Int] = [:]
  private var subscriptions: [AnyCancellable] = []

  /// Creates a view model for a resolved node and its descendants.
  ///
  /// - Parameters:
  ///   - node: The resolved node.
  ///   - surface: The surface the node belongs to. With one, each view model watches the data its
  ///     node read and updates itself when that data changes.
  public init(node: Node, surface: SurfaceViewModel? = nil) {
    self.id = node.id
    self.node = node
    self.surface = surface
    let children = node.allChildNodes.map { ComponentNode(node: $0, surface: surface) }
    self.children = children
    self.childrenByID = Self.index(children)
    watchDependencies(of: node)
  }

  /// Updates the component and its children from a newly resolved node.
  ///
  /// A child keeps its view model while its instance ID and type stay the same, and that view
  /// model is updated in turn. `node` is only reassigned, and so only publishes, when the
  /// component's own properties change.
  func update(_ newNode: Node) {
    watchDependencies(of: newNode)
    let newChildren = newNode.allChildNodes.map { child in
      guard let reused = childrenByID[child.id], reused.node.type == child.type else {
        return ComponentNode(node: child, surface: surface)
      }
      reused.update(child)
      return reused
    }
    if !newChildren.elementsEqual(children, by: ===) {
      children = newChildren
      childrenByID = Self.index(newChildren)
    }
    if !Self.hasSameOwnProperties(node, newNode) {
      node = newNode
    }
  }

  /// Returns the view model `parent` holds for a child `node`, or a new view model when there is
  /// no parent view model or it doesn't hold that child.
  public static func child(for node: Node, in parent: ComponentNode?) -> ComponentNode {
    parent?.childrenByID[node.id] ?? ComponentNode(node: node, surface: parent?.surface)
  }

  // MARK: - Watching Data

  /// Watches the data `node` read, replacing the previous subscriptions when that changed.
  ///
  /// A template array only matters by its length; its items' contents are watched by the items'
  /// own view models. The subscriptions end when the view model is released.
  private func watchDependencies(of node: Node) {
    context = node.context
    guard let dataModel = surface?.dataModel else { return }
    for path in node.dependencies.lists {
      listLengths[path] = dataModel.get(path)?.arrayValue?.count
    }
    guard node.dependencies != dependencies else { return }
    dependencies = node.dependencies
    let valueSubscriptions = node.dependencies.values.compactMap { path in
      try? dataModel.watch(path) { [weak self] _ in
        self?.refresh()
      }
    }
    let listSubscriptions = node.dependencies.lists.compactMap { path in
      try? dataModel.watch(path) { [weak self] value in
        guard let self, value?.arrayValue?.count != self.listLengths[path] else { return }
        self.refresh()
      }
    }
    subscriptions = valueSubscriptions + listSubscriptions
  }

  /// Resolves the node again after data it read changed.
  private func refresh() {
    guard let context, let newNode = surface?.nodeResolver.resolveNode(context) else { return }
    update(newNode)
  }

  /// Compares two nodes, treating child nodes as equal when their instance IDs and types match.
  ///
  /// A change inside a child is published by the child's own view model, so it doesn't make
  /// its parent publish.
  private static func hasSameOwnProperties(_ lhs: Node, _ rhs: Node) -> Bool {
    lhs.id == rhs.id && lhs.type == rhs.type && lhs.catalogID == rhs.catalogID
      && isSameOwnValue(ResolvedDictionary(lhs.properties), ResolvedDictionary(rhs.properties))
  }

  private static func isSameOwnValue(_ lhs: any Resolved, _ rhs: any Resolved) -> Bool {
    if let left = lhs as? Node, let right = rhs as? Node {
      return left.id == right.id && left.type == right.type
    }
    // An empty array of another element type also casts to `[Node]`.
    if let left = lhs as? [Node], let right = rhs as? [Node], !(left.isEmpty && right.isEmpty) {
      return left.map(\.id) == right.map(\.id) && left.map(\.type) == right.map(\.type)
    }
    if let left = lhs as? ResolvedDictionary, let right = rhs as? ResolvedDictionary {
      return left.storage.count == right.storage.count
        && left.storage.allSatisfy { key, value in
          right.storage[key].map { isSameOwnValue(value, $0) } ?? false
        }
    }
    if let left = lhs as? ResolvedArray, let right = rhs as? ResolvedArray {
      return left.elements.count == right.elements.count
        && zip(left.elements, right.elements).allSatisfy { isSameOwnValue($0, $1) }
    }
    return lhs.isEqual(to: rhs)
  }

  private static func index(_ children: [ComponentNode]) -> [String: ComponentNode] {
    Dictionary(children.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }
}
