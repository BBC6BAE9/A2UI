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

struct A2UIImage: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(ImageProperties.self) {
            let urlString = viewModel.resolveString(
                props.url, dataContextPath: dataContextPath
            )
            let hint = props.variant
            let defaults = defaultImageSizing(for: hint)
            let override = style.imageStyles[hint ?? ""]
            let sizing = ImageSizing(
                width: override?.width ?? defaults.width,
                height: override?.height ?? defaults.height
            )
            let radius = override?.cornerRadius ?? defaultCornerRadius(for: hint)

            if !urlString.isEmpty, urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
                // Remote URL — use AsyncImage
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            fitImage(image, fit: props.fit, sizing: sizing)
                        case .failure:
                            imagePlaceholder(sizing)
                        default:
                            ProgressView()
                                .frame(width: sizing.width, height: sizing.height)
                        }
                    }
                    .frame(width: sizing.width, height: sizing.height)
                    .frame(maxWidth: sizing.width == nil ? .infinity : nil)
                    .clipped()
                    .clipShape(hint == "avatar" && radius >= 1000
                        ? AnyShape(Circle())
                        : AnyShape(RoundedRectangle(cornerRadius: radius)))
                } else {
                    imagePlaceholder(sizing)
                }
            } else if !urlString.isEmpty {
                // Local asset path — load from bundle
                let assetName = Self.extractAssetName(from: urlString)
                fitImage(Image(assetName, bundle: .main), fit: props.fit, sizing: sizing)
                    .frame(width: sizing.width, height: sizing.height)
                    .frame(maxWidth: sizing.width == nil ? .infinity : nil)
                    .clipped()
                    .clipShape(hint == "avatar" && radius >= 1000
                        ? AnyShape(Circle())
                        : AnyShape(RoundedRectangle(cornerRadius: radius)))
            } else {
                imagePlaceholder(sizing)
            }
        }
    }

    /// Extract the asset catalog name from a path like "assets/travel_images/santorini_panorama.jpg".
    /// Strips directory prefixes and file extension → "santorini_panorama".
    static func extractAssetName(from path: String) -> String {
        a2uiExtractAssetName(from: path)
    }

    private struct ImageSizing {
        var width: CGFloat?
        var height: CGFloat
    }

    private func defaultImageSizing(for hint: String?) -> ImageSizing {
        switch hint {
        case "icon":          return ImageSizing(width: 32, height: 32)
        case "avatar":        return ImageSizing(width: 32, height: 32)
        case "smallFeature":  return ImageSizing(width: 50, height: 50)
        case "mediumFeature": return ImageSizing(width: nil, height: 150)
        case "largeFeature":  return ImageSizing(width: nil, height: 400)
        case "header":        return ImageSizing(width: nil, height: 240)
        default:              return ImageSizing(width: nil, height: 150)
        }
    }

    private func defaultCornerRadius(for hint: String?) -> CGFloat {
        hint == "avatar" ? .infinity : 4
    }

    @ViewBuilder
    private func fitImage(_ image: SwiftUI.Image, fit: String?, sizing: ImageSizing) -> some View {
        switch fit {
        case "cover":
            image.resizable().aspectRatio(contentMode: .fill)
        case "fill":
            image.resizable()
        case "none":
            image
        case "scaleDown":
            image.resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: sizing.width, maxHeight: sizing.height)
        default:
            image.resizable().aspectRatio(contentMode: .fit)
        }
    }

    private func imagePlaceholder(_ sizing: ImageSizing) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.15))
            .frame(width: sizing.width, height: sizing.height)
            .frame(maxWidth: sizing.width == nil ? .infinity : nil)
            .overlay {
                Image(systemName: "photo")
                    .font(sizing.width != nil && sizing.width! < 50 ? .caption : .largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
}

// MARK: - Public Asset Name Utility

/// Extract the asset catalog name from a path like "assets/travel_images/santorini_panorama.jpg".
/// Strips directory prefixes and file extension → "santorini_panorama".
public func a2uiExtractAssetName(from path: String) -> String {
    let filename = (path as NSString).lastPathComponent
    let name = (filename as NSString).deletingPathExtension
    return name.isEmpty ? path : name
}

// MARK: - Previews

#Preview("Image - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/10/600/300"}}}}]}}
    """) {
        A2UIImage(node: root, viewModel: vm).padding()
    }
}

#Preview("Image - Avatar") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/64/200/200"},"variant":"avatar"}}}]}}
    """) {
        A2UIImage(node: root, viewModel: vm).padding()
    }
}

#Preview("Image - Header") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/10/800/400"},"variant":"header","fit":"cover"}}}]}}
    """) {
        A2UIImage(node: root, viewModel: vm).padding()
    }
}
