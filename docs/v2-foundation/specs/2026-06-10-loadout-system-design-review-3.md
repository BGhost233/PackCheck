# 塔科夫式配装系统 Spec v3 · 第三轮审查意见

> 审查日期：2026-06-10 | 审查者：Everest  
> 审查对象：`docs/v2-foundation/specs/2026-06-10-loadout-system-design.md` (v3 修订版)  
> 审查方法：全流程时间线走查 + 微交互逐帧检查 + 架构可行性对照代码验证  
> 审查标准：第一性原理 × 用户体验 × 页面衔接流畅性 × 动效一致性

---

## 0. 总体评价

v3 是这个 spec 的**成熟版本**。前面两轮审查的 24 项反馈已全部吸收，文档从「方向性方案」进化为「可执行蓝图」。用户时间线（§3.1–§3.10）覆盖了从点击进入、配装操作、到退出的完整链路。整体无需结构性修改。

本轮审查聚焦于前三轮都未覆盖的**穿越页面边界的衔接细节**——那些在文档段落之间「恰好被跳过」的转场瞬间和微交互。这些问题不影响功能完整性，但决定用户感知到的质感是「Apple 级」还是「能用就行」。

以下按用户操作时间线组织，标注每个触点的当前状态和建议。

---

## 🟡 P1 · 需要补充

### 1. 行程卡片 → TripDetailPage 的转场衔接

#### 1.1 新建行程（路径 A）缺少转场定义

**当前状态**：Spec §3.1 路径 A 说 `TripFormSheet → 确认 → pushPathByName('TripDetailPage')`。TripFormSheet 关闭和 NavDestination push 之间没有定义转场动画。

**当前代码对照**：现有 `Index.ets:1078` 对 ChecklistDetail 的 push 包装在 `animateTo({ curve: SPRING_HERO_EXPAND() }, () => { ... pushPath({ name: 'ChecklistDetail' }, false) })` 中。这是共享元素转场的前提——动画驱动的 push。新 TripDetailPage 应该继承这个模式。

**问题**：新建行程时没有源卡片做共享元素（TripFormSheet 不是行程卡片），push 时的转场效果是什么？如果不指定，ArkUI 默认用系统推入动画（从右滑入），与 HomePage tap 行程卡片的共享元素展开不一致——用户会感知到「两种不同的进入方式」。

**建议**：为 TripDetailPage 的 NavDestination 添加 `.transition(TransitionEffect.OPACITY)`（保持与现有 ChecklistDetail NavDestination 一致）。同时 `animateTo` 内使用 `pushPath({ name: 'TripDetailPage' }, false)`。

#### 1.2 geometryTransition id 的源和目标需要一致性验证

**当前状态**：Spec §5.2 说 `.geometryTransition('trip-' + this.selectedChecklistId)` 绑在新 NavDestination 上。

**需要确认**：HomePage 中的行程卡片（HeroCard + HistoryRow）使用的 geometryTransition id 也是 `'trip-' + id`（`HomePage.ets` + `ChecklistDetail.ets:443`）。id 格式一致，可以正常工作。但需要在 spec 中明确说明：HomePage 的卡片 id 保持不变，TripDetailPage 的 NavDestination 使用相同的 id 格式。

**建议**：在 §5.2 的集成代码示例中加一行注释：
```typescript
// geometryTransition id 与 HomePage 的 trip card 保持一致：
// HomePage: .geometryTransition('trip-' + item.id)
// TripDetailPage NavDestination: .geometryTransition('trip-' + selectedChecklistId)
```

#### 1.3 NavDestination push 期间的背景景深

**当前状态**：现有代码在 push 时设置 `contentScale = 0.94` + `contentBlur = 12`（`Index.ets:1075-1076`），让主页内容在转场时后退。pop 时恢复。

**建议**：TripDetailPage 的 push 和 pop 应该做同样的背景景深处理。在 §3.1 的路径 B 描述中补充一句：「push 和 pop 时主内容同步施加 scale(0.94) + blur(12) 景深（复用现有 `returnToHome()` 和 `pushChecklistDetail()` 的动画逻辑）」。

---

### 2. GearPickerSheet 与 TempGearMiniSheet 的层级关系

#### 2.1 Sheet 叠 Sheet 的架构问题

**当前状态**：Spec §3.6 说 TempGearMiniSheet 从 GearPickerSheet 内部呼出，覆盖在其上。

**当前代码对照**：整个 App 的 Sheet 系统是单例模式——`Index.ets` 的 `sheetMode` 是一个字符串，`SheetOverlay` 是一个条件渲染的组件。不支持两个 Sheet 同时存在。GearPickerSheet 打开时 `sheetMode = SHEET_GEAR_PICKER`，此时不能再用同一个 `sheetMode` 打开 TempGearMiniSheet。

**解决方案**（二选一）：

**方案 A（推荐）**：TempGearMiniSheet 不使用 SheetOverlay，而是作为一个 **内联覆盖层** 在 GearPickerSheet 内部渲染——就是一个 `Stack` + 半透明遮罩 + 居中白色卡片。因为它的层级在 GearPickerSheet 之上，不受全局 Sheet 单例限制。实现简单，且视觉上「mini sheet 属于 GearPickerSheet 的一部分」语义正确。

**方案 B**：为 SheetOverlay 增加「子 Sheet」能力——新增 `@Prop subSheetMode: string` 和对应的渲染分支。但这是过度工程化，为一个 mini dialog 改造全局 Sheet 系统不值得。

**建议**：Spec §5.2 中 TempGearMiniSheet 的描述应明确：「作为 GearPickerSheet 内部的内联覆盖层（Stack + mask + 居中卡片），不经过全局 SheetOverlay 路由」。

#### 2.2 mini sheet 的动画

**当前状态**：Spec 未定义 TempGearMiniSheet 的入场/退场动画。

**建议**：使用与全局 Sheet 一致的 `SPRING_PANEL_ENTER/EXIT` + 背景 `backdropBlur(8)`。但由于它在 GearPickerSheet 内部（GearPickerSheet 本身已经有 backdropBlur(16)），叠加 blur 可能在 ArkUI 上产生性能问题。简化方案：遮罩使用 `opacity(0.3)` 纯黑（无 blur），卡片从 scale(0.92) + opacity(0) Spring 弹入。这是最安全且视觉上足够好的方案。

---

### 3. 装备从 Zone 中移除时的视觉反馈

#### 3.1 当前状态

Spec §3.8 定义了 long-press →「移除」操作，但没有定义移除后的视觉反馈。

#### 3.2 关键场景

当用户移除了 **某个 Zone 的最后一件装备** 时，按照渐进式策略（空 Zone 不渲染），该 Zone 卡片应该消失。但一个硬切消失会让用户困惑——「我刚点了什么？少了一个区域？」

#### 3.3 建议

装备移除分两种情况处理：

| 场景 | 视觉反馈 |
|------|---------|
| 移除后 Zone 内仍有其他装备 | 该装备行以 fadeOut + collapse（height → 0）+ Spring(0.3, 0.88) 退场，同行其他装备平滑上移 |
| 移除后 Zone 变为空 | 装备行退场后，Zone 卡片以 scale(1→0.92) + opacity(1→0) Spring(0.25, 0.8) 退场。相邻卡片平滑填补空位。同时显示一个微小的 toast：「「XX」已移除」（1.5s 自动消失） |

不需要撤销功能——当前 ChecklistDetail 也没有。但退场动画必须流畅可感知，不能硬切。

---

### 4. 从 TripDetailPage 切换到装备库 Tab 的路径

#### 4.1 场景

GearPickerSheet 空态引导中有一个按钮「去装备库」（§3.7）。tap 后需要：关闭 Sheet → pop TripDetailPage → 切换 Tab 到装备库。

这是一个跨越三个层级的操作：Sheet（覆盖层）→ NavDestination（页面层）→ Tab（应用层）。当前没有任何机制支持「关闭 Sheet 并 pop 页面并切换 Tab」的原子操作。

#### 4.2 建议

在 spec 中补充此流程（§3.7 末尾）：

```
tap「去装备库」→ 
  1. GearPickerSheet 关闭（SPRING_PANEL_EXIT） 
  2. Sheet onFinish 回调中 pop NavDestination（带动画回退到 HomePage）
  3. 同时设置 currentTabIndex = 1（切换到装备库 Tab）
```

实现上，`Index.ets` 需要在 GearPickerSheet 的 `onGoToGearLibrary` 回调中执行：
```typescript
onGoToGearLibrary: () => {
  this.closeSheet();        // 关闭 GearPickerSheet
  this.navPathStack.pop();  // pop TripDetailPage（返回到 HomePage/装备库 Tab）
  this.currentTabIndex = 1; // 可以在 pop 的 onFinish 中执行
}
```

注意：`navPathStack.pop()` 和 `currentTabIndex = 1` 的执行时序。如果 pop 有动画（~400ms），Tab 切换最好在 pop 动画结束后执行，避免两个动画竞争视觉焦点。或者 Tab 切换在 pop 之前静默执行（用户回到 HomePage 时已经看到装备库 Tab）。

**推荐**：先静默切换 Tab（在 Sheet 关闭回调和 pop 之前），这样 pop 动画结束后用户看到的就是装备库 Tab。

---

### 5. 从装备库 Tab 返回 TripDetailPage 的路径

#### 5.1 场景

用户从 TripDetailPage → Sheet 空态 → 「去装备库」→ 装备库 Tab 添加装备后，如何回到刚才配了一半的行程？

#### 5.2 问题

用户添加完装备后，刚才的 TripDetailPage 已经被 pop 了。用户需要从 HomePage 重新找到那个行程再点进去。如果行程多（10+），这很痛苦。

#### 5.3 建议

**两个选项**：

**选项 A（简单）**：不去装备库 Tab。在 Sheet 空态中去掉「去装备库」按钮，只保留「临时添加一件」。因为用户如果装备库为空，说明他们从未使用过装备管理功能——引导他们用临时添加更直接。等他们后续主动探索装备库时，自然会形成从装备库选装的习惯。

**选项 B（体验更好但复杂）**：支持「从 TripDetailPage 临时跳转到装备库 Tab 并自动返回」——类似于"短暂分心"模式。push 装备库 Tab 时保留 TripDetailPage 在 NavPathStack 上，用户添加完装备后通过「回到配装」按钮 pop 回来。但这是全新的导航概念，一期不做。

**推荐选项 A**。理由：装备库为空的用户是第一次使用的新用户——他们不需要「去装备库」这个概念。让他们先通过临时添加完成第一次配装，体验核心价值。装备库是他们后续自然会探索的功能。

---

## 🔵 P2 · 微交互优化

### 6. 新行程首次进入的引导按钮 → 有装备状态的过渡

**当前状态**：Spec §3.3 描述了全局空态（大 icon + 引导按钮），§3.4 描述了有装备状态。但两个状态之间的过渡动画未定义。

**建议**：
- 用户在 GearPickerSheet 中选中第一件装备并关闭 Sheet 后：
  1. 引导按钮和 icon 以 fadeOut 退场（~150ms）
  2. 首个 Zone 卡片以 scale(0.9→1) + translateY(8→0) + fadeIn 从下方弹入（Spring(0.38, 0.72)，与 PANEL_ENTER 一致）
  3. FAB 同时在右下角以 scale(0→1) + Spring(0.3, 0.75) 弹入
  4. 进度条以 translateY(-8→0) + fadeIn 从上方降下（Spring(0.35, 0.8)）
  5. 这三个元素（Zone 卡片、FAB、进度条）的动画有轻微 staggering（卡片先出现，50ms 后进度条，再 50ms 后 FAB），形成「装备栏解锁」的仪式感

### 7. 清单视图中对「从 Zone 添加的装备」的兼容展示

**当前状态**：Spec 说清单视图保留现有 ChecklistDetail 功能。但 ChecklistDetail 当前按 `group`（品类名）分组展示。配装视图添加的装备 `group` 值为 BodyZone 枚举（如 'upper', 'misc'），而非品类名（如 '穿着·上身'）。

**问题**：清单视图中，这些装备会按 BodyZone 枚举分组——「upper」分组、「misc」分组——品类名丢失了。用户在清单视图中看到的将是英文枚举值而非中文品类名。

**建议**：在 `ChecklistDetail` 中（或 LoadoutService 中）新增一个 `inferDisplayGroup(item: ChecklistItem, gears: GearItem[]): string` 函数：
- 如果 `item.group` 在 BodyZone 枚举范围内 → 通过 `item.fromGearId` 查找装备的 category（品类名）作为显示分组名；若无 `fromGearId`（临时装备），显示对应 Zone 的中文名 + 「(临时)」
- 如果 `item.group` 是旧格式（自由文本）→ 直接显示（保持向后兼容）

这样清单视图能正确展示从配装视图添加的装备的品类分组，避免出现 'upper' / 'misc' 这类无意义的标题。

### 8. 视图切换时 ChecklistDetail 的状态保持

**当前状态**：每次切换到清单视图，ChecklistDetail 被 if/else 条件渲染。如果用户折叠了某个分组、滚动到了某个位置，切换到配装视图再切回来——这些状态会丢失（组件被销毁重建）。

**建议**：在 TripDetailPage 中，使用 `if/else` 控制显示哪个视图时，将其生命周期管理好：
- 如果项目使用 `if` 条件渲染导致组件销毁，可以在两个视图的父级使用 `visibility()` 或 `opacity()` + `hitTestBehavior` 来「隐藏」而非「销毁」——但这只是权宜之计，长时间隐藏的组件仍然浪费内存
- **推荐**：接受组件重建。但 ChecklistDetail 的当前状态（滚动位置、折叠分组）不需要保持——每次进入清单视图都是一次「新的查看」。这不是 bug，是设计选择

在 spec 中明确标注：「切换视图时非当前视图组件被销毁（`if/else` 条件渲染），切换回时重建。清单视图的状态（折叠/滚动位置）不保持——每次进入清单视图都是一次新的查看。」

### 9. long-press 菜单的视觉设计

**当前状态**：Spec §3.8 列出了 long-press 菜单的三个选项（移动到其他 Zone / 查看详情 / 移除），但菜单的视觉设计未定义。

**建议**：使用 **iOS 风格的 Context Menu**（从按压位置弹出的小菜单）或 **底部 ActionSheet**。推荐 ActionSheet——与项目现有的 Sheet 交互模式一致，实现最简单，视觉统一。菜单选项：
```
┌──────────────────────────────────────┐
│  速干T恤 (Patagonia)                 │  ← 标题
│  ─────────────────────────────────── │
│  移动到其他区域  >                    │  ← 呼出 Zone 选择器
│  查看装备详情                        │  ← 呼出装备详情
│  从行程移除        (红色)            │  ← 危险操作
│  ─────────────────────────────────── │
│  取消                                │
└──────────────────────────────────────┘
```

通过 SheetOverlay 呼出（新增 `SHEET_GEAR_ITEM_ACTION` 常量），复用项目统一的 Sheet 动画。移除操作用红色字体。

### 10. GearPickerSheet 中品类 tab 的滚动行为

**当前状态**：Spec §3.5 说品类筛选使用 CategoryTagGroup。CategoryTagGroup 支持横向滚动 + 多选。但在 GearPickerSheet 中，目前没有提到品类 tab 与装备列表的联动方式。

**建议**：在 GearPickerSheet 中明确：品类 tab 为**单选**模式（`showAllOption = true`，`multiSelectMode = false`）。tap 某个品类 → 下方装备列表仅显示该品类装备。这比多选更直观——用户在 Sheet 中的心智模型是「我要找饮食系统的装备」，不是「我要同时看饮食和电力的装备」。

同时，品类 tab 应 sticky 在搜索栏下方、装备列表上方。当装备列表滚动时，品类 tab 保持可见（用 sticky 定位或放在非滚动区域）。

### 11. FAB 在配装视图中的 z-index

**当前状态**：FAB 应该是配装视图中最高层级的元素——悬浮在所有 Zone 卡片之上，不被任何内容遮挡。

**建议**：在 LoadoutView 中使用 `Stack` 布局，FAB 放在 Zone 卡片网格之后（在 Stack 中后渲染 = 在上层），使用 `.position({ x: ..., y: ... })` 绝对定位在右下角。同时确保 FAB 不被 GearPickerSheet 遮挡——因为 GearPickerSheet 通过全局 SheetOverlay 渲染（在根 Stack 层级），天然高于 LoadoutView，所以没有问题。

---

## 🔵 P3 · 值得考虑但非必须

### 12. 配装视图的 Zone 卡片入场顺序

**当前状态**：Zone 出现顺序是「谁先有装备谁先出现」，按实际添加时间排列。

**考虑**：是否可以按人体从上到下的逻辑顺序出现？即使用户先添加了「脚部」的装备，脚部卡片也应该出现在「上身」卡片下方。这需要在渲染时固定 Zone 的网格位置，而不是按出现顺序排列。

**判断**：按人体固定顺序（Head → UpperBody → LowerBody → Feet → Carry → Sleep → Misc）更好。即使 Zone 卡片是渐进出现的，它们应该占据自己的固定网格位置，出现时「点亮」那个位置，而不是从左到右重新排列。这符合用户的空间心理模型——头部在上、脚部在下，无论你什么时候添加装备，位置关系不变。

**建议**：在 §3.4 中补充：「Zone 卡片按 BodyZone 固定网格位置排列（Head 左上 → Misc 全宽底部），无论装备添加顺序如何。空 Zone 不渲染但占用网格位置（使用 0 高度占位符或 GridRow 固定 span），确保其他 Zone 不会因空 Zone 出现而跳动。」

### 13. 进度条在配装和清单视图中的不同含义

**当前状态**：配装视图的进度是「已装包 N/M」——M = 装备总数，N = 已勾选数。清单视图也有自己的进度展示。两个进度应该同步（因为 checked 状态共享），但展示形式不同。

**建议**：在 TripDetailPage 的共享信息区加一个轻量的迷你进度（如 `N/M` 小字放在日期旁边），使得两个视图切换时进度信息始终可见。但这不是必须的——两个视图各自有进度展示也足够了。一期不做。

### 14. 配装视图的底部安全区

**当前状态**：Zone 卡片网格 + FAB 的布局需要考虑底部安全区（iPhone 的 Home Indicator / 鸿蒙的导航条）。

**建议**：在 LoadoutView 中给 Zone 卡片网格底部留 padding（~32vp），确保最底部的卡片不被导航条遮挡。FAB 的位置也要考虑安全区——通常距底部 ~80-100vp（留出 TabBar 76vp + margin），而不是简单的 `screenHeight - FAB_SIZE - margin`。

---

## 📊 第三轮审查汇总

| 优先级 | 编号 | 触点 | 问题 | 建议 |
|--------|------|------|------|------|
| 🟡 P1 | 1 | 进入 | 新建行程的 NavDestination 转场未定义 | 加 `.transition(OPACITY)` + 景深处理 |
| 🟡 P1 | 2 | 选装 | TempGearMiniSheet 层级与 Sheet 单例冲突 | 改为 GearPickerSheet 内联覆盖层，不经 SheetOverlay |
| 🟡 P1 | 3 | 操作 | 装备移除（特别是 Zone 最后一件）无退场动画 | 分层级退场（装备 collapse + Zone 卡片 scaleOut）+ toast |
| 🟡 P1 | 4 | 页面衔接 | 「去装备库」按钮需要跨三层导航 | 建议去掉该按钮，改为纯「临时添加」引导（选项 A） |
| 🟡 P1 | 5 | 页面衔接 | 从装备库 Tab 无法回到配装页面 | 去掉了「去装备库」按钮就无需处理此问题 |
| 🔵 P2 | 6 | 进入 | 引导按钮 → Zone 卡片的过渡动画未定义 | staggered 入场序列（卡片→进度条→FAB） |
| 🔵 P2 | 7 | 视图切换 | 清单视图显示英文 BodyZone 枚举值 | 新增 `inferDisplayGroup()` 回译为品类名 |
| 🔵 P2 | 8 | 视图切换 | 清单视图切换时状态（折叠/滚动）丢失 | 明确标注为设计选择，接受组件重建 |
| 🔵 P2 | 9 | 操作 | long-press 菜单的视觉形式未定义 | 使用 ActionSheet（SHEET_GEAR_ITEM_ACTION），统一 Sheet 动画 |
| 🔵 P2 | 10 | 选装 | 品类 tab 未定义单选/多选模式 | 单选模式 + sticky 定位 |
| 🔵 P2 | 11 | 布局 | FAB z-index 需确保不被 Zone 卡片遮挡 | 使用 Stack + position 确保层级 |
| 🔵 P3 | 12 | 布局 | Zone 卡片按添加顺序 vs 固定人体位置 | 建议固定网格位置，空 Zone 用 0 高度占位 |
| 🔵 P3 | 13 | 信息展示 | 两个视图的进度不同步展示 | 一期不做 |
| 🔵 P3 | 14 | 布局 | 底部安全区适配 | padding 留白 + FAB 位置调整 |

---

## ✅ 第三轮没有发现的新增 P0 问题

这说明之前两轮审查的核心问题已经全部修正。现在处于「从 90% 打磨到 98%」的阶段。本轮发现的 P1 问题集中在**页面衔接**（进入/退出/跨页面跳转的过渡动画）和**组件层级**（Sheet 叠 Sheet 的架构约束），都是实现阶段会自然暴露的问题——在 spec 中预先定义好，开发时就不会临时凑合。

---

## 🎯 给 spec 作者的行动清单

如需修订到 v4，建议修改以下内容：

1. **§3.1 路径 A 补充转场说明**：NavDestination `.transition(OPACITY)` + push 时背景景深
2. **§3.6 TempGearMiniSheet 改为内联覆盖层**：不经过 SheetOverlay 路由，直接在 GearPickerSheet 内部用 Stack 渲染
3. **§3.8 补充移除退场动画**：分层级退场 + toast
4. **§3.7 去掉「去装备库」按钮**：仅保留「临时添加一件」链接（新用户不需要装备库概念）
5. **§5.2 TempGearMiniSheet 描述更新**：明确其作为 GearPickerSheet 内联组件，不占用全局 Sheet 槽位
6. **新增 §3.11 装备移除反馈**：定义两种退场场景的动画 + toast
7. **§2.1 补充网格固定位置规则**：Zone 卡片网格位置固定，空 Zone 用 0 高度占位
8. **§3.5 品类 tab 补充交互模式**：单选 + sticky 定位
9. **§9.2 补充视图切换声明**：明确 if/else 条件渲染 + 组件重建 + 状态不保持
10. **新增 §3.12 long-press 菜单设计**：ActionSheet 形式 + 三个操作 + 危险操作用红色
