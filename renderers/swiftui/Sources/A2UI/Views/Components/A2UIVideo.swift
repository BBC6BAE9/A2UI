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

#if canImport(AVKit) && !os(watchOS)
import AVKit
#endif
import SwiftUI

struct A2UIVideo: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(VideoProperties.self) {
            let urlString = viewModel.resolveString(
                props.url, dataContextPath: dataContextPath
            )
            let cr = style.videoStyle.cornerRadius ?? 10
            if !urlString.isEmpty, URL(string: urlString) != nil {
                VideoNodeView(
                    urlString: urlString,
                    uiState: node.uiState as? VideoUIState,
                    cornerRadius: cr
                )
            } else {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }
}

// MARK: - VideoNodeView

#if canImport(AVKit) && !os(watchOS)
/// Video player that reads its AVPlayer from `VideoUIState` so the player
/// survives tree rebuilds (LazyVStack recycling no longer destroys it).
struct VideoNodeView: View {
    let urlString: String
    var uiState: VideoUIState?
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let player = uiState?.player {
                SystemVideoPlayer(player: player)
            } else {
                Color.clear.background(.fill.tertiary)
                    .overlay { ProgressView() }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            guard let uiState, uiState.player == nil,
                  let url = URL(string: urlString) else { return }
            uiState.player = AVPlayer(url: url)
        }
        .onDisappear {
            uiState?.player?.pause()
        }
    }
}

#if os(iOS) || os(tvOS)
struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(
        _ controller: AVPlayerViewController, context: Context
    ) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
#elseif os(macOS)
struct SystemVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }
}
#else
struct SystemVideoPlayer: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
    }
}
#endif

#else
/// watchOS: AVKit is unavailable; show a placeholder.
struct VideoNodeView: View {
    let urlString: String
    var uiState: VideoUIState?
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                Image(systemName: "video.slash")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}
#endif

// MARK: - Previews

#Preview("Video") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Video":{"url":{"literalString":"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
