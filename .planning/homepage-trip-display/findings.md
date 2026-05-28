# 调研发现（第二轮）

## Bug 根因：@Builder 参数值快照

ArkTS `@Builder` 的参数是值传递快照。`TripListSection(trips)` 中 ForEach 绑定的是调用时刻的数组副本，后续 `@Prop checklists` 变化不触发该 Builder 重渲染。

修复：ForEach 直接写在 HistoryTimeline 内部，通过 `this.futureTrips()` / `this.pastTrips()` 访问组件实例，ArkUI 依赖追踪正常工作。

## List 内多段 ForEach 可行性

ArkUI List 支持：多个 ForEach（独立数据源）+ 独立 ListItem + if/else 条件渲染。渲染顺序即声明顺序。Header ListItem 不加 swipeAction/onClick 即可。

## 高度计算

Header ListItem 高度 28vp。Trip row 高度 72vp。
总高度 = `checklists.length * 72 + (hasBoth ? 56 : 0)`

## 颜色选择

| 天数 | 优化后颜色 |
|------|-----------|
| >3天 | PRIMARY_COLOR 绿 |
| 1~3天 | COUNTDOWN_ORANGE 暖橙 (#FF8C42) |
| 今天 | PRIMARY_COLOR 绿 + Bold |
| 已过/待定 | TEXT_TERTIARY 灰 |
