# God Component 拆分 — 进度日志

---

## 2026-06-29 — 会话 1: 调查探索 + 计划制定

### 已完成

- [x] 阅读对抗性审查报告 (`PackCheck-对抗性审查报告-20260629.md`)，提取 God Component 相关问题
- [x] 阅读 `docs/DEVELOPMENT_STANDARDS.md` §8.1/§8.2 拆分规则
- [x] 阅读 `memory/MEMORY.md` 全部 54 条避坑清单
- [x] 逐文件深度审计:
  - Index.ets (2528 行): 77 @State 分 11 域，46 个为 sheet 表单代理可消除，112 方法中 ~45 个可下沉
  - GearPage.ets (2292 行): 30 @State 分 7 域，拖拽状态机 (22 vars) 不可拆分，可提取 ~550 行
  - SheetOverlay.ets: 85 成员中 75 个纯透传，可替换为 SheetContainer (4+1 成员)
  - UnifiedChecklistView.ets (1082 行): 全部 5 条 §8.2 命中，整体不可拆分
  - HomePage.ets (1104 行): ~400 行可提取/下沉，HeroCard 动画不可拆分
  - ProfilePage.ets (615 行): 18/20 @State 是动画机，仅 StatCell + Timeline 可提取
  - TripDetailPage.ets (528 行): 在合理范围，优先级最低
- [x] 识别 4 条关键依赖链: Checklist 核心链、Gear↔Checklist 联动、Category 三事务、Sheet 双向耦合
- [x] 制定 4-Wave 拆分计划 (消冗→提取→架构→验证)
- [x] 创建 `.planning/god-component-split/task_plan.md`
- [x] 创建 `.planning/god-component-split/findings.md`
- [x] 创建 `.planning/god-component-split/progress.md`

### 关键决策

| 决策 | 理由 |
|------|------|
| 4-Wave 渐进式而非一次性大重构 | 每个 Wave 独立可验证，失败时可回滚到上一个稳定态 |
| Wave 1 先消灭 46 个 @State | 60% 的 @State 是无脑冗余，消除后才能清晰看到真正的架构问题 |
| SheetOverlay→SheetContainer 而非改良 | 85→8 成员，改良无法解决透传的根本问题 |
| UnifiedChecklistView 不拆分 | 5 条 §8.2 全命中，是经调查确认的技术约束，不是偷懒 |
| GearRowCard 拆分时保留拖拽状态机在父组件 | 坐标系不可跨组件边界，这是 ArkUI 的硬约束 |
| Wave 3 nonce 治理放在 Wave 1 之后 | Wave 1 消减 @State 后框架追踪能力可能已足够，避免过早优化 |
| ViewModel 层作为可选评估项 | 先做完 Wave 1+2 看剩余复杂度，如果 @State ≤ 25 且按域清晰分组，可能不需要 ViewModel |

### 下一步

- 开始 Wave 1B: SheetOverlay → SheetContainer 重构

---

## 2026-06-29 — 会话 2: Wave 1A 实施完成

### 已完成

- [x] GearFormSheet 内化: 5 @Prop + 5 onChange → `initialXxx` + 内部 @State + `aboutToAppear()` + `onSave(name, category, weight, price, note)` 单回调
- [x] TripFormSheet 内化: 7 @Prop + 7 onChange → `initialXxx` + 内部 @State + `aboutToAppear()` + `onConfirm(title, date, destination, distanceKm, maxAltitude, ascentM, durationHours)` 单回调
- [x] ProfileEditSheet 内化: 6 @Prop + 6 onChange → `initialXxx` + 内部 @State + `aboutToAppear()` + `onConfirm(date, destination, distanceKm, maxAltitude, ascentM, durationHours)` 单回调
- [x] TempItemSheet 内化: 3 @Prop + 2 onChange → `initialXxx` + 内部 @State + `onConfirm(name, group)` + 内部连续添加提示逻辑
- [x] ImportSheet 内化: `importGearIds/importGearCategory` 内化 + `toggleSelection()` 内化 + `onImport(ids: string[])` 单回调
- [x] SheetOverlay 重写: 删除所有 onChange 回调；初始值属性使用 `@Prop`（非 plain property，因 SheetOverlay 常驻 DOM 需同步）；prop 名改为 `gearInitialName/tripInitialTitle/profileInitialDate/tempInitialName` 等；回调改为 `onSaveGear(5参)/onCreateTrip(7参)/onSaveTrip(7参)/onSaveProfile(6参)/onAddTempItem(2参)/onImportGears(ids)`
- [x] Index.ets 精简:
  - 删除 3 个 @State: `importGearIds`, `importGearCategory`, `showTempAddNotice`
  - 删除包装方法: `saveGear()`, `createChecklist()`, `toggleImportSelection()`, `hasImportSelection()`
  - 参数化方法: `saveGearWithData(5参)`, `createChecklistWithData(7参)`, `saveTripInfo(7参)`, `saveProfileInfo(6参)`, `addTempItem(2参)`, `importSelectedGear(ids)`
  - SheetOverlay 调用点全面更新为新 prop 名 + 参数化回调
- [x] `devecocli build` 通过，零错误

### 关键发现

| 发现 | 影响 |
|------|------|
| 实际 @State 基线 = 83（非计划中的 77），会话后 = 80 | Day/Segment 表单 + CategoryDialog 字段在审计后被添加 |
| staging @State 无法在 1A 删除 | `gearName/tripTitle` 等仍被 EditGearPanel 读取 + SheetOverlay @Prop 需从 @State 同步 |
| SheetOverlay 常驻 DOM（opacity 控制显隐） | plain property 不会在构建后重新同步，必须使用 @Prop |
| 净消除: 3 @State, ~20 onChange, ~4 包装方法 | 实际收益小于计划预期（46），因 staging @State 有外部依赖 |

### 下一步

- Wave 1B: SheetOverlay → SheetContainer（4+1 成员），将进一步消除 staging @State 的透传需求
- Wave 1C: 基础设施清理
- Waves 2-4: 业务逻辑提取、子组件、nonce 治理、验证

---

## 2026-06-29 — 会话 3: Wave 2 纯计算提取完成（跳过 Wave 1B/1C）

### 已完成

- [x] Wave 2A.1-2: ChecklistService 新增 5 个纯函数 + 1 个接口 + 1 个 helper:
  - `moveChecklistItemToZone` / `reorderItemsInZone` / `batchMoveItems` / `setItemChecked` + `SetItemCheckedResult` / `isJustCompleted`
  - Index.ets 5 个方法委托给 service，`toggleChecklistItem` 使用 `isJustCompleted` 检测完成
- [x] Wave 2A.2 DRY: `formatKg` 统一到 GearService 版本（2 位小数 <10kg），GearPage/HomePage 删除私有副本
- [x] Wave 2A.3: `buildTripProfile` 提取到 ChecklistService（含 `TripProfileUpdate` 接口 + `clampNumber` 引入）
- [x] Wave 2B: GearPage 纯计算提取 — 新增 4 个函数到 GearService (`splitByKeyword`, `companionDays`, `companionDaysLabel`, `gearSummaryText`)；删除 7 个 private 方法；DRY 修复 `activeCategories`≡`normalizeGearCategories` / `activeCategoryText`≡`tempGearFilterText`
- [x] Wave 2C: HomePage 纯计算提取 — ChecklistService 新增 7 个函数 (`daysLeftCount`, `futureTrips`, `pastTrips`, `countdownLead`, `countdownSuffix`, `rowDateText`, `countdownLead`)；删除 9 个 private 方法
- [x] 4 次 `devecocli build` 全部通过，零错误
- [x] 4 次 commit: `48fbde5` → `b378f8d` → `f55b570` → `15318db`

### 行数变化

| 文件 | 会话前 | 会话后 | 净变化 |
|------|--------|--------|--------|
| Index.ets | ~2478 | 2388 | -90 |
| GearPage.ets | ~2229 | 2211 | -18 |
| HomePage.ets | ~1099 | 945 | -154 |
| ChecklistService.ets | — | +118 行新增 | +118 |
| GearService.ets | — | +30 行新增 | +30 |
| **净计** | | | **-114** |

### 关键发现

| 发现 | 影响 |
|------|------|
| `formatKg` 有 3 个实现，GearService 版精度更高 | 统一为 GearService 版（<10kg 显示 2 位小数） |
| `activeCategories`/`activeCategoryText` 与 GearService 已有函数完全重复 | 直接复用，无需重新提取 |
| HomePage `checklistItemWeight` 与 ChecklistService 版有行为分歧 | item.weight 优先 vs fromGearId 优先 — 已统一为 ChecklistService 版（优先 item.weight） |
| 子组件提取（2B.1-2B.3, 2C.2-2C.4, 2D）风险较高 | 涉及 §8.2 约束和动画状态机，建议独立会话处理 |

### 下一步

- Wave 2 剩余子组件提取（可选，中风险）: GearPage CollapsingHeader/GearFab/GearRowCard、HomePage EmptyHero/RingProgress/HistoryRow、ProfilePage StatCell/Timeline
- Wave 3: nonce 治理 + ViewModel 评估
- Wave 4: 验证收尾
