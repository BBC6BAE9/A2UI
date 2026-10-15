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
/// Given its surface, a view model also keeps itself up to date: it watches the data and component
/// definitions its node used and, when they change, resolves only its own node again with
/// ``NodeResolver/resolveNode(_:resolvingChildren:)``. Its children's nodes are resolved by their
/// own view models.
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
  private var dependencies: NodeDependencies?
  private var listLengths: [String: Int] = [:]
  private var subscriptions: [AnyCancellable] = []

  /// Creates a view model for a resolved node and its descendants.
  ///
  /// - Parameters:
  ///   - node: The resolved node.
  ///   - surface: The surface the node belongs to. With one, each child view model resolves its
  ///     own node from the child's context, so `node` only needs its own properties resolved, and
  ///     each view model keeps itself up to date.
  public init(node: Node, surface: SurfaceViewModel? = nil) {
    self.id = node.id
    self.node = node
    self.surface = surface
    let children = node.allChildNodes.map { Self.make($0, surface: surface) }
    self.children = children
    self.childrenByID = Self.index(children)
    watchDependencies(of: node)
  }

  /// Updates the component from its newly resolved node.
  ///
  /// A child keeps its view model while its instance ID and type stay the same. That view model
  /// keeps itself up to date, so it only resolves its node again if the child moved to another
  /// context. `node` is only reassigned, and so only publishes, when the component's own
  /// properties change.
  private func update(_ newNode: Node) {
    watchDependencies(of: newNode)
    let newChildren = newNode.allChildNodes.map { child in
      guard let reused = childrenByID[child.id], reused.node.type == child.type else {
        return Self.make(child, surface: surface)
      }
      if let childContext = child.context, childContext != reused.context {
        reused.refresh(at: childContext)
      }
      return reused
    }
    if !newChildren.elementsEqual(children, by: ===) {
      let kept = Set(newChildren.map(ObjectIdentifier.init))
      for child in children where !kept.contains(ObjectIdentifier(child)) {
        child.detach()
      }
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
    parent?.childrenByID[node.id] ?? make(node, surface: parent?.surface)
  }

  /// Creates the view model of a child, first resolving the child's own node when there's a
  /// surface.
  private static func make(_ child: Node, surface: SurfaceViewModel?) -> ComponentNode {
    let resolved = child.context.flatMap {
      surface?.nodeResolver.resolveNode($0, resolvingChildren: false)
    }
    return ComponentNode(node: resolved ?? child, surface: surface)
  }

  // MARK: - Watching Dependencies

  /// Watches the data and component definitions `node` used, replacing the previous
  /// subscriptions when they changed.
  ///
  /// A template array only matters by its length; its items' contents are watched by the items'
  /// own view models. The subscriptions end when the view model is released.
  private func watchDependencies(of node: Node) {
    context = node.context
    guard let surface else { return }
    let dataModel = surface.dataModel
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
    let componentIDs = node.dependencies.components.union(context.map { [$0.componentID] } ?? [])
    let componentSubscriptions = componentIDs.map { componentID in
      surface.componentsModel.watch(componentID) { [weak self] definition in
        self?.componentChanged(componentID, to: definition)
      }
    }
    subscriptions = valueSubscriptions + listSubscriptions + componentSubscriptions
  }

  /// Resolves the node again when its own component definition changes, or when a child's
  /// appears, disappears, or changes type.
  ///
  /// Other changes to a child's definition are handled by the child's own view model. If the
  /// component's own definition is gone or changed type, the parent replaces this view model.
  private func componentChanged(_ componentID: String, to definition: ComponentModel?) {
    guard componentID != context?.componentID else {
      if definition?.type == node.type {
        refresh()
      }
      return
    }
    let childNodes = node.allChildNodes.filter { $0.context?.componentID == componentID }
    let childrenChanged =
      childNodes.isEmpty
      ? definition != nil
      : childNodes.contains { $0.type != definition?.type }
    if childrenChanged {
      refresh()
    }
  }

  /// Stops keeping the view model and its descendants up to date, once it's no longer in the tree.
  ///
  /// Its views may still hold it until they're removed.
  func detach() {
    surface = nil
    subscriptions = []
    for child in children {
      child.detach()
    }
  }

  /// Resolves the node again, at `newContext` if given.
  ///
  /// If the component's definition is gone or changed type, the parent replaces this view model
  /// instead.
  private func refresh(at newContext: NodeContext? = nil) {
    guard let context = newContext ?? context,
      let newNode = surface?.nodeResolver.resolveNode(context, resolvingChildren: false),
      newNode.type == node.type
    else { return }
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
