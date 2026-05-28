# 任务计划：首页行程展示优化

**目标**：修复日期解析 Bug，实现 HeroCard 智能选取，历史行程列表分区，HistoryRow 动态日期文字。

**创建时间**：2026-05-28

---

## 阶段总览

| 阶段 | 内容 | 状态 | 文件 |
|------|------|------|------|
| 1 | 修复 parseTripDateAt 日期解析 Bug | pending | ChecklistService.ets |
| 2 | HeroCard 智能选取逻辑 | pending | HomePage.ets, Index.ets |
| 3 | 去掉"设置出发日期"文字 + 待定改灰色 | pending | HomePage.ets |
| 4 | HistoryTimeline 分区渲染 | pending | HomePage.ets |
| 5 | HistoryRow 动态日期文字 + 三色系统 | pending | HomePage.ets |
| 6 | 构建验证 + Commit | pending | — |

---

## 阶段 1：修复 parseTripDateAt

**问题根因**：`parseTripDateAt` 取 `'月'` 之前的全部字符串作为月份数字。
TripCeremonyCard 存入的格式是 `"2025年6月20日"`，`'月'` 之前是 `"2025年6"`，`Number("2025年6") = NaN`，解析失败返回 undefined，导致倒计时永远显示"待定"。

**修复方案**：在 `parseTripDateAt` 中先检测是否含 `'年'`，有则提取年份并截取年份之后的部分再解析月日；无则用当前年。

**改动位置**：`ChecklistService.ets` 第 72-87 行 `parseTripDateAt` 函数。

**注意**：`HomePage.ets` 中有一份完全相同的私有方法 `parseTripDateAt`（第 211-222 行），也需要同步修复。

---

## 阶段 2：HeroCard 智能选取逻辑

**当前**：`latestChecklist()` 直接返回 `checklists[0]`（按 createdAt 降序排列的第一个）。

**新逻辑**（纯函数，无副作用）：
```
今天0点时间戳 = startOfDay(new Date())

未来行程 = checklists.filter(c => checklistDateAt(c) >= 今天0点)
  → 按 dateAt 升序，取第一个（最近的未来行程）

如果无未来行程：
  有日期历史行程 = checklists.filter(c => checklistDateAt(c) < 今天0点)
    → 按 dateAt 降序，取第一个（最近的历史行程）

如果也没有：
  → 按 createdAt 降序取第一个（无日期行程 fallback）
```

**改动位置**：
- `HomePage.ets` 第 157-162 行 `latestChecklist()` 方法
- `Index.ets` 中同名方法（第 242-247 行）

**注意**：`historyContentHeight()` 依赖 `checklists.length`，分区后需要更新高度计算（阶段 4 处理）。

---

## 阶段 3：HeroCard 文案 & 颜色修复

**改动 1**：`countdownSuffix()` 中 `days === undefined` 时返回 `''`（空字符串），去掉"设置出发日期"。

**改动 2**：`countdownLead()` 中 `days === undefined` 时，大字颜色从 `PRIMARY_COLOR`（绿）改为 `TEXT_TERTIARY`（灰 #999）。

**实现方式**：HeroCard 中大字颜色由 `countdownColor()` 方法控制，该方法目前只判断 1~3 天红色，其余绿色。需增加 `days === undefined` 时返回 `TEXT_TERTIARY` 的分支。

---

## 阶段 4：HistoryTimeline 分区渲染

**分区逻辑**：
```
今天0点 = startOfDay(new Date())

futureTrips = checklists 中 dateAt >= 今天0点 的，按 dateAt 升序
pastTrips = checklists 中 (dateAt < 今天0点 OR dateAt === undefined) 的
  → 有日期的按 dateAt 降序排前面
  → 无日期的按 createdAt 降序排后面
```

**渲染结构**：
```
if futureTrips.length > 0 && pastTrips.length > 0:
  显示分区标题 "即将启程"
  渲染 futureTrips
  显示分区标题 "走过的路"
  渲染 pastTrips
else:
  不显示任何标题，直接渲染全部（futureTrips + pastTrips 合并）
```

**分区标题样式**：fontSize 12vp，fontColor TEXT_TERTIARY，letterSpacing 1，paddingTop 8，paddingBottom 4。

**高度计算**：`historyContentHeight()` 需要改为基于实际渲染行数（futureTrips.length + pastTrips.length + 分区标题行数）计算，或改为自适应高度（去掉固定 height，用 List 自适应）。推荐改为自适应，避免分区标题撑破容器。

**新增私有方法**：
- `futureTrips(): TripChecklist[]`
- `pastTrips(): TripChecklist[]`

---

## 阶段 5：HistoryRow 动态日期文字 + 三色系统

**当前**：第 714 行直接显示 `item.date` 字符串或 `createdAt` 格式化文本，颜色固定 `TEXT_TERTIARY`。

**新逻辑**：新增私有方法 `rowDateText(item)` 和 `rowDateColor(item)`：

```
rowDateText(item):
  dateAt = checklistDateAt(item)
  if dateAt === undefined → "日期待定"
  dayDiff = floor((dateAt - 今天0点) / 86400000)
  if dayDiff > 0  → "还有 X 天"
  if dayDiff === 0 → "今天出发"
  if dayDiff < 0  → "X 天前"

rowDateColor(item):
  dayDiff === undefined → TEXT_TERTIARY (#999)
  dayDiff === 0         → PRIMARY_COLOR (#2D7D46) + FontWeight.Bold
  dayDiff 1~3           → DANGER_COLOR (#E53935)
  dayDiff > 3           → PRIMARY_COLOR (#2D7D46)
  dayDiff < 0           → TEXT_TERTIARY (#999)
```

**改动位置**：`HomePage.ets` 第 714-716 行 Text 组件，替换为调用新方法。

---

## 可行性分析

| 风险点 | 风险等级 | 说明 |
|--------|---------|------|
| parseTripDateAt 修复影响旧数据 | 低 | 旧数据 date 字段是 "6月20日" 格式，修复后仍能正确解析；新数据 "2025年6月20日" 也能解析 |
| latestChecklist 变更影响 selectedChecklistId | 低 | selectedChecklistId 在 Index.ets 中独立维护，不依赖 latestChecklist() 的返回值 |
| 分区渲染破坏 geometryTransition | 低 | geometryTransition id 是 'trip-' + item.id，与渲染位置无关，分区不影响 id |
| historyContentHeight 计算错误 | 中 | 改为自适应高度可彻底规避，但需要测试 List 在 ScrollView 内的行为 |
| stagger 动画 index 错乱 | 低 | 分区后 index 从各自分区的 0 开始，stagger 效果不变 |

---

## 验收标准

### 功能验收
- [ ] 用仪式卡片新建一个未来日期的行程，HeroCard 倒计时显示正确天数（不再显示"待定"）
- [ ] HeroCard 上不再出现"设置出发日期"文字
- [ ] "待定"状态下大字颜色为灰色（#999），不再是绿色
- [ ] 同时存在未来和历史行程时，HeroCard 显示最近的未来行程
- [ ] 所有行程都是历史行程时，HeroCard 显示最近的历史行程
- [ ] 历史行程列表在两种行程都存在时显示"即将启程"和"走过的路"分区标题
- [ ] 只有一种行程时不显示任何分区标题
- [ ] HistoryRow 日期文字：未来行程显示"还有 X 天"（绿色），1~3天显示红色，今天显示"今天出发"（绿色加粗），历史显示"X 天前"（灰色），无日期显示"日期待定"（灰色）

### 技术验收
- [ ] `hvigorw assembleApp` 构建通过，无新增 error
- [ ] 旧数据（date 字段为 "6月20日" 格式）日期解析仍正确
- [ ] 新数据（date 字段为 "2025年6月20日" 格式）日期解析正确
- [ ] geometryTransition 转场动画不受分区渲染影响，仍正常工作
- [ ] 列表 stagger 入场动画正常
