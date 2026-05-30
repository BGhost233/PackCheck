# 多选拖拽交互体验全面优化

## 目标
优化装备库的长按、多选、拖拽到行程的完整交互链路，达到 Apple/Linear 级的流畅度和自然感。

## 约束
- ArkTS + ArkUI, API 23+
- 主文件: `entry/src/main/ets/components/GearPage.ets` (~1583行)
- 辅助文件: `entry/src/main/ets/pages/Index.ets`
- 每个阶段改完即 `hvigorw assembleApp` 验证构建
- 每次通过后 git commit

## 阶段总览

| # | 阶段 | 状态 |
|---|------|------|
| 1 | 长按响应速度优化 | complete |
| 2 | 多选模式原地化（消除"跳页感"） | complete |
| 3 | 拖拽跟手性修复 | complete |
| 4 | 底部行程托盘磁吸动效 | complete |
| 5 | 手势返回支持 | complete |
| 6 | 构建验证 + 全量测试 | complete |

---

## 阶段 1：长按响应速度优化

**目标**：缩短从触摸到视觉/触觉反馈的感知时间

**改动点**：

1. **多选模式下** `LongPressGesture` duration: 400ms → 200ms
   - 文件: GearPage.ets 约第1020行
   - `LongPressGesture({ fingers: 1, repeat: false, duration: 200 })`

2. **普通模式下** `bindContextMenu` 无法自定义 duration，但可以：
   - 确认 `onTouch(TouchType.Down)` 的 scale 0.97 反馈是即时的（当前已有）
   - 减小 `GearPreviewCard` 渲染复杂度——去掉不必要的 shadow 嵌套
   - 预计系统 LongPress 约 300~400ms，配合即时 scale 反馈用户体感会更快

**验证标准**：多选模式下长按 200ms 即触发拖拽；普通模式按下即有 scale 缩小反馈

---

## 阶段 2：多选模式原地化（消除"跳页感"）

**目标**：进入/退出多选时，页面布局保持连续，不产生跳感

**改动点**：

1. **保留 CollapsingHeader**（已收缩态），多选时标题变为「已选 N 件」
   - 去掉 `if (!this.multiSelectMode)` 对 CollapsingHeader 的条件隐藏
   - 在 CollapsingHeader 内部加 if/else：multiSelectMode 时显示选中计数 + 取消/生成按钮，正常时显示原来的标题

2. **GearRow 多选分支：仅渐入 Checkbox**，不改变卡片整体布局
   - 保留 category bar、name、weight 的排列
   - 在 category bar 左侧动画滑入 Checkbox（translateX -24→0 + opacity 0→1）
   - 保留展开箭头（但多选时不响应展开）

3. **MultiSelectBar 移除**（功能合并进 CollapsingHeader）
   - 原来的「选中 N 件」+「生成清单」+「取消」移入 Header 收缩区域

4. **进入/退出 animateTo 过渡**
   - `enterGearMultiSelect` 中用 `animateTo({ duration: 300, curve: springMotion(0.35, 0.8) })` 包裹 state 切换
   - List 顶部 spacer 高度从 `GEAR_HEADER_EXPANDED` 平滑过渡到 `GEAR_HEADER_COLLAPSED`（多选时 header 固定为收缩态）

**验证标准**：进入/退出多选无跳感，Header 始终可见，Checkbox 有入场动画

---

## 阶段 3：拖拽跟手性修复

**目标**：浮动装备堆精确跟随手指，无延迟、无偏移

**改动点**：

1. **去掉多余的 `px2vp` 转换**
   - ArkUI 手势事件的 `fingerList[].globalX/Y` 已经是 vp 单位
   - `enterDragMode` 和 `updateDragPosition` 中去掉 `px2vp()` 调用
   - 即：`this.enterDragMode(event.fingerList[0].globalX, event.fingerList[0].globalY)`

2. **DragGearStack 位置计算修正**
   - 当前：`.position({ x: this.dragX - 70, y: this.dragY - 50 })`（硬编码偏移）
   - 改为：在 `enterDragMode` 时记录初始触摸点相对浮层中心的偏移 `dragOffsetX/Y`
   - 后续：`.position({ x: this.dragX - dragOffsetX, y: this.dragY - dragOffsetY })`
   - 浮层宽 140、高 44，默认 offsetX=70, offsetY=22（中心点），但实际应该让卡片偏上一点避免手指遮挡：offsetY = -10（卡片在手指上方）

3. **opacity 过渡动画**
   - 被选中的卡片在进入 dragMode 时 opacity 变 0.4，加 `.animation({ duration: 200 })` 过渡
   - 当前代码已有 `.animation({ duration: 260, curve: springMotion(...) })`，确认 opacity 变化也在此动画范围内

4. **消除角标闪烁**
   - `DragGearStack` 中的 `×N` badge：确保 `selectedMultiGearIds.length` 在拖拽过程中不变
   - 目前逻辑中拖拽过程不会 toggle selection，应该是安全的
   - 如果仍有闪烁，改为缓存 `dragGearCount` state 在 enterDragMode 时固定

5. **LongPress duration 缩短到 200ms**（同阶段1）

**验证标准**：拖拽卡片完全在手指上方跟随移动，无延迟，无闪烁

---

## 阶段 4：底部行程托盘磁吸动效

**目标**：macOS Dock 风格的距离感应放大 + 拖入确认反馈

**改动点**：

1. **新增 state：`dragDistances: number[]`**
   - 或更简单：计算每个 TripCard 的 scale/translateY 基于 `dragX` 与卡片中心的距离

2. **TripCard scale 基于距离计算**
   - `updateDragPosition` 中，对每个 `tripCardAreas` 计算：
     ```
     dx = |dragX - (area.x + area.w/2)|
     dy = |dragY - (area.y + area.h/2)|
     distance = sqrt(dx² + dy²)
     proximity = max(0, 1 - distance / 150)  // 150vp 为影响半径
     scale = 1 + 0.12 * proximity
     translateY = -8 * proximity  // 向上涌起
     ```
   - 需要新增 `@State private tripCardScales: number[]` 或直接在 TripCard 中根据 dragX/dragY 实时计算

3. **TripCard translateY 涌起效果**
   - 离手指越近的卡片向上偏移越多（最大 -8vp）
   - 配合 `.animation({ duration: 120, curve: Curve.EaseOut })` 平滑过渡

4. **命中时的吸入确认**
   - 松手且命中目标时：
     - 命中卡片 scale 1.1 → 0.95 → 1.0 弹跳
     - 背景色闪绿色脉冲
     - 振动反馈 `{ type: 'time', duration: 25 }`
   - `completeDrag` 中加入动画序列

5. **新建卡片呼吸脉动**
   - 未被命中时，虚线边框 opacity 做 0.6 → 1.0 → 0.6 循环动画（仅在 dragMode 激活时）
   - 或者简单点：dragMode 时虚线加 scale 微脉动 1.0 → 1.02 → 1.0

6. **托盘整体视觉优化**
   - 增加顶部一条细线 drag indicator（capsule shape，宽 40vp，高 4vp，居中）
   - 背景毛玻璃增强：`#F0FFFFFF` → `#E8FFFFFF`，backdropBlur 30 → 40

**验证标准**：拖拽靠近底部时卡片有磁吸放大效果，松手命中有弹跳确认，视觉丝滑

---

## 阶段 5：手势返回支持

**目标**：多选模式下支持系统返回手势（侧滑/返回键）退出多选

**改动点**：

1. **在 Index.ets 的 NavDestination 中处理**
   - 当前页面是装备库 Tab（应该在主 Navigation 内）
   - 在 `onBackPressed` 回调中：如果 `multiSelectMode === true`，执行 `cancelGearMultiSelect()` 并 return true（拦截）

2. **备选方案：GearPage 内自行处理**
   - 如果 GearPage 不在 NavDestination 中，需要在 GearPage 外层或 Index 中监听
   - 查看 Index.ets 是否有 Navigation + NavDestination 结构

3. **右滑手势兼容**（如果系统返回不可用）
   - 在 GearPage 根 Stack 上加 `SwipeGesture({ direction: SwipeDirection.Horizontal })` 
   - 右滑速度 > 100vp/s 时触发退出多选
   - 注意：不能和 List 滚动冲突（SwipeGesture 是全局的，但方向是水平所以不冲突）

**验证标准**：多选模式下侧滑/返回键可退出多选，不影响正常页面导航

---

## 阶段 6：构建验证 + 全量测试

**目标**：确保所有改动不引入回归

**检查项**：
- [ ] `hvigorw assembleApp` 通过
- [ ] 普通模式：长按弹出预览 + Context Menu 正常
- [ ] 多选模式进入/退出：无跳感，Header 保持
- [ ] 多选 + 长按 → 拖拽：跟手、无闪烁
- [ ] 拖入行程卡片：磁吸放大 + 释放确认
- [ ] 拖入新建卡片：正常触发
- [ ] 手势返回：退出多选
- [ ] 折叠屏/分屏：FAB 和托盘位置自适应

---

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| (待记录) | | |

## 技术备注

- `fingerList[].globalX/Y` 在 ArkUI 中是 **vp 单位**，不需要 px2vp
- `bindContextMenu` 的 LongPress duration 不可自定义，由系统控制
- Spring 动画忽略 duration 参数，时间由 response 决定
- `@State` 数组变化会触发整个引用该数组的组件树重新渲染——磁吸 scale 需要精细控制避免性能问题
