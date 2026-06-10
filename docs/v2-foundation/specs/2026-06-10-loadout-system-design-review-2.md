# 塔科夫式配装系统 Spec v2 · 第二轮审查意见

> 审查日期：2026-06-10 | 审查者：Everest  
> 审查对象：`docs/v2-foundation/specs/2026-06-10-loadout-system-design.md` (v2 修订版)  
> 审查方法：逐流程阶段走查 + 代码架构交叉验证 + 第一性原理 × 用户体验

---

## 0. 总体评价

v2 修订版吸收了第一轮 3 个 P0 问题的修正，核心方向现在正确了——双视图并存、Misc 子分区、品类不锁死都是正确的决策。

但 v2 引入了新的问题：**双视图架构的 NavDestination 嵌套在技术上是不可行的**（ChecklistDetail 当前本身就是一个 NavDestination，不能嵌套在另一个 NavDestination 内）。此外，在用户流程的多个触点存在交互断层，需要补全。

以下按用户操作流程的时间线组织，从进入行程详情页到退出。

---

## 🔴 P0 · 架构阻断：NavDestination 不能嵌套

### 问题

Spec §5.1 和 §9.1 提出 `TripDetailPage` 作为一个新的 `NavDestination`，内部嵌入 ChecklistDetail 作为清单视图子组件。

**这在 ArkUI 中不可行。**

当前代码的实际情况（`Index.ets:1700-1755`）：

```typescript
// ChecklistDetail 当前就是一个 NavDestination 的直接子内容
NavDestination() {
  ChecklistDetail({ ... })
}
.hideTitleBar(true)
.transition(TransitionEffect.OPACITY)
.onBackPressed(() => { ... })
```

`NavDestination` 是 ArkUI Navigation 体系中的页面级容器。**不能在一个 `NavDestination` 内部再嵌套另一个 `NavDestination`**——ArkUI 框架不支持，运行时行为未定义。

### 影响

如果按 spec 当前方案实施，会出现以下问题之一：

1. ChecklistDetail 内部的 `NavDestination` 相关代码被移除后，`.onBackPressed()` 拦截失效，系统返回手势将直接 pop 整个页面而非切换回列表
2. 或者出现嵌套 `NavDestination` 的运行时渲染异常

### 修正方案

**两种路径，各有优劣：**

#### 方案 A（推荐）：ChecklistDetail 去 NavDestination 化

将 `ChecklistDetail` 从「NavDestination 的直接子内容」重构为「普通 @Component」。

具体改动：
1. **ChecklistDetail** 移除自身的 `NavDestination` 外壳（这个外壳目前在 `Index.ets:1702` 的 `NavDestinationMap` Builder 中，不在 ChecklistDetail 文件本身——ChecklistDetail 本身就是普通 @Component）
2. 在 `NavDestinationMap` 中新增 `'TripDetailPage'` 分支，创建 `NavDestination`
3. `TripDetailPage` 作为 `NavDestination` 的直接子内容，负责承载导航栏、分页控件、以及两个子视图
4. ChecklistDetail 作为 `TripDetailPage` 的一个子组件，通过 `@Prop` 接收数据

**实际上，我重新检查了代码——ChecklistDetail 已经是普通 @Component，它不是 NavDestination。NavDestination 是在 Index.ets 的 `NavDestinationMap` Builder 中创建的。** 所以嵌套问题不存在！ChecklistDetail 可以安全地嵌入 TripDetailPage。

但有一个相关的问题：`NavDestination` 的 `onBackPressed()` 和 `.transition()` 目前在 Index.ets 中绑定在 ChecklistDetail 所在的 NavDestination 上（`Index.ets:1748-1755`）。如果 ChecklistDetail 被嵌入 TripDetailPage，这些需要移到 TripDetailPage 的父 NavDestination 上。

#### 方案 B（备选）：两个独立 NavDestination

不创建 TripDetailPage 壳，保持 ChecklistDetail 和 LoadoutView 分别为独立的 NavDestination 注册：
- `'ChecklistDetail'` → 清单视图（保持不变）
- `'LoadoutView'` → 配装视图（新增）

两个视图之间通过导航栏按钮切换。这简化了架构，避免了「父 NavDestination 包装两个子视图」的需求。但缺点是两个视图之间切换需要 push/pop，不是同页切换，体验不如分页控件流畅。

**建议选方案 A**。影响面明确（仅 Index.ets 的 NavDestinationMap 需新增 TripDetailPage 分支），ChecklistDetail 几乎不需要改动。

### 需要在 spec 中补充

- 明确说明 ChecklistDetail 作为 @Component（不是 NavDestination）嵌入 TripDetailPage
- 更新 §5.1 的 TripDetailPage 描述，说明其与 Index.ets NavDestinationMap 的集成方式
- 更新 §11 Phase 4 的实现步骤，加入 NavDestinationMap 注册步骤

---

## 🟡 P1 · 交互断层：GearPickerSheet 展开时用户看不到背景动画

### 问题

Spec §3.3 流程第 3 步描述了一个理想的交互：

> 装备自动落入对应 BodyZone 卡片 → 背景 LoadoutView 中对应 Zone 卡片出现入场动画 → Sheet 不自动关闭

### 现实

当前 `SheetOverlay` 的视觉实现（`SheetOverlay.ets:253-255`）：

```
遮罩层 opacity: 1（sheetOverlayOpacity）
背景遮罩色 OVERLAY_SUBTLE（#26000000，~15% 黑）
backdropBlur(16)（16px 高斯模糊）
```

当 Sheet 展开时，**背景 LoadoutView 被 15% 暗色遮罩 + 16px 模糊覆盖**。用户**无法清晰看到** Zone 卡片中新装备的入场动画。入场效果被模糊严重削弱，用户可能完全注意不到装备已经落入了目标卡片。

### 修正方案

**不要依赖背景可见性来传达「装备已加入」的反馈。改为多层反馈组合：**

1. **GearPickerSheet 内反馈（主要）**：选中装备后，该行右侧的 Zone chip 从灰色变为绿色 + 出现 ✓ + 一个微小的 scale bounce 动画。这是用户视野焦点所在的位置，反馈必须在这里。
2. **Zone chip 微文案变化**：GearPickerSheet 顶部或底部增加一行实时计数——`已选择 3 件（上身 2 · 杂项 1）`——让用户在 Sheet 内就感知到选中了哪些装备以及它们的去向。
3. **关闭 Sheet 后的汇总动画（次要）**：Sheet 关闭后的第一帧，所有新添加的装备一起播放 staggered 入场动画。这比在 Sheet 展开时播放动画更有效——此时背景清晰可见，用户注意力回到配装视图。

**具体修改**：

在 GearPickerSheet 内部增加一个「已选汇总栏」：

```
┌──────────────────────────────────────┐
│  选择装备                    [完成]    │
│  ┌────────────────────────────────┐  │
│  │  🔍 搜索装备…                   │  │
│  └────────────────────────────────┘  │
│  全部  穿着·上身  饮食  …            │
│                                        │
│  已选 3 件  ▸ 上身 2 · 杂项 1       │  ← 新增：实时计数 + Zone 分布
│                                        │
│  ▸ 穿着·上身      …                  │
│  …                                    │
└──────────────────────────────────────┘
```

这解决了一个更深层的问题：用户在 Sheet 内选装备时，不需要频繁开关 Sheet 来确认「我选了哪些、落在哪」。

---

## 🟡 P1 · 空态体验：新行程的 7 张空卡片是视觉噪音

### 问题

当用户为一个全新行程（没有任何装备）首次进入配装视图时：

- 7 张 Zone 卡片全部为空
- 每张卡片显示虚线边框 + 「还没有 XX 装备」文案
- 7 个空洞的虚线框占据整个屏幕

这给人的第一印象是「空荡荡的表格」而非「为角色配装」。和目标体验「像玩游戏一样打包」相悖——游戏里你不会看到 7 个空槽位同时显示「空」，而是看到一个人体轮廓或装备栏，槽位是「等待填充」而非「空无一物」。

### 修正方案

**新行程空态采用渐进式引导，而非一次性展示全部 Zone 卡片：**

```
首次进入（无装备）:

┌──────────────────────────────────────┐
│  < 返回    武功山徒步         ···    │
│                                      │
│                                      │
│         🎒                           │  ← 大图标
│                                      │
│    开始为这次行程配装吧               │  ← 引导文案
│    从装备库中选择带哪些装备            │
│                                      │
│       ┌──────────────┐               │
│       │  ＋ 添加装备   │               │  ← 大号引导按钮（非 FAB）
│       └──────────────┘               │
│                                      │
└──────────────────────────────────────┘
```

用户添加第一件装备后，**对应的 Zone 卡片才出现**（而非全部 7 张同时存在）：

```
添加了 3 件装备后:

┌──────────────────────────────────────┐
│  已装包 1/3  ██░░░░░░░░░  33%       │
│                                      │
│  ┌──────────┐  ┌──────────┐         │
│  │ 😊 头部   │  │ 👕 上身   │         │  ← 只显示有装备的 Zone
│  │ [墨镜 ✓] │  │ [速干T]  │         │
│  │          │  │ [抓绒]   │         │
│  └──────────┘  └──────────┘         │
│                                      │
│  ┌─────────────────────────┐        │
│  │ 🔲 杂项                  │        │
│  │ ▸ 饮食: [炉头✓]          │        │
│  └─────────────────────────┘        │
│                                      │
│                          [＋]        │
└──────────────────────────────────────┘
```

**核心规则**：
- 空 Zone 不渲染卡片——不给用户展示空洞的虚线框
- 当某个 Zone 获得第一件装备时，卡片以 staggered 动画出现（而不是一开始就显示 7 个空卡片）
- 这有两个好处：① 新行程不显空旷 ② 每添加一件装备，视觉上「解锁」一个新区域，有游戏化的正向反馈
- FAB「＋」始终在右下角悬浮，无论当前有几个 Zone 卡片

---

## 🟡 P1 · FAB 在清单视图中不应出现

### 问题

Spec 把 FAB 描述为 LoadoutView 的组件（§5.2），但没有明确说明清单视图中是否也有 FAB。

当前 ChecklistDetail 的「添加装备」入口在 `ActionRow` Builder 中——是一个底部操作栏里的按钮，不是 FAB。如果清单视图保留这个 ActionRow（spec §9.3 说清单视图保留全部现有功能），那不应该再叠加一个 FAB。

如果在清单视图中出现 FAB，用户 tap 后会进入 GearPickerSheet 选装备——但选中的装备会落入 Zone，而清单视图本身不展示 Zone。这会造成困惑。

### 修正方案

- FAB 仅在配装视图中显示
- 切换至清单视图时，FAB 以淡出动画消失；切回配装视图时，FAB 淡入
- 清单视图的添加装备入口保持在原有的 ActionRow 中（与现行 ChecklistDetail 一致）

---

## 🟡 P1 ·「临时添加」流程未定义

### 问题

Spec §3.4 提到 GearPickerSheet 底部有「+ 临时添加（不入装备库）」入口。但用户点击后发生什么——完全没有描述。

临时装备的特殊性：
- 它没有 `fromGearId`
- 它不属于任何装备库品类
- 它需要知道落到哪个 Zone
- 它需要一个名称、可能需要重量（用于配重计算）

### 修正方案

tap「+ 临时添加」→ 弹出一个 **mini sheet**（覆盖在 GearPickerSheet 之上）：

```
┌──────────────────────────────────────┐
│  临时添加装备                         │
│                                        │
│  名称  [_______________]              │  ← TextInput
│                                        │
│  归属区域                             │
│  [头部] [上身] [下身] [脚部]          │  ← Zone 选择 chips
│  [背负] [睡眠] [杂项]                │
│                                        │
│  重量（可选） [_____] g               │
│                                        │
│          [取消]    [添加]              │
└──────────────────────────────────────┘
```

关键规则：
- 名称必填，归属区域必选（默认 Misc），重量可选
- 点击「添加」→ 创建 `ChecklistItem`（`fromGearId` 为空，`group` = 选中的 Zone）→ mini sheet 关闭 → 装备出现在背景对应 Zone 卡片中
- 临时装备在配装视图中显示一个小标记（如灰色 `·` 或 `临时` chip），表示它不是装备库中的正式装备

---

## 🟡 P1 · 行程结构化字段在新布局中的位置

### 问题

当前 `ChecklistDetail` 的 Header 区域展示了：
- 行程标题（大字）
- 行程日期（subtitle，tap 弹出 DatePicker）
- 结构化字段摘要（destination · distanceKm · maxAltitude · ascentM · durationHours，一行 chip 风格）
- 重量/进度信息（MetaRow）

在 TripDetailPage 的双视图架构中，这些信息有两个可能的放置位置：
1. 放在 TripDetailPage 的导航栏下方——两个视图共享
2. 放在清单视图中——配装视图不展示

Spec §9.3 提到「行程头部/渐进式 chip → 提升到父 NavDestination 顶部」，但没有给出具体布局。

### 修正方案

在 TripDetailPage 中，导航栏下方设置**共享信息区**：

```
┌──────────────────────────────────────┐
│  < 返回    武功山徒步         ···    │  ← 导航栏
│                                      │
│  2026年7月15日                        │  ← 日期 + 结构化字段（tap 编辑）
│  武功山 · 22km · 海拔1918m · 12h     │
│                                      │
│  [配装视图]  [清单视图]               │  ← 分段控件
│                                      │
│  已装包 12/18  ████████░░░  67%     │  ← 进度（仅配装视图显示）
│                                      │
│  ┌──────────────────────────────────┐│
│  │     当前激活视图的内容             ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

布局说明：
- 日期 + 结构化字段始终可见——提醒用户「这次行程去的是武功山」，与选装决策相关
- tap 日期/结构化字段行 → 呼出 `ProfileEditSheet`（保持现有编辑入口）
- 进度条仅在配装视图中显示（清单视图已有自己的进度展示）
- 切换视图时，分段控件下方的区域交叉淡入淡出，上方信息区不动

---

## 🔵 P2 · 细节优化

### 7. Zone chip 的颜色关联系统

Spec §3.4 提到「右侧 Zone chip 颜色与对应 Zone 卡片标题色一致，建立视觉关联」。但目前 Zone 卡片标题使用 `TEXT_SECONDARY`（灰色），没有独立的 Zone 颜色体系。

建议为每个 Zone 定义主题色（在 Colors.ets 中）：

| Zone | Token 名 | 建议色值 |
|------|----------|---------|
| Head | ZONE_HEAD | #42A5F5 蓝 |
| UpperBody | ZONE_UPPER | #EF5350 暖红 |
| LowerBody | ZONE_LOWER | #5C6BC0 靛蓝 |
| Feet | ZONE_FEET | #8D6E63 棕 |
| Carry | ZONE_CARRY | #FFA726 橙 |
| Sleep | ZONE_SLEEP | #7E57C2 紫 |
| Misc | ZONE_MISC | #78909C 灰蓝 |

Zone 卡片标题用该颜色 + GearPickerSheet 中的 Zone chip 也用该颜色——形成一致的视觉关联。

### 8. 勾选反馈的即时性

Spec §7 说勾选动画使用「opacity + bgColor Spring(0.25, 0.7)」。Spring 动画需要 ~200-300ms 才能 settle。用户快速连续勾选 5 件装备时，每个 tap 之间的视觉反馈应该即时可感知。

建议：勾选的第一帧（0-50ms）使用 EaseOut 快速过渡到 80% 目标值，然后用 Spring 完成剩余 20%。这样用户能立即看到反馈（checkbox 变色），同时弹性收尾保留质感。或者更简单：勾选时瞬间切换颜色（0ms），然后 checkbox 的 ✓ icon 用 spring 弹入。

### 9. 层级 Badge 的视觉层级

当前设计：层级 badge 是「独立 tap target」。但它在装备行左侧，尺寸较小。如果 badge 太小（< 44vp），不满足可操作元素的最小触控区域规范（`DEVELOPMENT_STANDARDS.md` §7.3：最小 48×48vp）。

建议：层级 badge 尺寸至少 20×20vp 可见区域，加上 padding 达到 44×44vp 触控区域。使用 `hitTestBehavior(HitTestMode.Block)` 确保不穿透到装备行的 tap。

### 10. 双视图切换的默认选择逻辑

用户打开行程详情页时默认显示配装视图。但如果用户上次在这个行程中切换到清单视图并退出，再次进入时应该记住用户的选择——还是始终默认配装视图？

建议：始终默认配装视图。原因：
- 配装视图是新功能的门面，需要曝光
- 记忆用户上次选择增加状态管理复杂度，收益低
- 用户如果经常需要清单视图，说明配装视图可能有问题——这是需要收集的信号，而非用状态记忆掩盖

### 11. 装备库为空时的 GearPickerSheet

Spec §8.5 说「引导用户先去装备库添加装备」。但如何引导？一个空 Sheet 弹出来然后用户不知道怎么关闭？建议：

GearPickerSheet 的空态：
- 中央 icon（背包 + 加号）
- 文案：「装备库还是空的，先去添加装备吧」
- 底部按钮：「去装备库」（tap → 关闭 Sheet → 切换到装备库 Tab）
- 如果用户在装备库为空时就点进了配装，说明用户可能想用「临时添加」功能——底部同时显示「临时添加一件装备」链接

### 12. 返回时自动保存的「变更检测」粒度

Spec §3.6 说「若无变更不触发 save」。但「变更」的定义需要明确：

- 添加/删除装备 = 有变更 ✓
- 勾选/取消勾选装备 = 有变更 ✓
- 仅切换视图（配装↔清单）未做任何操作 = 无变更 ✓
- 在 GearPickerSheet 中打开又关闭未选任何装备 = 无变更 ✓
- 修改了层级 badge 但改回原值 = ？ 建议：不检测回转操作，只要有层级修改动作就算有变更（简化实现）

### 13. 核查复盘的上下文保持

当用户从配装视图进入 ReviewPage（逐张卡片滑动确认），退出后应回到配装视图。从清单视图进入则回到清单视图。这个 spec 已经提到了，但实现时需要注意：ReviewPage 当前在 NavDestinationMap 中是一个独立路由。如果在 TripDetailPage 内部直接复用 ReviewPage，需要确认 ReviewPage 是否也是一个独立 NavDestination。

当前代码中 ReviewPage 确实是一个独立 NavDestination（`Index.ets:1757`）。如果要在 TripDetailPage 内部使用它，需要同样的去 NavDestination 化处理——或者保持现有的 pushPathByName 方式，让 ReviewPage 继续作为独立 NavDestination 被 push。这更简单——TripDetailPage 的 `···` 菜单中的「核查复盘」仍然调用 `pushPathByName('ReviewPage')`，退出 ReviewPage 后自然会 pop 回 TripDetailPage。

---

## 📊 第二轮审查汇总

| 优先级 | 编号 | 问题 | 影响 |
|--------|------|------|------|
| 🔴 P0 | 1 | NavDestination 嵌套不可行（经核查已排除——ChecklistDetail 是普通 @Component） | 原判断有误，不影响实施。但仍需补充 NavDestinationMap 集成说明 |
| 🟡 P1 | 2 | GearPickerSheet 遮罩模糊导致用户看不到背景动画 | 装备入场的核心反馈丢失——改为 Sheet 内实时计数 + Zone chip 变色 |
| 🟡 P1 | 3 | 新行程 7 张空 Zone 卡片是视觉噪音 | 与「像玩游戏」的体验目标相悖——改为逐 Zone 按需出现 |
| 🟡 P1 | 4 | FAB 在清单视图中不应出现 | 清单视图已有自己的添加入口，叠加 FAB 会造成困惑 |
| 🟡 P1 | 5 | 「临时添加」流程完全未定义 | 用户点了一个按钮后不知道会发生什么 |
| 🟡 P1 | 6 | 行程结构化字段在新布局的位置不明 | 日期/目的地/里程等信息与选装决策相关，应当可见 |
| 🔵 P2 | 7 | Zone chip 与 Zone 卡片无颜色关联 | 视觉关联需要具体的颜色系统 |
| 🔵 P2 | 8 | 勾选反馈的 Spring 动画可能感觉迟钝 | 快速连续勾选时的感知延迟 |
| 🔵 P2 | 9 | 层级 badge 触控区域可能不足 48×48vp | 无障碍合规 |
| 🔵 P2 | 10 | 双视图默认选择逻辑未定义 | 每次进入都应默认配装视图 |
| 🔵 P2 | 11 | 装备库为空时 GearPickerSheet 空态未细化 | 用户可能困在空 Sheet 中 |
| 🔵 P2 | 12 | 自动保存的变更检测粒度未明确 | 边界 case（如层级回改）需要定义 |
| 🔵 P2 | 13 | ReviewPage 路径确认 | 保持独立 NavDestination 方式更简单 |

---

## ✅ v2 中值得肯定的改进

1. **双视图并存的论证**（§3.2 / §9）：packing vs checking 的时态分析准确，引用了第一性原理，决策清晰
2. **Misc 子分区设计**（§2.4）：品类合并规则（≤2 件合并）具体且务实，为实机测试留了迭代出口（饮食升格为独立 Zone）
3. **层级微调交互分离**（§3.5）：tap badge vs long-press 菜单的交互分工明确，互不冲突
4. **GearPickerSheet 的目标 Zone 预览**（§3.4）：解决了"选之前不知道落哪"的核心问题
5. **导航栏设计**（§3.6 / §9.4）：返回 + 自动保存 + 更多菜单的布局合理，无冗余按钮
6. **退出时不必要 I/O 的优化**（§3.6）：变更检测避免无效 `saveChecklists()` 调用
7. **附件 C 的修订记录**（附录 C）：v1→v2 的变更追溯清晰，方便后续审查者理解演进历史
8. **响应式小屏适配**（§13 风险表）：宽度 < 360vp 时降为 1 列——具体且可实现
9. **Phase 实施顺序**（§11）：Service → Item → Card → Sheet → Page 的依赖链正确
10. **验证标准具体可测**（§12）：从构建通过到「像玩游戏的感觉」都有明确判据
