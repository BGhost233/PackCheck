# 任务计划：首页行程展示 Bug 修复 + 体验优化（第三轮）

**目标**：修复删除行程后 HeroCard 不刷新，优化分区标题视觉层次，统一 HeroCard 绿色系色调。

---

## 阶段总览

| 阶段 | 内容 | 状态 | 文件 |
|------|------|------|------|
| 1 | HeroCard 去参数化，内部直接读 latestChecklist() | pending | HomePage.ets |
| 2 | 分区标题视觉优化（padding + 字重 + 间距） | pending | HomePage.ets |
| 3 | heroGradientStart 改为绿色系梯度 + 统一颜色回绿色 | pending | ColorUtils.ets, HomePage.ets |
| 4 | 构建验证 + Commit | pending | — |

---

## 阶段 1：HeroCard 去参数化

**根因**：`@Builder private HeroCard(checklist: TripChecklist | undefined)` 接收参数是值快照，删除行程后不触发重渲染。

**方案**：删除 HeroCard 的参数，内部直接 `const checklist = this.latestChecklist()` 获取数据。调用处改为 `this.HeroCard()`。

---

## 阶段 2：分区标题视觉优化

**改动**：
- "即将启程" / "走过的路" Text 加 `.padding({ left: 16 })`
- 字号 12vp → 13vp
- 加 `.fontWeight(FontWeight.Medium)`
- "走过的路" ListItem 加 `.margin({ top: 8 })` 增加分区间距

---

## 阶段 3：绿色系统一

**heroGradientStart 改为**：
- `>14天` / `undefined`：`#F1F8F3`（极浅绿）
- `8~14天`：`#E8F5E9`（浅绿）
- `4~7天`：`#C8E6C9`（中浅绿）
- `1~3天`：`#A5D6A7`（绿色加深）
- `今天(0)`：`#81C784`（深绿）

**HeroCard 大字颜色**：1~3天从 COUNTDOWN_ORANGE 改回 PRIMARY_COLOR。

**HistoryRow rowDateColor**：1~3天从 COUNTDOWN_ORANGE 改回 PRIMARY_COLOR + FontWeight.Medium。

---

## 阶段 4：构建验证 + Commit

验收项：
- [ ] 删除最近未来行程后 HeroCard 立即切换到下一个行程
- [ ] 分区标题视觉清晰，左对齐有 padding，两段有间距
- [ ] HeroCard 渐变色始终为绿色系，无橙/红跳色
- [ ] 行程列表颜色统一为绿色系
