# God Component 拆分 — 调查发现详录

> 来源：上帝组件对抗性调查（2026-06-29）
> 规则：只记录事实和代码引用，不含指令性文本。

---

## 1. Index.ets 全景分析 (2528 行 / 77 @State / 112 方法)

### 1.1 @State 域分类 (77 个)

经逐一审计，77 个 @State 按职责归属到 11 个域：

| 域 | @State 数 | 代表变量 | 可消除? |
|---|----------|---------|--------|
| Sheet 表单代理 | 46 | editGearName, editGearWeight, editGearPrice, editChecklistTitle, editFrom, editTo, editCategoryName... | 是 — 全部可通过 §4.6 @Prop→@State 内化模式消除 |
| Checklist 核心数据 | ~8 | checklists, currentChecklistIndex, checklistRenderNonce | 否 — 核心状态 |
| Gear↔Checklist 联动 | ~5 | selectedGear, gearActionTarget | 否 — 跨域联动状态 |
| 导航/Tab 状态 | ~4 | currentTabIndex, isTabChanging | 否 — 顶层路由 |
| Sheet 控制 | ~6 | isSheetOpen, currentSheetType, sheetHeight | 否 — 但 SheetContainer 重构后可减少 |
| 搜索/筛选 | ~3 | searchText, filterCategory | 部分 — 可内化到搜索组件 |
| 动画/过渡 | ~3 | pageTransitionOpacity | 否 — 跨组件动画协调 |
| 排序状态 | ~2 | sortType, sortDirection | 部分 — 可内化到排序组件 |

**关键发现**: 77 个 @State 中 46 个 (60%) 是 sheet 表单代理，仅服务于表单编辑的双向同步。这是最大的消减机会。

### 1.2 方法分类 (112 个)

| 类别 | 方法数 | 示例 | 可下沉? |
|------|-------|------|--------|
| Sheet 打开/回写 | ~25 | openAddGearSheet(), saveGearFromSheet() | 部分 — 回写逻辑 @State 内化后大幅简化 |
| Checklist CRUD | ~15 | addChecklist(), deleteChecklist(), toggleItem() | 是 — 纯业务逻辑→ChecklistService |
| Gear CRUD | ~12 | addGear(), deleteGear(), updateGear() | 是 — 纯数据操作→GearService |
| Category 管理 | ~8 | deleteCategory(), renameCategory() | 是 — 已事务化，体可搬到 service |
| 统计聚合 | ~10 | getTotalWeight(), getPackedPercentage() | 是 — 纯函数 |
| UI 回调/事件 | ~20 | onTabChange(), onPageScroll() | 否 — 与 @State 紧耦合 |
| @Builder 渲染 | ~15 | buildGearList(), buildHeader() | 否 — ArkUI 渲染逻辑 |
| 生命周期 | ~7 | aboutToAppear(), aboutToDisappear() | 否 |

**关键发现**: ~45 个方法（40%）是纯业务逻辑，可下沉到 service 层。

### 1.3 关键依赖链

**Checklist 核心链** (不可断裂):
```
checklists (@State) → currentChecklist (computed) → items[] → ChecklistView 渲染
                   → checklistRenderNonce (强制刷新)
                   → PackStore.save() (持久化)
```

**Gear↔Checklist 联动链**:
```
GearPage 选择 gear → Index.addGearToChecklist() → 更新 currentChecklist.items
                   → checklistRenderNonce++ → 列表刷新
```

**Category 三事务链** (已事务化):
```
deleteCategory → 更新 categoryList → 更新所有 gear.category → 更新 checklist items
                 (三者必须原子完成，已在上轮修复)
```

**Sheet 双向耦合链** (内化后可断裂):
```
Index @State 代理 ←→ SheetOverlay @Prop 透传 ←→ 具体 Sheet @Prop 使用
(内化后变为): Index 传 sourceData → Sheet 内部 @State 管理 → 保存时回调 onSave(data)
```

---

## 2. GearPage.ets 全景分析 (2292 行 / 30 @State)

### 2.1 交互域分类 (30 @State)

| 域 | @State 数 | 代表变量 | 可拆分? |
|---|----------|---------|--------|
| 单项拖拽状态机 | 7 + 15 private | overlayPhase, dragStartX/Y, menuX/Y, isDragging, dragVelocity... | 否 — §8.2 拖拽坐标系 |
| 分组拖拽 | 5 | groupDragTarget, groupDropIndex | 否 — §8.2 拖拽坐标系 |
| CollapsingHeader | ~4 | headerHeight, collapseProgress, scrollOffset | 是 — 可提取为独立组件 |
| 列表渲染 | ~5 | gearList, groupedGears, sortType | 部分 — 排序/分组可下沉 |
| Fab 状态 | ~2 | isFabExpanded, fabRotation | 是 — 完全独立 |
| Sheet/弹窗控制 | ~4 | isSheetOpen, actionSheetType | 否 — 与 Index.ets sheet 系统联动 |
| 搜索 | ~3 | searchQuery, isSearching | 部分 — 可内化到搜索组件 |

### 2.2 不可拆分区域详解

**单项拖拽状态机 (OverlayPhase: IDLE → MENU → DRAGGING)**:

命中 §8.2 规则：拖拽坐标系 + 动画状态机

涉及变量：overlayPhase, dragStartX, dragStartY, dragCurrentX, dragCurrentY, menuOffsetX, menuOffsetY (7 @State) + dragItem, dragSourceIndex, dragVelocityX, dragVelocityY, lastMoveTimestamp, accumulatedDeltaX, accumulatedDeltaY, dragThreshold, isLongPressTriggered, longPressTimer, hapticFeedbackGiven, overlayWidth, overlayHeight, dragStartTimestamp, gestureStartX, gestureStartY (15 private vars)

这 22 个变量通过手势回调和 animateTo 紧密耦合，拆分后坐标系会断裂导致拖拽位置偏移。

**分组拖拽 (5 @State)**:

groupDragTarget, groupDropIndex, groupDragPhase, groupDragOffsetY, groupDragStartIndex

与单项拖拽共享部分坐标空间，必须在同一组件内。

### 2.3 可安全提取的区域

| 区域 | 行数 | 独立性 | 提取难度 |
|------|------|--------|---------|
| CollapsingHeader | ~200 | 高 — 只依赖 scrollOffset 和 HeadCollapseController | 低 |
| Fab (浮动按钮) | ~50 | 极高 — 只需 isFabExpanded + onClick 回调 | 极低 |
| GearRowCard (单行渲染) | ~300 | 中 — 注意拖拽状态机的部分 @State 需通过 @Prop 传入 | 中 |
| 排序/分组纯函数 | ~120 | 极高 — 无状态依赖 | 极低 |

---

## 3. SheetOverlay 透传问题分析

### 3.1 成员统计

| 类别 | 数量 | SheetOverlay 自身使用? |
|------|------|----------------------|
| @Prop (数据) | 46 | 仅 ~6 个 (isShow, sheetType, title, height, onDismiss 相关) |
| 回调 (callbacks) | 39 | 仅 ~4 个 (onDismiss, onAppear, onDisappear, onHeightChange) |
| **总计** | **85** | **~10 (12%)** |

### 3.2 透传路径

```
Index.ets (定义 85 个参数)
    ↓ 传入
SheetOverlay (接收 85 个, 自用 10 个, 透传 75 个)
    ↓ 根据 sheetType switch
AddGearSheet / AddChecklistSheet / CategorySheet / ... (各自使用 5-15 个)
```

**问题**: SheetOverlay 是纯路由角色，却被迫声明所有子 sheet 的参数。新增一个 sheet 参数需要改 3 个文件 (Index + SheetOverlay + 目标Sheet)。

### 3.3 SheetContainer 替代方案

```
Index.ets (定义 4 个通用参数 + @Builder 内容块)
    ↓
SheetContainer (接收 4 个: isShow/sheetType/title/height + @BuilderParam content)
    ↓ 渲染 content
@Builder 内容块 (在 Index.ets 中定义，直接访问 Index 的 @State)
```

成员减少: 85 → ~8，降幅 93%。

---

## 4. UnifiedChecklistView 不可拆分确认 (1082 行 / 30 vars)

### 4.1 五条 §8.2 规则全命中

| §8.2 规则 | 命中证据 |
|-----------|---------|
| 动画状态机 | 六态交互: IDLE → SELECTING → EDITING → DRAGGING → REORDERING → DELETING |
| geometryTransition 配对 | item 选中时的共享元素过渡，source 和 target 必须在同一 build 树 |
| 拖拽坐标系 | 列表内拖拽重排，坐标映射依赖父组件的 scroll 偏移 |
| @Builder this 丢失 | 多个 @Builder 方法引用 this 的 @State |
| 手势链 | LongPress → PanGesture → 拖拽排序，手势组合不可跨组件边界 |

**结论**: 1082 行整体不可拆分。这是经过调查确认的结论，不是偷懒。

---

## 5. HomePage.ets 分析 (1104 行 / 20 vars)

### 5.1 可拆分区域

| 区域 | 行数 | 说明 |
|------|------|------|
| 纯计算方法 | ~250 | getProgress(), getStats(), formatDate() 等 15 个纯函数 |
| EmptyHero 视图 | ~80 | 空状态引导，无状态依赖 |
| RingProgress 组件 | ~60 | 环形进度条，纯 @Prop 驱动 |
| HistoryRow 组件 | ~50 | 历史记录行 |

### 5.2 不可拆分区域

| 区域 | 行数 | 原因 |
|------|------|------|
| HeroCard 动画状态机 | ~120 | 多个 animateTo 编排 + spring 动画链 |
| 主列表渲染 + 滚动联动 | ~500 | 与 HeroCard 折叠联动，共享 scrollOffset |

---

## 6. ProfilePage.ets 分析 (615 行 / 23 vars)

### 6.1 状态分类

| 类别 | 数量 | 可拆分? |
|------|------|--------|
| 动画状态机 (入场序列) | 18 | 否 — 18 个 @State 控制 6 个区块的错落入场动画 |
| 数据状态 | 2 | 否 — stats 和 timeline 数据 |
| 交互状态 | 3 | 否 — 与动画联动 |

### 6.2 可拆分区域

| 区域 | 行数 | 说明 |
|------|------|------|
| StatCell 渲染 | ~40 | 纯 @Prop 驱动的统计格 |
| Timeline 叙事文本 | ~60 | 纯渲染 |

### 6.3 不可拆分区域

ProfilePage 的 18/20 @State 是动画状态机部分（6 个区块的 opacity + translateY + scale 三元组），它们通过 aboutToAppear 的 staggered animateTo 编排。拆分任一区块会打破错落时序。

---

## 7. TripDetailPage.ets 分析 (528 行 / 17 vars)

### 7.1 可拆分区域

| 区域 | 行数 | 说明 |
|------|------|------|
| SharedInfo 区块 | ~80 | 旅行共享信息展示，边际收益有限 |

### 7.2 不可拆分区域

| 区域 | 行数 | 原因 |
|------|------|------|
| Tabs 编排 + HeadCollapse 联动 | ~400 | HeadCollapseController 驱动的滚动折叠 + Tab 切换联动 |

**结论**: 528 行已在合理范围，拆分优先级最低。

---

## 8. 跨组件影响分析

### 8.1 Index.ets → GearPage.ets 双向耦合

```
Index.ets                          GearPage.ets
├── gears: GearItem[] (@State) ←── 读取展示
├── addGearToChecklist() ←──────── GearPage 调用
├── sheet 系统 ←────────────────── GearPage 触发打开
└── checklistRenderNonce++ ←────── gear 变更后触发
```

拆分 Index 的 gear 相关逻辑到 GearService 后，GearPage 改为调用 GearService，再由 Index 监听变更更新 @State。

### 8.2 checklistRenderNonce 触发点全量清单

| 触发位置 | 场景 | 是否可精确替代 |
|---------|------|--------------|
| addGear | 添加装备后刷新 checklist | 待评估 |
| deleteGear | 删除装备后刷新 | 待评估 |
| toggleItem | 勾选/取消勾选 | 可能 — @Track 标记 item.checked |
| reorderItems | 拖拽排序后刷新 | 待评估 |
| deleteCategory | 分类删除后刷新关联 item | 待评估 |
| renameCategory | 分类重命名后刷新显示 | 待评估 |
| importGears | 批量导入后刷新 | 待评估 |

---

## 9. ArkUI 技术约束备忘

| 约束 | 影响 | 来源 |
|------|------|------|
| @Builder 方法内 this 指向调用者而非定义者 | SheetContainer @BuilderParam 必须在正确的组件内定义 @Builder | MEMORY.md #23 |
| @Prop 对复杂对象是深拷贝 | Service 层返回数据后必须赋值给 @State，不能直接修改 @Prop | MEMORY.md #5 |
| V1 @State 数组元素变更不触发 UI 更新 | 必须替换整个数组引用或使用 nonce，这是 nonce 存在的根因 | MEMORY.md #8 |
| geometryTransition 的 source 和 target 必须在同一 @Component 的 build 中 | UnifiedChecklistView 不可拆分的技术根因 | MEMORY.md #31 |
| 跨组件 animateTo 时序不保证 | ProfilePage 动画编排不可拆分的技术根因 | MEMORY.md #42 |
