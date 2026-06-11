# 统一清单视图 — 真机交互问题修复开发计划

> 日期：2026-06-11
> 范围：统一清单视图（UnifiedChecklistView）网格态 / ZoneGridCell / GearPickerSheet 真机交互问题修复
> 关联 spec：`docs/v2-foundation/specs/2026-06-22-unified-checklist-view-design.md` v0.7.0/v3
> 前置：审查报告 B1/B2/B3/I4/V2/V3/D1/C1/C2 已修复并构建通过（commit 99221ce、7e0cc3c）

---

## 〇、背景与问题清单

真机自测（截图二张）暴露 5 个问题，用户已逐条确认方向。本计划把它们拆成 5 个独立 commit，按依赖顺序实施，每步构建验证通过再进下一步。

| 编号 | 问题 | 性质 | 用户确认方向 |
|------|------|------|--------------|
| P1 | 行程无装备时显示「引导按钮页」，应直接铺虚线空格子 | 设计 | 删引导页，空态=全虚线格子 |
| P2 | 点有装备的格子主体不进全屏聚焦（白卡区无手势） | **Bug** | 点 check 圆圈勾选；点装备名/其余位置整卡进聚焦 |
| P3 | 新建未入库装备入口藏在列表底部 | 交互 | A+B（顶部常驻 + 搜不到就建）；新建时让用户选「本次临时」or「存入装备库」 |
| P4 | 格子太高 + 底部被硬截断 | 设计 | 4a 降格高露 4 条；4b 底部高斯模糊暗示可滑 |
| P5 | picker sheet 品类 tab 占屏过大、列表归属不清 | 重构 | 去品类 tab；装备按品类分组、可折叠；默认全折叠 + 预选/搜索命中自动展开 |

---

## 一、铁律遵循

- 禁止硬编码色值/字号/时长/曲线 → 一律 `constants/` token
- 动画统一 Spring；可点击元素必须按压反馈
- 新增字段全部 optional，向后兼容
- 一次只做一件事；每个 commit 独立可回滚
- 每步改完跑 `hvigorw assembleHap` 构建验证，BUILD SUCCESSFUL 才 commit

---

## 二、逐项方案与执行路径

### Commit 1 — P1：空态直接铺虚线格子

**文件**：`UnifiedChecklistView.ets`

**改动**：
1. `build()` 中删除 `trip.items.length === 0` → `buildEmptyState()` 的分支，让 `buildGridState()` 成为唯一布局。0 件时所有 ZoneGridCell 走空态虚线框（ZoneGridCell 已支持空态，无需改）。
2. FAB 由「仅有内容时显示」改为「始终显示」：删除 `if (this.trip.items.length > 0) { this.buildFAB() }` 的条件，直接渲染。
3. `buildEmptyState()` @Builder 整块删除（连带 import 里若仅它用到的 `bag` symbol / Button 相关无需额外清理，Button 是内置组件）。
4. 进度条 `LoadoutProgressBar` 维持「仅有内容时显示」（0 件时不显示进度条，符合 0/0 无意义）。

**验证点**：新建空行程 → 直接看到 7 个虚线空格子 + FAB；点任一空格子的「+」进 picker。

**风险**：`reservedTop()`（TripDetailPage）在 0 件时不算 ProgressBar 高度（条件是 items>0），与本改动一致，无需动。

---

### Commit 2 — P2：整卡热区进全屏聚焦（Bug 修复）

**文件**：`ZoneGridCell.ets`

**根因**：有内容态格子只有 `buildTitleRow(true)` 绑 `onTapTitle`，下方白卡主体区无手势 → 点主体无反应。

**热区决策（已与用户对齐取向）**：网格态卡片是「预览」，全屏聚焦态才是「核查」。因此：
- 网格态有内容态卡片：**整卡（标题行 + 白卡主体）点击都进聚焦**。
- 网格态卡片内的 ChecklistRow **不再响应勾选**（预览态只读），勾选只在 FocusedZoneView（全屏聚焦态）进行。

**改动**：
1. `buildContentCell()` 根 `Column` 加整体按压反馈（scale）+ `onClick(() => this.onTapTitle(this.zone))`。
2. 网格态预览不勾选：`buildContentCell` 内 ChecklistRow 的 `onToggleCheck` 传空函数（`() => {}`），让点击冒泡到外层卡片触发聚焦；ChecklistRow 本身整行 onClick 会拦截 → 需让网格态 ChecklistRow 不拦截。
   - 实现：给 ChecklistRow 加 `@Prop interactive: boolean = true`；为 false 时不绑 onClick/不显示按压、纯展示。网格态预览传 `interactive: false`，聚焦态传 `interactive: true`（默认）。
3. `buildTitleRow(true)` 的独立 onClick 保留（标题行也能进聚焦，双保险），但按压态统一由外层卡片驱动，避免双重 scale 叠加 → 标题行按压改为不独立 scale（clickable 时不再 setPressed），统一用卡片级 pressed。

**验证点**：点有装备格子任意位置（标题/装备名/空白）→ 全屏聚焦放大；网格态点装备名不勾选。

**风险**：ArkUI `@Builder` 调用处不能外挂属性 → scale/onClick/animation 全部加在 `buildContentCell` 内部根 Column。

---

### Commit 3 — P4：降格高 + 底部高斯模糊

**文件**：`ZoneGridCell.ets`、`UnifiedChecklistView.ets`、（可能）`constants/Layout.ets`

**4a 降格高、露 4 条**：
1. `ZoneGridCell.MAX_PREVIEW_ITEMS` 3 → 4。
2. 网格态 ChecklistRow 行高 40 → 32（聚焦态保持宽松，由 FocusedZoneView 各自传参，不受影响）；checkSize 22 → 20。
3. 标题行高 24、卡片内边距收紧，整格净高下降。
4. `UnifiedChecklistView.FIRST_SCREEN_ROWS` 维持 2.5（保留半行暗示），cellHeight 反算逻辑不变；行变密后同样 cellHeight 能容纳 4 条预览。
   - 校验：cellHeight 内可用高 = cellHeight - 标题行(24) - gap - 卡片padding；4 条 × 32 + 折叠行 28 ≈ 156，需确认反算 cellHeight 够用；若不够，微调 FIRST_SCREEN_ROWS 或行高。

**4b 底部高斯模糊**：
1. 在 `buildGridState()` 外层（Stack 内）底部叠一层渐变模糊遮罩：`Column` 定位贴底，高度约 64vp，`backdropBlur(...)` + 从透明到 PAGE_BG 的线性渐变，`hitTestBehavior(None)` 不挡交互。
2. 模糊层在 FAB 之下、网格之上；仅网格态显示。
3. 模糊强度 / 渐变用现有 token；若无合适常量，模糊半径走字面量但加注释（ArkUI backdropBlur 半径非「色值/字号/时长/曲线」，不违反 token 铁律，但仍尽量收敛到 Layout 常量）。

**验证点**：格子明显变矮、露 4 条；底部出现渐隐模糊带，下方格子半透可见，暗示可滑。

---

### Commit 4 — P5：GearPickerSheet 重构（去品类 tab + 分组折叠）

**文件**：`GearPickerSheet.ets`（主），可能新增 `services/LoadoutService.ets` 或 `models` 的分组辅助

**删除**：
1. 顶部 `CategoryTagGroup` 整块 + `filterCategory` 状态 + `filteredGears()` 里的品类筛选分支（搜索过滤保留）。
2. 移除对 `CategoryTagGroup` 的 import（确认无他处复用本文件该 import）。

**新增「按品类分组 + 可折叠」列表**：
1. 数据结构：`groupGearsByCategory(gears): Array<{category, gears[]}>`，按 `DEFAULT_CATEGORIES` 顺序排列，空品类不显示。
2. 折叠状态：`@State private expandedCategories: Set<string>`（或 `string[]`，ArkTS Set 状态需谨慎，用 string[] 更稳）。
3. 每组渲染：
   - section header 行：品类名 + 件数 + 折叠箭头（chevron）。点击切换展开/折叠，箭头 `rotate` 用 `SPRING_CHEVRON`，组内容高度过渡用 `SPRING_GENERAL`。
   - 展开时 ForEach 渲染该组 `buildGearRow`（复用现有行，含选中态/Zone chip/I4 高亮）。
4. **默认折叠策略**：`aboutToAppear` 初始化 `expandedCategories`：
   - 若 `preselectZone` 非空 → 把该 zone 对应的所有 category 加入展开集合（需 zone→categories 反查，见下）。
   - 其余默认折叠。
5. **搜索命中自动展开**：`searchText` 非空时，命中装备所属 category 自动视为展开（渲染时 `isExpanded(cat) || searchActive`）。
6. **I4 预选 zone 兼容**：原「该 zone 装备置顶」改为「该 zone 相关 category 分组排前 + 默认展开」；行内高亮 `isPreselectZone` 逻辑保留。

**zone→categories 反查**：当前 `assignSlot(gear).zone` 是 gear→zone（单向）。分组按 category，需要把 preselectZone 映射到「哪些 category 属于该 zone」。
- 方案：遍历 `gears`，凡 `assignSlot(g).zone === preselectZone` 的 `g.category` 收集成集合（数据驱动，无需硬编码映射表）。简单且与现有 assignSlot 一致。

**验证点**：sheet 打开无品类 tab；装备按品类分组、默认折叠；点 header 展开收起有动画；搜索自动展开命中组；从空格子进入时该 zone 相关品类已展开并排前。

---

### Commit 5 — P3：新建装备入口 A+B + 入库/临时二选一

**文件**：`GearPickerSheet.ets`（UI）、`SheetOverlay.ets`（透传）、`Index.ets`（落地逻辑）

**A — 顶部常驻入口**：搜索框下方常驻一行「+ 新建装备」，点击打开新建覆盖层（不用滚到底）。删除/保留列表底部入口：保留底部入口为兜底亦可，但为避免双入口混乱 → **删底部、只留顶部常驻**。

**B — 搜不到就建**：`searchText` 非空且 `filteredGears().length === 0` 时，分组列表区顶部显示「+ 新建『{searchText}』」一行，点击带着已输入名字打开新建覆盖层（`tempName` 预填 searchText）。

**入库/临时二选一**：新建覆盖层（原 TempGearMiniSheet overlay）增加一个选择：
1. 覆盖层标题下加一组二选一开关（segmented / 两个 chip）：「本次行程临时」/「存入装备库」，默认「本次行程临时」（保守，不污染装备库）。
2. 字段：名称、归属区域（zone，保留）、重量（保留）。
3. 「存入装备库」时需要 category：由所选 zone 反推一个默认 category（取该 zone 下最常见 category，或 zone 对应的代表 category；若无法确定 → CATEGORY_FALLBACK「其他」）。可在覆盖层加一个 category 选择（可选，默认按 zone 推断），避免新建入库后品类乱。
   - **决策点（实现时确认）**：入库是否要求用户显式选 category？倾向：默认按 zone 推断 category，覆盖层不强制选，保持轻量；后续用户可在装备库编辑。
4. 回调拆分：
   - 现有 `onTempAdd(name, zone, weight)` → 保留，语义=本次临时（落 `addTempGearToTrip`，只挂行程不入库）。
   - 新增 `onCreateGear(name, zone, weight, persist: boolean)`，或新增 `onPersistAdd(name, category, zone, weight)` 走「新建入库 + 同时挂当前行程」。
   - **倾向**：扩展为单一回调 `onCreateGear(name, zone, weight, toLibrary: boolean)`，Index 内部分流：toLibrary=true 走新写的 `createGearAndAddToTrip`（saveGears + addItemsToChecklist + ensureCategory），false 走原 `addTempGearToTrip`。

**Index.ets 新增 `createGearAndAddToTrip`**：
1. 构造 `GearItem`（makeId('gear')、name、category=zone 推断、weight、createdAt=Date.now()）。
2. `saveGears([...gears, newGear])` 入库 + `ensureCategory(category)`。
3. `buildItemsFromGears([newGear], [newGear.id])` 生成 item 挂入当前行程（带 fromGearId，进度可计入）。
4. `applyChecklistState` + `saveChecklists`。

**验证点**：
- 顶部常驻「+ 新建装备」可点；
- 搜「不存在的名字」→ 列表顶部出现「+ 新建『xxx』」预填；
- 新建覆盖层可选「临时」/「入库」；
- 选「入库」后该装备出现在装备库 Tab + 当前行程；选「临时」只在行程、不入库。

---

## 三、commit 顺序与依赖

```
C1 (P1 空态格子)        ── 独立
C2 (P2 整卡热区 bug)    ── 独立
C3 (P4 降格高+模糊)     ── 依赖 C2（行 interactive 改动后再调行高更稳）
C4 (P5 picker 重构)     ── 独立（改 GearPickerSheet 主体）
C5 (P3 新建入口+入库)   ── 依赖 C4（在重构后的 picker 上加入口，避免冲突）
```

实施顺序：C1 → C2 → C3 → C4 → C5，每步构建验证 + 独立 commit。

---

## 四、构建命令

```
cd /Users/bghost233/Documents/PackCheck && \
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" && \
export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" && \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default --no-daemon
```

commit message 用多个 `-m`，不含换行。

---

## 五、待实现时确认的小决策（不阻塞，倾向已给）

1. **P2 热区**：网格态卡片内装备行是否完全只读（不勾选）→ 倾向是，勾选只在聚焦态。
2. **P4 行高**：32vp 是否够清晰 → 实测微调。
3. **P5 默认折叠**：已定全折叠 + 预选/搜索自动展开。
4. **P3 入库 category**：是否强制用户选 → 倾向默认按 zone 推断、不强制。

以上 4 点若实施中需偏离倾向，会先同步再改。

---

## 六、第二批真机问题（问题4：聚焦态完整交互体系）

> 来源：2026-06-11 真机自测后用户追加需求。P1-P5（第一批）落地后，针对**全屏聚焦态**提出的完整交互体系。
> 用户原话：「点格子展开后，再次点击展开后的格子或左右划就收起聚焦回网格，不要新增返回按钮；格子展开态时单击装备名展开装备详情，长按显示二级菜单，不松手保持拖拽则格子收缩，可拖拽装备到别的格子。」

拆成 4 个子任务，按 4a→4b→4c→4d 顺序，每个独立构建验证 + commit。

| 子任务 | 内容 | 状态 | commit |
|--------|------|------|--------|
| 4a | 聚焦态状态透传 Index + onBackPressed 分层拦截（有 sheet 关 sheet → 有聚焦收聚焦 → 否则返回首页，侧滑同样分层） | ✅ 完成 | `14bee41` |
| 4b | 聚焦态点空白处 / 左右划任意方向收起聚焦回网格（无返回按钮） | ✅ 完成 | `42c9a85` |
| 4c | 单击装备名原地手风琴展开详情（品类/重量/品牌/备注，经 `fromGearId` 反查装备库） | ✅ 完成 | `42c9a85` |
| 4d | 长按弹二级菜单（编辑/移除）+ 长按不松手转拖拽跨 Zone 移动装备 | ⏸ **推迟到 phase4** | `7ce4155`（仅预埋注释） |

### 关键实现决策

**4a 状态透传链**：聚焦态 `focusedZone` 由 Index 持有 `@State` 源 → TripDetailPage `@Link` → UnifiedChecklistView `@Link` → FocusedZoneView `@Prop active`。收起用「信号递增」技巧：Index 不直接改 `focusedZone`（会丢失 `SPRING_HERO_COLLAPSE` 收起动画），而是递增 `focusedCloseSignal: number`，UnifiedChecklistView `@Watch` 后调自己的 `closeFocus()`（动画封装留在组件内）。

**4b 收起机制（借力 ArkUI 事件消费）**：聚焦态根 Column 绑 `onClick(收起)` + 横向 `PanGesture(distance:24, 收起)`。利用「组件绑 onClick 即消费事件不冒泡」特性——装备行 ChecklistRow / check 圆圈 / 底部添加行 / 顶栏关闭键各自消费点击，只有点到「行间空隙 / 列表底部留白 / 顶栏空白」才冒泡到根触发收起。无需新增返回按钮。

**4c 双热区 + 手风琴**：聚焦态 ChecklistRow 改 `checkOnlyHotzone: true`——点 check 圆圈勾选，点装备名/行其余区调 `onTapRow` → `toggleExpand(id)` 原地手风琴展开详情。详情经 `fromGearId` 反查 `GearItem` 取品类/品牌/备注；临时装备（无 fromGearId）只显已有字段，全空显「暂无更多信息」占位。

**4d 推迟（phase4）**：`onEditItem`/`onRemoveItem`/`onMoveItemToZone` 三层透传链已贯通到 FocusedZoneView 并预埋（回调默认空函数，build 内暂无消费方），phase4 只需在 build 里挂手势消费，不用再改透传链。Index 侧 `moveItemToZone(itemId, zone)` 改 group 的落地逻辑已就绪。
- **手势方案建议（phase4 直接用）**：阈值分流——长按≈500ms 手指基本不动 → 弹轻量浮层菜单（编辑/移除）；长按后手指明显移动 → 不弹菜单、聚焦态 SPRING 收缩回 2 列网格、被拖装备跟手浮起、悬停目标格子高亮、松手落入 → `moveItemToZone` 改 group。两条路互斥不互吞，规避 ArkUI menu-then-drag 手势互吞的真机风险。
- group 改写无需担心被覆盖：`inferZoneFromGroup` 只在推断时用，`assignSlot` 只在 GearPickerSheet 加装备时用一次，无运行时自动重算逻辑。
