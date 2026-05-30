# 装备库弹性回弹 + 分组拖拽排序 实施计划

## 目标
1. 内容不满屏时 List 也有弹性回弹
2. 长按分组 header 拖拽调整分组顺序

## 约束
- ArkTS + ArkUI, API 23+
- 主文件: GearPage.ets (~1860行)
- 辅助文件: PackStore.ets
- 每阶段改完即验证 lint
- 完成后 git commit

## 阶段

| # | 阶段 | 状态 |
|---|------|------|
| 1 | 弹性回弹 1 行改动 | ✅ done |
| 2 | PackStore +categoryOrder 持久化 | ✅ done |
| 3 | 排序逻辑按 categoryOrder | ✅ done |
| 4 | 分组拖拽完整交互 | ✅ done |
| 5 | 分组 header 按压反馈 | ✅ done |
| 6 | 构建验证 + commit | ✅ done |

---

## 阶段 1：弹性回弹

**文件**: GearPage.ets 第 661 行
**改动**: `.edgeEffect(EdgeEffect.Spring)` → `.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })`

---

## 阶段 2：PackStore categoryOrder

**文件**: PackStore.ets

新增:
```
const KEY_CATEGORY_ORDER = 'packcheck_category_order';

async getCategoryOrder(): Promise<string[]>
async saveCategoryOrder(order: string[]): Promise<void>
```

---

## 阶段 3：排序逻辑

**文件**: GearPage.ets

1. 新增 `@State private categoryOrder: string[] = []`
2. `aboutToAppear` 中加载 `store.getCategoryOrder()`
3. `sortedGears()` GROUP 模式：按 categoryOrder index 排序（不在数组中的 fallback 到末尾 + localeCompare）
4. `filteredGearGroups()`: 输出顺序也遵循 categoryOrder

---

## 阶段 4：分组拖拽交互

**文件**: GearPage.ets

### 4.1 新增 State
```
@State private groupDragMode: boolean = false;
@State private groupDragGroup: string = '';
@State private groupDragY: number = 0;
@State private groupDragOffsetY: number = 0;
@State private groupReorderList: string[] = []; // 拖拽过程中的实时顺序
private groupCardHeights: Map<string, number> = new Map();
```

### 4.2 GearGroupCard 加 onAreaChange 记录高度

### 4.3 分组 header 加 LongPressGesture(300ms) + PanGesture
- 条件: gearSortMode === GEAR_SORT_GROUP && !multiSelectMode && !searchExpanded
- LongPress onAction: 记录初始位置、设 groupDragMode=true、haptic
- Pan onActionUpdate: 更新 groupDragY、碰撞检测→让位
- Pan onActionEnd: 归位动画 + 持久化

### 4.4 List 滚动锁定
- `.enableScrollInteraction(!this.groupDragMode)`

### 4.5 渲染逻辑
- ForEach 用 groupReorderList（拖拽中）或 filteredGearGroups()（正常）
- 被拖分组: 通过独立浮动层渲染（Stack 中 position 跟手）
- 其余分组: opacity + translateY 让位动画

### 4.6 碰撞检测
- 计算浮动分组中心 Y
- 遍历 groupReorderList 中其他分组的累积 Y + height/2
- 越过中线则 splice reorder

### 4.7 松手归位
- animateTo spring 将浮动分组归位
- 持久化 saveCategoryOrder
- 恢复所有视觉状态

---

## 阶段 5：分组 header 按压反馈

- 新增 `@State private pressedGroupId: string = ''`
- header Row 加 .onTouch 切换 pressedGroupId
- scale(pressedGroupId === group ? 0.97 : 1.0) + spring animation

---

## 阶段 6：验证

- lint 检查
- 功能检查清单:
  - [ ] 1-2 件装备（不满屏）上下拖有回弹
  - [ ] 满屏正常回弹不变
  - [ ] 分组模式长按 header 可拖拽
  - [ ] 拖动越过相邻分组会让位
  - [ ] 松手归位 + 持久化
  - [ ] 非分组模式下长按无反应
  - [ ] 多选模式下长按无反应
  - [ ] 短按仍能折叠/展开分组
