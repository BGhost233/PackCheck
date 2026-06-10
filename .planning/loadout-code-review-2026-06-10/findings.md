# 塔科夫式配装系统 · 代码实现审查报告

> 审查日期：2026-06-10 | 范围：15 次 commit，10 个文件新增/修改  
> 新增文件：LoadoutService.ets, LoadoutGearItem.ets, LoadoutZoneCard.ets, LoadoutProgressBar.ets, LoadoutView.ets, TripDetailPage.ets, GearPickerSheet.ets, GearItemActionSheet.ets  
> 修改文件：Index.ets, SheetOverlay.ets, DesignTokens.ets, Colors.ets, SheetMode.ets

---

## 0. 总体评价

实现质量**中等偏上**。核心架构（双视图、Zone 网格、渐进式出现、Sheet 内实时反馈、Misc 子分区）已正确落地，LoadoutService 的纯函数写得很好，GearPickerSheet 的交互流程完整。但存在 **3 个编译阻断问题和若干功能缺失**。

---

## 🔴 P0 · 编译阻断

> **修正**：经核实，以下 3 条 P0 中，#1 和 #2 为误报（CategoryTagGroup 已在此次改动中新增了所需 prop；`buildSearchEmpty` 已存在）。仅 #3 为真实问题（Flex space API 在构建中未报错，说明 API 23+ 已支持或参数被静默忽略）。因此本次实现**无编译阻断问题**。

### 1. ~~GearPickerSheet 调用了 CategoryTagGroup 不存在的 props~~ → 误报

经核实，`CategoryTagGroup` 已在此次改动中新增了 `selectedCategory: string`、`mode: string`、`editable: boolean`、`onSelect` 等 prop。代码正确。

### 2. ~~buildSearchEmpty 不存在~~ → 误报

`buildSearchEmpty()` 已在 `GearPickerSheet.ets:333` 定义。代码正确。

### 3. GearItemActionSheet 中 `Flex` 使用了 `space` API → 构建通过

`GearItemActionSheet.ets:121` 和 `GearPickerSheet.ets:178` 中 `Flex({ space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } })` — API 23+ 中 Flex 可能已支持此参数，或参数被静默忽略。构建通过，非阻断问题。但建议改用 `Row/Column({ space: N })` + 手动 margin 以确保更广泛的 API 兼容性。

---

## 🟡 P1 · 功能缺失或行为错误

### 4. TripDetailPage 缺失共享信息区

**文件**：`TripDetailPage.ets`

Spec §3.2 明确要求导航栏和分段控件之间有一个**共享信息区**，显示行程日期和结构化字段摘要（`2026年7月15日 / 武功山 · 22km · 海拔1918m · 12h`）。这个区域在代码中完全不存在。

**影响**：用户在配装时看不到行程的目的地和基本参数——而这直接影响选装决策（「武功山 22km」vs 「周边公园 3km」带的东西完全不同）。

**修复**：在 `buildNavBar()` 和 `buildSegment()` 之间新增一个 `buildSharedInfo()` @Builder，渲染当前行程的 `date`、`destination`、`distanceKm`、`maxAltitude`、`ascentM`、`durationHours` 的摘要行。

### 5. TripDetailPage 缺失「更多」菜单（···）

**文件**：`TripDetailPage.ets:153`

导航栏右侧是一个空的 `Row().width(40).height(40)` 占位符。Spec §3.6 要求这里有一个 `···` 更多菜单，包含三个选项：编辑行程信息、核查复盘、删除行程。

**修复**：将右侧占位符替换为可点击的 `SymbolGlyph($r('sys.symbol.ellipsis'))`，点击后呼出菜单。

### 6. TripDetailPage 缺失 isDirty 变更检测

**文件**：`TripDetailPage.ets` + `Index.ets:1881-1884`

Spec §4.5 和 §3.6 定义了变更检测逻辑：无变更退出时不调用 `saveChecklists()`。当前 `onBackPressed` 直接调用 `this.returnToHome()` 不做任何检测。每次退出都会触发不必要的 I/O。

**修复**：TripDetailPage 维护一个 `@State isDirty: boolean`，在添加/删除/勾选/移动装备时置 true。`onBackPressed` 中通过 callback 通知 Index.ets 是否需要保存。或将 isDirty 作为 @Prop 传递给 Index.ets 的回调。

### 7. TripDetailPage 的 NavDestination 缺失 geometryTransition

**文件**：`Index.ets:1876-1884`

```typescript
NavDestination() {
  TripDetailPage({ ... })
}
.hideTitleBar(true)
.width('100%')
.height('100%')
.transition(TransitionEffect.opacity(0.99))  // ← 只有这个
.onBackPressed(() => { ... })
// ❌ 缺少 .geometryTransition('trip-' + this.selectedChecklistId)
```

**影响**：从 HomePage 点击行程卡片进入 TripDetailPage 时，共享元素转场失效——用户看到的是普通 fade 而非卡片一镜展开。这是**最明显的体验退步**。

**修复**：添加 `.geometryTransition('trip-' + this.selectedChecklistId)`。同时验证 HomePage 中行程卡片的 `geometryTransition` id 格式一致（应该都是 `'trip-' + id`）。

### 8. TripDetailPage 的 `transition` 属性参数错误

**文件**：`Index.ets:1880`

`.transition(TransitionEffect.opacity(0.99))` — `opacity(0.99)` 意味着页面从 99% opacity 开始，几乎无淡入。这是前代码审查中已指出的问题（ChecklistDetail 同样问题）——应改为 `opacity(0)`。

**修复**：`.transition(TransitionEffect.opacity(0))`

### 9. LoadoutView: `trip` @Prop 的变化不会触发缓存刷新

**文件**：`LoadoutView.ets:58, 76, 84-86`

```typescript
@Prop @Watch('onTripChange') trip: TripChecklist = { ... };

onTripChange(): void {
  this.refreshCache();
}
```

`@Watch` 只在 `trip` 引用变化时触发。但 `trip.items` 的内容变化（添加/删除装备、勾选切换）不会改变 `trip` 的引用——Index.ets 的 `applyChecklistState` 创建了新引用，所以 `trip` @Prop 应该能收到变化。**但如果 Index.ets 没有正确创建新引用，缓存就不会刷新。**

需要验证：`toggleGearInTrip`（`Index.ets:1467`）调用 `addItemsToChecklist` → `applyChecklistState`。`applyChecklistState` 使用 `this.checklists = nextChecklists`（新引用），然后通过 @Prop 传给 TripDetailPage → LoadoutView。链路上的引用是新的，应该触发 @Watch。

**结论**：当前实现应该能正确刷新，但需要真机验证。潜在风险：`incrementGearTripCounts` 在 toggle 时没有被调用（spec 提到自动反哺是第二步的事），目前可以接受。

### 10. Misc 子分区的 `groupMiscByCategory` 每次 build 都重新计算

**文件**：`LoadoutZoneCard.ets:125-138`

`getMiscCategories()` 和 `getItemsForMiscCategory(category)` 在渲染时调用 `groupMiscByCategory(this.items, this.gears)`。一个 Misc Zone 有 ~15 件装备时，每次 build 都重新计算一次按品类分组的 Map。

**修复**：在 `LoadoutZoneCard` 中缓存 `miscGroupMap`，通过 `@Watch` 监听 `items` 变化时重建缓存。类似 LoadoutView 的 `zoneMapCache` 模式。

### 11. `inferZoneFromGroup` 模糊匹配顺序问题

**文件**：`LoadoutService.ets:118-119`

```typescript
if (group.indexOf('背') >= 0 || group.indexOf('包') >= 0 || group.indexOf('背负') >= 0) {
  return BodyZone.Carry;
}
```

注意顺序：`'背'` 匹配在 `'背负'` 之前。因为 `String.indexOf('背')` 也会匹配 `'背负'`，所以 `'背' >= 0` 为 true 时已经 return，`'背负' >= 0` 永远不会被检查。这不是 bug（因为它们映射到同一个 Zone），但逻辑有冗余。

同样 `'脚'` / `'鞋'` / `'行走'`（line 115）——任意一个命中即返回 Feet。如果旧数据的分组名是「电子」，`'子'` 不在任何匹配中，应该正确 fallback 到 Misc。✓

### 12. `inferDisplayGroup` 对临时装备返回 `'杂项(临时)'`

**文件**：`LoadoutService.ets:146`

临时装备在清单视图中显示为 `'杂项(临时)'`。但配装视图中已经有 `临时` chip 标记（`LoadoutGearItem.ets:88-95`）。清单视图中「杂项(临时)」作为分组名不够直观。

**建议**：显示为 `'临时装备'` 而非 `'杂项(临时)'`——更直观，不暴露 Zone 内部枚举。

---

### 23. LoadoutView: `onTapLayerBadge` 错误映射到 `onLongPressItem`

**文件**：`LoadoutView.ets:200`

```typescript
onTapLayerBadge: this.onLongPressItem  // ❌ 应该映射到 onLayerChange
```

层级 badge 的 tap 回调错误地映射到了长按菜单处理程序。tap 层级 badge 的预期行为是切换层级，而不是弹出操作菜单。**这是一个功能 bug**。

**修复**：`onTapLayerBadge: this.onLayerChange`

### 24. Index.ets: `onActionViewDetail` 无法正确导航

**文件**：`Index.ets:2354-2361`

代码关闭 Sheet 后设置 `expandedGearId` 和 `currentTabIndex`，但**没有 pop NavDestination**。用户仍停留在 TripDetailPage 上，看不到任何变化。此外 `currentTabIndex = 0` 切换到的是**行程 Tab**（index 0），不是装备库 Tab（index 1）。

**修复**：关闭 Sheet 后先 `pop` 回 HomePage，然后切换 Tab 到装备库（index 1），最后设置 `expandedGearId`。

### 25. 新增方法中缺失 `await saveChecklists`

**文件**：`Index.ets:1477, 1482, 1500, 1543, 1554`

`toggleGearInTrip`、`addTempGearToTrip`、`moveItemToZone`、`removeItemFromTrip` 调用 `this.store.saveChecklists(nextChecklists)` 时没有 `await`。代码库其他所有 `save*` 调用都使用了 `await`。如果操作后 App 立即关闭，这些数据可能不会被持久化。

---

## 🔵 P2 · 代码质量与细节

### 13. Zone chip 颜色使用字符串拼接添加透明度

**文件**：`GearPickerSheet.ets:294`

```typescript
.backgroundColor(this.isSelected(gear.id) ? PRIMARY_COLOR : '#33' + this.getZoneColor(assignSlot(gear).zone).substring(1))
```

`'#33' + '#42A5F5'.substring(1)` = `'#3342A5F5'`（7 位 → 9 位 hex）。这在 ArkUI 中可能不被解析为有效的 ARGB 颜色。应该使用 `Colors.ets` 中已有的透明度 token 或定义 ZONE_*_COLOR 的半透明变体。

**修复**：在 `Colors.ets` 中为每个 Zone 颜色新增半透明 token（如 `ZONE_HEAD_COLOR_SUBTLE: '#3342A5F5'`），或在代码中使用 `Color.argb()` API。

### 14. TempGearMiniSheet 使用 setTimeout 清理

**文件**：`GearPickerSheet.ets:415-417`

```typescript
setTimeout(() => {
  this.showTempOverlay = false;
}, 250);
```

250ms 是硬编码的，假设动画在 250ms 内完成。如果设备卡顿，覆盖层可能在动画中途消失。应使用 `animateTo({ onFinish: () => { ... } })`。

**修复**：
```typescript
this.getUIContext().animateTo(
  { curve: SPRING_PRESS(), onFinish: () => { this.showTempOverlay = false; } },
  () => { this.overlayScale = PANEL_SCALE_START; this.overlayOpacity = 0; }
);
```

### 15. LoadoutProgressBar 重复实现了 counter 动画

**文件**：`LoadoutProgressBar.ets:102-128`

`animateCounter` 函数使用 `setTimeout` + `Date.now()` + easeOutCubic（`1 - (1-t)^3`），与项目中已存在的 `AnimationUtils.counterAnimate` 功能完全重复。引入了不必要的代码冗余。

**修复**：复用 `counterAnimate(from: number, to: number, callback: (v: number) => void)`。

### 16. LoadoutProgressBar 使用了 `setTimeout` 庆祝动画

**文件**：`LoadoutProgressBar.ets:121-123`

```typescript
setTimeout(() => {
  this.celebrateScale = 1.0;
}, 200);
```

应该使用 `.animation()` + `.onAppear()` 或 `animateTo` 的 `onFinish` 来驱动回弹，而非 `setTimeout`。

### 17. TripDetailPage 中两个视图都使用 `layoutWeight(1)` + `transition`

**文件**：`TripDetailPage.ets:82-83, 105-106`

```typescript
LoadoutView({...})
  .layoutWeight(1)
  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() }))
```

`.transition()` 是**进场/退场**动画（当组件通过 if/else 创建/销毁时触发）。但这里两个视图都是通过 `if/else` 条件渲染——每次切换会销毁一个、创建另一个。`.transition()` 应该能生效，但需要注意：**`TransitionEffect.OPACITY` 不带参数意味着 opacity(1)**，即进场时从 opacity 0 过渡到 1。搭配 `.animation()` 修饰器应该能产生交叉淡入淡出效果。**需要在真机上验证实际效果**——如果 if/else 切换是瞬间的（不触发 transition），可能需要改用 `animateTo` + `if/else` 组合。

### 18. SheetOverlay 的 SHEET_GEAR_PICKER 标题缺失

**文件**：`SheetOverlay.ets:366-369`

```typescript
if (this.sheetMode === SHEET_GEAR_PICKER) {
  return '选择装备';  // ✓ 正确
}
if (this.sheetMode === SHEET_GEAR_ITEM_ACTION) {
  return '';          // ✓ 空标题（ActionSheet 自带标题）
}
```

Sheet 标题设置正确，但 GearPickerSheet 的「关闭」按钮文字在 picker 模式下不合适——用户期望看到「完成」或「关闭」。「完成」更合适（暗示选完装备可以关闭）。

### 19. GearPickerSheet「临时添加」行缺少按压反馈

**文件**：`GearPickerSheet.ets:114-126`

「+ 临时添加（不入装备库）」行只有 `onClick`，无 `.onTouch`、`.scale()`、`.animation()` 按压反馈。

### 20. `addTempGearToTrip` 没有设置 `fromGearId`

**文件**：`Index.ets:1491-1497`

这是正确的——临时装备 `fromGearId` 应该为 `undefined`。

### 21. Zone 颜色 token 名称不一致

`Colors.ets` 中 Zone 颜色被定义为 `ZONE_HEAD_COLOR`、`ZONE_UPPER_COLOR` 等（推测），但 spec §6.2 使用的颜色值与代码中可能不完全一致。如果开发时直接使用了不同色值，需要统一。

### 22. `currentTabIndex = 0` 应该是 1

**文件**：`Index.ets:2359`

```typescript
this.currentTabIndex = 0; // 切换到装备 Tab  ← ❌ index 0 是 行程 Tab
```

装备库 Tab 的 index 是 **1**，不是 0。当前代码切到了错误的 Tab。

---

## ✅ 做得好的地方

1. **LoadoutService 的纯函数设计**：`assignSlot`、`groupByZone`、`sortItemsByLayer`、`calcProgress`、`inferZoneFromGroup`、`inferDisplayGroup`——全部是纯函数，无状态，参数和返回值类型清晰。`inferZoneFromGroup` 的旧数据兼容逻辑（模糊匹配 + 兜底 Misc）很完善。

2. **Zone 渐进式出现**：LoadoutView 的 `getVisibleZones()` 只返回有装备的 Zone，空 Zone 不渲染卡片——与 spec §3.3 的渐进式策略完全对齐。

3. **GearPickerSheet 的反馈机制**：已选汇总栏（`getZoneSummary()`）、Zone chip 颜色（选中变绿 + ✓）、连续多选（Sheet 不自动关闭）——与 spec §3.5 的反馈设计一致。

4. **TempGearMiniSheet 作为内联覆盖层**：不走全局 SheetOverlay，用 Stack + 遮罩 + 居中卡片实现——与第三轮审查 P1-2 的建议一致。

5. **勾选即时反馈**：`LoadoutGearItem.onItemChange()` 使用 `animateTo` 驱动 checkScale，勾选动画即时触发——与 spec §6.5 的即时反馈策略一致。

6. **Misc 子分区**：`LoadoutZoneCard.buildMiscContent()` 按品类分子区展示——与 spec §2.4 一致。

7. **SheetOverlay 集成干净**：新增的两个 Sheet 模式（`SHEET_GEAR_PICKER`、`SHEET_GEAR_ITEM_ACTION`）与现有 9 种 Sheet 模式同路径管理，props 和 callbacks 清晰。

8. **Index.ets 的 toggleGearInTrip**：添加/移除装备的逻辑正确（查找 `fromGearId`、`removeItemFromChecklists` / `buildItemsFromGears` + `addItemsToChecklist`、`applyChecklistState` + `saveChecklists`）。

---

## 📊 审查汇总

| 优先级 | 数量 | 说明 |
|--------|------|------|
| 🔴 P0 编译阻断 | 3 | CategoryTagGroup 不存在的 props、buildSearchEmpty 不存在、Flex space API |
| 🟡 P1 功能缺失 | 9 | 共享信息区、更多菜单、isDirty、geometryTransition、transition 参数、缓存刷新风险等 |
| 🔵 P2 代码质量 | 8 | 颜色拼接、setTimeout 清理、代码重复、Tab index 错误等 |

### 修复优先级排序

```
P0-1: 修复 CategoryTagGroup props → 自建品类 chip Row
P0-2: 修复 buildSearchEmpty → 内联渲染
P0-3: 修复 Flex space → Row/Column 替代
P1-1: TripDetailPage 添加 .geometryTransition('trip-' + id) 
P1-2: TripDetailPage 添加共享信息区 (date + structured fields)
P1-3: TripDetailPage 添加 ··· 更多菜单
P1-4: TripDetailPage 添加 isDirty 变更检测
P1-5: Index.ets currentTabIndex = 0 → 1
P2-1: Zone chip 颜色拼接 → Colors token
P2-2: TempGearMiniSheet setTimeout → animateTo onFinish
P2-3: ProgressBar 复用 counterAnimate
```
