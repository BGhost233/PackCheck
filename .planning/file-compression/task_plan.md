# PackCheck 大文件压缩全盘计划

> **目标**: 将 5 个超千行文件压缩到合理规模，同时零功能回归、零动画降级  
> **当前行数**: Index.ets 2345 | GearPage.ets 2063 | TripCeremonyCard.ets 1231 | UnifiedChecklistView.ets 1082 | ChecklistService.ets 1036  
> **合理目标**: Index.ets < 2000 | GearPage.ets < 1500 | TripCeremonyCard.ets < 900 | ChecklistService.ets < 400(主文件) | UnifiedChecklistView.ets 不动（§8.2 全命中）  
> **方法论**: 按"收益/风险比"排序，5 个 Phase 递进执行  
> **红线**: UnifiedChecklistView 全文命中 §8.2（六态交互机 + geometryTransition + 拖拽坐标系），禁止拆分

---

## Phase 1: ChecklistService 文件拆分（零风险，纯重组织）

**状态**: `pending`  
**目标文件**: `services/ChecklistService.ets` (1036 → 主文件 ~350 + 3 子模块)  
**方法**: 按职责域拆为 3 个子模块文件，主文件只做 re-export + 协调  
**风险**: 零（纯文件拆分，不改逻辑，import 路径更新即可）

| # | 任务 | 详情 | 状态 |
|---|------|------|------|
| 1.1 | 识别职责域 | 审计 ChecklistService 全部方法，按域分类：① CRUD 核心（create/read/update/delete）② 统计聚合（getProgress/getStats/format 系列）③ 导入导出（import/export/serialize） | `pending` |
| 1.2 | 创建 `services/checklist/ChecklistCrudService.ets` | 迁移 CRUD 核心方法（预估 ~300 行） | `pending` |
| 1.3 | 创建 `services/checklist/ChecklistStatsService.ets` | 迁移统计聚合方法（预估 ~250 行） | `pending` |
| 1.4 | 创建 `services/checklist/ChecklistIOService.ets` | 迁移导入导出方法（预估 ~200 行） | `pending` |
| 1.5 | 主文件瘦身为协调层 | ChecklistService.ets 保留实例管理 + re-export + 跨域协调逻辑（~350 行） | `pending` |
| 1.6 | 更新全部 import 路径 | grep 所有引用 ChecklistService 的文件，确认路径无误 | `pending` |
| 1.7 | `devecocli build` 验证 | 编译通过 | `pending` |

### 验收标准
- ChecklistService.ets < 400 行
- 3 个子模块各 < 350 行
- 全部调用方无需改业务代码（仅 import 路径可能变化）
- 编译通过

---

## Phase 2: GearPage 子组件提取（中风险，高收益 -600 行）

**状态**: `pending`  
**目标文件**: `components/GearPage.ets` (2063 → ~1450)  
**方法**: 提取 CollapsingHeader + GearRow 两大独立 UI 区块  
**风险**: 中（CollapsingHeader 涉及 HeadCollapseController 传值，GearRow 需确保不切断拖拽状态机）

| # | 任务 | 详情 | 状态 |
|---|------|------|------|
| 2.1 | 提取 `GearCollapsingHeader` 组件 | GearPage 顶部折叠头部 ~199 行 → `components/gear/GearCollapsingHeader.ets`。HeadCollapseController 留父组件，只传 @Prop progress: number。4 个按压态 @State（searchBtnPressed/filterBtnPressed/sortBtnPressed/addBtnPressed）随之内化 | `pending` |
| 2.2 | 提取 `GearFab` 组件 | 浮动按钮 ~49 行 → `components/gear/GearFab.ets`。fabX/fabY/fabDragging 3 个 @State 全内化 | `pending` |
| 2.3 | 提取 `GearPreviewCard` 组件 | 装备预览卡 ~93 行 → `components/gear/GearPreviewCard.ets`。纯 @Prop item 驱动，零风险 | `pending` |
| 2.4 | 提取 `GearGroupCard` 头部渲染 | 分组卡头部展示 ~80 行 → 独立 @Builder 或子组件。⚠ 注意：分组拖拽手势链不可拆出（§8.2），只提取纯渲染部分 | `pending` |
| 2.5 | GearPage 纯计算下沉 | `sortedGears`/`rebuildGearCache` 纯函数部分 ~80 行 → `services/GearService.ets`（`buildGearGroups(gears, filters, sortMode, categoryOrder)`），`gearOverlayMenuTop`/`bottomSpacerHeight` → `utils/LayoutUtils.ets` | `pending` |
| 2.6 | `devecocli build` + 拖拽功能验证 | 编译通过，拖拽排序/分组拖拽/左滑删除/长按菜单全正常 | `pending` |

### 红线提醒
- 单品拖拽状态机（OverlayPhase: IDLE→MENU→DRAGGING，22 变量）：禁止拆出
- 分组拖拽状态机：禁止拆出
- GearRow 左滑 + 长按手势组合：禁止拆出
- GearGroupCard 长按→拖拽手势：禁止拆出

### 验收标准
- GearPage.ets < 1500 行
- 新组件各 < 250 行
- 拖拽全流程功能不变
- 编译通过

---

## Phase 3: TripCeremonyCard 分层提取（低风险，-330 行）

**状态**: `pending`  
**目标文件**: `components/TripCeremonyCard.ets` (1231 → ~900)  
**方法**: 将内部重复的仪式动画子元素提取为独立渲染组件  
**风险**: 低（TripCeremonyCard 内部动画大多是独立 timeline，非跨组件状态机）

| # | 任务 | 详情 | 状态 |
|---|------|------|------|
| 3.1 | 审计 TripCeremonyCard 内部结构 | 识别可提取区块：① 仪式头部（标题+日期+图标）② 里程碑列表渲染 ③ 统计摘要区 ④ 动画编排区 | `pending` |
| 3.2 | 提取 `CeremonyMilestoneList` | 里程碑渲染列表（预估 ~150 行），纯 @Prop 驱动 | `pending` |
| 3.3 | 提取 `CeremonySummaryCard` | 统计摘要区（预估 ~100 行），纯展示组件 | `pending` |
| 3.4 | 提取 `CeremonyHeader` | 仪式头部渲染（预估 ~80 行） | `pending` |
| 3.5 | 清理 TripCeremonyCard 重复样式常量 | 内联重复的 padding/margin/fontSize 替换为 token 引用 | `pending` |
| 3.6 | `devecocli build` + 仪式动画验证 | 完成仪式卡片展开/折叠/里程碑入场动画正常 | `pending` |

### 验收标准
- TripCeremonyCard.ets < 900 行
- 仪式展开/折叠动画无降级
- 编译通过

---

## Phase 4: Index.ets 表单 @State 内化 + 纯计算下沉（低-中风险，-300 行）

**状态**: `pending`  
**目标文件**: `pages/Index.ets` (2345 → ~2000)  
**方法**: 两步走 — ① 表单代理 @State 续扫内化（-200 行）② 纯计算方法下沉（-60 行）③ applyAndPersist 封装（-40 行）  
**风险**: 低-中（表单内化需验证 onAppear 时序）

| # | 任务 | 详情 | 状态 |
|---|------|------|------|
| 4.1 | DayFormSheet @State 内化 | `editingDayId/dayFormFrom/dayFormTo/dayFormDate/dayFormNote` 5 个 → Sheet 内部 @State | `pending` |
| 4.2 | SegmentFormSheet @State 内化 | `editingSegmentId/editingSegDayId/segFormFrom...segFormTicketPrice` 11 个 → Sheet 内部 | `pending` |
| 4.3 | EditItemPanel @State 内化 | `editingItemId/Name/Group/Weight/Price` + `showEditItemPanel` 6 个 → Panel 内部 | `pending` |
| 4.4 | EditGearPanel @State 内化 | `editingGearId` + `gearName/Category/Weight/Price/Note` + `showEditGearPanel` 7 个 → Panel 内部 | `pending` |
| 4.5 | 删除 Index.ets 中已内化 @State + resetXxxForm() | 净删 ~200 行 | `pending` |
| 4.6 | 纯计算方法下沉 | `currentTripGearIds`/`reviewSummaryText`/`tabVisualWeight` → service/utils ~60 行 | `pending` |
| 4.7 | applyAndPersist 模式封装 | 识别 Index.ets 中重复的「修改数组 → nonce++ → persist()」调用模式，封装为 `applyChecklistChange(mutator)` helper ~-40 行 | `pending` |
| 4.8 | `devecocli build` + 全 Sheet 功能验证 | 每个 Sheet 的打开/编辑/保存/取消全正常 | `pending` |

### 验收标准
- Index.ets < 2050 行
- Index.ets @State ≤ 40
- 全部 Sheet 表单功能正常
- 编译通过

---

## Phase 5: 低风险子组件提取收尾（零风险，-150 行）

**状态**: `pending`  
**目标文件**: Index.ets + GearPage.ets + HomePage.ets  
**方法**: 收割剩余独立性极高的 UI 碎片  
**风险**: 零

| # | 任务 | 详情 | 状态 |
|---|------|------|------|
| 5.1 | `CategoryInputDialog` 提取 | Index.ets ~73 行 → `components/CategoryInputDialog.ets`。`categoryDialogMode/OldName/Input` 3 个 @State 内化 | `pending` |
| 5.2 | `CompletionToast` 提取 | Index.ets ~28 行 → `components/CompletionToast.ets` | `pending` |
| 5.3 | `HomeEmptyHero` 提取 | HomePage.ets ~33 行 → `components/home/HomeEmptyHero.ets`。`emptyBtnPressed` 内化 | `pending` |
| 5.4 | `headerBorderColor` 工具提取 | HomePage + GearPage → `utils/ColorUtils.ets` ~12 行消除跨文件重复 | `pending` |
| 5.5 | `devecocli build` 验证 | 编译通过 | `pending` |

### 验收标准
- Index.ets < 2000 行（累计 Phase 4+5）
- 编译通过
- 无功能回归

---

## 不动区域（§8.2 全命中，禁止触碰）

| 文件 | 行数 | 命中条款 | 决策 |
|------|------|---------|------|
| UnifiedChecklistView.ets | 1082 | 六态交互机 + geometryTransition + 拖拽坐标系 + 手势链 + 动画状态机（5/5 全命中） | **不动** |
| GearPage 拖拽状态机区域 | ~250 行 | 拖拽坐标系 + 动画状态机 + 手势链 | 就地保留 |
| Index.ets NavDestinationMap @Builder | ~120 行 | @Builder this 绑定 | 就地保留 |
| Index.ets openSheet/closeSheet 联动 | ~60 行 | 动画状态机 | 就地保留 |
| HomePage HeroCard + HistoryRow geometryTransition | ~120 行 | geometryTransition 配对 | 就地保留 |

---

## 预期终态

| 文件 | 当前 | Phase 1 后 | Phase 2 后 | Phase 3 后 | Phase 4 后 | Phase 5 后 |
|------|------|-----------|-----------|-----------|-----------|-----------|
| ChecklistService.ets | 1036 | ~350(主) | ~350 | ~350 | ~350 | ~350 |
| GearPage.ets | 2063 | 2063 | ~1450 | ~1450 | ~1450 | ~1450 |
| TripCeremonyCard.ets | 1231 | 1231 | 1231 | ~900 | ~900 | ~900 |
| Index.ets | 2345 | 2345 | 2345 | 2345 | ~2045 | ~1950 |
| UnifiedChecklistView.ets | 1082 | 1082 | 1082 | 1082 | 1082 | 1082 |

**总净减**: ~1700 行（从 7757 行 → ~6050 行，压缩率 22%）

---

## 执行顺序与依赖

```
Phase 1 (ChecklistService 拆分) ← 零风险，热身 + 建立子模块目录结构
    ↓
Phase 2 (GearPage 子组件提取)   ← 最大单笔收益 -600 行，独立于 Phase 1
    ↓  （可与 Phase 3 并行）
Phase 3 (TripCeremonyCard 分层) ← 独立文件，无交叉依赖
    ↓
Phase 4 (Index.ets @State 内化) ← 依赖 Phase 1 的 service 目录结构
    ↓
Phase 5 (收尾碎片提取)          ← 收割剩余，快速收官
```

Phase 2 和 Phase 3 无依赖关系，可同会话并行。Phase 1 建议独立 commit，Phase 2-3 各独立 commit，Phase 4-5 可合为一个 commit。

---

## 风险矩阵

| 风险 | 影响 | 概率 | 缓解 |
|------|------|------|------|
| CollapsingHeader 拆出后 progress 传值延迟 | 折叠动画卡顿 | 低 | @Prop number 是值类型，同步传递无延迟 |
| 表单 @State 内化后 onAppear 时序问题 | Sheet 打开显示旧数据 | 中 | 每个 Sheet 逐一验证 open/edit/save/cancel |
| ChecklistService 拆分后循环引用 | 编译失败 | 低 | 单向依赖：IO→CRUD→Stats，不允许反向引用 |
| TripCeremonyCard 动画拆分后 timeline 断裂 | 仪式动画缺帧 | 低 | 只提取纯渲染，动画编排保留主组件 |
| GearGroupCard 头部提取误触碰分组拖拽 | 拖拽失效 | 低 | 只提取头部渲染 @Builder，手势绑定留原处 |
