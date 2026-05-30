# 研究发现

## ArkUI 手势事件坐标单位

- `GestureEvent.fingerList[].globalX/Y`: **vp 单位**（全局坐标）
- `GestureEvent.offsetX/Y`: **vp 单位**（相对初始点增量）
- `TouchEvent.touches[].x/y`: **vp 单位**（相对组件）
- `TouchEvent.touches[].windowX/windowY`: **vp 单位**（相对窗口）
- 结论：ArkUI 中所有手势/触摸坐标已经是 vp，**不需要 px2vp 转换**

## bindContextMenu 限制

- `ResponseType.LongPress` 的触发时长由系统控制，无 API 可调
- 系统默认约 300~500ms
- Preview 渲染复杂度影响感知延迟
- 无法自定义 duration，只能通过即时反馈（scale/opacity）减少感知延迟

## 磁吸动效性能考量

- `@State` 数组每次修改触发所有引用组件重新 build
- 方案 A：每个 TripCard 独立 @State scale（需要固定数量）
- 方案 B：在 TripCard builder 中实时计算 scale（基于 dragX/dragY state）
  - 每次 dragX/Y 变化会触发所有 TripCard 重新 build（因为引用了 this.dragX）
  - 卡片数量有限（≤10+1），性能可接受
- **结论：采用方案 B，直接在 TripCard 中计算**

## 多选模式布局分析

- 当前 `multiSelectMode` 隐藏 CollapsingHeader + FAB
- 顶部 spacer 从 GEAR_HEADER_EXPANDED 变为 8（硬跳）
- MultiSelectBar 替代 Header 但高度仅 ~44vp（vs GEAR_HEADER_COLLAPSED ~56vp）
- 优化方向：Header 保持收缩态，内容换为多选控件
