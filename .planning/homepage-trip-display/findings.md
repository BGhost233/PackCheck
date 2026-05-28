# 调研发现

## 日期字段现状

TripChecklist 有两套日期字段并存：
- `date?: string` — 人类可读格式，如 `"6月20日"` 或 `"2025年6月20日"`
- `dateAt?: number` — Unix 毫秒时间戳

TripCeremonyCard 存入的 date 格式是 `"2025年6月20日"`（含年份），但 `parseTripDateAt` 只能解析 `"6月20日"` 格式，导致 dateAt 始终为 undefined，倒计时永远显示"待定"。

## parseTripDateAt Bug 详情

```typescript
// 当前实现（有 Bug）
const month = Number(value.substring(0, monthIndex));
// 输入 "2025年6月20日"，monthIndex = 6（'月' 的位置）
// value.substring(0, 6) = "2025年6"
// Number("2025年6") = NaN → 解析失败
```

修复方案：先检测 `'年'` 的位置，有则提取年份并从年份之后截取月日：
```typescript
const yearIndex = value.indexOf('年');
let year = new Date().getFullYear();
let parseFrom = value;
if (yearIndex > 0) {
  year = Number(value.substring(0, yearIndex));
  parseFrom = value.substring(yearIndex + 1); // "6月20日"
}
const monthIndex = parseFrom.indexOf('月');
const dayIndex = parseFrom.indexOf('日');
// 正常解析月日，用提取的 year 构造时间戳
```

## latestChecklist 现状

两处实现完全相同，都是直接返回 `checklists[0]`：
- `HomePage.ets` 第 157-162 行
- `Index.ets` 第 242-247 行

checklists 在 Index.ets 加载后按 `createdAt` 降序排序，所以 `[0]` 是最新创建的行程，与日期无关。

## HistoryTimeline 现状

- 标题固定写死为 `'历史行程'`（第 639 行）
- 渲染全量 `checklists`，无分区
- `historyContentHeight()` = `checklists.length * 72`（固定行高计算）
- HistoryRow 日期文字：`item.date` 字符串 or `formatDateText(createdAt)`，颜色固定 `TEXT_TERTIARY`

## geometryTransition 绑定方式

HistoryRow 上绑定了 `.geometryTransition('trip-' + item.id)`，id 基于 item.id，与渲染顺序/分区无关，分区改造不会影响转场。

## countdownColor 方法位置

HeroCard 大字颜色由 `countdownColor()` 控制（HomePage.ets 约第 270 行附近），当前逻辑：
- 1~3 天 → DANGER_COLOR 红
- 其余 → PRIMARY_COLOR 绿（包括 undefined 待定状态）

需增加 `days === undefined` → TEXT_TERTIARY 灰 的分支。

## historyContentHeight 风险

当前 `historyContentHeight()` 返回 `checklists.length * 72`，分区后如果加了分区标题行，高度会不够。
建议改为自适应：去掉 List 的固定 `.height()`，让 List 根据内容自适应，外层 ScrollView 控制滚动。
需要验证 List 在 ScrollView 内不设 height 时的行为（ArkUI 中 List 默认 layoutWeight 可能需要显式设置）。
