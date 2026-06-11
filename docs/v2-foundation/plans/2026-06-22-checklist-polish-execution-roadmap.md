# 核查清单页质感提升 — 施工执行路线图

> 性质：本文件是 `2026-06-22-checklist-visual-polish-benchmark.md`（设计论证版）的**施工执行版**。
> 论证版回答「为什么这么做」，本文件回答「具体怎么改、改成什么、怎么验、什么时候 commit」。
> 两份并存：开工前先读论证版对齐方向，施工时照本文件逐条勾。
> 沉淀日期：2026-06-22
> 代码基线：已逐函数核对（行号截至本文件沉淀时，改动后会偏移，以函数名定位为准）。

---

## 0. 施工总则（每个 Task 都适用，不再重复）

1. **一次一个 Task**：每个带 `[ ]` 的复选框是一次独立改动，改完即构建、即 commit。禁止攒着一起改。
2. **构建命令**（固定，不要改）：
   ```
   DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon
   ```
3. **commit 时机**：构建通过 → `git add -A && git commit -m "<message>"`。message 用本文件每个 Task 给出的建议文案。
4. **token 纪律**：色值/尺寸/时长/曲线一律走 `Colors.ets` / `Layout.ets` / `Typography.ets` / `AnimationTokens.ets`，禁止组件内硬编码。
5. **范式红线**（来自论证版 §7，违反即作废）：不抄便单整块染色 / 不改 2 列信息架构 / 不引入任何拖拽态 dim / 不加新入口按钮 / 不藏空格子 / 不把展开态做成铺满全屏新页面 / 不对可滚动网格做整体 scale / 不强行居中展开 Rect / 不新增 Hero 转场 token。
6. **验收纪律**：每个 Task 的「验收标准」必须真机/模拟器实测确认，不能只靠"构建通过"。涉及转场/拖拽的必须录屏。

### 0.1 代码现状关键事实（核对后确认，影响施工判断）

| 事实 | 含义 |
|---|---|
| `SHADOW_LIGHT #14000000` / `SHADOW_MEDIUM #28000000` / `LIGHT_PRIMARY_COLOR #E8F5E9` / `AMBER_ACCENT` / `PROGRESS_INACTIVE #90A4AE` 已存在于 `Colors.ets` | 直接引用，不新增 |
| `SPRING_COUNTER`(0.3/0.75) / `SPRING_HERO_EXPAND`(0.42/0.73) / `SPRING_HERO_COLLAPSE`(0.36/0.78) / `STAGGER_OFFSET_Y` / `staggerDelay()` 已存在于 `AnimationTokens.ets` | 直接复用，不新增 token |
| `ZONE_*_TINT`（20% 部位色 `#33` 前缀）7 个已存在 | 描边 token 需另建更淡的 `ZONE_*_STROKE` |
| `LoadoutProgressBar` 已实现 counter 滚动(`animateCounter`)+100% 庆祝(`celebrateScale`)+完成态主色 | Phase E 进度条是「微调校验」非「新建」 |
| `ZoneGridCell.buildTitleRow` 现状：色条/图标/文字**全部 `zoneColor` 彩色** | §4.1 要反转为「浅染底 + 文字 `TEXT_MAIN` 深色」，注意是改回深色 |
| `FocusedZoneView` 现状 `width/height 100%` + `backgroundColor(PAGE_BG)` 整屏页 | §4.7 要改卡片浮层，是 Phase D 最大头 |
| 元信息区现状 = `TripDetailPage.buildSharedInfo` 单行 `buildInfoText()` 字符串拼接 | §4.6 海拔加图标需拆行重构，非纯改样式 |
| 拖拽蒙层在 `UnifiedChecklistView.buildLongPressOverlay` 首个 Column，`.opacity(this.overlayVisible ? 1 : 0)` | Phase A 核心就改这一行 |

---

## Phase A — 拖动态去灰（最高优先级 / 最低成本 / 最高感知收益）

> 目标：干掉「长按转拖拽时全页压灰」的尴尬中间态，让拖拽全程页面常亮 + 胶囊有「被拎起」物理感。
> 涉及文件：仅 `components/gear/UnifiedChecklistView.ets`（1 个文件）。
> 依赖：无。可立即开工。

### A-1 蒙层在 dragging 阶段淡出（核心修复）

- [ ] **改动点**：`UnifiedChecklistView.buildLongPressOverlay()` 内第一个 `Column()`（蒙层，`backgroundColor('#33000000')`）。
- [ ] **改成什么**：把 `.opacity(this.overlayVisible ? 1 : 0)` 改为按阶段判定——`dragging` 阶段返回 0，其余阶段维持原逻辑（菜单态 1、未显示 0）。
- [ ] **补过渡**：给该 Column 加 `.animation`（曲线 `EASE_FADE`、时长 `DURATION_OVERLAY_FADE`），保证蒙层是「淡出」而非「硬消失」。两者已 import，无需新增。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**（必须实测）：长按弹菜单 → 蒙层压灰（正常）；从菜单态滑动进入拖拽 → **蒙层平滑淡出，背景恢复常亮**；松手归位后无残留灰。
- [ ] **commit**：`fix(checklist): 拖拽阶段蒙层淡出，消除全页压灰中间态`

### A-2 跟手胶囊浮起物理感

- [ ] **改动点**：`buildLongPressOverlay()` 内阶段2 跟手胶囊 `Row({ space: 8 })`（含 `position({ x: dragCurrentX-60, y: dragCurrentY-40 })` 那个）。
- [ ] **改成什么**（逐项）：
  - 阴影升档：`radius 16 / OVERLAY_DIM / offsetY 6` → `radius 20 / SHADOW_MEDIUM / offsetY 8`（`SHADOW_MEDIUM` 已存在，import 补入）。
  - 浮起缩放：进入 dragging 时 `scale 1.05`，曲线用 `SPRING_PRESS()`。
  - 轻微倾斜（可选，先做）：dragging 时 `rotate 2.5°`，同 `SPRING_PRESS()`。实测若晃眼则去掉，倾斜不是硬性。
- [ ] **注意**：胶囊现用 `.animation`（`EASE_FADE`）控 opacity。scale/rotate 的弹性曲线与 opacity 的 EASE 不能共用一个 `.animation()`——ArkUI 同一 `.animation()` 只能挂一条曲线。**优先用属性级 animation**：scale/rotate 各自后跟 `.animation`（`SPRING_PRESS()`），opacity 后跟原 `EASE_FADE`，互不干扰。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：拖拽时胶囊明显「浮起」（更大阴影 + 略放大），像被手指拎着；倾斜（若保留）自然不晃眼。
- [ ] **commit**：`feat(checklist): 拖拽胶囊浮起物理感（放大+升阴影+微倾斜）`

> Phase A 完成定义：录一段「长按→拖拽→松手」，确认全程无全页变灰、胶囊有浮起感。

---

## Phase B — 容器化（解决「简陋」+「空满区分不清」两大主诉求）

> 目标：满格子成为有边界有重量的实体盒子；空格子压缩淡化、修正层级倒置；两列高度对齐。
> 涉及文件：`constants/Colors.ets`、`components/gear/ZoneGridCell.ets`、`components/gear/UnifiedChecklistView.ets`。
> 依赖：无（但 Phase D 依赖 B 产出的描边/标题行视觉，故 B 必须在 D 前）。

### B-1 新增 `ZONE_*_STROKE` token（按饱和度分档）

- [ ] **改动点**：`constants/Colors.ets`，在 `ZONE_*_TINT` 区块后新增一组描边色。
- [ ] **改成什么**：透明度按论证版 §3.1 饱和度分档（高饱和蓝/红/靛 ~8%、中饱和橙/紫 ~11%、低饱和棕/灰蓝 ~14%），初值真机并排微调。命名 `ZONE_HEAD_STROKE` … `ZONE_MISC_STROKE` 共 7 个。
- [ ] **配套 helper**：新增「zone → stroke 色」映射 `zoneStroke(zone)`，与现有 `UnifiedChecklistView.zoneColor()` 并列，透传给 `ZoneGridCell` 新 prop。
- [ ] **构建验证**：`hvigorw assembleApp`（仅加 token + helper，应零报错）。
- [ ] **验收标准**：构建通过；token 可被引用。
- [ ] **commit**：`feat(colors): 新增 ZONE_*_STROKE 容器描边色（按饱和度分档）`

### B-2 满格子白卡容器化（`ZoneGridCell.buildContentCell`）

- [ ] **前置**：`ZoneGridCell` 新增 `@Prop zoneStroke`（默认 `ZONE_MISC_STROKE`）+ `@Prop zoneTint`（复用已存在的 `ZONE_*_TINT`），由 B-1 的 helper 传入。
- [ ] **改动点 1 — 阴影升档**：内层白卡 Column 的 `radius 8 / SHADOW_SUBTLE / offsetY 2` → `radius 12 / SHADOW_LIGHT / offsetY 4`（`SHADOW_LIGHT` 已存在，import 补入）。
- [ ] **改动点 2 — 加描边**：同一**内层白卡** Column 加 `border`（宽 0.5、色 `zoneStroke`、Solid）。注意外层 Column 的 `border` 是拖拽高亮专用（`isDropTarget`），不要动那个。
- [ ] **改动点 3 — 标题行浅染（反转）**：改 `buildTitleRow`：色条保持 `zoneColor`（色彩锚点留彩），**图标和文字 `fontColor` 从 `zoneColor` 改为 `TEXT_MAIN`**；标题 Row 加浅染底（`zoneTint`）+ `borderRadius 8`；padding 由 `left/right 4` 调到 `8`，高度 24 可保留或微增到 28。
- [ ] **改动点 4 — 卡内无分隔线**：收缩态不加行间分隔线（论证版 S1），行内逻辑不动。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：满格子有明显「盒子感」——柔和阴影浮起 + 极淡同部位色描边 + 标题行浅彩底深色字；七个 zone 的描边深浅看起来均衡。
- [ ] **commit**：`feat(checklist): 满格子白卡容器化（升阴影+部位色描边+浅染标题行）`

### B-3 空格子压缩 + 极致淡化 + 提示文案（`ZoneGridCell.buildEmptyCell`）

- [ ] **改动点 1 — 高度封顶**：空格子虚线区高度从撑满 cellHeight 改为最高 132vp；外层 Column 仍占满 `cellHeight`（保持同行对齐），多出空间在框外居中留白。
- [ ] **改动点 2 — 虚线淡化**：`border` 宽 `1.5` → `1`；色先维持 `DIVIDER_COLOR`，实测仍重再换更淡色（如 `PLACEHOLDER_COLOR`）。
- [ ] **改动点 3 — 「+」降权**：`SymbolGlyph plus` 的 `fontSize 20 / fontColor TEXT_TERTIARY` → `fontSize 18 / fontColor PLACEHOLDER_COLOR`。
- [ ] **改动点 4 — 加提示文案**：「+」下方加一行 `Text`（部位名 `zoneDisplayName(zone)`），`FONT_SIZE_CAPTION` / `PLACEHOLDER_COLOR` / `margin top 4`，满足 vision §4.3「空格子是提醒」。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：空格子视觉重量明显**低于**满格子（修正层级倒置）；扫一眼注意力落在「已装了什么」；空格子仍可见、有部位名提示。
- [ ] **commit**：`feat(checklist): 空格子压缩淡化+部位名提示，修正空满层级倒置`

### B-4 网格同行等高对齐（`UnifiedChecklistView.buildGridState` + `ZoneGridCell`）

- [ ] **先排查**：满/空格子外层 Column 都用 `cellHeight`，理论同高。若实机仍参差，重点查 GridItem 是否被内容撑高。
- [ ] **改动策略**：给 `buildGridState` 两处 `GridItem` 显式 `height(cellHeight)`，强制同行等高；空格子「最高 132vp」在 cell 内部消化，不破坏 GridItem 等高。`columnStart/columnEnd`（杂项跨列）不动。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：左右两列同行基线齐平，整体呈严整矩阵，无参差错落。
- [ ] **commit**：`fix(checklist): 网格同行等高对齐，消除两列参差`

> Phase B 完成定义：收缩态截图与便单并排，「容器感」「空满分层」两项达标；网格整齐。

---

## Phase C — 拖动物理感深化

> 目标：被拖项源位留虚线空槽；目标格高亮叠淡绿底。
> 涉及文件：`components/gear/UnifiedChecklistView.ets`、`components/gear/ZoneGridCell.ets`。
> 依赖：Phase A（拖拽态已常亮）+ Phase B（描边/容器已就位）。

### C-1 源位置虚线空槽

- [ ] **数据透传**：`ZoneGridCell` 新增 `@Prop draggingItemId`，在 `buildGridState` 两处透传（仅 `dragging` 阶段为 `overlayItem.id`，否则 null）。
- [ ] **渲染空槽**：`buildContentCell` 的 `ForEach(previewItems)` 内，命中 `item.id === draggingItemId` 的行 → 渲染虚线占位空槽（同高 `GRID_ROW_HEIGHT`，不渲染 ChecklistRow、不绑手势）。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：拖动某项时它在原行变虚线空位，不塌陷不消失；松手放回原位时空槽复原。
- [ ] **commit**：`feat(checklist): 拖拽源位置留虚线空槽，明确"从哪拿的"`

### C-2 目标格高亮叠淡绿底

- [ ] **改动点**：`ZoneGridCell` 外层 Column 现有 `isDropTarget` 绿框 + glow，再叠一层极淡背景。
- [ ] **改成什么**：`isDropTarget` 为 true 时白卡内层背景从 `CARD_BG` 切到 `LIGHT_PRIMARY_COLOR`（已存在），用 `SPRING_GENERAL()` 平滑过渡，离开恢复 `CARD_BG`。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：拖到某格上方时绿框 + glow + 淡绿底三重反馈，可放置非常明确；离开恢复白底。
- [ ] **commit**：`feat(checklist): 拖拽目标格叠淡绿底，强化可放置反馈`

---

## Phase D — 展开态容器化 + 共享元素转场重构（本轮重头戏，§4.5 + §4.7 合并）

> 目标：聚焦态 = 收缩态格子的等比放大版（共用外壳），转场是「同一边框连续放大」而非「翻页」。
> 涉及文件：`components/gear/ZoneGridCell.ets`、`components/gear/FocusedZoneView.ets`、`components/gear/UnifiedChecklistView.ets`，可能新增 `components/gear/ZoneShell.ets`。
> 依赖：Phase B（外壳描边/标题行浅染必须先就位，否则两端外观不一致，转场退化）。
> 合并理由：转场重构依赖「两端共用外壳」，正是展开态容器化的产出，拆开会先做一版再推翻。
> ⚠️ 这是风险最高的 Phase，HarmonyOS geometryTransition 对两端差异敏感，每个 Task 后必须真机录屏。

### D-1 抽出统一外壳 `ZoneShell` 组件

- [ ] **设计**：外壳 = 「白卡背景 `CARD_BG` + `CARD_RADIUS` 圆角 + `ZONE_*_STROKE` 描边 + 浅染标题行（色条彩 / 图标文字 `TEXT_MAIN`）+ 内容插槽」。
- [ ] **落地决策（推荐方式 a）**：做成独立 `@Component struct ZoneShell`（新建 `components/gear/ZoneShell.ets`），用 `@BuilderParam content` 作内容插槽。`ZoneGridCell` 与 `FocusedZoneView` 都内嵌 `ZoneShell` 包裹各自内容，从根上保证两端外壳结构 100% 一致——这是 geometryTransition 不闪烁的地基。（方式 b：两 struct 各写一份结构一致的 `@Builder`，成本低但易腐化，不推荐。）
- [ ] **接入**：先让 `ZoneGridCell` 切到 `ZoneShell`。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：构建通过；收缩态外观与 Phase B 一致（无回退）。
- [ ] **commit**：`refactor(checklist): 抽出 ZoneShell 组件供网格/聚焦两端共用外壳`

### D-2 `FocusedZoneView` 改卡片浮层（不铺满）

- [ ] **改哪**：`FocusedZoneView.build()`：去掉根 Column 的 `backgroundColor(PAGE_BG)`、`width/height 100%`；改为外层 `ZoneShell` 卡片，宽由父层留边距约束、高度自适应封顶（超出时卡内 List 滚动）。
- [ ] **顶栏**：`buildTopBar` 的 Zone 名区浅染 `ZONE_*_TINT`（与收缩态一致），色条/图标/名保 `TEXT_MAIN`。
- [ ] **底部**：`buildAddRow` 确认留在卡片容器内（现已在 List 内末项）。
- [ ] **父层留边距**：`UnifiedChecklistView.buildFocusedLayer()` 给 `FocusedZoneView` 包定位容器，左右 `margin 20-24vp`、上避开顶部信息区、下避开安全区；geometryTransition 仍挂外层节点、id 不变。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：展开后四周能看到背景余光，不再整屏白底裸露；卡片有圆角/描边/阴影。
- [ ] **commit**：`feat(checklist): 聚焦态从整屏页改为卡片浮层（保留边框圆角，不铺满）`

### D-3 目标 Rect 锚定原格中心（就地放大）

- [ ] **机制**：geometryTransition 自动从「源格子 Rect」插值到「目标节点 Rect」。靠父层定位容器对齐方式，让展开卡片几何中心尽量贴近被点格子中心，做到「就地放大」。
- [ ] **风险**：若自动布局把卡片摆到屏幕中央，需用 `position`/`offset` 微调；先真机看默认表现，不够再补。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：点偏下行的格子，卡片在原位附近长大，不是「跳到屏幕中央再放大」。
- [ ] **commit**：`fix(checklist): 聚焦卡片就地放大，锚定原格几何中心`

### D-4 背景联动：全屏蒙层压暗 + 网格虚化下沉（不缩放）

- [ ] **加哪**：`UnifiedChecklistView` Stack 内新增覆盖全屏的压暗蒙层 `#33000000`，由 `focusedZone != null` 驱动，与 `SPRING_HERO_EXPAND/COLLAPSE` 同帧淡入淡出；层级在网格之上、聚焦卡片之下；蒙层 `onClick` → `closeFocus()`。
- [ ] **网格虚化**：`buildGridState()` 整体加 `blur` + 极小 `translateY` 下沉（聚焦时），**不加 scale**（R1：网格可滚动，下行展开时前几行可能已滚出视口）。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：展开任意行（含滚到底部的行）背景都有稳定压暗 + 虚化纵深感；点蒙层收起。
- [ ] **commit**：`feat(checklist): 聚焦态全屏蒙层压暗 + 网格虚化下沉（不缩放）`

### D-5 真机录屏逐帧对比便单（本 Phase 验收闸门）

- [ ] 真机录屏收→展→收全过程，逐帧确认：① 边框连续放大（非两套界面淡入淡出）② 无翻页感 ③ 无闪烁/错位 ④ 卡内 List 滚动与外层横划收起手势不打架。
- [ ] 若转场闪烁：排查两端 `ZoneShell` 外观是否真一致、`focusedZone`+`focusedZoneRender` 是否同帧赋值（现 `openFocus` 已正确）。
- [ ] **Phase D Done 定义**：录屏对比便单，转场「边框放大」体感成立，无翻页感，构建通过，全部子项 commit。

---

## Phase E — 顶部信息区 + 进度条 + 勾选态强化（§4.6 + 勾选）

> 锦上添花层。把「行程档案」精致感拉满。

### E-1 勾选完成态强化

- [ ] **改哪**：`ChecklistRow.build()`。已勾态现状已较完整：实心填充圆 + 白勾 + 删除线 + 文字 `PLACEHOLDER_COLOR`。
- [ ] **微调**：填充色与文字弱化程度调到位（填充色用主色还是部位色见 Q3）；文字可改 `TEXT_TERTIARY`。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：打勾后成就反馈明确（实心圆 + 白勾 + 删除线 + 文字弱化）。
- [ ] **commit**：`style(checklist): 强化勾选完成态视觉反馈`

### E-2 进度条微调（克制，大部分已实现）

- [ ] **现状**：`LoadoutProgressBar` 已实现 counter 滚动（`animateCounter`）、100% 主色高亮（`isComplete`）、纯色不渐变。
- [ ] **唯一可能调整**：填充动画曲线从 `SPRING_GENERAL` 换 `SPRING_COUNTER`（更贴「数字滚动」语义），是否换见 Q4。
- [ ] **构建验证**：`hvigorw assembleApp`（如有改动）。
- [ ] **验收标准**：进度条细条克制，数字滚动、100% 主色高亮。
- [ ] **commit**：`style(progress): 进度条曲线微调（如有改动）`

### E-3 顶部元信息区重构

- [ ] **改哪**：`TripDetailPage.buildSharedInfo()` + `buildInfoText()`。现状纯文字 `parts.join(' · ')` 单行。
- [ ] **目标**：拆成 Row 结构——日期/地点纯文字，仅「海拔」前加三角图标点睛；数字用 `tnum` 等宽 + `AMBER_ACCENT` 点睛；顶部信息区与格子区留足呼吸间距（§3.4）。
- [ ] **改动幅度**：结构化重构 vs 单行只给海拔加图标，见 Q5。
- [ ] **构建验证**：`hvigorw assembleApp`。
- [ ] **验收标准**：顶部信息「行程档案」感，海拔图标点睛，数据 amber 强调。
- [ ] **commit**：`style(trip): 顶部元信息区图标点睛 + 数据强调 + 呼吸间距`

> Phase E 完成定义：勾选态、进度条、顶部信息区三项精装修完成，构建通过，逐项 commit。整页质感对标便单达标。

---

## 待决策清单（开工前需拍板，避免中途返工）

| # | 决策点 | 位置 | 选项 | 建议 |
|---|---|---|---|---|
| Q1 | `ZONE_*_STROKE` 7 色透明度初始值 | B-1 / Colors.ets | §3.1 的 8%/11%/14% 分档 | 按表落地，真机微调 |
| Q2 | `ZoneShell` 走独立组件还是双份 @Builder | D-1 | a 独立组件 / b 双份 Builder | **a 独立组件**（防腐化） |
| Q3 | 勾选态填充用主色还是部位色 | E-1 | PRIMARY_COLOR / zone 色 | 待定（主色更统一，部位色更呼应容器） |
| Q4 | 进度条曲线是否换 SPRING_COUNTER | E-2 | 换 / 保持 SPRING_GENERAL | 待定 |
| Q5 | 顶部信息区重构幅度 | E-3 | 结构化重构 / 单行加海拔图标 | 待定（看要多精致） |
| Q6 | 空格子高度上限 132vp 是否合适 | B-3 | 132 / 其他值 | 真机看再定 |

---

## 全局纪律（每个 commit 前自检）

- [ ] 色值/尺寸/时长/曲线全部走 token，无硬编码
- [ ] 动效用 `AnimationTokens` 预设；按压三段式；拖拽跟手 `duration:0`、松手 `SPRING_GENERAL`
- [ ] Spring 系列忽略 duration，错落用 delay（MEMORY ArkUI 约定）
- [ ] 同一属性不 `.animation()` + `animateTo()` 并存
- [ ] 新增数据结构字段 optional、向后兼容
- [ ] 一次只做一件事；改完即 `hvigorw assembleApp`；通过即 `git add -A && git commit`
- [ ] 每步开工前对照 vision v3 §4 与本文档，确认不偏离「格子即清单」范式

---

_本计划为 §6 设计论证文档的施工落地版。评审/决策拍板后，从 Phase A-1 启动。_
