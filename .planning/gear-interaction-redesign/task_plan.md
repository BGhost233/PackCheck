# 装备库交互重构 — 点击精简 + 多选拖拽到行程

## 目标
1. **议题 A**：点击展开只保留信息展示，移除编辑/删除按钮（操作统一收拢到长按 Context Menu）
2. **议题 B**：多选模式下长按已选装备触发拖拽，屏幕底部弹出行程托盘，拖入即添加

## 涉及文件
- `entry/src/main/ets/components/GearPage.ets` — 主列表/拖拽逻辑
- `entry/src/main/ets/pages/Index.ets` — 多选回调/行程数据桥接
- `entry/src/main/ets/models/PackModels.ets` — 数据模型（无需改动）
- 可能新增：`entry/src/main/ets/components/TripDropTray.ets` — 行程托盘组件

---

## 可行性分析

### 技术可行性

| 能力需求 | ArkUI API | API 23 支持 | 备注 |
|---------|-----------|------------|------|
| 多选后长按拖动 | PanGesture + LongPressGesture(组合) | ✅ | FAB 已验证 PanGesture 可行 |
| 装备堆跟随手指 | @State + .position({ x, y }) | ✅ | 同 FAB 实现 |
| 底部托盘弹出 | animateTo + translateY | ✅ | 同 FilterPanel |
| 背景模糊+压暗 | .backdropBlur() + opacity | ✅ | 已在项目中使用 |
| 拖入检测(hitTest) | 手动计算手指坐标与目标区域碰撞 | ✅ | 无需系统 onDrop API |
| 振动反馈 | vibrator.startVibration | ✅ | 已在项目中使用 |
| 行程数据访问 | 通过 @Prop/回调从 Index 传入 | ✅ | 现有模式 |

### 核心技术方案

**不使用系统 onDragStart/onDrop API**（兼容性差，动画不可控），而是用 **PanGesture + 手动坐标计算** 实现完全自定义的拖拽体验。

**拖拽坐标碰撞检测**：
- 托盘中每个行程卡片记录其 position + size（通过 onAreaChange）
- PanGesture.onActionUpdate 中实时计算手指坐标是否落入某卡片区域
- 命中时该卡片高亮+放大，离开时恢复

**多选模式下长按切换**：
- 当 `multiSelectMode = true` 且点击的装备已被选中时，长按不再弹 Context Menu
- 改为触发拖拽态（LongPressGesture → PanGesture 的组合手势 GestureGroup(Sequential)）

### 风险评估

| 风险 | 等级 | 缓解方案 |
|------|------|---------|
| PanGesture 与 List 滚动冲突 | 中 | 拖拽态下禁止 List 滚动(.scrollEnabled(false)) |
| 手势组合(LongPress→Pan)时序 | 中 | 用 GestureGroup(GestureMode.Sequence) 保证先长按后拖 |
| 坐标系对齐（列表滚动偏移） | 低 | 用全局坐标(componentUtils 或 onAreaChange 记录的 globalPosition) |
| 托盘内行程过多 | 低 | 横向滚动 Scroll，最多显示最近 10 个行程 |

---

## Phase 1: 议题 A — Detail 移除操作按钮 — `pending`

### 1.1 GearPage.ets: Detail Builder 移除编辑+删除按钮
- 删除 Detail 中的 `Row { Button('编辑') ... Button('删除') ... }` 整个 Row
- 保留信息行（分组/重量/价格/备注/添加时间/出行次数）

### 1.2 验证
- 点击展开只显示信息
- 长按 Context Menu 仍可编辑/删除
- 左滑删除仍正常

### 预期效果
- Detail 区域更轻量纯净，纯粹作为信息预览
- 操作入口统一在长按 Context Menu

---

## Phase 2: 拖拽态状态管理 — `pending`

### 2.1 GearPage 新增 State
```typescript
@State private dragMode: boolean = false;           // 是否处于拖拽态
@State private dragX: number = 0;                   // 装备堆跟随手指 X
@State private dragY: number = 0;                   // 装备堆跟随手指 Y
@State private dragOverTripId: string = '';          // 当前悬停的行程 ID
@State private showTripTray: boolean = false;       // 行程托盘是否展示
```

### 2.2 新增 Prop（从 Index 传入）
```typescript
@Prop checklists: TripChecklist[] = [];             // 已有行程列表
```

### 2.3 新增回调
```typescript
onAddGearsToTrip: (gearIds: string[], tripId: string) => void = () => {};
onAddGearsToNewTrip: (gearIds: string[]) => void = () => {};
```

---

## Phase 3: 多选模式下的手势切换 — `pending`

### 3.1 GearRow 手势逻辑分支
- `multiSelectMode = false`：保持 bindContextMenu（长按弹菜单）
- `multiSelectMode = true` 且装备已选中：绑定 GestureGroup(Sequence, LongPress → Pan)
- `multiSelectMode = true` 且装备未选中：onClick toggle selection（保持现有）

### 3.2 LongPress → Pan 组合手势
```typescript
GestureGroup(GestureMode.Sequence,
  LongPressGesture({ duration: 300 })
    .onAction(() => { this.enterDragMode(); }),
  PanGesture({ fingers: 1, distance: 0 })
    .onActionUpdate((event) => { this.updateDragPosition(event); })
    .onActionEnd(() => { this.completeDrag(); })
)
```

### 3.3 enterDragMode()
1. `this.dragMode = true`
2. 记录初始手指位置
3. `vibrator.startVibration({ type: 'time', duration: 30 })` — 触觉确认
4. animateTo 弹出底部行程托盘 (`showTripTray = true`)
5. 背景模糊+压暗动画

### 3.4 updateDragPosition(event)
1. 更新 dragX/dragY（手指位置）
2. 碰撞检测：遍历行程卡片区域，找到命中的 tripId
3. 如果 dragOverTripId 变了 → 振动反馈 + 目标卡片高亮动画

### 3.5 completeDrag()
1. 如果 `dragOverTripId` 非空 → 调用 `onAddGearsToTrip(selectedIds, tripId)`
2. 如果拖到「新建行程」区域 → 调用 `onAddGearsToNewTrip(selectedIds)`
3. 退出拖拽态：animateTo 恢复背景、收起托盘、清空选中
4. 如果没有命中任何目标 → 取消拖拽，装备堆弹回原位

---

## Phase 4: 行程托盘 UI (TripDropTray) — `pending`

### 4.1 组件设计
- 从屏幕底部弹出，高度约 180vp
- 毛玻璃背景 + 圆角顶部 (borderRadius topLeft/topRight: 20)
- 标题行：「拖入行程」+ 行程数量
- 横向 Scroll：行程卡片列表 + 末尾「+ 新建行程」卡片

### 4.2 行程卡片
- 宽度 120vp，高度 100vp
- 显示：行程名称 + 日期 + 已有装备数量
- 正常态：白色卡片 + 轻阴影
- 悬停态（dragOverTripId 命中）：scale 1.08 + 主题色边框 + 阴影加深

### 4.3 「+ 新建行程」卡片
- 虚线边框 + 加号图标
- 悬停态：虚线变实线 + 主题色填充

### 4.4 碰撞区域记录
- 每个卡片通过 .onAreaChange 记录 globalPosition + size
- 存到数组 `tripCardAreas: { id: string, x: number, y: number, w: number, h: number }[]`

---

## Phase 5: 拖拽时的装备堆视觉 — `pending`

### 5.1 浮动装备堆组件
- 跟随手指的小卡片（position absolute, 跟随 dragX/dragY）
- 显示第一个装备名称 + 右上角数量徽章（如 "×3"）
- 半透明 + 圆角 12 + 阴影 + 轻微旋转（-3°）增加动感
- 宽度约 140vp

### 5.2 进入拖拽态动画
- 原始装备行 opacity → 0.3（表示「被拎起来了」）
- 装备堆从原始位置 spring 弹到手指位置
- 背景 backdropBlur(20) + opacity(0.4) 遮罩渐入

### 5.3 完成/取消时动画
- 命中目标：装备堆 spring 飞入目标卡片 → scale 缩小消失
- 未命中：装备堆 spring 弹回原位 → 透明度恢复

---

## Phase 6: Index.ets 桥接逻辑 — `pending`

### 6.1 传入行程列表
- GearPage 新增 `@Prop checklists: TripChecklist[]`
- Index 在渲染 GearPage 时传入 `this.checklists`

### 6.2 onAddGearsToTrip 实现
```
1. 找到目标 checklist
2. 将选中的 gearIds 转为 ChecklistItem[]（同 generateChecklistFromSelectedGears 逻辑）
3. 追加到 checklist.items
4. 持久化
5. incrementGearTripCounts
6. toast 提示 "已添加 N 件到 XXX"
7. 退出多选模式
```

### 6.3 onAddGearsToNewTrip 实现
```
1. 预填 selectedMultiGearIds
2. 打开 GenerateTripSheet（复用现有流程）
```

---

## Phase 7: 构建验证 + Git Commit — `pending`

### 7.1 hvigorw assembleApp 通过
### 7.2 功能回归清单
- [ ] 点击装备展开只显示信息，无操作按钮
- [ ] 长按 Context Menu 编辑/多选/删除正常
- [ ] 多选模式：选中装备后长按开始拖拽
- [ ] 拖拽时背景模糊 + 底部托盘弹出
- [ ] 装备堆跟随手指
- [ ] 拖入已有行程 → 添加成功
- [ ] 拖入新建行程 → 弹出 Sheet
- [ ] 未命中任何目标 → 取消返回
- [ ] 普通点击、搜索、排序不受影响

---

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （待填充） | | |

---

## 执行顺序与依赖关系
```
Phase 1 (独立，无依赖)
  ↓
Phase 2 (状态定义，Phase 3-6 的前置)
  ↓
Phase 3 (手势逻辑，依赖 Phase 2)
  ↓
Phase 4 (托盘 UI，依赖 Phase 2)
  ↓
Phase 5 (浮动视觉，依赖 Phase 2+3)
  ↓
Phase 6 (数据桥接，依赖 Phase 2+4)
  ↓
Phase 7 (验证，依赖全部)
```

Phase 1 可以立即执行。Phase 3/4/5 之间有部分并行可能但为安全起见顺序执行。
