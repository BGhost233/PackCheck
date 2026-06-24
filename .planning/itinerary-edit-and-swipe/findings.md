# 研究发现

## Tabs 组件 API（HarmonyOS 离线文档）

- `Tabs(options?: TabsOptions)` 支持 `index` 属性双向绑定（`$$this.tripTabIndex`，API 10+）
- `scrollable(true)` 默认开启，原生支持左右滑动切换内容页
- `.barHeight(0)` 隐藏内置 TabBar（我们用自定义 NavBar 标题做 Tab 指示）
- `onGestureSwipe(index: number, event: TabsAnimationEvent)` — 逐帧回调，`event.currentOffset` 为当前偏移量（vp），可据此算 swipeRatio 做字号/颜色插值
- `onAnimationStart(index: number, targetIndex: number, event: TabsAnimationEvent)` — 手势释放后动画开始时触发
- `onChange(index: number)` — 动画完成后触发
- `animationDuration(ms)` — 翻页动画时长。滑动翻页默认用 `interpolatingSpring(-1, 1, 228, 30)`，设置此值后改为 bezier 曲线+指定时长
- `loop(false)` — 不循环
- Tabs 与子组件内的 Scroll/List 嵌套兼容（垂直滚动不冲突水平 Tab 切换）

## 关键注意点

- Tabs 的 `onGestureSwipe` 只在用户手指拖拽期间逐帧触发；松手后的惯性动画期间**不触发**
- 松手后标题字号/颜色的"归位"动画需要在 `onAnimationStart` 中用 animateTo 驱动 tripTabProgress → 目标值
- `event.currentOffset`：正值=向右偏移（往 index-1 方向），负值=向左偏移（往 index+1 方向）
- 需要获取 Tabs 组件宽度来计算 ratio：通过 `.onAreaChange` 缓存 tabsWidth

## 持久化链路（已有）

- `TripChecklist.itinerary?: DayItinerary[]` 已定义
- `PackStore.saveChecklists()` 序列化 JSON，自动包含 itinerary 字段
- Index.ets 通过 `applyChecklistState(nextChecklists)` + `store.saveChecklists(nextChecklists)` 统一持久化
- 编辑 itinerary 只需：构造 nextChecklists（带更新后的 itinerary）→ 调用上述链路

## DayCard 当前架构

- DayCard 是纯展示组件（@Prop day + isExpanded + onToggle 回调）
- 展开态已有时间线 UI（buildSegmentRow），添加编辑入口只需在现有节点上加 onClick
- 收缩态 onClick 当前只触发 onToggle（折叠/展开），长按菜单需要新增 LongPressGesture

## SPRING_TAB 现有参数

- response: 0.40, dampingFraction: 0.75
- 体感：偏慢有弹性，适合休闲浏览但不适合频繁切换
- 目标：response: 0.32, dampingFraction: 0.82（快到位、微弹、克制）
