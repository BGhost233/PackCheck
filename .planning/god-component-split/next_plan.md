# PackCheck 后续瘦身计划（基于 Wave 2 纯计算提取完成后的审计）

> **生成时间**: 2026-06-29  
> **当前状态**: Wave 1A ✅ / Wave 1B 跳过 / Wave 1C 跳过 / Wave 2 纯计算提取 ✅  
> **当前行数**: Index.ets 2388 | GearPage.ets 2211 | HomePage.ets 945

---

## 现状快照

| 指标 | 当前值 | 目标值 | 差距 |
|------|--------|--------|------|
| Index.ets 行数 | 2388 | < 800 | -1588 |
| Index.ets @State | ~68 | ≤ 35 | -33 |
| GearPage.ets 行数 | 2211 | < 1800 | -411 |
| HomePage.ets 行数 | 945 | < 700 | -245 |

**核心矛盾**: Index.ets 还有 68 个 @State，其中 28 个是 Day/Segment 表单代理（Wave 1A 漏网），SheetOverlay 传参区 137 行纯信噪比为零。

---

## Phase 5: 表单代理 @State 续扫（零风险，净删代码）

**预期收益**: -28 @State，-200 行 reset/prefill 逻辑，Index.ets → ~2180

Wave 1A 消除了 Gear/Trip/Profile/TempItem/Import 表单的代理 @State，但 Day 表单（5 个）和 Segment 表单（11 个）及 EditItemPanel（6 个）共 22+ 个还在 Index.ets。它们与 1A 同模式——打开时从 sourceData 复制到代理，关闭时回写。

| # | 任务 | 涉及 @State | 预估删除行数 |
|---|------|------------|------------|
| 5.1 | DayFormSheet 表单 @State 内化 | `editingDayId`, `dayFormFrom`, `dayFormTo`, `dayFormDate`, `dayFormNote` (5个) | ~40 |
| 5.2 | SegmentFormSheet 表单 @State 内化 | `editingSegmentId`, `editingSegDayId`, `segFormFrom`...`segFormTicketPrice` (11个) | ~60 |
| 5.3 | EditItemPanel 表单 @State 内化 | `editingItemId/Name/Group/Weight/Price`, `showEditItemPanel` (6个) | ~50 |
| 5.4 | EditGearPanel 表单 @State 内化 | `editingGearId`, `gearName/Category/Weight/Price/Note`, `showEditGearPanel` (6+1个) | ~50 |
| 5.5 | 从 Index.ets 删除已内化的 @State + 全部 resetXxxForm() + SheetOverlay 对应传参行 | — | 累计 ~200 |

---

## Phase 6: 低风险子组件提取

**预期收益**: Index.ets -73 行/-4 @State、GearPage.ets -49 行/-3 @State、HomePage.ets -33 行/-1 @State

全部零 §8.2 风险，独立性极高。

| # | 提取目标 | 源文件 | 约行数 | 内化 @State | 风险 |
|---|---------|--------|--------|------------|------|
| 6.1 | `CategoryInputDialog` | Index.ets → `components/CategoryInputDialog.ets` | ~73 | `categoryDialogMode/OldName/Input` (3个) + `showCategoryDialog` 改为 @Prop | 零 |
| 6.2 | `CompletionToast` | Index.ets → `components/CompletionToast.ets` | ~28 | `showCompletionToast` → @Prop visible | 零 |
| 6.3 | `GearFab` | GearPage.ets → `components/gear/GearFab.ets` | ~49 | `fabX/fabY/fabDragging` (3个) 全内化 | 零 |
| 6.4 | `HomeEmptyHero` | HomePage.ets → `components/home/HomeEmptyHero.ets` | ~33 | `emptyBtnPressed` (1个) 内化 | 零 |
| 6.5 | `headerBorderColor` 提取到 `ColorUtils` | HomePage + GearPage → `utils/ColorUtils.ets` | ~12 | — | 零（消除跨文件重复） |

---

## Phase 7: 中风险子组件提取 + 纯计算续扫

**预期收益**: GearPage.ets -250 行、HomePage.ets -140 行、Index.ets -50 行

| # | 任务 | 约行数 | 风险 | 备注 |
|---|------|--------|------|------|
| 7.1 | `GearCollapsingHeader` 提取 | GearPage ~199 行 | 中 | 搜索展开/折叠有独立 animateTo，不跨组件。HeadCollapseController 留父组件只传 progress 值。4 个按压态 @State 随之内化 |
| 7.2 | `HomeHistoryTimeline` 提取 | HomePage ~94 行 | 中 | 先将 futureTrips/pastTrips 在 onChecklistsChange 中预缓存，消除 build 内多次 O(N) 遍历后再拆。注意 HistoryRow 含 geometryTransition 不可独立为 @Component（§8.2），但 Timeline 整体可拆（geometryTransition 在其 @Builder 子节点中，随 Timeline 组件一起移动不断裂） |
| 7.3 | `GearPreviewCard` + `GearDetail` 提取 | GearPage ~93 行 | 低 | 纯展示，@Prop item 驱动 |
| 7.4 | HomePage 剩余纯计算下沉 | ~70 行 | 低 | `homeStatusText`/`heroSubtitleText`/`heroStatusLabel`/`heroStatusColor`/`heroLeadColor`/`rowDateColor`/`rowDateBold`/`compactHeaderText`/`nearestFutureChecklist`/`quickReviewLabel` → ChecklistService |
| 7.5 | GearPage 剩余纯计算下沉 | ~80 行 | 低 | `sortedGears`/`rebuildGearCache` 的纯函数部分 → GearService（`buildGearGroups(gears, filters, sortMode, categoryOrder)`），`gearOverlayMenuTop`/`bottomSpacerHeight` → utils |
| 7.6 | Index.ets 剩余纯计算下沉 | ~50 行 | 低 | `currentTripGearIds`/`reviewSummaryText`/`tabVisualWeight` → service/utils |

---

## Phase 8: nonce 治理（Wave 3A）

**前置条件**: Phase 5 完成后 @State ≤ 40

| # | 任务 | 风险 |
|---|------|------|
| 8.1 | 审计全部 `checklistRenderNonce++` 调用点（当前 7 处），逐一分析是否可用数组引用替换触发 | 低——只审计不改 |
| 8.2 | 尝试替代方案 1: 每次 CRUD 后 `this.checklists = [...this.checklists]` 强制新引用 | 中——需逐场景验证列表刷新 |
| 8.3 | 如替代可行，逐一消除 nonce 点并验证；如不可行，记录原因保留 nonce | 中 |
| 8.4 | ViewModel 评估：Phase 5-7 完成后若 Index.ets @State ≤ 25 且按域清晰分组，跳过 ViewModel；否则引入 ChecklistViewModel | — |

---

## Phase 9: 验证收尾（Wave 4）

| # | 任务 |
|---|------|
| 9.1 | 全量 `devecocli build` 编译通过 |
| 9.2 | 逐文件行数/@State/方法数终审 |
| 9.3 | 全功能手动测试矩阵（每个 tab × 每个 sheet × 每个 CRUD × 每个动画） |
| 9.4 | 更新 `docs/DEVELOPMENT_STANDARDS.md` |
| 9.5 | 更新 `memory/MEMORY.md` 避坑清单 |

---

## 不可碰的红线清单（§8.2 命中，任何 Phase 均禁止）

| 区域 | 所属文件 | 命中条款 |
|------|---------|---------|
| NavDestinationMap @Builder | Index.ets | @Builder this 绑定 |
| customTabBar + triggerBlurPulse 动画编排 | Index.ets | 动画状态机 + 手势链 |
| openSheetAnimated/closeSheet 四 @State 联动 | Index.ets | 动画状态机 |
| pushTripDetail/returnToHome geometryTransition | Index.ets | geometryTransition 配对 |
| build() 内 Tab 手势编排 | Index.ets | 手势链 |
| 单品拖拽状态机全链路（22 变量） | GearPage.ets | 拖拽坐标系 + 动画状态机 + 手势链 |
| 分组拖拽状态机 | GearPage.ets | 拖拽坐标系 |
| GearRow 左滑 + 长按手势组合 | GearPage.ets | 手势链 |
| GearGroupCard 长按→拖拽手势 | GearPage.ets | 手势链 |
| HeroCard 动画编排 + geometryTransition | HomePage.ets | 动画状态机 + geometryTransition |
| HistoryRow geometryTransition 配对 | HomePage.ets | geometryTransition（不可拆为独立 @Component） |
| HeadCollapseController 联动 | HomePage.ets | 动画状态机 |
| UnifiedChecklistView 整体（1082 行） | UnifiedChecklistView.ets | 全部 5 条命中 |
| ProfilePage 动画编排（18/20 @State） | ProfilePage.ets | 动画状态机 |

---

## 预期终态

| 指标 | Phase 5 后 | Phase 6 后 | Phase 7 后 | Phase 8 后 | 目标 |
|------|-----------|-----------|-----------|-----------|------|
| Index.ets 行数 | ~2180 | ~2080 | ~2030 | ~2030 | — |
| Index.ets @State | ~40 | ~36 | ~36 | ~36 | ≤ 35 |
| GearPage.ets 行数 | 2211 | ~2162 | ~1820 | ~1820 | < 1800 |
| HomePage.ets 行数 | 945 | ~912 | ~700 | ~700 | < 700 |

**诚实评估**: Index.ets 的行数目标 < 800 在不做 SheetOverlay → SheetContainer 重构的前提下**不可达**。当前 NavDestinationMap @Builder（120 行）+ SheetOverlay 传参区（137 行）+ Tab 手势编排（60 行）+ build() 结构（200 行）= ~517 行纯 UI 壳不可删减。Phase 5-8 可将 Index.ets 压到 ~2030 行，但要达到 < 800 必须重新评估 SheetContainer 方案或将 NavDestination 路由拆分到独立 router。

**建议**: 将 Index.ets 目标修正为 < 2000（合理）或 < 1500（激进，需 SheetContainer 重构）。GearPage < 1800 和 HomePage < 700 可达。

---

## 建议执行顺序

```
Phase 5 (表单 @State 续扫)    ← 最高收益最低风险，第一优先
    ↓
Phase 6 (零风险子组件)        ← 独立性强，可与 Phase 5 同会话
    ↓
Phase 7 (中风险子组件+纯计算) ← 建议独立会话，逐个提取逐个验证
    ↓
Phase 8 (nonce 治理)          ← 依赖 Phase 5 完成
    ↓
Phase 9 (终审)                ← 全部完成后统一验证
```

Phase 5+6 可以在一个会话完成（纯机械操作）；Phase 7 每个子组件提取建议单独 commit；Phase 8 需要细致的逐点验证。
