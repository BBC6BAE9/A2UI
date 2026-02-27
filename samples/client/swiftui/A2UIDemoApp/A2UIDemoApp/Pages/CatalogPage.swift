import SwiftUI
import A2UI

// MARK: - Catalog Page

struct CatalogPage: View {
    @State private var showingInspector = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(componentCatalog) { entry in
                    NavigationLink {
                        CatalogDetailPage(entry: entry)
                    } label: {
                        catalogCard(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Component Gallery")
        #if !os(visionOS) && !os(tvOS)
        .navigationSubtitle("Building blocks and examples for Agent Driven UIs")
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingInspector.toggle()
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
#if !os(visionOS) && !os(tvOS)
        .inspector(isPresented: $showingInspector) {
            ScrollView {
                Text("A gallery of all A2UI standard components rendered by the SwiftUI renderer. Each card is live-rendered from static JSON. Tap a card to inspect its source JSON and full-screen preview.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
#endif
    }

    @ViewBuilder
    private func catalogCard(_ entry: CatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.name)
                .font(.title3)
                .fontWeight(.medium)
                .padding(.horizontal, 4)

            VStack {
                if let vm = entry.viewModel, let root = vm.componentTree {
                    A2UIComponentView(node: root, viewModel: vm)
                        .environment(\.a2uiCustomComponentRenderer, rizzchartsRenderer)
                        .padding()
                } else {
                    Text("Failed to parse")
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            #if os(iOS)
            .background(Color(.secondarySystemGroupedBackground))
            #elseif os(macOS)
            .background(Color(.windowBackgroundColor))
            #elseif os(visionOS)
            .background(.regularMaterial)
            #else
            .background(.ultraThinMaterial)
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            #if os(macOS)
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail Page

struct CatalogDetailPage: View {
    let entry: CatalogEntry
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Rendered").tag(0)
                Text("JSON").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if selectedTab == 0 {
                renderedView
            } else {
                jsonView
            }
        }
        .navigationTitle(entry.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var renderedView: some View {
        ScrollView {
            if let vm = entry.viewModel, let root = vm.componentTree {
                A2UIComponentView(node: root, viewModel: vm)
                    .environment(\.a2uiCustomComponentRenderer, rizzchartsRenderer)
                    .padding()
            } else {
                ContentUnavailableView(
                    "Parse Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Failed to parse the JSON input.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var jsonView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(entry.prettyJSON)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(.systemGray6))
        #elseif os(macOS)
        .background(Color(.textBackgroundColor))
        #else
        .background(.ultraThinMaterial)
        #endif
    }
}

// MARK: - Data

struct CatalogEntry: Identifiable {
    let name: String
    let icon: String
    let jsonl: String
    let viewModel: SurfaceViewModel?

    var id: String { name }

    var prettyJSON: String {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return jsonl
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line -> String in
                guard let data = line.data(using: .utf8),
                      let obj = try? decoder.decode(AnyCodableJSON.self, from: data),
                      let pretty = try? encoder.encode(obj),
                      let str = String(data: pretty, encoding: .utf8)
                else { return line }
                return str
            }
            .joined(separator: "\n\n")
    }

    init(name: String, icon: String = "square", jsonl: String) {
        self.name = name
        self.icon = icon
        self.jsonl = jsonl

        let vm = SurfaceViewModel()
        let decoder = JSONDecoder()
        var ok = true
        for line in jsonl.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let data = line.data(using: .utf8),
               let msg = try? decoder.decode(ServerToClientMessage.self, from: data) {
                try? vm.processMessage(msg)
            } else {
                ok = false
            }
        }
        self.viewModel = ok ? vm : nil
    }
}

struct AnyCodableJSON: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodableJSON].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodableJSON].self) {
            value = array.map { $0.value }
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let n = try? container.decode(Double.self) {
            value = n
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableJSON(value: $0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodableJSON(value: $0) })
        case let s as String:
            try container.encode(s)
        case let n as Double:
            try container.encode(n)
        case let b as Bool:
            try container.encode(b)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode("\(value)")
        }
    }

    init(value: Any) { self.value = value }
}

// MARK: - Catalog Data

let componentCatalog: [CatalogEntry] = [

    CatalogEntry(name: "Text", icon: "textformat", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["h1","h2","h3","h4","h5","body","cap"]}}}},{"id":"h1","component":{"Text":{"text":{"literalString":"Heading 1 — h1"},"variant":"h1"}}},{"id":"h2","component":{"Text":{"text":{"literalString":"Heading 2 — h2"},"variant":"h2"}}},{"id":"h3","component":{"Text":{"text":{"literalString":"Heading 3 — h3"},"variant":"h3"}}},{"id":"h4","component":{"Text":{"text":{"literalString":"Heading 4 — h4"},"variant":"h4"}}},{"id":"h5","component":{"Text":{"text":{"literalString":"Heading 5 — h5"},"variant":"h5"}}},{"id":"body","component":{"Text":{"text":{"literalString":"Body text — default"}}}},{"id":"cap","component":{"Text":{"text":{"literalString":"Caption text — caption"},"variant":"caption"}}}]}}
    """),

    CatalogEntry(name: "Image", icon: "photo", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["sec_variants","row_small","header_img","sec_fit","fit_contain","fit_cover","fit_fill","fit_none","fit_scaledown"]}}}},{"id":"sec_variants","component":{"Text":{"text":{"literalString":"Variants"},"variant":"h4"}}},{"id":"row_small","component":{"Row":{"children":{"explicitList":["avatar","icon","small"]},"align":"center"}}},{"id":"avatar","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/64/200/200"},"variant":"avatar"}}},{"id":"icon","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/76/200/200"},"variant":"icon"}}},{"id":"small","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/82/200/200"},"variant":"smallFeature"}}},{"id":"header_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/10/800/400"},"variant":"header","fit":"cover"}}},{"id":"sec_fit","component":{"Text":{"text":{"literalString":"Fit modes (same 600×300 image in 300×150 frame)"},"variant":"h4"}}},{"id":"fit_contain","component":{"Column":{"children":{"explicitList":["fc_label","fc_img"]}}}},{"id":"fc_label","component":{"Text":{"text":{"literalString":"contain — fit entirely, may letterbox"},"variant":"caption"}}},{"id":"fc_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"variant":"mediumFeature","fit":"contain"}}},{"id":"fit_cover","component":{"Column":{"children":{"explicitList":["fv_label","fv_img"]}}}},{"id":"fv_label","component":{"Text":{"text":{"literalString":"cover — fill frame, may crop"},"variant":"caption"}}},{"id":"fv_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"variant":"mediumFeature","fit":"cover"}}},{"id":"fit_fill","component":{"Column":{"children":{"explicitList":["ff_label","ff_img"]}}}},{"id":"ff_label","component":{"Text":{"text":{"literalString":"fill — stretch to frame, ignores aspect ratio"},"variant":"caption"}}},{"id":"ff_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"variant":"mediumFeature","fit":"fill"}}},{"id":"fit_none","component":{"Column":{"children":{"explicitList":["fn_label","fn_img"]}}}},{"id":"fn_label","component":{"Text":{"text":{"literalString":"none — original size, no scaling"},"variant":"caption"}}},{"id":"fn_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"variant":"mediumFeature","fit":"none"}}},{"id":"fit_scaledown","component":{"Column":{"children":{"explicitList":["fs_label","fs_img"]}}}},{"id":"fs_label","component":{"Text":{"text":{"literalString":"scaleDown — like contain, but never enlarges"},"variant":"caption"}}},{"id":"fs_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"variant":"mediumFeature","fit":"scaleDown"}}}]}}
    """),

    CatalogEntry(name: "Icon", icon: "star.circle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["title","r1","r2","r3","r4","r5","r6","r7","r8","r9","r10"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"All 59 Standard Icons"},"variant":"h4"}}},{"id":"r1","component":{"Row":{"children":{"explicitList":["i_accountCircle","i_add","i_arrowBack","i_arrowForward","i_attachFile","i_calendarToday"]}}}},{"id":"r2","component":{"Row":{"children":{"explicitList":["i_call","i_camera","i_check","i_close","i_delete","i_download"]}}}},{"id":"r3","component":{"Row":{"children":{"explicitList":["i_edit","i_event","i_error","i_fastForward","i_favorite","i_favoriteOff"]}}}},{"id":"r4","component":{"Row":{"children":{"explicitList":["i_folder","i_help","i_home","i_info","i_locationOn","i_lock"]}}}},{"id":"r5","component":{"Row":{"children":{"explicitList":["i_lockOpen","i_mail","i_menu","i_moreVert","i_moreHoriz","i_notifications"]}}}},{"id":"r6","component":{"Row":{"children":{"explicitList":["i_notificationsOff","i_pause","i_payment","i_person","i_phone","i_photo"]}}}},{"id":"r7","component":{"Row":{"children":{"explicitList":["i_play","i_print","i_refresh","i_rewind","i_search","i_send"]}}}},{"id":"r8","component":{"Row":{"children":{"explicitList":["i_settings","i_share","i_shoppingCart","i_skipNext","i_skipPrevious","i_star"]}}}},{"id":"r9","component":{"Row":{"children":{"explicitList":["i_starHalf","i_starOff","i_stop","i_upload","i_visibility","i_visibilityOff"]}}}},{"id":"r10","component":{"Row":{"children":{"explicitList":["i_volumeDown","i_volumeMute","i_volumeOff","i_volumeUp","i_warning"]}}}},{"id":"i_accountCircle","component":{"Icon":{"name":{"literalString":"accountCircle"}}}},{"id":"i_add","component":{"Icon":{"name":{"literalString":"add"}}}},{"id":"i_arrowBack","component":{"Icon":{"name":{"literalString":"arrowBack"}}}},{"id":"i_arrowForward","component":{"Icon":{"name":{"literalString":"arrowForward"}}}},{"id":"i_attachFile","component":{"Icon":{"name":{"literalString":"attachFile"}}}},{"id":"i_calendarToday","component":{"Icon":{"name":{"literalString":"calendarToday"}}}},{"id":"i_call","component":{"Icon":{"name":{"literalString":"call"}}}},{"id":"i_camera","component":{"Icon":{"name":{"literalString":"camera"}}}},{"id":"i_check","component":{"Icon":{"name":{"literalString":"check"}}}},{"id":"i_close","component":{"Icon":{"name":{"literalString":"close"}}}},{"id":"i_delete","component":{"Icon":{"name":{"literalString":"delete"}}}},{"id":"i_download","component":{"Icon":{"name":{"literalString":"download"}}}},{"id":"i_edit","component":{"Icon":{"name":{"literalString":"edit"}}}},{"id":"i_event","component":{"Icon":{"name":{"literalString":"event"}}}},{"id":"i_error","component":{"Icon":{"name":{"literalString":"error"}}}},{"id":"i_fastForward","component":{"Icon":{"name":{"literalString":"fastForward"}}}},{"id":"i_favorite","component":{"Icon":{"name":{"literalString":"favorite"}}}},{"id":"i_favoriteOff","component":{"Icon":{"name":{"literalString":"favoriteOff"}}}},{"id":"i_folder","component":{"Icon":{"name":{"literalString":"folder"}}}},{"id":"i_help","component":{"Icon":{"name":{"literalString":"help"}}}},{"id":"i_home","component":{"Icon":{"name":{"literalString":"home"}}}},{"id":"i_info","component":{"Icon":{"name":{"literalString":"info"}}}},{"id":"i_locationOn","component":{"Icon":{"name":{"literalString":"locationOn"}}}},{"id":"i_lock","component":{"Icon":{"name":{"literalString":"lock"}}}},{"id":"i_lockOpen","component":{"Icon":{"name":{"literalString":"lockOpen"}}}},{"id":"i_mail","component":{"Icon":{"name":{"literalString":"mail"}}}},{"id":"i_menu","component":{"Icon":{"name":{"literalString":"menu"}}}},{"id":"i_moreVert","component":{"Icon":{"name":{"literalString":"moreVert"}}}},{"id":"i_moreHoriz","component":{"Icon":{"name":{"literalString":"moreHoriz"}}}},{"id":"i_notifications","component":{"Icon":{"name":{"literalString":"notifications"}}}},{"id":"i_notificationsOff","component":{"Icon":{"name":{"literalString":"notificationsOff"}}}},{"id":"i_pause","component":{"Icon":{"name":{"literalString":"pause"}}}},{"id":"i_payment","component":{"Icon":{"name":{"literalString":"payment"}}}},{"id":"i_person","component":{"Icon":{"name":{"literalString":"person"}}}},{"id":"i_phone","component":{"Icon":{"name":{"literalString":"phone"}}}},{"id":"i_photo","component":{"Icon":{"name":{"literalString":"photo"}}}},{"id":"i_play","component":{"Icon":{"name":{"literalString":"play"}}}},{"id":"i_print","component":{"Icon":{"name":{"literalString":"print"}}}},{"id":"i_refresh","component":{"Icon":{"name":{"literalString":"refresh"}}}},{"id":"i_rewind","component":{"Icon":{"name":{"literalString":"rewind"}}}},{"id":"i_search","component":{"Icon":{"name":{"literalString":"search"}}}},{"id":"i_send","component":{"Icon":{"name":{"literalString":"send"}}}},{"id":"i_settings","component":{"Icon":{"name":{"literalString":"settings"}}}},{"id":"i_share","component":{"Icon":{"name":{"literalString":"share"}}}},{"id":"i_shoppingCart","component":{"Icon":{"name":{"literalString":"shoppingCart"}}}},{"id":"i_skipNext","component":{"Icon":{"name":{"literalString":"skipNext"}}}},{"id":"i_skipPrevious","component":{"Icon":{"name":{"literalString":"skipPrevious"}}}},{"id":"i_star","component":{"Icon":{"name":{"literalString":"star"}}}},{"id":"i_starHalf","component":{"Icon":{"name":{"literalString":"starHalf"}}}},{"id":"i_starOff","component":{"Icon":{"name":{"literalString":"starOff"}}}},{"id":"i_stop","component":{"Icon":{"name":{"literalString":"stop"}}}},{"id":"i_upload","component":{"Icon":{"name":{"literalString":"upload"}}}},{"id":"i_visibility","component":{"Icon":{"name":{"literalString":"visibility"}}}},{"id":"i_visibilityOff","component":{"Icon":{"name":{"literalString":"visibilityOff"}}}},{"id":"i_volumeDown","component":{"Icon":{"name":{"literalString":"volumeDown"}}}},{"id":"i_volumeMute","component":{"Icon":{"name":{"literalString":"volumeMute"}}}},{"id":"i_volumeOff","component":{"Icon":{"name":{"literalString":"volumeOff"}}}},{"id":"i_volumeUp","component":{"Icon":{"name":{"literalString":"volumeUp"}}}},{"id":"i_warning","component":{"Icon":{"name":{"literalString":"warning"}}}}]}}
    """),

    CatalogEntry(name: "Divider", icon: "minus", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["sec_h","t1","dh","t2","sec_v","row_v"]}}}},{"id":"sec_h","component":{"Text":{"text":{"literalString":"Horizontal (default)"},"variant":"h4"}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Content above"}}}},{"id":"dh","component":{"Divider":{}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Content below"}}}},{"id":"sec_v","component":{"Text":{"text":{"literalString":"Vertical (axis)"},"variant":"h4"}}},{"id":"row_v","component":{"Row":{"children":{"explicitList":["left","dv","right"]},"align":"stretch"}}},{"id":"left","component":{"Text":{"text":{"literalString":"Left"}}}},{"id":"dv","component":{"Divider":{"axis":"vertical"}}},{"id":"right","component":{"Text":{"text":{"literalString":"Right"}}}}]}}
    """),

    CatalogEntry(name: "Row", icon: "arrow.left.and.right", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["lbl_default","row_default","lbl_center","row_center","lbl_between","row_between","lbl_evenly","row_evenly","lbl_end","row_end","lbl_align","row_align"]}}}},{"id":"lbl_default","component":{"Text":{"text":{"literalString":"justify: start (default)"},"variant":"caption"}}},{"id":"row_default","component":{"Row":{"children":{"explicitList":["d1","d2","d3"]}}}},{"id":"d1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"d2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"d3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_center","component":{"Text":{"text":{"literalString":"justify: center"},"variant":"caption"}}},{"id":"row_center","component":{"Row":{"children":{"explicitList":["c1","c2","c3"]},"justify":"center"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"c2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_between","component":{"Text":{"text":{"literalString":"justify: spaceBetween"},"variant":"caption"}}},{"id":"row_between","component":{"Row":{"children":{"explicitList":["b1","b2","b3"]},"justify":"spaceBetween"}}},{"id":"b1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_evenly","component":{"Text":{"text":{"literalString":"justify: spaceEvenly"},"variant":"caption"}}},{"id":"row_evenly","component":{"Row":{"children":{"explicitList":["e1","e2","e3"]},"justify":"spaceEvenly"}}},{"id":"e1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"e2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"e3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_end","component":{"Text":{"text":{"literalString":"justify: end"},"variant":"caption"}}},{"id":"row_end","component":{"Row":{"children":{"explicitList":["n1","n2","n3"]},"justify":"end"}}},{"id":"n1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"n2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"n3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_align","component":{"Text":{"text":{"literalString":"align: center (mixed height)"},"variant":"caption"}}},{"id":"row_align","component":{"Row":{"children":{"explicitList":["a1","a2"]},"align":"center"}}},{"id":"a1","component":{"Text":{"text":{"literalString":"Small"}}}},{"id":"a2","component":{"Text":{"text":{"literalString":"Big Title"},"variant":"h2"}}}]}}
    """),

    CatalogEntry(name: "Column", icon: "arrow.up.and.down", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["lbl_justify","row_justify","lbl_align","col_align"]}}}},{"id":"lbl_justify","component":{"Text":{"text":{"literalString":"justify: start / center / end"},"variant":"caption"}}},{"id":"row_justify","component":{"Row":{"children":{"explicitList":["col_start","dv1","col_center","dv2","col_end"]}}}},{"id":"col_start","component":{"Column":{"children":{"explicitList":["ls","s1","s2","s3","s4","s5","s6"]},"justify":"start"}},"weight":1},{"id":"ls","component":{"Text":{"text":{"literalString":"start"},"variant":"caption"}}},{"id":"s1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"s2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"s3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"s4","component":{"Text":{"text":{"literalString":"D"}}}},{"id":"s5","component":{"Text":{"text":{"literalString":"E"}}}},{"id":"s6","component":{"Text":{"text":{"literalString":"F"}}}},{"id":"dv1","component":{"Divider":{"axis":"vertical"}}},{"id":"col_center","component":{"Column":{"children":{"explicitList":["lc","c1","c2","c3"]},"justify":"center"}},"weight":1},{"id":"lc","component":{"Text":{"text":{"literalString":"center"},"variant":"caption"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"c2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"dv2","component":{"Divider":{"axis":"vertical"}}},{"id":"col_end","component":{"Column":{"children":{"explicitList":["le","e1","e2","e3"]},"justify":"end"}},"weight":1},{"id":"le","component":{"Text":{"text":{"literalString":"end"},"variant":"caption"}}},{"id":"e1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"e2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"e3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_align","component":{"Text":{"text":{"literalString":"align: center"},"variant":"caption"}}},{"id":"col_align","component":{"Column":{"children":{"explicitList":["a1","a2"]},"align":"center"}}},{"id":"a1","component":{"Text":{"text":{"literalString":"Short"}}}},{"id":"a2","component":{"Text":{"text":{"literalString":"A longer text to show cross-axis centering"}}}}]}}
    """),

    CatalogEntry(name: "Card", icon: "rectangle.on.rectangle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Card":{"child":"content"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["title","desc"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Card Title"},"variant":"h4"}}},{"id":"desc","component":{"Text":{"text":{"literalString":"This is a card with some content inside."}}}}]}}
    """),

    CatalogEntry(name: "Button", icon: "rectangle.and.hand.point.up.left", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["b1","b2","b3"]}}}},{"id":"b1","component":{"Button":{"child":"bt1","variant":"primary","action":{"name":"tap1"}}}},{"id":"bt1","component":{"Text":{"text":{"literalString":"Primary"}}}},{"id":"b2","component":{"Button":{"child":"bt2","action":{"name":"tap2"}}}},{"id":"bt2","component":{"Text":{"text":{"literalString":"Default"}}}},{"id":"b3","component":{"Button":{"child":"bt3","variant":"borderless","action":{"name":"tap3"}}}},{"id":"bt3","component":{"Text":{"text":{"literalString":"Borderless"}}}}]}}
    """),

    CatalogEntry(name: "TextField", icon: "character.cursor.ibeam", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["tf_short","tf_num","tf_pw","tf_long","tf_regex"]}}}},{"id":"tf_short","component":{"TextField":{"label":{"literalString":"Name"},"value":{"path":"/name"}}}},{"id":"tf_num","component":{"TextField":{"label":{"literalString":"Age"},"value":{"path":"/age"},"variant":"number"}}},{"id":"tf_pw","component":{"TextField":{"label":{"literalString":"Password"},"value":{"path":"/pw"},"variant":"obscured"}}},{"id":"tf_long","component":{"TextField":{"label":{"literalString":"Bio"},"value":{"path":"/bio"},"variant":"longText"}}},{"id":"tf_regex","component":{"TextField":{"label":{"literalString":"Email"},"value":{"path":"/email"},"validationRegexp":"^[\\\\w.+-]+@[\\\\w-]+\\\\.[a-zA-Z]{2,}$"}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"name","valueString":"Jane Doe"},{"key":"age","valueString":"28"},{"key":"pw","valueString":"secret"},{"key":"bio","valueString":"Hello world"},{"key":"email","valueString":"jane@example.com"}]}}
    """),

    CatalogEntry(name: "CheckBox", icon: "checkmark.square", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["cb1","cb2"]}}}},{"id":"cb1","component":{"CheckBox":{"label":{"literalString":"Accept Terms"},"value":{"path":"/terms"}}}},{"id":"cb2","component":{"CheckBox":{"label":{"literalString":"Subscribe to Newsletter"},"value":{"path":"/newsletter"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"terms","valueBool":true},{"key":"newsletter","valueBool":false}]}}
    """),

    CatalogEntry(name: "Slider", icon: "slider.horizontal.3", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["s"]}}}},{"id":"s","component":{"Slider":{"label":{"literalString":"Volume"},"value":{"path":"/volume"},"min":0,"max":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"volume","valueNumber":50}]}}
    """),

    CatalogEntry(name: "List (Vertical)", icon: "list.bullet", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"List":{"children":{"explicitList":["l1","l2","l3"]},"direction":"vertical"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"Item 1"}}}},{"id":"l2","component":{"Text":{"text":{"literalString":"Item 2"}}}},{"id":"l3","component":{"Text":{"text":{"literalString":"Item 3"}}}}]}}
    """),

    CatalogEntry(name: "List (Horizontal)", icon: "list.bullet.indent", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"List":{"children":{"explicitList":["h1","h2","h3","h4","h5"]},"direction":"horizontal"}}},{"id":"h1","component":{"Card":{"child":"ht1"}}},{"id":"ht1","component":{"Text":{"text":{"literalString":"Card A"}}}},{"id":"h2","component":{"Card":{"child":"ht2"}}},{"id":"ht2","component":{"Text":{"text":{"literalString":"Card B"}}}},{"id":"h3","component":{"Card":{"child":"ht3"}}},{"id":"ht3","component":{"Text":{"text":{"literalString":"Card C"}}}},{"id":"h4","component":{"Card":{"child":"ht4"}}},{"id":"ht4","component":{"Text":{"text":{"literalString":"Card D"}}}},{"id":"h5","component":{"Card":{"child":"ht5"}}},{"id":"ht5","component":{"Text":{"text":{"literalString":"Card E"}}}}]}}
    """),

    CatalogEntry(name: "DateTimeInput", icon: "calendar", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["dt1","dt2","dt3"]}}}},{"id":"dt1","component":{"DateTimeInput":{"label":{"literalString":"Date only"},"value":{"path":"/date"},"enableDate":true,"enableTime":false}}},{"id":"dt2","component":{"DateTimeInput":{"label":{"literalString":"Time only"},"value":{"path":"/time"},"enableDate":false,"enableTime":true}}},{"id":"dt3","component":{"DateTimeInput":{"label":{"literalString":"Date & Time"},"value":{"path":"/datetime"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"date","valueString":"2025-12-09"},{"key":"time","valueString":"14:30:00"},{"key":"datetime","valueString":"2025-12-09T14:30:00"}]}}
    """),

    CatalogEntry(name: "ChoicePicker (Checkbox)", icon: "checklist", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Fruits"},"value":{"path":"/favorites"},"options":[{"label":{"literalString":"Apple"},"value":"A"},{"label":{"literalString":"Banana"},"value":"B"},{"label":{"literalString":"Cherry"},"value":"C"}],"filterable":true}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"favorites","valueMap":[{"key":"0","valueString":"A"}]}]}}
    """),

    CatalogEntry(name: "ChoicePicker (Radio)", icon: "circle.inset.filled", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Choose one"},"value":{"path":"/pick"},"variant":"mutuallyExclusive","options":[{"label":{"literalString":"Option A"},"value":"A"},{"label":{"literalString":"Option B"},"value":"B"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"pick","valueMap":[{"key":"0","valueString":"A"}]}]}}
    """),

    CatalogEntry(name: "ChoicePicker (Chips Single)", icon: "tag", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Pick one color"},"value":{"path":"/colors"},"displayStyle":"chips","variant":"mutuallyExclusive","options":[{"label":{"literalString":"Red"},"value":"R"},{"label":{"literalString":"Green"},"value":"G"},{"label":{"literalString":"Blue"},"value":"B"},{"label":{"literalString":"Yellow"},"value":"Y"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"colors","valueMap":[{"key":"0","valueString":"G"}]}]}}
    """),

    CatalogEntry(name: "ChoicePicker (Chips Multi)", icon: "tag.fill", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"ChoicePicker":{"label":{"literalString":"Select tags"},"value":{"path":"/tags"},"displayStyle":"chips","options":[{"label":{"literalString":"Work"},"value":"work"},{"label":{"literalString":"Home"},"value":"home"},{"label":{"literalString":"Urgent"},"value":"urgent"},{"label":{"literalString":"Later"},"value":"later"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"tags","valueMap":[{"key":"0","valueString":"work"},{"key":"1","valueString":"urgent"}]}]}}
    """),

    CatalogEntry(name: "Tabs", icon: "rectangle.split.3x1", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Tabs":{"tabs":[{"title":{"literalString":"View One"},"child":"t1"},{"title":{"literalString":"View Two"},"child":"t2"}]}}},{"id":"t1","component":{"Text":{"text":{"literalString":"First tab content"}}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Second tab content"}}}}]}}
    """),

    CatalogEntry(name: "Modal", icon: "rectangle.portrait.on.rectangle.portrait", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Modal":{"trigger":"mbtn","content":"mcol"}}},{"id":"mbtn","component":{"Button":{"child":"mbtn-text","action":{"name":"open_modal"}}}},{"id":"mbtn-text","component":{"Text":{"text":{"literalString":"Open Modal"}}}},{"id":"mcol","component":{"Column":{"children":{"explicitList":["mh","mp","mclose"]}}}},{"id":"mh","component":{"Text":{"text":{"literalString":"Modal Title"},"variant":"h3"}}},{"id":"mp","component":{"Text":{"text":{"literalString":"This is a modal dialog with rich content. Tap the X button or swipe down to dismiss."}}}},{"id":"mclose","component":{"Button":{"child":"mclose-text","action":{"name":"dismiss_modal"}}}},{"id":"mclose-text","component":{"Text":{"text":{"literalString":"Got it"}}}}]}}
    """),

    CatalogEntry(name: "Video", icon: "play.rectangle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Video":{"url":{"literalString":"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"}}}}]}}
    """),

    CatalogEntry(name: "AudioPlayer", icon: "waveform", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"AudioPlayer":{"url":{"literalString":"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"},"description":{"literalString":"Sample Audio Track"}}}}]}}
    """),

    CatalogEntry(name: "v0.9 Contact Form", icon: "envelope.badge.shield.half.filled", jsonl: """
    {"version":"v0.9","createSurface":{"surfaceId":"main"}}
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"Card","child":"form"},{"id":"form","component":"Column","children":["header","name_row","email_field","phone_field","pref_picker","divider_1","newsletter_cb","submit_btn"],"align":"stretch"},{"id":"header","component":"Text","text":"Contact Us","variant":"h2"},{"id":"name_row","component":"Row","children":["first_name","last_name"],"justify":"spaceBetween"},{"id":"first_name","component":"TextField","label":"First Name","value":{"path":"/contact/firstName"},"weight":1},{"id":"last_name","component":"TextField","label":"Last Name","value":{"path":"/contact/lastName"},"weight":1},{"id":"email_field","component":"TextField","label":"Email","value":{"path":"/contact/email"},"checks":[{"condition":{"call":"required","args":{"value":{"path":"/contact/email"}}},"message":"Email is required."},{"condition":{"call":"email","args":{"value":{"path":"/contact/email"}}},"message":"Please enter a valid email address."}]},{"id":"phone_field","component":"TextField","label":"Phone","value":{"path":"/contact/phone"},"checks":[{"condition":{"call":"regex","args":{"value":{"path":"/contact/phone"},"pattern":"^\\d{10}$"}},"message":"Phone number must be 10 digits."}]},{"id":"pref_picker","component":"ChoicePicker","label":"Preferred Contact","variant":"mutuallyExclusive","options":[{"label":"Email","value":"email"},{"label":"Phone","value":"phone"},{"label":"SMS","value":"sms"}],"value":{"path":"/contact/preference"}},{"id":"divider_1","component":"Divider"},{"id":"newsletter_cb","component":"CheckBox","label":"Subscribe to newsletter","value":{"path":"/contact/subscribe"}},{"id":"submit_label","component":"Text","text":"Send Message"},{"id":"submit_btn","component":"Button","child":"submit_label","variant":"primary","action":{"event":{"name":"submitContactForm","context":{"formId":"contact_form_1"}}}}]}}
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","path":"/contact","value":{"firstName":"John","lastName":"Doe","email":"john.doe@example.com","phone":"1234567890","preference":["email"],"subscribe":true}}}
    """),

    CatalogEntry(name: "Chart (Doughnut)", icon: "chart.pie", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Canvas":{"children":{"explicitList":["chart"]}}}},{"id":"chart","component":{"Chart":{"type":"doughnut","title":{"path":"/chart.title"},"chartData":{"path":"/chart.items"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"chart.title","valueString":"Sales by Category"},{"key":"chart.items[0].label","valueString":"Apparel"},{"key":"chart.items[0].value","valueNumber":41},{"key":"chart.items[0].drillDown[0].label","valueString":"Tops"},{"key":"chart.items[0].drillDown[0].value","valueNumber":31},{"key":"chart.items[0].drillDown[1].label","valueString":"Bottoms"},{"key":"chart.items[0].drillDown[1].value","valueNumber":38},{"key":"chart.items[1].label","valueString":"Home Goods"},{"key":"chart.items[1].value","valueNumber":15},{"key":"chart.items[2].label","valueString":"Electronics"},{"key":"chart.items[2].value","valueNumber":28},{"key":"chart.items[2].drillDown[0].label","valueString":"Phones"},{"key":"chart.items[2].drillDown[0].value","valueNumber":25},{"key":"chart.items[2].drillDown[1].label","valueString":"Laptops"},{"key":"chart.items[2].drillDown[1].value","valueNumber":27},{"key":"chart.items[3].label","valueString":"Health & Beauty"},{"key":"chart.items[3].value","valueNumber":10},{"key":"chart.items[4].label","valueString":"Other"},{"key":"chart.items[4].value","valueNumber":6}]}}
    """),

    CatalogEntry(name: "Map (MapKit)", icon: "map", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Canvas":{"children":{"explicitList":["header","map"]}}}},{"id":"header","component":{"Text":{"text":{"literalString":"Points of Interest in Los Angeles"},"variant":"h3"}}},{"id":"map","component":{"GoogleMap":{"center":{"path":"/mapConfig.center"},"zoom":{"path":"/mapConfig.zoom"},"pins":{"path":"/mapConfig.locations"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"mapConfig.center.lat","valueNumber":34.0522},{"key":"mapConfig.center.lng","valueNumber":-118.2437},{"key":"mapConfig.zoom","valueNumber":11},{"key":"mapConfig.locations[0].lat","valueNumber":34.0135},{"key":"mapConfig.locations[0].lng","valueNumber":-118.4947},{"key":"mapConfig.locations[0].name","valueString":"Google Store Santa Monica"},{"key":"mapConfig.locations[1].lat","valueNumber":34.1341},{"key":"mapConfig.locations[1].lng","valueNumber":-118.3215},{"key":"mapConfig.locations[1].name","valueString":"Griffith Observatory"},{"key":"mapConfig.locations[2].lat","valueNumber":34.0453},{"key":"mapConfig.locations[2].lng","valueNumber":-118.2673},{"key":"mapConfig.locations[2].name","valueString":"Crypto.com Arena"}]}}
    """),
]

#Preview {
    NavigationStack {
        CatalogPage()
    }
}
