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

import Foundation

/// A single message from the A2UI server to the client.
/// Each message contains exactly one of the four possible payloads.
/// Supports both v0.8 (beginRendering/surfaceUpdate) and v0.9 (createSurface/updateComponents).
public struct ServerToClientMessage: Codable {
    // v0.8
    public var beginRendering: BeginRenderingMessage?
    public var surfaceUpdate: SurfaceUpdateMessage?
    public var dataModelUpdate: DataModelUpdateMessage?
    public var deleteSurface: DeleteSurfaceMessage?
    // v0.9
    public var version: String?
    public var createSurface: CreateSurfaceMessage?
    public var updateComponents: UpdateComponentsMessage?
    public var updateDataModel: V09DataModelUpdateMessage?
}

/// Signals the client to begin rendering a surface.
public struct BeginRenderingMessage: Codable {
    public var surfaceId: String
    public var root: String
    public var styles: [String: String]?
}

/// Adds or updates components in a surface's component buffer.
public struct SurfaceUpdateMessage: Codable {
    public var surfaceId: String
    public var components: [RawComponentInstance]
}

/// Updates the data model for a surface (v0.8 format with `contents` array).
public struct DataModelUpdateMessage: Codable {
    public var surfaceId: String
    public var path: String?
    public var contents: [ValueMapEntry]
}

/// Updates the data model for a surface (v0.9 format with raw JSON `value`).
public struct V09DataModelUpdateMessage: Codable {
    public var surfaceId: String
    public var path: String?
    public var value: AnyCodable
}

/// Removes a surface and all its associated data.
public struct DeleteSurfaceMessage: Codable {
    public var surfaceId: String
}

// MARK: - v0.9 Messages

/// v0.9: Creates a new surface (equivalent to beginRendering).
public struct CreateSurfaceMessage: Codable {
    public var surfaceId: String
    public var catalogId: String?
}

/// v0.9: Updates components in a surface (equivalent to surfaceUpdate).
public struct UpdateComponentsMessage: Codable {
    public var surfaceId: String
    public var components: [RawComponentInstance]
}
