# 研究发现

## 现有代码结构

### TripDetailPage NavBar 现状
- 三元素 Row：左返回(40×40) + 中标题(layoutWeight 1) + 右核查按钮(40×40)
- 标题字号随 headCollapseProgress 呼吸：展开 20fp + 下沉 4vp → 折叠 17fp + 归位 0vp
- 曲线三级分离：聚焦态 SPRING_HERO_EXPAND / 吸附态 SPRING_SCROLL / 跟手态 SPRING_HEAD_FOLLOW
- NavBar 总高度 = statusBarHeight + 40vp

### 首页 Tab 切换（参考实现）
- HdsTabs + 自定义 .onTouch() 计算滑动 progress
- `tabSwipeProgress` 范围 [-1, 1]，驱动 `tabVisualWeight(index)` 连续值
- 视觉权重驱动：icon/文字颜色、字重、底部横条宽/透明度、整体 scale/opacity
- 点击切换有「呼吸脉冲」微交互（scale 0.97 下压 + Spring 弹回）
- 内容 contentScale 随滑动深度 1.0→0.97

### 手风琴模式（GearPage expandedGearId）
- `@State expandedGearId: string = ''`
- `toggleGearExpanded(id)` 互斥逻辑：相同 id 收起，不同 id 展开新的
- 配合 `animateTo(SPRING_GENERAL)` + `.transition()` 实现展开/收起动画

### 现有 Typography token
- Title Medium: 20fp / Medium (500) — 适合 NavBar 激活标题
- Body Medium: 14fp / Regular (400) — 适合 NavBar 非激活标题
- 中间没有 token（17fp 是硬编码折叠计算值）

### HeadCollapseController 机制
- TripDetailPage 用 inline 塌缩范式（head 是滚动兄弟节点）
- NavBar 标题参与呼吸：字号 20→17 + 下沉 4→0
- progress 由 UnifiedChecklistView 内 Grid.onScroll 驱动

## 技术可行性评估

### PanGesture 水平 + 垂直共存
- 避坑 #26：PanGesture distance ≥ 5 防吃 onClick
- 方向锁定：首次 move 确定主方向后锁定，避免对角滑动时两个方向同时响应
- List 垂直滚动与外层水平 Pan 需要方向互斥——参考 SwipeGesture(Horizontal) 与垂直 List 不冲突的验证结论（MEMORY 补充验证）

### 条件渲染 + 转场动画
- 避坑 #27：`if/else` 条件渲染动画需 `animateTo` 包裹 state 赋值 + 组件加 `.transition()`
- 两个 Tab 内容可以用 `if (tripTabIndex === 0)` / `if (tripTabIndex === 1)` 切换
- 滑动期间需要双内容并存（translateX 滑动）——此时不能用 if/else，需用 opacity + translateX 控制

### NavBar 双标题字号插值
- ArkUI Text.fontSize() 接受 number，可以用 `14 + 6 * weight` 连续插值
- 字重不支持连续插值，只能在阈值处离散切换
- 颜色插值：可通过 opacity 实现（两个 Text 各自 opacity 0.4~1.0 范围切换）

## 潜在陷阱

1. **滑动期间双内容并存 vs if/else 条件渲染的矛盾**：
   - 滑动中必须双内容可见（translateX 并排滑动），不能用 if/else
   - 但常驻两个重组件（UnifiedChecklistView 尤其重）内存压力大
   - 解法：默认只渲染当前 Tab（if/else），手势 Down 时切为"双渲染"模式，手势 End 后 300ms 延迟销毁非活跃内容

2. **NavBar 标题宽度随字号变化导致布局跳动**：
   - 解法方向：两个 Text 用 `width('auto')` + 外层 Row `justifyContent(Center)`，或给每个 Text 一个 `constraintSize({ minWidth })` 防止过窄时挤压

3. **HeadCollapseController 与 Tab 内容的关系**：
   - 切换到行程 Tab 后，ItineraryView 也需要驱动折叠——需将 onScroll 挂到 ItineraryView 的 List 上
   - 或者：切换 Tab 时不重置折叠状态，两个 Tab 共享同一 progress
