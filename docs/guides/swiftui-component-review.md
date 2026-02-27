# SwiftUI 标准组件校验与修复流程

## 第一步：读 v0.9 Spec（唯一的属性真相来源）

读 `specification/v0_9/json/basic_catalog.json`，确认组件有哪些属性、哪些是 `required`、每个属性的类型和枚举值。

**只有 spec 里写的属性才需要响应，不要自己发明。**

## 第二步：读官方 Lit 实现（行为和默认值的真相来源）

必须读 **两个文件**：

1. **`renderers/lit/src/0.8/ui/<component>.ts`** — 组件自身的渲染逻辑、CSS 样式（间距、布局、默认值全在这里）
2. **`renderers/lit/src/0.8/ui/root.ts`** — 看组件是怎么被实例化的，哪些属性实际传了、哪些没传（spec 里有但 root.ts 没传的 = 官方也没实现）

**不要猜默认值。** 比如 `gap: 8px` 不是 List 组件的间距，是 Root 的 `:host` 样式。必须看清代码归属。

## 第三步：读 web_core 的 Theme 类型（判断用户重写）

读 `renderers/web_core/src/v0_8/types/types.ts`，确认官方为该组件提供了什么层级的自定义。**用户重写的范围和粒度必须严格对齐官方 Theme 定义，不可自行发明。**

### 判断规则

在 `types.ts` 的 `Theme` 接口中找到组件对应的字段：

- **`Record<string, boolean>`（纯 classMap）** → 官方只提供 CSS class 级别的重写，无结构化自定义。SwiftUI 侧 **不要** 发明 Style struct。
  - 例：`List: Record<string, boolean>` → 不加 `ListComponentStyle`
- **嵌套结构（如 `container` / `element` / `label`）** → 官方认为组件有多个可独立自定义的部分。SwiftUI 侧对应创建 Style struct，每个嵌套键对应一组属性。
  - 例：`Slider: { container, element, label }` → 创建 `SliderComponentStyle`，包含 label 字体/颜色、轨道颜色等
  - 例：`TextField: { container, element, label }` → 创建 `TextFieldComponentStyle`
- **`additionalStyles?.<Component>`（inline styleMap）** → 官方允许自由注入样式，说明组件的视觉重写是预期行为。SwiftUI 侧应提供对应的 ViewModifier。

### SwiftUI 侧实现模式

当确认需要用户重写时，遵循已建立的模式：

1. 在 `A2UIStyle` 中添加 `public var xxxStyle: XxxComponentStyle` 属性
2. 定义 `XxxComponentStyle` struct，属性与官方 Theme 嵌套结构对齐（不要多加也不要少加）
3. 在 `View` extension 中添加 `.a2uiXxxStyle(...)` ViewModifier，用 `transformEnvironment(\.a2uiStyle)` 实现
4. 在组件的 render 方法中读取 `style.xxxStyle` 并应用，原生控件属性优先、自定义样式作为补充

### 不要重写的情况

- 组件在 Theme 中只有 `Record<string, boolean>` → 不加自定义
- 组件是纯原生控件映射（如 SwiftUI.Slider、Toggle）且官方无嵌套 Theme → 只用原生控件，不包装自定义样式

## 第四步：逐项对比 SwiftUI 实现

拿着 spec 的属性列表和 Lit 的行为，逐一检查：

| 检查项 | 方法 |
|---|---|
| 属性是否声明 | 看 `ComponentTypes.swift` 的 struct |
| 属性是否在渲染中响应 | 看 `A2UIComponentView.swift` 对应的 render 方法 |
| 默认值是否正确 | 对比 Lit 的 CSS / JS 默认值 |
| 是否有多余的自定义 | 对比 Lit 的 theme 类型，官方没有的不要加 |
| 是否需要自定义 | 对比 Lit 的 theme 类型，官方有的要加 |
| HIG 对齐 | 用 SwiftUI 原生控件（Slider、Toggle、DatePicker 等）就自动跟系统走 |

## 第五步：Demo 验证

对照 spec 的属性和 Lit 实际使用的属性，确保 demo 覆盖了组件的主要用法（如 direction 的两种值），但不要展示 spec 有、官方未实现的属性。

## 核心原则

1. **Spec 定义"有什么"，Lit 定义"怎么做"** — 不要只看 spec 就开始写，必须看官方怎么实现的
2. **不要猜，不要发明** — 间距、颜色、自定义入口，全部从官方代码里找依据
3. **官方没实现的属性不要抢跑** — 比如 `align` 在 spec 里有，但 root.ts 没传，说明官方也没做，不要自作聪明
4. **原生控件优先** — SwiftUI 原生控件（Slider、Toggle、TextField 等）自动跟随系统 HIG，不要套自定义样式覆盖它

## 涉及文件速查

| 用途 | 路径 |
|---|---|
| v0.9 组件属性定义 | `specification/v0_9/json/basic_catalog.json` |
| v0.9 公共类型定义 | `specification/v0_9/json/common_types.json` |
| 官方 Lit 组件实现 | `renderers/lit/src/0.8/ui/<component>.ts` |
| 官方 Lit 组件实例化 | `renderers/lit/src/0.8/ui/root.ts` |
| 官方 Theme 类型定义 | `renderers/web_core/src/v0_8/types/types.ts` |
| SwiftUI 属性模型 | `renderers/swiftui/Sources/A2UI/Models/ComponentTypes.swift` |
| SwiftUI 渲染逻辑 | `renderers/swiftui/Sources/A2UI/Views/A2UIComponentView.swift` |
| SwiftUI 样式/自定义 | `renderers/swiftui/Sources/A2UI/Styling/A2UIStyle.swift` |
| Demo 数据 | `samples/client/swiftui/A2UIDemoApp/A2UIDemoApp/Pages/CatalogPage.swift` |
