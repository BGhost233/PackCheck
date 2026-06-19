# PackCheck 全面性能优化计划

> ✅ **已完成** — 2026-06-14 全部 8 步执行完毕，构建验证通过（BUILD SUCCESSFUL in 10s）。
>
> 基于 2026-06-14 全项目代码审计产出，按 P0→P1→P2→P3 优先级实施。
> 原则：最小改动、向后兼容、不改变任何视觉行为，只消灭冗余计算和不必要的节点重建。
>
> **改动文件**：LoadoutService.ets / UnifiedChecklistView.ets / GearPage.ets / TripDetailPage.ets / ZoneGridCell.ets / FocusedZoneView.ets

---

## P0：拖拽/滚动热路径直接卡顿源

### 优化 1：缓存 `display.getDefaultDisplaySync()` 屏幕尺寸

**问题**：`UnifiedChecklistView` 的 `handleEdgePanUpdate`/`handleEdgePanEnd`/`handleEdgeDragOut`/`handleBatchDragOut` 每帧（~16ms）调用 `display.getDefaultDisplaySync()` 获取屏幕尺寸——这是 IPC 跨进程调用，累积延迟直接吃掉帧预算。`computeCellHeight()` 也重复调用。

**改动范围**：`UnifiedChecklistView.ets`

**方案**：
- 新增 `private screenWidthVp: number` / `private screenHeightVp: number` 成员变量
- `aboutToAppear()` 中一次性计算并缓存：
  ```typescript
  const di = display.getDefaultDisplaySync();
  this.screenWidthVp = this.getUIContext().px2vp(di.width);
  this.screenHeightVp = this.getUIContext().px2vp(di.height);
  ```
- `handleEdgePanUpdate`/`handleEdgePanEnd`/`handleEdgeDragOut`/`handleBatchDragOut`/`computeCellHeight` 中所有 `display.getDefaultDisplaySync()` 替换为读缓存
- 删除这些方法中的 `try-catch`（缓存保证有值，fallback 移到 aboutToAppear）

**预估收益**：拖拽帧时间减少 2-5ms（IPC 开销），Pan 事件处理吞吐提升 ~20%。

---

### 优化 2：`GearPage` 筛选/排序结果缓存化（消灭计算链爆炸）

**问题**：`filteredGears()` 内执行全量遍历 + `sortedGears()` 完整排序，但在一次 build 帧中被 `filteredGearGroups()`、`filteredGearsByGroup(group)` × N、`gearGroupCount(group)` × N、ForEach 分割线判断 × M 等调用点重复触发，总计执行 (2+2N) 次。100 件装备 × 5 分组 ≈ 12 次完整排序/帧。

**改动范围**：`GearPage.ets`

**方案**：
- 新增缓存结构：
  ```typescript
  @State private cachedFilteredGears: GearItem[] = [];
  @State private cachedGearGroupOrder: string[] = [];
  @State private cachedGearsByGroup: Map<string, GearItem[]> = new Map();
  ```
- 新增 `private rebuildGearCache(): void` 方法，一次性计算 filteredGears → 分组 → 排序 → 填充三个缓存
- 触发时机：`@Watch('onGearDataChange')` / `gearSearchKeyword` 变化 / `gearSortMode` 变化 / `selectedGearCategories` 变化 / `categoryOrder` 变化时调 `rebuildGearCache()`
- 将 `filteredGears()`、`filteredGearGroups()`、`filteredGearsByGroup(group)`、`gearGroupCount(group)` 改为直接读缓存
- ForEach 中分割线判断 `index < this.filteredGearsByGroup(group).length - 1` 改为 `index < (this.cachedGearsByGroup.get(group)?.length ?? 0) - 1`

**预估收益**：build 帧中计算量减少 80%+，装备库页面滚动/折叠/展开动画帧率显著提升。

---

### 优化 3：`gearRowShiftY()` 拖拽索引预算（O(N²) → O(1)）

**问题**：拖拽排序时，`gearRowShiftY(item)` 对屏幕上每个可见行执行 `filteredGearsByGroup()` + 双 `findIndex()`。Pan 每帧 ×20 行 = O(20×N) 每帧。

**改动范围**：`GearPage.ets`

**方案**：
- 新增拖拽预算索引：
  ```typescript
  private dragGroupItems: GearItem[] = [];
  private dragItemIndexMap: Map<string, number> = new Map();
  ```
- 进入拖拽态时（`gearOverlayPhase` 切 `'dragging'`）预算一次索引：
  ```typescript
  this.dragGroupItems = this.cachedGearsByGroup.get(category) ?? [];
  this.dragGroupItems.forEach((g, i) => this.dragItemIndexMap.set(g.id, i));
  ```
- `gearRowShiftY()` 内用 `this.dragItemIndexMap.get(item.id)` 和 `this.dragItemIndexMap.get(draggingId)` O(1) 查表替代 `findIndex()`
- 拖拽结束时清空索引

**预估收益**：拖拽排序帧率从 ~30fps 提升到稳定 60fps。

---

## P1：重复计算导致的不必要 re-render

### 优化 4：`TripDetailPage.metaSegments()` 缓存

**问题**：build 中被调 3 次（`reservedTop` 判断 ×2 + `buildSharedInfo` 内 ForEach），每次构造新数组 → ForEach 拿到不同引用 → 不必要的节点重建。

**改动范围**：`TripDetailPage.ets`

**方案**：
- 新增 `@State private cachedMetaSegments: MetaSegment[] = [];`
- 新增 `private refreshMetaCache(): void`，在 `checklists`/`selectedChecklistId` 变化时调用
- `metaSegments()` 改为返回 `this.cachedMetaSegments`
- `reservedTop()` 和 `buildSharedInfo` 直接读 `this.cachedMetaSegments.length`

**预估收益**：行程详情页 build 中 ForEach diff 命中率 100%（引用不变不重建）。

---

### 优化 5：`TripDetailPage.currentChecklist()` 结果复用

**问题**：一次 build 中 `currentChecklist()` 被多处调用（line 156、214、260、314），每次 O(N) 线性扫描。

**改动范围**：`TripDetailPage.ets`

**方案**：
- 新增 `@State private cachedTrip: TripChecklist | undefined = undefined;`
- 在 `checklists`/`selectedChecklistId` 变化时一次性查找并缓存
- build 中所有 `this.currentChecklist()` 调用改为 `this.cachedTrip`

**预估收益**：消除 4× 线性扫描/帧，代码更清晰。

---

### 优化 6：`groupByZoneAll()` 单次遍历分桶

**问题**：7 次 `.filter()` 遍历全量 items（每个 zone 一遍），O(7N)。

**改动范围**：`services/LoadoutService.ets`

**方案**：
```typescript
export function groupByZoneAll(items: ChecklistItem[]): Map<string, ChecklistItem[]> {
  const map = new Map<string, ChecklistItem[]>();
  const zoneOrder: string[] = [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
  // 预初始化全部 zone 为空数组
  for (const zone of zoneOrder) {
    map.set(zone, []);
  }
  // 单次遍历分桶
  for (let i = 0; i < items.length; i++) {
    const zone = inferZoneFromGroup(items[i].group);
    const bucket = map.get(zone);
    if (bucket !== undefined) {
      bucket.push(items[i]);
    } else {
      // 未知 zone 归入 Misc
      map.get(BodyZone.Misc)!.push(items[i]);
    }
  }
  return map;
}
```

**预估收益**：从 O(7N) → O(N)，清单页打开速度提升 ~6x（items 多时差异明显）。

---

### 优化 7：`buildGearIndex` 去冗余（父级构建 → @Prop 下发）

**问题**：`UnifiedChecklistView` 下有 7 个 `ZoneGridCell` + 1 个 `FocusedZoneView`，每个都在 `@Watch('gears')` 中独立执行 `buildGearIndex(gears)`，共 8 次 O(N) 构建。

**改动范围**：`UnifiedChecklistView.ets`、`ZoneGridCell.ets`、`FocusedZoneView.ets`

**方案**：
- `UnifiedChecklistView` 新增：
  ```typescript
  @State private gearIndex: Map<string, GearItem> = new Map();
  ```
  在 `aboutToAppear` 和 gears prop 变化时构建一次
- `ZoneGridCell` 和 `FocusedZoneView`：
  - 新增 `@Prop gearIndex: Map<string, GearItem> = new Map();`
  - 删除各自的 `@Watch('gears')` + `onGearsChange()` + 自行 `buildGearIndex`
  - 直接读 `this.gearIndex`

**预估收益**：gears 变化时 Map 构建从 8N → N，减少 7 次冗余遍历。

---

## P2：ForEach key 策略导致的过度重建

### 优化 8：`UnifiedChecklistView` Grid ForEach key 精确化

**问题**：`checklistRenderNonce` 拼入全部 7 个 zone 的 ForEach key → 勾选一项时所有 7 个 ZoneGridCell 销毁重建（即使只有一个 zone 变了）。

**改动范围**：`UnifiedChecklistView.ets`

**方案**：
- 将 ForEach key 从 `zone + '_' + length + '_' + nonce` 改为 `zone + '_' + zoneContentHash`
- `zoneContentHash` = 该 zone 下 items 的 checked 状态串（如 `"101100"`），精确标识哪个 zone 真正变了
- 具体实现：
  ```typescript
  private zoneKey(zone: string): string {
    const items = this.itemsForZone(zone);
    let key = zone + '_' + items.length.toString();
    for (let i = 0; i < items.length; i++) {
      key += items[i].checked ? '1' : '0';
    }
    return key;
  }
  ```
- 只有真正变化的 zone 才触发重建，其他 6 个保持复用

**预估收益**：勾选操作从全网格 7 格重建 → 仅 1 格重建，帧开销降为 1/7。

---

### 优化 9：`GearPage` ForEach 分割线重复计算消除

**问题**：ForEach 闭包内每个 item 的 `if (index < this.filteredGearsByGroup(group).length - 1)` 触发完整 filter+sort。

**改动范围**：`GearPage.ets`（`GearGroupCard` Builder）

**方案**：
- 此问题已被优化 2 的缓存方案一并解决——`filteredGearsByGroup` 改为读缓存 O(1)
- 额外优化：ForEach 数据源直接用 `this.cachedGearsByGroup.get(group) ?? []`，分割线判断用 `index < items.length - 1`（items 在 ForEach 外取一次）

**预估收益**：随优化 2 一并生效。

---

## P3：次要优化

### 优化 10：`Index.ets` latestChecklist 调用合并

**问题**：`latestChecklistTitle()`、`latestChecklistSubtitle()`、`latestChecklistProgress()` 各自独立调 `latestChecklist()` 做线性查找。

**改动范围**：`Index.ets`（如果 HomePage 通过 callback 获取这些值）

**方案**：考虑到 Index 的 latestChecklist 系列方法在 build 中由 HomePage @Prop 接收，实际只在 checklists 变化时需要重算。如果 HomePage 本身有缓存则无需改动。评估后如果 HomePage 在 build 中多次调用这些回调，则在 Index 中预算一个 `@State latestTrip` 缓存。

**预估收益**：小幅优化，影响不大。

---

### 优化 11：`gearHeaderBorderColor()` 字符串分配优化

**问题**：滚动期间每帧拼接新 hex 字符串。

**方案**：保持现状——微秒级开销不影响帧率，改动投入产出比低。标记为 WONTFIX。

---

## 实施顺序

```
Step 1: 优化 6 (groupByZoneAll 单次分桶) — 独立纯函数，零风险
Step 2: 优化 1 (display 缓存) — UnifiedChecklistView 局部改动
Step 3: 优化 2 + 9 (GearPage 缓存体系) — 核心重构，影响面最大
Step 4: 优化 3 (拖拽索引预算) — 依赖 Step 3 的缓存
Step 5: 优化 4 + 5 (TripDetailPage 缓存) — 独立页面
Step 6: 优化 7 (gearIndex 上提) — 跨 3 文件
Step 7: 优化 8 (Grid key 精确化) — 依赖 Step 6 的缓存结构
Step 8: 构建验证 + commit
```

## 不变量（安全网）

- 所有改动不改变任何 UI 视觉表现和交互行为
- 缓存更新时机覆盖所有数据变化路径（@Watch + 事件回调）
- ForEach key 变更后仍保证正确的 diff 行为（变化时重建、不变时复用）
- 构建通过（`hvigorw assembleApp`）
- 遵循 MEMORY.md 避坑 #38（数组不原地 mutation）、#46（@State 镜像驱动渲染）
