# 装备库弹性回弹 & 分组拖拽排序 设计规格

## 概述

两个独立优化，目标是让装备库页面更「灵动有生命力」：

1. 内容不满屏时也有弹性回弹（消除死板感）
2. 长按分组直接拖拽调整顺序（用户自定义分组排列）

---

## 功能 1：内容不满屏弹性回弹

### 问题

ArkUI `EdgeEffect.Spring` 默认只在内容溢出时生效。装备很少时上下拖没有任何视觉反馈，感觉死板。

### 方案

使用 `alwaysEnabled` 参数（API 12+）：

```typescript
.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
```

这让 List 即使内容不满屏也能触发 rubber band 弹性拉伸，行为与 iOS `UIScrollView.alwaysBounceVertical = true` 一致。

### 改动范围

- 文件：`GearPage.ets` 第 661 行
- 改动量：1 行

### 验证标准

- 装备库仅有 1~2 件装备（不满屏）时，上下拖有弹性回弹
- 满屏时行为不变（跟之前一样的 Spring 回弹）
- 折叠 Header 的 `onDidScroll` 不受影响

---

## 功能 2：分组长按拖拽排序

### 前提条件

仅在 `gearSortMode === GEAR_SORT_GROUP`（按分组）时启用。其他排序模式下分组无意义，不响应长按拖拽。

### 数据层设计

**新增持久化字段**：`categoryOrder: string[]`

- Key：`packcheck_category_order`
- 含义：用户自定义的分组显示顺序
- 空数组 = 未自定义，fallback 到 `localeCompare` 字母序
- 新分类（不在数组中的）自动追加到末尾

**PackStore 新增方法**：

```typescript
async getCategoryOrder(): Promise<string[]>
async saveCategoryOrder(order: string[]): Promise<void>
```

### 排序逻辑变更

`sortedGears()` 中 GROUP 模式的分组间排序（第 308 行）：

```typescript
// 旧: return left.category.localeCompare(right.category);
// 新: 按 categoryOrder index 排序
const leftIdx = this.categoryOrder.indexOf(left.category);
const rightIdx = this.categoryOrder.indexOf(right.category);
const li = leftIdx >= 0 ? leftIdx : 9999;
const ri = rightIdx >= 0 ? rightIdx : 9999;
if (li !== ri) return li - ri;
return left.category.localeCompare(right.category); // 同 index fallback
```

同步修改 `filteredGearGroups()` 使其输出顺序也遵循 `categoryOrder`。

### 交互设计

#### 触发

- 长按分组 header Row（28vp 区域）> 300ms
- 触发条件：`gearSortMode === GEAR_SORT_GROUP` && `!multiSelectMode` && `!searchExpanded`
- 短按（<300ms）仍触发折叠/展开，不受影响

#### 进入拖拽态

- 被拖分组整体（GearGroupCard = header + 卡片）浮起
- 视觉效果：scale(1.03) + shadow(radius: 24, offsetY: 8) + rotate(-1°) + zIndex 提升
- 其余分组：opacity 0.6 暗淡
- 触觉反馈：`vibrator.startVibration({ type: 'preset', preset: 'haptic.effect.soft' })`
- 原位置留出同高度空白占位（避免列表跳动）

#### 拖动中

- 浮动分组 `.position()` 跟手，`.animation({ duration: 0 })` 消除插值
- 碰撞检测：浮动分组中心 Y 越过相邻分组的中线时，触发让位
- 让位动画：目标分组 translateY ± (被拖分组高度 + 16) ，spring(0.35, 0.8)
- 让位时更新内存中的 order 数组（实时反映最终排列），但不立即持久化

#### List 滚动锁定

- 进入分组拖拽态时：`.enableScrollInteraction(false)` 禁止 List 滚动
- 退出时恢复 `.enableScrollInteraction(true)`
- 原因：拖分组的手指位移会被 List 捕获为滚动，导致冲突

#### 松手归位

- 浮动分组 spring 归位到新计算位置：springMotion(0.35, 0.8)
- scale/rotate/shadow 恢复
- 其余分组 opacity 恢复 1.0
- 振动确认：`haptic.clock.timer`
- 持久化 `saveCategoryOrder(newOrder)`

#### 手势冲突分析

| 手势 | 区域 | 条件 | 冲突 |
|------|------|------|------|
| 分组拖拽 LongPress | 分组 header 28vp | sortMode=group, 非多选 | 无 |
| 装备多选拖拽 LongPress | 装备卡片区域 | multiSelectMode | 区域不重叠 |
| 分组折叠 onClick | 分组 header 28vp | 短按 | LongPress 不触发 onClick |
| List 垂直滚动 | 整个 List | 总是 | 长按 300ms 才触发，不干扰正常滑动 |

### GearPage 新增 State

```typescript
@State private groupDragMode: boolean = false;
@State private groupDragId: string = ''; // 被拖分组名称
@State private groupDragY: number = 0;   // 浮动分组 Y 坐标
@State private groupDragStartY: number = 0; // 长按起始 Y
@State private groupDragOffsetY: number = 0; // 手指相对分组顶部偏移
@State private categoryOrder: string[] = []; // 从 PackStore 加载
private groupCardAreas: Array<{ group: string; y: number; h: number }> = [];
```

### 视觉细节

- 浮动分组底部投影：`#28000000` radius 24, offsetY 8（比卡片常态深）
- 暗淡分组：opacity 0.6 + `.animation({ duration: 200, curve: Curve.EaseOut })`
- 归位后涟漪：相邻分组 scale 1→1.01→1（200ms spring），暗示重排完成
- 空占位区域：虚线边框 `#E0E0E0` + borderRadius 14，跟分组卡片同等大小

### 额外增强：分组 header 按压反馈

所有分组 header Row 新增按压态：

```typescript
.scale({ x: this.pressedGroupId === group ? 0.97 : 1.0, y: ... })
.animation({ duration: 200, curve: curves.springMotion(0.25, 0.7) })
```

需要新增 `@State private pressedGroupId: string = ''`，在 `onTouch(TouchType.Down/Up)` 中切换。

---

## 影响范围

| 文件 | 改动 |
|------|------|
| GearPage.ets | 弹性回弹 1 行 + 分组排序全部交互逻辑 |
| PackStore.ets | +2 方法 (getCategoryOrder / saveCategoryOrder) |
| 可能 Index.ets | 如果 categoryOrder 需要从父组件传入（待定，也可 GearPage 自己管理） |

## 不做的事

- 非 GROUP 排序模式下的分组拖拽
- 多选模式下的分组拖拽
- 分组内部装备的拖拽重排（未来可做，本次不涉及）
- 分组拖拽跨 category 合并（不做）
