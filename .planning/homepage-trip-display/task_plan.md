# 任务计划：首页行程展示 Bug 修复 + 体验优化（第二轮）

**目标**：修复分区渲染导致的列表不刷新/无法删除 Bug，优化状态文字和颜色系统。

---

## 阶段总览

| 阶段 | 内容 | 状态 | 文件 |
|------|------|------|------|
| 1 | 修复 HistoryTimeline 列表不刷新 + 左滑删除失效 | pending | HomePage.ets |
| 2 | 验证 HeroCard 智能选取 | pending | HomePage.ets, Index.ets |
| 3 | 优化 homeStatusText + HeroCard 状态标签 | pending | HomePage.ets |
| 4 | 红色 → 暖橙色 | pending | HomePage.ets |
| 5 | 构建验证 + Commit | pending | — |

---

## 阶段 1：修复 HistoryTimeline

**根因**：`TripListSection(@Builder)` 通过参数传入 `trips` 数组，ArkTS @Builder 参数是值快照不响应式，导致 ForEach 不跟随 `@Prop checklists` 变化刷新。

**方案**：删除 `TripListSection` 和 `SectionHeader` Builder，HistoryTimeline 内直接用单个 List + 内联 ForEach。分区标题做成普通 ListItem。

**结构**：
```
List() {
  if (hasBoth) {
    ListItem() { Text("即将启程") }
  }
  ForEach(this.futureTrips(), (item, index) => {
    ListItem() { HistoryRow(item) }.swipeAction(...).onClick(...)
  }, (item) => item.id)
  
  if (hasBoth) {
    ListItem() { Text("走过的路") }
  }
  ForEach(this.pastTrips(), (item, index) => {
    ListItem() { HistoryRow(item) }.swipeAction(...).onClick(...)
  }, (item) => item.id)
}
.height(checklists.length * 72 + (hasBoth ? 56 : 0))
```

---

## 阶段 2：验证 HeroCard 智能选取

修完阶段 1 后观察：创建两个未来行程（6月25日 + 7月1日），HeroCard 应显示6月25日。如仍有问题，排查 `checklistDateAt` 对第二个行程的返回值。

---

## 阶段 3：优化状态文字

**homeStatusText 改为**：
- 有未来行程 → `"X 个行程待出发"`
- 无未来行程 → `"已完成 X 个行程"`
- 无行程 → `"还没有行程，创建一个吧"`

**HeroCard 右上角状态标签改为**：
- 未来行程（dateAt >= 今天）→ `"准备中"`（橙色 COUNTDOWN_ORANGE）
- 历史行程或无日期 → `"已完成"`（绿色 PRIMARY_COLOR）

---

## 阶段 4：红色 → 暖橙色

将 HistoryRow `rowDateColor` 和 HeroCard 大字颜色中 1~3 天的 `DANGER_COLOR (#E53935)` 替换为 `COUNTDOWN_ORANGE (#FF8C42)`。

---

## 阶段 5：构建验证 + Commit

验收项：
- [ ] 创建多个未来行程，列表全部显示
- [ ] 左滑删除正常
- [ ] HeroCard 显示最近的未来行程
- [ ] 状态文字显示"X 个行程待出发"
- [ ] HeroCard 未来行程"准备中"，历史行程"已完成"
- [ ] 1~3 天颜色为暖橙色
