# 完整掌握 A2UI：官方 Demo 运行指南

> 除 SwiftUI Demo App 外，你还需要运行哪些官方 Demo 才能完整理解 A2UI 协议的全部能力。
> 所有 Demo 均来自仓库自带代码，无需额外下载。

---

## 当前 SwiftUI Demo 的覆盖范围（~25%）

| Demo | 覆盖的功能 |
|------|-----------|
| **Catalog**（18 组件） | 全部标准组件的静态展示；基础数据绑定（TextField/CheckBox/Slider 绑 path）；v0.8 JSONL 格式 |
| **Samples**（3 个） | 静态 JSON 一次性加载渲染；Card + 布局组合；restaurant_list 使用了 template 展开 |

**未覆盖的关键能力**：A2A Agent 通信、Action 回传、checks/validation 函数体系、formatString 插值、多 Surface、增量更新、流式渲染、自定义组件、Accessibility、Agent 身份展示、多 Agent 编排。

---

## 推荐运行的 6 个官方 Demo

### Demo 1: Lit Component Gallery + Agent（最高优先级）

**你能学到什么**: 全组件行为参考、Action 交互闭环、Agent 动态响应模式

**路径**:
- Agent: `samples/agent/adk/component_gallery`
- Client: `samples/client/lit/component_gallery`

**运行方式**:

```bash
# Terminal 1 — Agent
cd samples/agent/adk/component_gallery
export GEMINI_API_KEY="your_key"
uv run .
# 运行在 http://localhost:10005

# Terminal 2 — Client
cd samples/client/lit/component_gallery
npm install && npm run dev
# 浏览器打开 http://localhost:5173
```

**观察重点**:
- 这是 A2UI 的 "Kitchen Sink"，所有 18 个标准组件 + 交互 + Action 回传 + Agent 动态响应都能看到
- 它是官方的**参考实现** —— SwiftUI Catalog 应该对标它的行为
- Agent 响应是流式到达还是一次性到达
- 用户点击 Button 后 Action 如何回传、Agent 如何用新 UI 响应
- TextField/CheckBox/Slider 等输入组件的数据绑定行为
- 多个 Surface 同时存在的效果

---

### Demo 2: Angular Gallery（客户端独立，无需 Agent）

**你能学到什么**: 组合布局模式、编程式 Surface 构造、Theme 自定义

**路径**: `samples/client/angular/projects/gallery`

**运行方式**:

```bash
cd samples/client/angular
npm install
npm run build
npm start -- gallery
```

**观察重点**:
- 这是**纯客户端**的组件展示，不需要 Agent 后端
- 用 TypeScript 代码直接构造 `Surface` 对象来渲染，对比 SwiftUI 中用 JSONL 硬编码的方式
- 组合布局模式：Row 嵌套 Column、Card 包裹复杂内容
- Theme 自定义的视觉效果
- 它分为 Library（单组件展示）和 Gallery（复合场景）两个视图

---

### Demo 3: Restaurant Finder 全链路（最接近真实产品）

**你能学到什么**: template 数组展开、表单交互闭环、Action context 数据绑定

**路径**:
- Agent: `samples/agent/adk/restaurant_finder`
- Client: `samples/client/lit/shell`

**运行方式**:

```bash
# Terminal 1 — 先构建渲染器依赖
cd renderers/web_core && npm install && npm run build
cd ../../renderers/lit && npm install && npm run build

# Terminal 2 — Agent
cd samples/agent/adk/restaurant_finder
export GEMINI_API_KEY="your_key"
uv run .

# Terminal 3 — Client (Shell)
cd samples/client/lit/shell
npm install && npm run dev
# 浏览器打开 http://localhost:5173
```

**观察重点**:
- 用户提问 → AI 生成餐厅列表 UI（`template` 展开数组数据）
- 用户点击餐厅 → AI 生成预约表单（TextField + DateTimeInput + Button with action context）
- 用户填写提交 → Action 带着数据模型回传 Agent → Agent 返回确认 UI
- 理解 **template 数组展开、Action context 数据绑定、完整交互闭环** 的最佳场景

**官方 JSON 参考**（可直接读取理解数据结构）:
- `samples/agent/adk/restaurant_finder/examples/single_column_list.json` — 餐厅列表
- `samples/agent/adk/restaurant_finder/examples/booking_form.json` — 预约表单
- `samples/agent/adk/restaurant_finder/examples/confirmation.json` — 提交确认

---

### Demo 4: Contact Multiple Surfaces（多 Surface 演示）

**你能学到什么**: 多 Surface 同时渲染、自定义组件注册、复杂数据模型

**路径**:
- Agent: `samples/agent/adk/contact_multiple_surfaces`
- Client: `samples/client/lit/contact`

**运行方式**:

```bash
# Terminal 1 — Agent
cd samples/agent/adk/contact_multiple_surfaces
export GEMINI_API_KEY="your_key"
uv run . --port=10004

# Terminal 2 — Client
cd samples/client/lit/contact
npm install && npm run dev
```

**观察重点**:
- 仓库中唯一演示 **多 Surface 同时渲染** 的 Demo
- 一次响应中同时 `beginRendering` 两个 Surface（`contact-card` + `org-chart-view`）
- 客户端如何布局多个 Surface（分屏/侧栏）
- 自定义组件（`OrgChart`、`WebFrame`）的注册和渲染方式
- Client-first 扩展模型：客户端告知 Agent 自己支持哪些自定义组件

**官方 JSON 参考**:
- `samples/agent/adk/contact_multiple_surfaces/examples/multi_surface.json` — 多 Surface 响应结构
- `samples/agent/adk/contact_multiple_surfaces/examples/org_chart.json` — 自定义组件
- `samples/agent/adk/contact_multiple_surfaces/examples/contact_card.json` — 联系人卡片

---

### Demo 5: Orchestrator 多 Agent 编排（最复杂场景）

**你能学到什么**: 多 Agent 路由、同一客户端接收不同 Agent 的 UI

**路径**:
- 子 Agent: `restaurant_finder` / `contact_lookup` / `rizzcharts`
- 编排 Agent: `samples/agent/adk/orchestrator`
- Client: `samples/client/angular/projects/orchestrator`

**运行方式**:

```bash
# Terminal 1 — Restaurant Agent
cd samples/agent/adk/restaurant_finder
export GEMINI_API_KEY="your_key"
uv run . --port=10003

# Terminal 2 — Contact Agent
cd samples/agent/adk/contact_lookup
export GEMINI_API_KEY="your_key"
uv run . --port=10004

# Terminal 3 — Rizzcharts Agent
cd samples/agent/adk/rizzcharts
export GEMINI_API_KEY="your_key"
uv run . --port=10005

# Terminal 4 — Orchestrator Agent
cd samples/agent/adk/orchestrator
uv run . --port=10002 \
  --subagent_urls=http://localhost:10003 \
  --subagent_urls=http://localhost:10004 \
  --subagent_urls=http://localhost:10005

# Terminal 5 — Angular Client
cd samples/client/angular
npm install && npm run build
npm start -- orchestrator
```

**观察重点**:
- Orchestrator Agent 根据用户意图将请求路由到不同的子 Agent
- 同一个客户端接收来自不同 Agent 的 UI 响应
- 理解 A2UI 在多 Agent 协作场景下的工作方式
- 注意：rizzcharts 需要 Google Maps API key，没有也能跑，只是地图部分不显示

---

### Demo 6: v0.9 Spec 官方测试用例（读 JSON，不需运行）

**你能学到什么**: checks/validation 函数体系的完整语法、协议边界条件

**路径**: `specification/v0_9/test/cases/`

| 文件 | 覆盖的功能 |
|------|-----------|
| `contact_form_example.jsonl` | **完整表单**：checks + required/email/regex 函数 + formatDate + ChoicePicker + Button action with context |
| `checkable_components.json` | **所有可校验组件**的 checks 用法：TextField(required/email/regex/length) + ChoicePicker(length) + Slider(numeric) + CheckBox(required) + DateTimeInput(required) + **and/or/not 嵌套逻辑** |
| `button_checks.json` | Button checks 的 **and/or 嵌套条件**、variant 属性、废弃属性检测 |
| `text_variants.json` | Text 组件所有 variant 的验证 |
| `theme_validation.json` | Theme（primaryColor）的合法/非法格式 |
| `function_catalog_validation.json` | 函数目录的 schema 验证 |
| `client_messages.json` | 客户端消息格式（UserAction 等） |

**重点阅读**: `contact_form_example.jsonl` 和 `checkable_components.json`，它们定义了 checks/validation 函数体系的权威用法，直接决定你 SwiftUI 渲染器需要实现的函数引擎行为。

---

## 推荐运行顺序与收益

| 顺序 | Demo | 运行难度 | 学到什么 | 累计覆盖率 |
|:----:|------|:--------:|---------|:----------:|
| 1 | **Lit Component Gallery** | 中（Agent + Client） | 全组件行为参考、Action 交互、Agent 响应模式 | ~45% |
| 2 | **Angular Gallery** | 低（纯客户端） | 组合布局、编程式 Surface 构造、Theme | ~50% |
| 3 | **Restaurant Finder** | 中（Agent + Client） | template 展开、表单闭环、Action context | ~60% |
| 4 | **Contact Multi-Surface** | 中（Agent + Client） | 多 Surface、自定义组件、复杂数据模型 | ~70% |
| 5 | **Orchestrator** | 高（4 Agent + Client） | 多 Agent 编排、最复杂场景 | ~85% |
| 6 | **读 v0.9 test cases** | 零（读 JSON） | checks/validation 函数体系、协议边界条件 | ~100% |

---

## 每个 Demo 对 SwiftUI 渲染器开发的反哺

| 观察到的行为 | 反哺到 SwiftUI 渲染器 |
|-------------|---------------------|
| Lit Component Gallery 中的 Action 回传流程 | SwiftUI Demo 目前无 Agent 通信，需新建 Live Agent 页面实现 Action 回传 |
| Restaurant Finder 中 template 展开数组 | 验证 SwiftUI restaurant_list.json 的 template 行为是否正确 |
| Contact Multi-Surface 的多 Surface 布局 | SwiftUI `SurfaceManager` 已实现但无 Demo，需补充演示 |
| Contact Multi-Surface 的自定义组件注册 | SwiftUI 需实现自定义组件注册机制 |
| checkable_components.json 中 and/or/not 嵌套 | SwiftUI 需实现 checks 引擎 + 客户端函数注册表 |
| contact_form_example.jsonl 中 formatDate | SwiftUI 需实现 formatDate 函数 |
| Orchestrator 中不同 Agent 的 UI 路由 | SwiftUI 需实现 Agent 连接页面，支持切换/管理多 Agent |

---

## 前置依赖

### 运行 Agent 需要

- Python 3.10+ 和 `uv`（Python 包管理器）
- `GEMINI_API_KEY` 环境变量（从 Google AI Studio 获取）

### 运行 Lit Client 需要

- Node.js 18+ 和 `npm`
- 先构建渲染器：`cd renderers/web_core && npm install && npm run build && cd ../lit && npm install && npm run build`

### 运行 Angular Client 需要

- Node.js 18+ 和 `npm`
- `cd samples/client/angular && npm install && npm run build`
