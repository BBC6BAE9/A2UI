# A2UI Base Component SwiftUI Mapping Decisions

This document records the implementation decisions for mapping base components from the [A2UI protocol](https://github.com/anthropics/a2ui) (Agent-to-UI specification defined by Google) to the SwiftUI platform.
Based on **A2UI spec v0.8**.

---

## Design Principles

### 1. Default to System Native Controls

The framework's default implementation **prioritizes SwiftUI system controls and system styles** (such as `ButtonStyle`, `ToggleStyle`, `DatePickerStyle`),
ensuring automatic HIG-standard behavior across all Apple platforms (iOS / macOS / tvOS / watchOS / visionOS),
including Dynamic Type, Dark Mode, Accessibility, and platform-specific interactions (visionOS hover, tvOS focus), etc.

### 2. Business-Level Overridable

The framework provides `A2UIStyle` and a series of `.a2uiXxxStyle()` view modifiers via SwiftUI Environment,
allowing the business layer to override any component's appearance as needed. Overrides are optional — system defaults are used when no override is applied.

For example, Button: the framework defaults to system `.borderedProminent` / `.bordered` / `.borderless`,
but the business layer can inject `ButtonVariantStyle` (foregroundColor, backgroundColor, cornerRadius, etc.) via `.a2uiButtonStyle(for:)`,
at which point the framework switches to custom rendering mode.

### 3. Does Not Respond to web_core CSS Theme

The Lit renderer's theme system (`components` class map + `additionalStyles` inline CSS) is a **Web-specific mechanism**.
The SwiftUI renderer does not parse or respond to it. The SwiftUI side provides **equivalent override capabilities** through `A2UIStyle` + SwiftUI Environment,
but using native SwiftUI APIs instead of CSS. This is the same approach as the Flutter renderer (separate repo `genui_a2ui`) — each native platform renderer provides its own platform-native override mechanism.

---

## Component Nativeness Levels

Based on the degree of system control usage in the implementation, all components are classified into three levels:

### Level A — Direct System Control Mapping

1:1 usage of system controls + system styles. Framework code only passes spec properties to system control parameters.

| A2UI Component | SwiftUI Control | Notes |
|---|---|---|
| Text | `Text` | System semantic fonts (`.largeTitle`, `.title`, etc.) |
| Button | `Button` + `.borderedProminent`/`.bordered`/`.borderless` | System `ButtonStyle`, zero custom rendering |
| CheckBox | `Toggle` (`.automatic`) | iOS → switch, macOS → checkbox, system auto-selects |
| TextField | `TextField` / `SecureField` / `TextEditor` | `.roundedBorder` system style |
| DateTimeInput | `DatePicker` (`.automatic`) | iOS → compact, macOS → stepperField |
| Slider | `Slider` | System slider; tvOS falls back to `Button` + `ProgressView` |
| Divider (horizontal) | `Divider` | System separator line |
| Modal | `.sheet` modifier | System modal + `NavigationStack` |

### Level B — System Control Composition

Multiple system controls composed together. Each sub-control is system-native, but the composition is defined by the framework.

| A2UI Component | Composition | Notes |
|---|---|---|
| Image | `AsyncImage` / `Image` | System async loading + system modifiers (`.resizable`, `.clipShape`) |
| Icon | `Image(systemName:)` | SF Symbols standard icons; custom SVG path falls back to `Shape` |
| Video | `AVPlayerViewController` / `AVPlayerView` / `VideoPlayer` | Platform-specific system player selection |
| AudioPlayer | `AVPlayer` + `Button` + `Slider` + `Text` | No system audio UI, but every sub-control is system-native |
| Row | `HStack` + `Spacer` | `justify` implemented via `Spacer` composition |
| Column | `VStack` + `Spacer` | Same as above, vertical direction |
| List | `ScrollView` + `LazyVStack`/`LazyHStack` | System lazy-loading containers |

### Level C — System Primitives + Custom Layout/Rendering

Uses system modifiers / Shape / SF Symbols as primitives, but the overall layout or interaction logic is custom.

| A2UI Component | Custom Part | Reason |
|---|---|---|
| Card | `RoundedRectangle` + `.background` + `.shadow` composition | Apple HIG has no Card concept; requires composing system primitives |
| Tabs | Custom `HStack` + `Button` + underline indicator | Lit renderer uses underline tab style; `Picker(.segmented)` appearance differs too much |
| ChoicePicker (chips) | Custom `FlowLayout` + `Button(.bordered)` + `Capsule` | SwiftUI has no native chips/FlowLayout |
| Divider (vertical) | `Color(.separator).frame(width: 1)` | SwiftUI `Divider` direction is determined by parent container, cannot be self-specified |

---

## Component Mapping Overview

| A2UI Component | SwiftUI Mapping | Nativeness | Reference |
|---|---|---|---|
| Text | `Text` | A | [Labels](https://developer.apple.com/design/human-interface-guidelines/labels) |
| Image | `Image` / `AsyncImage` | B | [Image Views](https://developer.apple.com/design/human-interface-guidelines/image-views) |
| Icon | `Image(systemName:)` | B | [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) |
| Button | `Button` + system `ButtonStyle` | A | [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) |
| CheckBox | `Toggle` (`.automatic`) | A | [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles) |
| TextField | `TextField` / `SecureField` / `TextEditor` | A | [Text Fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) |
| DateTimeInput | `DatePicker` (`.automatic`) | A | [Date Pickers](https://developer.apple.com/design/human-interface-guidelines/date-pickers) |
| Slider | `Slider` (+ tvOS stepper fallback) | A | [Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders) |
| ChoicePicker | `Button(.bordered)` + `FlowLayout` / SF Symbols list | C(chips) / B(radio,multi) | [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles) |
| Row | `HStack` | B | [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) |
| Column | `VStack` | B | [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) |
| List | `ScrollView` + `LazyVStack`/`LazyHStack` | B | [Lists and Tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) |
| Card | `RoundedRectangle` + `.background` + `.shadow` | C | [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) |
| Tabs | Custom `HStack` + `Button` + underline | C | — |
| Divider | `Divider` / `Color(.separator)` | A(horizontal) / C(vertical) | — |
| Modal | `.sheet` modifier | A | [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) |
| Video | `AVPlayerViewController` / `AVPlayerView` / `VideoPlayer` | B | [AVKit](https://developer.apple.com/documentation/avkit) |
| AudioPlayer | `AVPlayer` + system native control composition | B | [AVFoundation](https://developer.apple.com/documentation/avfoundation/avplayer) |

---

## Content Components

### Text

- **Mapping**: `SwiftUI.Text`
- **HIG Reference**: [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) / [Labels](https://developer.apple.com/design/human-interface-guidelines/labels)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `text` | `StringValue` | Yes | Displayed text content, supports simple Markdown (bold, italic, links) |
| `usageHint` | `string` enum | No | Text hierarchy hint: `h1`/`h2`/`h3`/`h4`/`h5`/`body`/`caption` |

- **variant → System semantic font mapping**:

| A2UI `usageHint` | → SwiftUI `Font` | → `Font.Weight` | → Color | HIG Semantics |
|---|---|---|---|---|
| `h1` | `.largeTitle` | `.semibold` | Default | Top-level page/screen title |
| `h2` | `.title` | `.semibold` | Default | Secondary title |
| `h3` | `.title2` | `.semibold` | Default | Tertiary title |
| `h4` | `.title3` | `.medium` | Default | Quaternary title |
| `h5` | `.headline` | `.medium` | Default | Paragraph heading |
| `caption` | `.caption` | Default | `.secondary` | Auxiliary description text |
| `body` / default | `.body` | Default | Default | Body text |

- **Decisions**:
  - **Use system semantic fonts throughout** (no hardcoded font sizes): System semantic fonts (`.largeTitle`, `.title`, etc.) automatically support Dynamic Type, optimal font sizes per platform, and Accessibility large fonts — a core HIG principle
  - **Markdown rendering**: Uses `AttributedString(markdown:)` to parse inline Markdown (bold, italic, code, links), a native system API available on iOS 15+
  - **Does not use `UILabel`/`NSTextField`**: SwiftUI `Text` is available across all platforms (iOS/macOS/tvOS/watchOS/visionOS) and automatically supports Dynamic Type
  - **Color adaptation**: Only `caption` uses the `.secondary` system semantic color; all others use the system default foreground color (automatically adapts to Light/Dark Mode)

- **Platform Availability**: `SwiftUI.Text` — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
- **Style Override**: Via `.a2uiTextStyle(for:font:weight:color:)` modifier, allowing per-variant override of font, weight, and color

### Image

- **Mapping**: Remote URL → `AsyncImage`; Local resource → `Image(assetName, bundle: .main)`
- **HIG Reference**: [Image Views](https://developer.apple.com/design/human-interface-guidelines/image-views)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `url` | `StringValue` | Yes | Image URL (remote http/https or local asset path) |
| `usageHint` | `string` enum | No | Image usage/size hint |
| `fit` | `string` enum | No | Image fit mode within container |

- **variant → System size mapping**:

| A2UI `usageHint` | Default Width | Default Height | HIG Semantics |
|---|---|---|---|
| `icon` | 32 | 32 | Small icon, inline usage |
| `avatar` | 32 | 32 | User avatar, `.clipShape(.circle)` when cornerRadius ≥ 1000 |
| `smallFeature` | 50 | 50 | Small feature image |
| `mediumFeature` | Full width | 150 | Medium feature image |
| `largeFeature` | Full width | 400 | Large feature image |
| `header` | Full width | 240 | Page header image |
| Default | Full width | 150 | General image |

- **fit mode → SwiftUI mapping**:

| A2UI `fit` | → SwiftUI | Notes |
|---|---|---|
| `"cover"` | `.resizable().scaledToFill().clipped()` | Fill container, clip overflow |
| `"contain"` / default | `.resizable().scaledToFit()` | Display fully, may have whitespace |
| `"fill"` | `.resizable()` without aspect ratio | Stretch to fill |
| `"none"` | Original size | No scaling |
| `"scale-down"` | `.scaledToFit()` + maxWidth/maxHeight | Only scale down, never up |

- **Decisions**:
  - **Use `AsyncImage` for remote loading**: A native system async image loader available on iOS 15+, with built-in loading `ProgressView` and error placeholder, available across all platforms
  - **Extract asset name from path for local resources**: Strip extension and use `Image(name, bundle: .main)` to load from Asset Catalog
  - **Avatar circular clipping**: Uses `.clipShape(.circle)` when `cornerRadius ≥ 1000`, the standard HIG presentation for avatars
  - **Placeholder**: Shows `Image(systemName: "photo")` system placeholder icon when URL is empty or loading fails

- **Platform Availability**: `AsyncImage` — iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+ / visionOS 1+ (all platforms)
- **Style Override**: Via `.a2uiImageStyle(for:width:height:cornerRadius:)` modifier, allowing per-variant override of size and corner radius

### Icon

- **Mapping**: `Image(systemName:)` (SF Symbols)
- **HIG Reference**: [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `name` | `IconNameValue` | Yes | Icon name (standard enum value) or custom SVG path |

- **Icon name mapping strategy**:
  - A2UI spec defines **42+ standard icon names** (Material Design style naming, e.g., `accountCircle`, `arrowBack`)
  - Each standard name maps to a corresponding **SF Symbol** via the `IconName` enum (e.g., `accountCircle` → `person.circle.fill`, `arrowBack` → `chevron.left`)
  - 59 SF Symbol mappings are built-in, covering navigation, actions, status, media, and other categories

- **Two rendering modes**:

| Mode | Trigger Condition | Rendering Method |
|---|---|---|
| Standard icon | `name` is an enum value | `Image(systemName: sfSymbolName)` |
| Custom SVG | `name` starts with SVG command letter (M/m) | `SVGPathShape` custom Shape rendering |

- **Decisions**:
  - **SF Symbols is Apple's standard icon system across all platforms**: Automatically adapts to Dynamic Type, Accessibility, Dark Mode, and platform-specific HIG appearance. Using `Image(systemName:)` ensures cross-platform consistency
  - **Name conversion**: Automatically converts snake_case (`arrow_back`) to camelCase (`arrowBack`), compatible with different server-side naming conventions
  - **Custom SVG path fallback**: When the spec-provided icon is not in the standard enum, parses SVG path data and renders using `Shape`
  - **Unified size**: 32×32, font `.title2`, consistent with the standard rendering size for system icons

- **Platform Availability**: `Image(systemName:)` — iOS 13+ / macOS 11+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
- **Style Override**: Via `.a2uiIcon(_:systemName:)` to replace any icon's SF Symbol name

---

## Interactive Components

### Button

- **Mapping**: `SwiftUI.Button` + system native `ButtonStyle`
- **SwiftUI system-provided ButtonStyles**:

| SwiftUI ButtonStyle | Appearance | Modifier Properties |
|---|---|---|
| `.borderedProminent` | Filled background, most prominent | Color changeable via `.tint()` |
| `.bordered` | Light/semi-transparent background border | Color changeable via `.tint()` |
| `.borderless` | Plain text, no border or background | — |
| `.plain` | No system decoration | Typically used for fully custom appearance |

  Additionally, the system supports two universal modifier properties:
  - **Destructive role** — `Button(role: .destructive)` automatically changes text/background to red
  - **Disabled state** — `.disabled(true)` automatically reduces opacity and disables interaction

- **A2UI spec defined Variants** (3 types):

| A2UI variant | Notes |
|---|---|
| `"primary"` | Primary action button |
| `"borderless"` | Borderless/text button |
| Default (no variant) | Standard button |

- **Mapping decisions**:

| A2UI variant | → SwiftUI ButtonStyle | Rationale |
|---|---|---|
| `"primary"` | `.borderedProminent` | Semantically equivalent — both represent the most prominent primary action on the page |
| `"borderless"` | `.borderless` | Direct correspondence — plain text, no border |
| Default (no variant) | `.bordered` | The spec's default button is a standard style; `.bordered` is the system's moderate choice between prominent and borderless |

  `.plain` is not used because it removes all system interaction feedback (highlight, hover, etc.), making it unsuitable as a clickable button.

- **Decisions**: **The framework defaults to system ButtonStyle with zero custom rendering** (no custom padding, color, or radius). This ensures automatic HIG-standard appearance on iOS, iPadOS, macOS, tvOS, and visionOS.
- **Business Override**: The business layer can inject `ButtonVariantStyle` (foregroundColor, backgroundColor, pressedOpacity, cornerRadius, padding, etc.) via `.a2uiButtonStyle(for:)`. Once injected, the framework switches to custom rendering mode and no longer uses system ButtonStyle. This provides equivalent override capability to the Lit renderer's `theme.additionalStyles.Button`, but using SwiftUI APIs instead of CSS.
- **tint**: Primary uses `style.primaryColor`
- **v0.8 compatibility**: `"primary": true` is automatically converted to `variant: "primary"`
- **Uncovered system capabilities**: `Button(role: .destructive)` and `.bordered` + `.tint(.secondary)` currently have no corresponding variants in the spec; they can be directly mapped if the spec expands in the future

### CheckBox

- **Mapping**: `SwiftUI.Toggle` + `.automatic` style (default)
- **HIG Reference**: [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `label` | `StringValue` | Yes | Text displayed next to the checkbox |
| `value` | `BooleanValue` | Yes | Current checked state (true/false), supports data binding |
| `checks` | `CheckRule[]` | No | Client-side validation rules (v0.9+) |

- **Core challenge**: The spec is named "CheckBox" (checkbox semantics), but iOS in the Apple ecosystem has no native checkbox appearance

- **All ToggleStyle evaluation**:

| ToggleStyle | Appearance | Platform | Suitable? |
|---|---|---|---|
| `.automatic` | **iOS → switch toggle**; **macOS → checkbox ☑** | All platforms | **Best** — System auto-selects the best appearance per platform according to HIG |
| `.switch` | Slide toggle switch | iOS / macOS / visionOS | Usable but forces switch on all platforms; not HIG-compliant on macOS |
| `.checkbox` | Checkbox ☑ | **macOS only** | Not available on iOS, won't compile |
| `.button` | Press-highlighted button | iOS 15+ / macOS 12+ | Semantic mismatch — looks like a button rather than a selection control |

- **Decisions**: Use `Toggle` + `.automatic` (i.e., don't explicitly specify a ToggleStyle)
  - **iOS/iPadOS** → Renders as a slide switch toggle (HIG-standard boolean toggle control)
  - **macOS** → Renders as a checkbox (HIG standard)
  - **tvOS** → System automatically adapts for focus interaction
  - **visionOS** → System automatically adapts for spatial interaction
  - Although the spec is named "CheckBox", the underlying semantics is **boolean toggling**, which `Toggle` fully covers. The appearance differences across platforms are exactly the HIG design intent — "one control, best presentation per platform"
  - **Does not use `.checkbox`**: Only available on macOS, won't compile cross-platform
  - **Does not use custom checkbox appearance**: Violates HIG guidance on per-platform control appearance, increases multi-platform maintenance cost

- **Style Override**: Via `.a2uiCheckBoxStyle(tintColor:labelFont:labelColor:)`
- **Validation**: Supports `checks` rules; on failure, displays a red caption error message below the Toggle

### TextField

- **Mapping**: `SwiftUI.TextField` / `SecureField` / `TextEditor` (auto-selected based on variant)
- **HIG Reference**: [Text Fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `label` | `StringValue` | Yes | Input field label text |
| `text` / `value` | `StringValue` | No | Current input value, supports data binding |
| `textFieldType` / `variant` | `string` enum | No | Input type: `shortText`/`number`/`date`/`longText`/`obscured` |
| `validationRegexp` | `string` | No | Client-side input validation regex |
| `checks` | `CheckRule[]` | No | Client-side validation rules (v0.9+) |

- **variant → System control mapping**:

| A2UI `variant` | → SwiftUI Control | → System Style | Rationale |
|---|---|---|---|
| Default / `shortText` | `TextField` | `.textFieldStyle(.roundedBorder)` | System standard single-line input, native on all platforms |
| `"obscured"` | `SecureField` | `.textFieldStyle(.roundedBorder)` | HIG requires a dedicated control for password input; `SecureField` auto-masks characters and shows system "passwords" keyboard hint |
| `"longText"` | `TextEditor` | Custom background + rounded corners | System multi-line text input control; watchOS/tvOS don't support `TextEditor`, falls back to regular `TextField` |
| `"number"` | `TextField` | `.keyboardType(.decimalPad)` (iOS) | System standard input + numeric keyboard; HIG recommends choosing the most appropriate keyboard type for the content |

- **All TextFieldStyle evaluation**:

| TextFieldStyle | Appearance | Platform | Suitable? |
|---|---|---|---|
| `.roundedBorder` | Rounded border input field | iOS / macOS / visionOS | **Best** — System standard, native on all platforms |
| `.plain` | No border, plain text | All platforms | Not suitable — Lacks visual boundary, users have difficulty identifying the input area |
| `.automatic` | System default | All platforms | Equivalent to `.roundedBorder` (iOS) or platform default |

- **Decisions**:
  - **Use all system native input controls** with no custom rendering. `TextField`, `SecureField`, and `TextEditor` all automatically get system appearance (rounded corners, focus highlight, cursor color, etc.) on each platform
  - **Keyboard adaptation**: The `number` variant uses `.decimalPad` on iOS; other platforms automatically ignore it (macOS has no virtual keyboard concept)
  - **Focus management**: Uses `@FocusState` to track focus; triggers regex validation on focus loss
  - **Validation feedback**: When `validationRegexp` or `checks` fail, displays a red `caption` error message below the input field, following the HIG principle of "provide immediate feedback near the input"
  - **longText fallback**: watchOS/tvOS don't support `TextEditor`; automatically falls back to regular `TextField`

- **Platform Availability**:
  - `TextField` / `SecureField` — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
  - `TextEditor` — iOS 14+ / macOS 11+ / visionOS 1+ (not available on watchOS/tvOS, requires fallback)
- **Style Override**: Via `textFieldStyle` (`longTextMinHeight`, `longTextBackgroundColor`, `longTextCornerRadius`, `errorColor`)

### DateTimeInput

- **Mapping**: `SwiftUI.DatePicker` + `.automatic` style
- **HIG Reference**: [Date Pickers](https://developer.apple.com/design/human-interface-guidelines/date-pickers)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `value` | `StringValue` | Yes | Selected date/time in ISO 8601 format, supports data binding |
| `enableDate` | `bool` | No | Whether to show date selection (default true) |
| `enableTime` | `bool` | No | Whether to show time selection (default true) |
| `min` | `StringValue` | No | Minimum selectable date/time (v0.9+) |
| `max` | `StringValue` | No | Maximum selectable date/time (v0.9+) |
| `label` | `StringValue` | No | Custom label (v0.9+) |
| `checks` | `CheckRule[]` | No | Client-side validation rules (v0.9+) |

- **enableDate/enableTime → DatePicker.Components mapping**:

| enableDate | enableTime | → `DatePicker.Components` | Default Label |
|---|---|---|---|
| true | true (default) | `.date` + `.hourAndMinute` | "Date & Time" |
| true | false | `.date` | "Date" |
| false | true | `.hourAndMinute` | "Time" |

- **All DatePickerStyle evaluation**:

| DatePickerStyle | Appearance | Platform | Suitable? |
|---|---|---|---|
| `.automatic` | **System selects the best appearance per platform** | iOS / macOS / visionOS | **Best** — compact on iOS, stepperField on macOS |
| `.compact` | Compact single-line, tap to expand calendar | iOS 14+ / macOS 10.15.4+ | Suitable, but explicit specification loses platform adaptiveness |
| `.graphical` | Inline full calendar view | iOS 14+ / macOS 10.15+ | Takes too much space, not suitable for embedding in forms |
| `.wheel` | Wheel picker | iOS only | Not suitable for cross-platform |

- **Decisions**:
  - **Use `DatePicker` + `.automatic` style** (don't explicitly specify DatePickerStyle); the system automatically selects the best presentation per platform
  - **iOS** → compact style (tap to expand calendar)
  - **macOS** → stepper field style (numeric stepper + dropdown calendar)
  - **visionOS** → System automatically adapts for spatial interaction
  - **tvOS fallback** → tvOS doesn't support `DatePicker` interaction; falls back to plain text display (formatted date string)
  - **watchOS** → System DatePicker is available but with limited interaction

- **Platform Availability**: `DatePicker` — iOS 13+ / macOS 10.15+ / watchOS 10+ / visionOS 1+ (tvOS not supported, requires fallback)
- **Style Override**: Via `.a2uiDateTimeInputStyle(tintColor:labelFont:labelColor:)`

### Slider

- **Mapping**: `SwiftUI.Slider` (tvOS falls back to stepper control)
- **HIG Reference**: [Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `value` | `NumberValue` | Yes | Current value, supports data binding |
| `minValue` / `min` | `number` | No | Minimum value |
| `maxValue` / `max` | `number` | No | Maximum value |
| `label` | `StringValue` | No | Label text (v0.9+) |
| `checks` | `CheckRule[]` | No | Client-side validation rules (v0.9+) |

- **spec property → SwiftUI Slider parameter mapping**:

| A2UI Property | → SwiftUI Parameter | Notes |
|---|---|---|
| `value` | `value: Binding<Double>` | Two-way binding via `a2uiDoubleBinding` |
| `min` | `in: min...max` | Slider range lower bound |
| `max` | `in: min...max` | Slider range upper bound |
| `label` | `label: { Text(label) }` | HIG: Provide descriptive label alongside the control |

- **Decisions**:
  - **Use system native `Slider`**: Native control on all platforms (except tvOS), automatically gets HIG-standard track, thumb, and tint coloring
  - **When label is present**: Label text on the left, current value on the right (monospaced digit font `.monospacedDigit()` to avoid layout jitter when values change)
  - **Value formatting**: Integers display as `"%.0f"`, decimals as `"%.1f"`, customizable via `sliderStyle.valueFormatter`
  - **tvOS fallback**: tvOS doesn't support native `Slider` (no touch interaction); falls back to **minus/plus system buttons + `ProgressView`** combination, with step size of 1/20 of the range
  - **tint coloring**: Uses `.tint()` modifier to set the filled track color, following the HIG principle "use tint to indicate interactivity"

- **tvOS fallback details**:

| Control | SwiftUI Component | Notes |
|---|---|---|
| Decrease button | `Button` + `Image(systemName: "minus")` | System SF Symbol |
| Progress bar | `ProgressView(value:total:)` | System native progress bar, visually replaces the Slider track |
| Increase button | `Button` + `Image(systemName: "plus")` | System SF Symbol |

- **Platform Availability**: `Slider` — iOS 13+ / macOS 10.15+ / watchOS 6+ / visionOS 1+ (tvOS not supported, falls back to stepper)
- **Style Override**: Via `.a2uiSliderStyle(tintColor:labelFont:labelColor:valueFont:valueColor:valueFormatter:)`

### ChoicePicker

- **Mapping**: System native control composition (`Button(.bordered)` + `FlowLayout` / Settings App-style selection list)
- **HIG Reference**: [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) (Settings App selected row + checkmark pattern)

- **A2UI spec definition** (v0.8 MultipleChoice / v0.9 ChoicePicker):

| Property | Type | Required | Notes |
|---|---|---|---|
| `options` | `[{label: StringValue, value: string}]` | Yes | List of selectable options |
| `value` / `selections` | `StringListValue` | Yes | Currently selected value array, supports data binding |
| `variant` / `displayStyle` | `string` enum | No | Display style: `"chips"` / `"checkbox"` |
| `filterable` | `bool` | No | Whether to show a search filter input |
| `maxAllowedSelections` | `number` | No | Maximum number of selections allowed |
| `label` | `StringValue` | No | Component label (v0.9+) |
| `checks` | `CheckRule[]` | No | Client-side validation rules (v0.9+) |

- **Core challenge**: The Apple ecosystem has no native "chips/tags multi-select" control

- **Native strategies for the two display modes**:

| Mode | Trigger Condition | Implementation | Reference |
|---|---|---|---|
| **Chips** | `displayStyle == "chips"` | Custom `FlowLayout` + `Button(.bordered)` + `Capsule` | `Button` (system `.bordered` style) |
| **Selection list** | Default (including radio and multi-select) | Text row + trailing `checkmark` icon | iOS/macOS Settings App single/multi-select pattern |

- **Decisions**:
  - **Radio and Multi-select both use the Settings App pattern**: Each row displays the option text, with selected items showing `Image(systemName: "checkmark")` on the right. This is the universal selection pattern used in the iOS Settings App (Wi-Fi selection, language selection, ringtone selection) and macOS System Preferences. The difference between Radio and Multi-select is only at the data layer (mutually exclusive vs. multi-select); the visual presentation is identical.
  - **Does not use SF Symbol checkbox squares / radio circles**: On iOS, Apple has never used checkbox square appearance (`checkmark.square.fill` / `square`) — that's a web and Android convention. macOS checkboxes are implemented via `Toggle(.checkbox)` and should not be manually simulated in list selection scenarios. The same applies to radio circles.
  - **No system-level "chips" control exists**, but every sub-control uses system native components: `Button(.bordered)` provides system button interaction feedback (highlight, hover, focus), and `Capsule` provides pill-shaped clipping
  - **FlowLayout** is the only custom `Layout`: Implements horizontal flow with automatic line wrapping; SwiftUI has no native equivalent (`HStack` does not auto-wrap)
  - **filterable search**: Uses a system `TextField` as the filter input
  - **Color semantics**: Selected checkmark uses `.accentColor` (system accent color), all automatically adapt to Dark Mode

- **Platform Availability**: All sub-components (`Button`, `Image(systemName:)`, `TextField`) — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
- **FlowLayout** requires the `Layout` protocol — iOS 16+ / macOS 13+ (lower versions need to fall back to VStack vertical arrangement)

---

## Layout Components

### Row

- **Mapping**: `SwiftUI.HStack`
- **HIG Reference**: SwiftUI native layout system, follows [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) HIG principles

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `children` | `ChildrenReference` | Yes | Child component list (explicitList or template) |
| `distribution` | `string` enum | No | Main axis (horizontal) distribution: `start`/`center`/`end`/`spaceBetween`/`spaceAround`/`spaceEvenly` |
| `alignment` | `string` enum | No | Cross axis (vertical) alignment: `start`/`center`/`end`/`stretch` |

- **distribution → SwiftUI mapping**:

| A2UI `distribution` | → SwiftUI Implementation | Notes |
|---|---|---|
| `start` / default | `HStack` default left-aligned | Children packed to the left |
| `center` | `HStack` + leading/trailing `Spacer` | Centered arrangement |
| `end` | `HStack` + leading `Spacer` | Children aligned to the right |
| `spaceBetween` | `Spacer` inserted between children | First and last flush to edges, space evenly distributed in between |
| `spaceAround` | Equal-width `Spacer` before and after each child | Equal spacing on both sides of each child |
| `spaceEvenly` | Equal-width `Spacer` in all gaps | All spacing (including edges) equal |

- **alignment → SwiftUI mapping**:

| A2UI `alignment` | → SwiftUI `VerticalAlignment` | Additional Handling |
|---|---|---|
| `start` / default | `.top` | — |
| `center` | `.center` | — |
| `end` | `.bottom` | — |
| `stretch` | `.center` | Children set `.frame(maxHeight: .infinity)` to stretch-fill |

- **Decisions**:
  - **`HStack` is the SwiftUI native horizontal layout container**, available on all platforms, automatically handles RTL layout (Arabic and other right-to-left languages)
  - **Default spacing 16**: 16pt spacing between children, close to the system default HStack spacing
  - **`distribution` implemented via `Spacer` composition**: SwiftUI has no direct `justify-content` property, but `Spacer` is a system native component with deterministic behavior across all platforms
  - **`stretch` implemented via `.frame(maxHeight: .infinity)`**: The native SwiftUI way to make child views stretch-fill the cross axis

- **Platform Availability**: `HStack` — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)

### Column

- **Mapping**: `SwiftUI.VStack`
- **HIG Reference**: SwiftUI native layout system, follows [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) HIG principles

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `children` | `ChildrenReference` | Yes | Child component list |
| `distribution` | `string` enum | No | Main axis (vertical) distribution: same as Row |
| `alignment` | `string` enum | No | Cross axis (horizontal) alignment: `start`/`center`/`end`/`stretch` |

- **alignment → SwiftUI mapping**:

| A2UI `alignment` | → SwiftUI `HorizontalAlignment` | Additional Handling |
|---|---|---|
| `start` / default | `.leading` | — |
| `center` | `.center` | — |
| `end` | `.trailing` | — |
| `stretch` | `.leading` | Children set `.frame(maxWidth: .infinity)` to stretch-fill |

- **Decisions**:
  - **`VStack` is the SwiftUI native vertical layout container**, available on all platforms
  - **Default spacing 8**: 8pt spacing between children
  - **Default alignment `.leading`**: Matches most UI design conventions (left-aligned typography), equivalent to CSS `align-items: flex-start`
  - **`alignment == nil` does not equal `stretch`**: This is a fixed bug — nil uses `.leading` default alignment, not stretch-fill
  - **`distribution` implementation logic is completely symmetric to Row**, only changing direction from horizontal to vertical

- **Platform Availability**: `VStack` — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)

### List

- **Mapping**: `ScrollView` + `LazyVStack` (vertical) / `LazyHStack` (horizontal)
- **HIG Reference**: [Lists and Tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `children` | `ChildrenReference` | Yes | Child component list (supports template mode for data-driven rendering) |
| `direction` | `string` enum | No | Scroll direction: `"vertical"` (default) / `"horizontal"` |
| `alignment` | `string` enum | No | Cross axis alignment: `start`/`center`/`end`/`stretch` |

- **Why `ScrollView` + `LazyVStack` instead of system `SwiftUI.List`**:

| Candidate Approach | Exclusion Reason |
|---|---|
| `SwiftUI.List` | Comes with separators, inset grouped style, and other system list decorations that don't match A2UI's "pure content scrolling list" semantics; doesn't support horizontal scrolling |
| `ScrollView` + `VStack` | No lazy loading support; creates all child components at once with large datasets, poor performance |
| **`ScrollView` + `LazyVStack`/`LazyHStack`** | **Best** — Lazy loading (on-demand creation) + no system list decorations + supports both horizontal and vertical directions |

- **direction → SwiftUI mapping**:

| A2UI `direction` | → SwiftUI Implementation |
|---|---|
| `"vertical"` / default | `ScrollView(.vertical)` + `LazyVStack(spacing: 0)` |
| `"horizontal"` | `ScrollView(.horizontal)` + `LazyHStack(spacing: 0)` |

- **Decisions**:
  - **`LazyVStack`/`LazyHStack` implements lazy loading**: Child views are only created when they're about to appear on screen, suitable for long lists/large datasets
  - **Spacing is 0**: A2UI's List is a pure container; child components control their own spacing (via padding or Card, etc.)
  - **Scroll indicators hidden**: `showsIndicators: false`, maintaining a clean content display
  - **alignment is passed through the LazyVStack/LazyHStack alignment parameter**
  - **Does not use system `List`**: System `List`'s separators and inset grouped style are designed for "settings pages" and are not suitable for a general-purpose A2UI content container

- **Platform Availability**: `LazyVStack`/`LazyHStack` — iOS 14+ / macOS 11+ / tvOS 14+ / watchOS 7+ / visionOS 1+ (all platforms)

### Card

- **Mapping**: System `.background` + `RoundedRectangle` + `.shadow` composition
- **HIG Reference**: [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) / [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `child` | `string` (ComponentId) | Yes | Child component embedded in the card |

- **Core challenge**: SwiftUI/Apple HIG has no native control named "Card". Material Design's Card corresponds to a **content container with rounded corners and shadow** in the Apple ecosystem

- **System native components used**:

| Component | Purpose | System Native? |
|---|---|---|
| `RoundedRectangle(cornerRadius:)` | Rounded shape | **System Shape** |
| `.background()` | Background color | **System modifier** |
| `.shadow(color:radius:y:)` | Card shadow | **System modifier** |
| `.clipShape(RoundedRectangle(...))` | Content clipping | **System modifier** |
| `Color(.systemBackground)` / `.background` | Default background color | **System semantic color** |

- **Decisions**:
  - **Compose system native components** to build the Card effect: rounded corners + background color + shadow. Each component part is a system native API, ensuring cross-platform consistency
  - **Background color uses system semantic color**: Defaults to `.background` (system background color), automatically adapts to Light/Dark Mode
  - **Shadow parameters**: Default `cornerRadius: 12`, `shadowRadius: 4`, `shadowColor: .black.opacity(0.08)`, `shadowY: 1`, creating a subtle floating effect
  - **Full-width left-aligned**: `.frame(maxWidth: .infinity, alignment: .leading)`, card automatically fills container width
  - **Does not use `GroupBox`**: `GroupBox` is a system native container component, but its appearance (title + group border) doesn't match A2UI Card's "pure content container" semantics

- **Platform Availability**: `RoundedRectangle`, `.background()`, `.shadow()` — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
- **Style Override**: Via `.a2uiCardStyle(padding:cornerRadius:shadowRadius:shadowColor:shadowY:backgroundColor:)`

### Tabs

- **Mapping**: Adaptive — `Picker(.segmented)` (≤5 tabs) / `ScrollView(.horizontal)` + `Button(.bordered)` (>5 tabs)
- **HIG Reference**: [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `tabs` | `[{title: StringValue, child: ComponentId}]` | Yes | Tab list, each item contains a title and content component |

- **Candidate approach exclusion analysis**:

| Candidate Approach | Exclusion Reason |
|---|---|
| `TabView` (default) | Full-screen navigation structure (bottom tab bar), cannot be embedded inline in a page |
| `TabView(.page)` | Swipe pagination + dot indicators, semantically a content carousel/onboarding flow, not tabs |
| `TabView(.sidebarAdaptable)` | iOS 18+ full-screen navigation, becomes sidebar on iPadOS, still not an inline component |
| Custom `HStack` + `Button` + underline | Material Design / Web style, not Apple native controls, loses system Dynamic Type, VoiceOver, and focus management |

- **Decisions**: Adaptively select system native approach based on tab count

| Tab Count | Approach | Apple Reference |
|---|---|---|
| **≤5** | `Picker(.segmented)` | iOS Settings (Map/Transit/Satellite), Calendar (Day/Week/Month/Year) |
| **>5** | `ScrollView(.horizontal)` + `Button(.bordered)` | Apple Music Browse categories, App Store filters |

  - **≤5 tabs — `Picker(.segmented)`**: Apple HIG explicitly recommends no more than 5 segments in a segmented control. The iOS Settings App widely uses this pattern. Native rendering on all platforms, system automatically handles Dynamic Type, VoiceOver, and keyboard navigation
  - **>5 tabs — `ScrollView(.horizontal)` + `Button(.bordered)`**: The standard pattern in Apple Music Browse and App Store category filters. Each tab is a system `Button(.bordered)`, selected item highlighted via `.tint(.accentColor)`, unselected uses `.tint(.secondary)`. Both `ScrollView` and `Button` are system native controls
  - **Threshold of 5 rationale**: Apple HIG states "On iPhone, a segmented control should have five or fewer segments"

- **State Management**: Uses `TabsUIState` to maintain `selectedIndex`
- **Platform Availability**: `Picker(.segmented)` / `ScrollView` / `Button(.bordered)` — iOS 15+ / macOS 12+ / tvOS 15+ / visionOS 1+ (all platforms)

### Divider

- **Mapping**: Horizontal → `SwiftUI.Divider()`; Vertical → `Color(.separator).frame(width: 1)`
- **Decisions**:
  - Horizontal direction fully uses system native `Divider`
  - Vertical direction: SwiftUI `Divider`'s direction is **determined by the parent container** (automatically becomes vertical in HStack), but A2UI's `axis` is a component-level property that cannot depend on parent container context. Therefore, vertical dividers use a 1pt color block with the platform separator color
  - **Does not use `.rotationEffect`**: Rotation causes layout issues (frame doesn't change with rotation); the current `Color.frame(width: 1)` approach is more reliable
- **Platform Color Adaptation**: `UIColor.separator` (iOS) / `NSColor.separatorColor` (macOS) / `Color.gray.opacity(0.3)` (fallback), automatically adapts to Light/Dark Mode

### Modal

- **Mapping**: `.sheet` modifier (system native modal presentation)
- **HIG Reference**: [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) / [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `entryPointChild` / `trigger` | `string` (ComponentId) | Yes | Component that triggers opening the modal (e.g., a button) |
| `contentChild` / `content` | `string` (ComponentId) | Yes | Content component displayed inside the modal |

- **Candidate approach evaluation**:

| Approach | SwiftUI API | Platform | Suitable? |
|---|---|---|---|
| `.sheet` | `.sheet(isPresented:)` | All platforms | **Best** — HIG standard modal presentation |
| `.fullScreenCover` | `.fullScreenCover(isPresented:)` | iOS 14+ (macOS not supported) | Not suitable — Full-screen cover is too aggressive; A2UI Modal semantics is a temporary content panel |
| `.popover` | `.popover(isPresented:)` | iOS/macOS/visionOS | Not suitable — Semantically an anchored tooltip bubble, not an independent content panel |
| `.alert` | `.alert(isPresented:)` | All platforms | Not suitable — Only for simple information prompts, cannot embed complex components |
| Custom `ZStack` overlay | `ZStack` + animation | All platforms | Not suitable — Loses system sheet gesture interaction (drag to dismiss) and platform adaptation |

- **Decisions**:
  - **Use system `.sheet` modifier**: HIG explicitly recommends Sheet for "gathering input or presenting content related to the current context", which perfectly matches A2UI Modal semantics
  - **Dual-channel triggering**:
    1. Tap trigger component (`onTapGesture`) → open sheet
    2. Action handler interception (action triggered by a button within child components) → open sheet
  - **Content structure**: `NavigationStack` + `ScrollView` + content component, ensuring:
    - Content is scrollable (long content is not truncated)
    - System navigation bar provides consistent appearance
  - **Close button**: System `xmark` icon (SF Symbol) in the top-right corner, controlled by `modalStyle.showCloseButton`
  - **iOS/visionOS enhancements**: Uses `.presentationDetents([.medium, .large])` for half-screen/full-screen two-stop docking + `.presentationBackground(.regularMaterial)` frosted glass background
  - **macOS**: System sheet automatically renders as a modal panel sliding from the top of the window, following macOS HIG
  - **tvOS**: System `.sheet` automatically adapts for focus navigation

- **Platform Availability**:
  - `.sheet` — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
  - `.presentationDetents` — iOS 16+ / macOS 13+ / visionOS 1+ (automatically ignored on lower versions)
  - `.presentationBackground` — iOS 16.4+ / macOS 13.3+ / visionOS 1+ (automatically ignored on lower versions)
- **State Management**: `ModalUIState` (reference type) manages the `isPresented` boolean
- **Style Override**: Via `.a2uiModalStyle(showCloseButton:contentPadding:)`

---

## Media Components

### Video

- **Mapping**: System native video player (automatically selects the best implementation per platform)
- **HIG Reference**: [Playing Video](https://developer.apple.com/design/human-interface-guidelines/playing-video)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `url` | `StringValue` | Yes | Video URL |

- **Platform → System player mapping**:

| Platform | Implementation | System Control | Notes |
|---|---|---|---|
| **iOS/iPadOS** | `UIViewControllerRepresentable` | `AVPlayerViewController` | System full playback control UI (play/pause, progress bar, fullscreen, picture-in-picture) |
| **tvOS** | `UIViewControllerRepresentable` | `AVPlayerViewController` | System tvOS player + Siri Remote control |
| **macOS** | `NSViewRepresentable` | `AVPlayerView` (inline control style) | System macOS video player |
| **visionOS** | SwiftUI native | `VideoPlayer(player:)` | SwiftUI native video view |
| **watchOS** | — | Placeholder view | AVKit not available, displays `video.slash` icon placeholder |

- **Decisions**:
  - **All use system native video players**: `AVPlayerViewController` (UIKit) / `AVPlayerView` (AppKit) / `VideoPlayer` (SwiftUI) are all Apple system-level players with complete built-in playback control UI, requiring no custom rendering
  - **16:9 aspect ratio**: Uses `.aspectRatio(16/9, contentMode: .fit)` to ensure the video area maintains the standard ratio
  - **URL validation**: Shows a gray placeholder + `video.slash` SF Symbol for invalid or empty URLs
  - **Player instance management**: `AVPlayer` instances are stored in `VideoUIState` (reference type) to avoid destroying/recreating the player during view tree rebuilds (which would cause reloading)
  - **Lifecycle**: `onAppear` creates the player, `onDisappear` pauses (doesn't destroy)
  - **Corner radius clipping**: Default 10pt corner radius, customizable via `videoStyle.cornerRadius`

- **Platform Availability**:
  - `AVPlayerViewController` — iOS 8+ / tvOS 9+
  - `AVPlayerView` — macOS 10.9+
  - `VideoPlayer` — iOS 14+ / macOS 11+ / tvOS 14+ / watchOS 7+ / visionOS 1+
  - watchOS: AVKit not available, falls back to placeholder
- **Style Override**: Via `.a2uiVideoStyle(cornerRadius:)`

### AudioPlayer

- **Mapping**: `AVPlayer` + system native control composition (`Button` + `Slider` / `ProgressView`)
- **HIG Reference**: [Playing Audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)

- **A2UI spec definition** (v0.8):

| Property | Type | Required | Notes |
|---|---|---|---|
| `url` | `StringValue` | Yes | Audio URL |
| `description` | `StringValue` | No | Audio description/title |

- **Core challenge**: Apple's system has no out-of-the-box audio player UI control (`AVPlayerViewController` is video-specific). However, we can build one using **entirely system native sub-controls**

- **System native controls used**:

| Control | SwiftUI Component | Purpose |
|---|---|---|
| Description label | `Text` | Display audio title/description |
| Play/Pause button | `Button` + `Image(systemName: "play.circle.fill"/"pause.circle.fill")` | SF Symbol system icons, `.title` font size |
| Current time | `Text` + `.monospacedDigit()` | Monospaced digit font to avoid layout jitter |
| Progress bar (iOS/macOS/visionOS) | `Slider(value:in:)` | System native Slider, draggable for seeking |
| Progress bar (tvOS) | `ProgressView(value:total:)` | tvOS doesn't support Slider, falls back to non-draggable system progress bar |
| Total duration | `Text` + `.monospacedDigit()` | Monospaced digit font |

- **Time display format**: `m:ss` (e.g., `1:30`, `12:05`)

- **Decisions**:
  - **Although there is no single system audio player control, every sub-control in the UI is system native**: `Button`, `Slider`, `ProgressView`, `Text`, `Image(systemName:)`, ensuring automatic HIG-standard appearance and interaction on all platforms
  - **Playback engine uses `AVPlayer`**: Apple's standard system audio playback framework, supports streaming
  - **Progress updates**: Syncs playback progress every 0.25 seconds via `addPeriodicTimeObserver(forInterval: 0.25s)`
  - **Async loading**: Uses `.task(id: url)` to asynchronously create `AVPlayer` and load audio duration
  - **tvOS fallback**: Slider not available, uses `ProgressView` instead (display only, not draggable)
  - **watchOS fallback**: AVKit not available, displays a waveform icon + description text as a static placeholder

- **Platform Availability**:
  - `AVPlayer` — iOS 4+ / macOS 10.7+ / tvOS 9+ (not available on watchOS)
  - All UI sub-controls (`Button`, `Slider`, `Text`, etc.) — iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / visionOS 1+ (all platforms)
- **State Management**: `AudioPlayerUIState` stores `player`, `isPlaying`, `currentTime`, `duration`, `timeObserver`
- **Style Override**: Via `.a2uiAudioPlayerStyle(tintColor:labelFont:cornerRadius:)`

---

## Extension Mechanism

### Custom Components

- **Mapping**: Custom renderers injected via `.a2uiCustomComponents(_:)` environment
- **Decisions**: Unregistered component types fall back to VStack layout rendering child elements. Custom renderers receive `ComponentNode` + `SurfaceViewModel` and return `AnyView?`.

---

## Cross-Platform Adaptation Strategy

| Platform | Adaptation Approach | Components Requiring Fallback |
|---|---|---|
| iOS / iPadOS | Primary target platform, full component support | — |
| macOS | System controls auto-adapt (Toggle → checkbox, DatePicker → stepperField, etc.) | — |
| tvOS | System controls auto-adapt for focus interaction | DatePicker → text display, Slider → Button stepper, AudioPlayer Slider → ProgressView |
| watchOS | System controls generally available | TextEditor → TextField, Video → placeholder, AudioPlayer → placeholder |
| visionOS | System controls auto-adapt for spatial interaction (hover, gestures, etc.) | — |

## Styling System

### Relationship with Web Renderer

The Lit renderer's styling is driven by `web_core`'s `Theme` type:
- `theme.components.Button` — `Record<string, boolean>`, CSS class toggles (e.g., `"layout-pt-3": true`, `"border-br-16": true`)
- `theme.additionalStyles.Button` — `Record<string, string>`, inline CSS properties (e.g., `background: "linear-gradient(...)"`)

These are purely Web/CSS mechanisms. **The SwiftUI renderer does not parse or respond to this CSS theme.** The Flutter renderer (separate repo `genui_a2ui`) follows the same principle.

### SwiftUI-Side Override Mechanism

The SwiftUI renderer provides equivalent override capabilities through `A2UIStyle` + SwiftUI Environment:

```swift
A2UIRendererView(manager: manager)
    .a2uiTextStyle(for: .h1, font: .system(size: 48), weight: .black)
    .a2uiCheckBoxStyle(tintColor: .green)
    .a2uiCardStyle(cornerRadius: 16, shadowRadius: 8)
    .a2uiButtonStyle(for: .primary, foregroundColor: .white, backgroundColor: .blue)
```

### Override Layering

| Layer | Behavior | Example |
|---|---|---|
| **Framework default** | Uses system native controls + system styles | Button → `.borderedProminent` |
| **Business override** | Injects custom parameters via `.a2uiXxxStyle()` modifier | Button → custom foreground/background/cornerRadius |

Core principle: **Style overrides are optional** — all components use system default appearance when no override is applied.
