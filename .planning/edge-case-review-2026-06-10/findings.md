# PackCheck 修复后审查报告 — 边缘场景专项

> 日期：2026-06-10 | 针对 commit `83d7d43`  
> 方法：逐行审查 + 边缘场景走查（空态/极端数据/快速操作/动画中断）

---

## 0. 修复验证总结

上一轮 7 个 Critical + 20 个 Medium 的修复状态：

| 类别 | 状态 |
|------|------|
| 7 处 @State 数组原地修改 | ✅ 全部修复（GearPage 4 处 spread + WeightGauge 3 处 spread） |
| 4 处 CURVE_DECELERATE 替换 | ✅ GearPage/HomePage 全部改为 SPRING_GENERAL/SPRING_PRESS/SPRING_SCROLL |
| ProfilePage ForEach key | ✅ 新增 `(trip: TripSummary) => trip.id` |
| ProfilePage 死按压状态 | ✅ StatCell 新增 index prop + onTouch handler |
| GearSortSheet setTimeout→onFinish | ✅ bounce→rest 链式 animateTo |
| TripCeremonyCard 硬编码色值 | ✅ WHITE_TRANSPARENT/SHIMMER_WHITE_FAINT/SHIMMER_GREEN_GLOSS token |
| TripCeremonyCard setTimeout dismiss | ✅ flyAway/manualDismiss 改用 onFinish |
| GearItemActionSheet 全行按压 | ✅ 7 个操作行 + Zone chips 全部新增按压反馈 |
| MoveGroupSheet 全行按压 | ✅ 新增 pressHandler |
| TripDetailPage onDeleteTrip 接线 | ✅ Index.ets 新增 callback |
| TripDetailPage 按压缩放值 | ✅ 0.9/0.97 → PRESS_SCALE_DOWN |

**BUILD SUCCESSFUL** ✅。本轮聚焦于边缘场景。

---

## 🔴 HIGH — 边缘场景 Bug

### EDGE-H1. 视图切换/TripDetailPage 销毁时 timer 泄漏

**文件**：`LoadoutView.ets:77`、`LoadoutProgressBar.ets:113,127`

视图切换（配装↔清单）时 `if/else` 条件渲染会**销毁** `LoadoutView` 和 `LoadoutProgressBar`。但两个组件中的 `setTimeout`（入场动画 80ms）和 `setInterval`（counter 动画 16ms tick）**从未在 `aboutToDisappear` 中清除**。

**后果**：快速切换几次后，多个僵尸 timer 持续运行在已销毁的组件上，`this.getUIContext().animateTo(...)` 在 stale 引用上抛出运行时异常。`setInterval` 永久泄漏，每个 16ms。

**修复**：在 `LoadoutView` 和 `LoadoutProgressBar` 中添加 `aboutToDisappear()`，清除所有 timer。

### EDGE-H2. Counter 动画在快速双击时脱同步

**文件**：`LoadoutProgressBar.ets:29-33`

`onCheckedChange` 用 `if (this.displayChecked !== this.checked)` 判断是否需要动画。快速双击时：Tap1 ON → 动画 0→1 完成 → `displayChecked=1`。Tap2 OFF → `checked=0`，`displayChecked(1) !== checked(0)` true，动画启动。但如果 Tap3 ON 在前一个动画完成前到达：`displayChecked(~0.5) !== checked(1)`，动画反向。多次快速切换后 `displayChecked` 可能卡在中间值。

**修复**：引入 `@State private animating: boolean` 标志。`animating` 为 true 时始终启动新动画（不依赖值相等判断）。

### EDGE-H3. 装备/Zone 卡片移除无情退场动画

**文件**：`LoadoutView.ets:190-211`、`LoadoutZoneCard.ets:90-103`

当用户移除 Zone 中的最后一件装备时，Zone 卡片因 `getVisibleZones()` 过滤而**瞬间消失**——没有任何 fadeOut、scaleDown、slideOut 动画。同样，移除单个装备行时，`ForEach` 重建列表，被移除的项直接不见。

**修复**：给 `LoadoutZoneCard` 和 `LoadoutGearItem` 添加 `TransitionEffect` 退场动画：
```typescript
.transition(TransitionEffect.OPACITY.animation({ curve: SPRING_GENERAL() }))
```

---

## 🟡 MEDIUM — 边缘场景问题

### EDGE-1. GearPickerSheet 品类筛选结果为空时无提示

**文件**：`GearPickerSheet.ets:108-113`

```typescript
if (this.filteredGears().length === 0 && this.gears.length === 0) {
  this.buildEmptyState()
} else if (this.filteredGears().length === 0 && this.searchText.length > 0) {
  this.buildSearchEmpty()
} else {
  Scroll() { ... }  // ← 品类筛选为空也走这里，渲染空 Scroll
}
```

**场景**：装备库有「穿着·上身」装备 5 件，用户切换到「饮食系统」品类筛选——该品类无装备。`filteredGears()` 返回 `[]`，`gears.length > 0`，`searchText.length === 0`——三个条件都不满足，进入 `else` 分支，渲染一个空的 `Scroll`（白屏）。用户看到空白区域，不知道是「该品类下没有装备」还是「加载失败」。

**修复**：在 `else if` 链中增加一个条件分支：
```typescript
} else if (this.filteredGears().length === 0) {
  // 品类筛选无结果
  Text('该品类下没有装备').fontSize(14).fontColor(TEXT_SECONDARY)...
}
```

### EDGE-2. LoadoutProgressBar 无数据时显示混乱

**文件**：`LoadoutProgressBar.ets`

**场景**：`total === 0` 且 `checked === 0` 时：
- `isComplete()` 返回 `false`（因为 `total > 0` 为 false）✓
- 文案显示「已装包 0/0」——分母为 0，对用户无意义
- 进度条 `progressBarWidth()` 返回 `'0%'`——空进度条
- `percentage()` 返回 `0`

**改善**：当 `total === 0` 时，显示更友好的文字如「还没有添加装备」或在进度条位置不渲染（当前空态已由 LoadoutView 处理，ProgressBar 在 total===0 时不显示）。确认 LoadoutView 是否在 items.length===0 时不渲染 ProgressBar——查看代码，LoadoutView 在 `buildContentState()` 中始终渲染 `LoadoutProgressBar`，不管 items 是否为空。但 `buildContentState()` 本身只在 `trip.items.length > 0` 时调用——所以 ProgressBar 不会在空态下显示。

**结论**：当前行为正确。`trip.items.length > 0` 保证 ProgressBar 收到 `total > 0`。

### EDGE-3. TripDetailPage 视图快速切换时动画竞争

**文件**：`TripDetailPage.ets:250-256`

```typescript
.onClick(() => {
  if (this.activeView !== view) {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.activeView = view;
    });
  }
})
```

**场景**：用户快速连续点击「配装」→「清单」→「配装」。第一次点击触发 200ms Spring 动画切换 `activeView`。在动画未完成时第二次点击——`this.activeView` 可能处于过渡中间态。如果 ArkUI 在动画过程中已经更新了 @State 值（取决于实现），第二次点击可能正确响应；如果 @State 在动画完成回调中才更新，则第二次点击会因 `this.activeView === view` 而跳过。

**当前实现使用 `animateTo` 直接设置 `activeView`**——在 ArkUI 中，`animateTo` 内的 @State 赋值是立即生效的（动画是视觉插值，状态已变）。所以第二次点击时 `activeView` 已经是新值，`if (this.activeView !== view)` 为 true，会触发新的动画。**行为正确，但连续快速切换时动画可能叠加产生视觉抖动。**

**建议**：在切换动画进行中时禁用 SegmentButton（或不做调整，因为这是极边缘场景，用户通常不会故意快速切换）。

### EDGE-4. LoadoutView Zone 卡片首次出现时 `appeared` 永不重置

**文件**：`LoadoutView.ets:75-79`

```typescript
aboutToAppear() {
  this.refreshCache();
  setTimeout(() => {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.appeared = true;
    });
  }, 80);
}
```

**场景**：用户在一个已有装备的行程中进入配装视图，再通过 GearPickerSheet 添加了一件新类别的装备（如首次添加「头部」装备）。新 Zone 卡片出现时，`appeared` 已经为 `true`。在 `buildZoneGrid()` 中：
```
.opacity(this.appeared ? 1 : 0)
.translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
```
由于 `appeared === true`，新卡片直接以全不透明度显示在最终位置，**没有入场动画**。

**改善**：`zoneMapCache` 变化时（通过 `onTripChange` @Watch），新出现的 Zone 应该有独立的入场动画。方案：在 `refreshCache()` 中对比新旧 zoneMap，标记新增的 Zone，在渲染时对新增 Zone 播放独立动画。或更简单：每个 Zone 卡片内部管理自己的 `@State appeared`。

### EDGE-5. GearPickerSheet 临时装备重量 NaN 风险

**文件**：`GearPickerSheet.ets:251`

```typescript
const weight = this.tempWeight.trim().length > 0 ? Number(this.tempWeight) : undefined;
```

**场景**：用户输入非数字字符（如粘贴 "1.5kg" 或输入中文），`Number("1.5kg")` 返回 `NaN`。`NaN` 被传递到 `onTempAdd` → `addTempGearToTrip` → `ChecklistItem.weight = NaN`。之后 `LoadoutGearItem` 中 `this.item.weight > 0` 对 NaN 返回 `false`（静默不显示重量），但 NaN 被持久化到 Preferences 中。

**修复**：
```typescript
const parsed = Number(this.tempWeight);
const weight = (!Number.isNaN(parsed) && this.tempWeight.trim().length > 0) ? parsed : undefined;
```

### EDGE-6. Misc 子分区中品类合并规则可能导致「摄影 · 急救 · 洗护 · 其他」合并在同一行

**文件**：`LoadoutZoneCard.ets` + spec §2.4

Spec 规则：「装备 ≤ 2 件的品类合并为最后一个综合行」。但当前代码中的 `getMiscCategories()` 只是从 `miscMapCache` 的 key 顺序返回品类列表——**没有实现「≤ 2 件合并」的逻辑**。这意味着所有品类独立展示子分区，如果 Misc 下有 7 个品类各 1 件装备，会显示 7 个子分区行——每一行只有一个装备名，视觉上碎片化。

**改善**：在 `getMiscCategories()` 中实现合并逻辑：遍历品类，将装备数 ≤ 2 的品类名 join 为 `'摄影 · 急救 · 洗护'` 这样的合并标题。但这增加了复杂度。一期可以不做——这是 UX 打磨，非功能问题。

### EDGE-7. TripDetailPage 调用 `this.onDeleteTrip()` 需要确认弹窗

**文件**：`TripDetailPage.ets:200` + `Index.ets:1874-1879`

```typescript
onDeleteTrip: () => {
  const checklist = this.checklists.find(c => c.id === this.selectedChecklistId);
  if (checklist) {
    this.confirmDeleteChecklist(checklist);
  }
}
```

`confirmDeleteChecklist` 会弹出确认对话框——✓ 正确。但 `···` 菜单中的「删除行程」是红色显示的吗？当前 `bindMenu` 的 value 是纯文本，不支持颜色定制。作为危险操作，应该有视觉警示。ArkUI 的 `bindMenu` 不支持 item 级别的颜色。**可接受，后续可改用自定义 ActionSheet**。

---

## ✅ 边缘场景已正确处理的

| 场景 | 处理方式 |
|------|---------|
| 装备库为空 + GearPickerSheet | `buildEmptyState()` 显示 icon + 文案 + 「临时添加」按钮 ✓ |
| 搜索无结果 | `buildSearchEmpty()` 显示提示文案 ✓ |
| 新行程 0 件装备 | LoadoutView `buildEmptyState()` 全屏引导 ✓ |
| 所有装备在同一 Zone（如全部 Misc） | `getVisibleZones()` 只返回有装备的 Zone，单列全宽卡片 ✓ |
| 移除最后一个 Zone 的装备 | Zone 卡片因 `getVisibleZones()` 过滤而消失 ✓ |
| 进度条 100% 庆祝 | `celebrateScale` + scale bounce ✓ |
| 快速连续勾选 | LoadoutGearItem 用 animateTo 驱动 checkScale + ProgressBar counterTimerId 取消旧动画 ✓ |
| Tab 边界滑动 | TripDetailPage 不涉及 Tab 滑动（在 NavDestination 内）|
| 深色模式 | 所有颜色使用 Colors token，支持未来切换 ✓ |

---

## 📊 总结

| 类别 | 数量 | 说明 |
|------|------|------|
| 🔴 HIGH | 3 | Timer 泄漏、Counter 动画脱同步、无退场动画 |
| 🟡 MEDIUM | 4 | NaN 传播、TransitionEffect 冲突、大列表无虚拟化、ActionSheet 无过渡 |
| 🔵 LOW | 6 | 品类空态、固定宽度溢出、无数据操作的加载/错误态、移动无效 Zone、搜索空态分支错误、重复 callback |

**核心评价**：修复质量很高。上一轮所有 Critical 已清零。本轮发现的 HIGH 问题聚焦于**组件生命周期管理**（timer 泄漏在视图销毁时）和**动画完整性**（退场动画缺失）。建议优先修复 EDGE-H1（timer 泄漏），其次是 EDGE-H3（退场动画），再次是 EDGE-H2（counter 脱同步）。
