# 给执行 AI 的指令

你的任务是：**基于 PackCheck 项目的塔科夫式配装系统设计 Spec，先出实现计划（plan），等我确认后再按计划逐步开发。**

---

## 0. 开始之前：必须读完的上下文

**在你写任何代码或计划之前，用 Read 工具按顺序完整读完以下文件。跳过任何一项都会导致方向偏离。**

### 第一优先级：方向与规范

| 顺序 | 文件 | 为什么要读 |
|------|------|-----------|
| 1 | `CLAUDE.md` | 这是项目的"宪法"——开发铁律、UI/UX 规范、设计决策三步法、沟通底线。**不读这个就开始写代码 = 盲干** |
| 2 | `docs/DEVELOPMENT_STANDARDS.md` | 架构规范（代码放哪）、设计语言系统（颜色/字号/间距/动效 token）、组件封装规范、ArkUI 避坑要点 |
| 3 | `docs/vision/2026-06-04-product-vision-and-restructure.md` | 产品愿景纲领。重点读 §4（塔科夫配装的完整范式定义）、§6（三步走落地排序） |
| 4 | `docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md` | v2 地基层技术 spec（数据模型现状、配装数据种子 GearLoadout、各页面交互逻辑） |
| 5 | `memory/MEMORY.md` | 37 条 ArkUI 踩坑清单——遇到动效/手势/布局问题先查这里 |

### 第二优先级：配装系统 Spec 及其审查意见

| 顺序 | 文件 | 为什么要读 |
|------|------|-----------|
| 6 | `docs/v2-foundation/specs/2026-06-10-loadout-system-design.md` | **本次开发的核心 spec（v3）**。全文精读。这是你的蓝图 |
| 7 | `docs/v2-foundation/specs/2026-06-10-loadout-system-design-review-3.md` | 第三轮审查意见。spec 已成熟但仍有一些衔接细节（P1/P2）需要你在实施时注意。读完理解即可，不用逐条回复 |
| 8 | `docs/ROADMAP.md` | 整体路线图，了解这个功能在全局中的位置 |

### 第三优先级：需要修改/参考的关键代码文件

| 顺序 | 文件 | 重点关注 |
|------|------|---------|
| 9 | `entry/src/main/ets/pages/Index.ets` | `NavDestinationMap` @Builder（行 1700-1779）——这是你要新增 `'TripDetailPage'` 分支的地方；`openSheetAnimated()`/`closeSheet()` 方法；`pushPath`/`pushPathByName` 的调用方式；`contentScale`/`contentBlur` 的景深处理 |
| 10 | `entry/src/main/ets/constants/GearLoadout.ets` | 已有的 `BodyZone`/`LayerOrder` 枚举 + `CATEGORY_SLOT_MAP` + `slotHintForCategory()`——配装系统的数据地基，**不要重新定义**，直接 import 使用 |
| 11 | `entry/src/main/ets/components/ChecklistDetail.ets` | 理解现有的行程详情页结构——它将被嵌入 TripDetailPage 作为清单视图。关注它的 @Prop 接口和 callback |
| 12 | `entry/src/main/ets/components/sheets/SheetOverlay.ets` | 理解 Sheet 体系——如何注册新 Sheet 模式、如何呼出/关闭、动画参数 |
| 13 | `entry/src/main/ets/constants/SheetMode.ets` | 所有现有 Sheet 模式常量——你要新增 `SHEET_GEAR_PICKER` 和 `SHEET_GEAR_ITEM_ACTION` |
| 14 | `entry/src/main/ets/models/PackModels.ets` | `ChecklistItem` 和 `TripChecklist` 的字段定义——确认 `group`/`checked`/`fromGearId` 的现有语义 |
| 15 | `entry/src/main/ets/utils/AnimationUtils.ets` | 通用动画封装——`staggeredAnimationOptions`、`counterAnimate` 等可直接复用 |

---

## 1. 你的任务流程

### Step 1：读完所有必读文件（约 15 分钟 Read 时间）

按上面的顺序逐个 Read。不要跳过。

### Step 2：输出实现计划（plan）

基于 spec v3 和第三轮审查意见，输出一份类似 `docs/v2-foundation/plans/2026-06-09-service-archive-foundation.md` 格式的实现计划，包含：

- **Goal**：一句话说清楚要做什么
- **Architecture**：简要说明技术栈和架构约束
- **任务分解**：按 spec §11 的 Phase 1-5 顺序，每个 Phase 拆成独立可验证的 Task
- **每个 Task**：要改/建哪些文件、具体做什么、验证标准
- **依赖关系**：哪些 Task 必须先做、哪些可以并行
- **风险点**：从第三轮审查意见中提取你关注到的 P1 问题

### Step 3：等我 review 计划

输出计划后，我会告诉你是否批准、是否需要调整。

### Step 4：逐 Task 开发（我确认计划后）

按你的计划逐 Task 执行。**严格执行以下纪律**：

1. 一次只做一件事（一个 Task）
2. 每个 Task 改完立即跑 `hvigorw assembleApp` 构建验证
3. 构建通过后立即 `git add -A && git commit -m "描述本次改动"`
4. 构建不过不进下一步、不提交
5. 禁止注释报错绕过编译
6. 禁止 hardcode mock 数据跑通逻辑
7. **禁止在组件中硬编码色值/字号/时长/曲线**，必须从 `constants/` 引用
8. 所有动画统一 Spring 弹性曲线，严禁 linear/ease
9. 新增常量必须归入对应 token 文件（Colors.ets / Layout.ets 等）

---

## 2. 关键架构约束（实施时必须遵守）

### 2.1 导航架构

- 当前是单 Page（`Index.ets`）+ `NavPathStack` 模式
- `NavDestinationMap` @Builder 注册所有页面路由（通过 `if/else` 按 name 分支）
- `TripDetailPage` 是**普通 @Component**（不是 NavDestination），由 NavDestinationMap 中新建的 NavDestination 包裹
- ChecklistDetail 也是普通 @Component——可以安全嵌入 TripDetailPage
- `geometryTransition` 绑在 NavDestination 上，不绑在子组件上
- `.onBackPressed()` 在 NavDestination 上处理条件保存 + pop

### 2.2 Sheet 体系

- 所有 Sheet 通过 `Index.ets` 的 `sheetMode` 状态机 + `SheetOverlay` 容器统一路由
- 新增 Sheet 需要：① `SheetMode.ets` 加常量 ② `DesignTokens.ets` 加 re-export ③ `SheetOverlay.ets` 加渲染分支 + 标题
- **例外**：TempGearMiniSheet 不经过 SheetOverlay——它是 GearPickerSheet 内部的内联覆盖层（Stack + mask + 居中卡片）
- Sheet 不可嵌套（全局只有一个 Sheet 槽位）

### 2.3 数据流

- 所有数据由 `Index.ets` 的 @State 持有
- 向下传递使用 `@Prop`（不是 `@Provide/@Consume`）
- 向上通信使用 callback（`onXxx: () => void`）
- 持久化通过 `PackStore.saveChecklists()` 和 `saveGears()`
- **不新增任何持久化字段**——复用 `ChecklistItem.group` 存 Zone、`checked` 做打勾

### 2.4 动效

- 所有动画曲线从 `AnimationTokens.ets` 引用
- Spring 默认参数：`response: 0.35, dampingFraction: 0.8`
- 按压反馈：`scale 1→0.96→1.02→1.0`，`SPRING_PRESS()`
- Sheet 入场：`SPRING_PANEL_ENTER()`（response 0.38, damping 0.72）
- Sheet 退场：`SPRING_PANEL_EXIT()`（response 0.30, damping 0.88）
- 禁止 Spring + duration 同时使用（Spring 忽略 duration，延迟用 `delay`）

### 2.5 构建命令

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon
```

---

## 3. 实施中的优先级判断

### 严格按 spec 做的
- 双视图架构（配装 + 清单）
- Zone 网格 + 渐进式出现
- GearPickerSheet + 已选汇总栏 + Zone chip 预览
- Misc 品类子分区
- 勾选即时反馈（第一帧硬切 + Spring 收尾）
- 自动保存 + isDirty 检测

### spec + 审查意见综合考虑
- TempGearMiniSheet 作为内联覆盖层（不走 SheetOverlay）——第三轮审查 P1
- 移除装备的退场动画——第三轮审查 P1
- 「去装备库」按钮改为纯「临时添加」引导——第三轮审查 P1
- 新行程引导按钮→Zone 卡片的过渡动画序列——第三轮审查 P2
- 清单视图的 `inferDisplayGroup()` 回译——第三轮审查 P2
- FAB 在配装/清单视图切换时的淡入淡出——spec §3.4 已定义

### 如果遇到 ArkUI 限制可以调整的
- sys.symbol 图标可用性——如果某个 icon 不可用，用文字替代
- SymbolGlyph 的颜色渲染——部分 symbol 可能不支持 `.fontColor()` 数组，用单色即可
- GridRow/WaterFlow 的兼容性——如果 API 23 不支持，用 Column + Row 手动拼网格
- PanGesture 在 Sheet 内与 Scroll 的冲突——如果出现问题，给 Scroll 加 `.edgeEffect(EdgeEffect.None)`（MEMORY.md 避坑清单有记录）

---

## 4. 提醒

- 这个项目是鸿蒙原生 App（ArkTS + ArkUI），不是 Web 前端。不要用 HTML/CSS 思维
- 没有 `useState`、没有 `useEffect`、没有 JSX——用 ArkUI 的 `@State`/`@Prop`/`@Builder`
- `ForEach` 的第三个参数是 key generator，**必须包含所有影响渲染的维度**（MEMORY.md 避坑 #24）
- `animateTo` 包裹的 state 变更才会被动画插值——直接赋值不带动画
- 同一个属性上不能同时有 `.animation()` 修饰器 **和** `animateTo()` ——两者竞争会产生卡顿（MEMORY.md 避坑 #7）

---

## 5. 开始

现在请**按顺序阅读第 0 节列出的文件**。读完所有必读文件后，输出你的实现计划。

不要跳过任何文件。不要在没有读完上下文的情况下就开始写计划。
