# PackCheck God Component 拆分计划

> **目标**: 将 Index.ets (2528行/77 @State/112方法) 和 GearPage.ets (2292行/30 @State) 两个上帝组件拆分到可维护规模（单组件 < 500行），同时安全处理 HomePage/ProfilePage/SheetOverlay 的膨胀问题。
>
> **最高约束**: 零功能回归，零动画降级。拆分后用户体验与拆分前像素级一致。
>
> **方法论**: 4 个 Wave，按风险由低到高排序 — Wave 1 消灭无脑冗余（零风险高收益），Wave 2 提取纯函数和独立子组件（低风险），Wave 3 重构数据流架构（中风险），Wave 4 验证收尾。
>
> **不可拆分约束 (§8.2)**: 动画状态机 / geometryTransition 配对 / 拖拽坐标系 / @Builder this 绑定 / 手势链 — 命中任一条即禁止拆分。

---

## 阶段 1: Wave 1 — 无脑消冗（零风险，净删代码）

**状态**: `pending`
**预计净减**: Index.ets 约 -800 行 / SheetOverlay -93% props / PackStore -1 实例
**复杂度**: 低

### 1A: Sheet 表单 @State 内化 (§4.6 @Prop→@State 内化模式)

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 1A.1 | 识别 Index.ets 中 46 个 sheet 表单代理 @State | pages/Index.ets | 77 个 @State 中有 46 个仅服务于 sheet 表单的双向同步代理（如 editGearName/editGearWeight/editGearPrice 等），sheet 打开时从源数据复制到代理，关闭时从代理写回源数据 | `pending` |
| 1A.2 | 将 AddGearSheet 表单状态内化 | components/sheets/ | 将 editGearName/editGearWeight/editGearPrice/editGearCategory/editGearQuantity 等 ~8 个 @Prop 改为 sheet 内部 @State，打开时通过 onAppear 从传入的 sourceGear 初始化 | `pending` |
| 1A.3 | 将 AddChecklistSheet 表单状态内化 | components/sheets/ | 将 editChecklistTitle/editChecklistDate 等 ~4 个 @Prop 内化 | `pending` |
| 1A.4 | 将 AddItinerarySheet 表单状态内化 | components/sheets/ | 将 editFrom/editTo/editDate/editNote 等 ~6 个 @Prop 内化 | `pending` |
| 1A.5 | 将 CategorySheet 表单状态内化 | components/sheets/ | 将 editCategoryName/editCategoryIcon 等 ~4 个 @Prop 内化 | `pending` |
| 1A.6 | 将 TripSheet 表单状态内化 | components/sheets/ | 将 editTripTitle/editTripDates 等 ~5 个 @Prop 内化 | `pending` |
| 1A.7 | 将其余零散 sheet 表单状态内化 | components/sheets/ | 剩余 ~19 个 sheet 代理 @State 逐一内化 | `pending` |
| 1A.8 | 从 Index.ets 删除 46 个已内化的 @State 及其赋值逻辑 | pages/Index.ets | 净删 ~200 行声明 + ~400 行赋值/回写逻辑 | `pending` |

### 1B: SheetOverlay → SheetContainer 重构

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 1B.1 | 创建 SheetContainer 组件 | components/sheets/SheetContainer.ets | 仅需 4 个 @Prop: isShow/sheetType/title/height + 1 个 @BuilderParam: content。替代当前 SheetOverlay 的 46 @Prop + 39 回调 = 85 个成员的透传路由 | `pending` |
| 1B.2 | 迁移 SheetOverlay 逻辑到 SheetContainer | components/sheets/ | SheetOverlay 自身只使用 ~10 个成员（isShow/onDismiss/sheetType + 动画相关），其余 75 个成员是纯透传给子 sheet | `pending` |
| 1B.3 | 修改 Index.ets 中 SheetOverlay 调用点 | pages/Index.ets | 从传 85 个参数改为传 4 个 @Prop + @Builder 内容块，约 -150 行 | `pending` |
| 1B.4 | 删除旧 SheetOverlay 或标记 deprecated | components/sheets/ | 待全部迁移完成后删除 | `pending` |

### 1C: 基础设施清理

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 1C.1 | 确认 PackStore singleton 已生效 | components/GearPage.ets | 上一轮修复已将 GearPage 的私有 PackStore 改为 singleton getPackStore()，此处仅确认无回退 | `pending` |
| 1C.2 | 清理死 token 和未使用导入 | 全局 | 上轮 token 化后可能存在未使用的旧常量 | `pending` |

### 第一性原理

> **公理**: 状态管理的最小化原则 — 一个 @State 的最佳归属是「使用它的最近公共祖先」。如果一个 @State 只被一个 sheet 使用，它不应该存在于 Index.ets 中。
>
> **推论**: 46 个表单代理 @State 违反了此原则。内化后 Index.ets 的 @State 从 77 个降到 ~31 个，进入人脑工作记忆可管理范围 (7±2 个概念域)。

### 验收标准

- Index.ets @State 数量 ≤ 35
- SheetOverlay 成员数 ≤ 10（或已被 SheetContainer 替代）
- 所有 sheet 打开/编辑/保存/取消功能不变
- `devecocli build` 通过

---

## 阶段 2: Wave 2 — 提取纯函数 + 独立子组件（低风险）

**状态**: `pending`
**预计净减**: Index.ets 约 -300 行 / GearPage 约 -550 行 / HomePage 约 -400 行
**复杂度**: 中

### 2A: Index.ets 业务逻辑下沉到 Service 层

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 2A.1 | Checklist CRUD 方法提取到 ChecklistService | services/ChecklistService.ets | Index.ets 中 ~8 个 checklist 相关方法（addChecklist/deleteChecklist/renameChecklist/toggleItem 等）的纯业务逻辑部分下沉，Index.ets 只保留调用 service + 更新 @State 的薄壳 | `pending` |
| 2A.2 | Gear 管理方法提取到 GearService | services/GearService.ets (新建) | addGear/deleteGear/updateGear/moveGear 的纯数据操作下沉。注意: gear↔checklist 联动逻辑需要跨 service 协调 | `pending` |
| 2A.3 | Category 三事务方法重构 | services/ | deleteCategory/renameCategory 已在上轮事务化，此处将事务逻辑体从 Index.ets 搬到 service 层 | `pending` |
| 2A.4 | 统计/聚合计算提取 | services/ | 如 getTotalWeight/getPackedPercentage/getCategoryStats 等纯计算函数 | `pending` |

### 2B: GearPage 子组件提取

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 2B.1 | 提取 CollapsingHeader 组件 | components/gear/CollapsingHeader.ets | ~200 行的顶部折叠头部。注意: 必须走 HeadCollapseController，通过 @Prop 传入折叠进度值 | `pending` |
| 2B.2 | 提取 GearFab 组件 | components/gear/GearFab.ets | ~50 行的浮动操作按钮，独立性强 | `pending` |
| 2B.3 | 提取 GearRowCard 组件 | components/gear/GearRowCard.ets | ~300 行的装备行卡片渲染。⚠ 注意: 单项拖拽状态机 (OverlayPhase: IDLE→MENU→DRAGGING) 的 7 @State + 15 私有变量必须与 GearRowCard 保持在同一组件中（§8.2 拖拽坐标系规则） | `pending` |
| 2B.4 | 纯计算方法下沉 | services/ | ~120 行的排序/筛选/分组纯函数移至 service 或 utils | `pending` |

### 2C: HomePage 瘦身

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 2C.1 | 纯计算方法下沉到 ChecklistService | services/ChecklistService.ets | ~15 个纯计算方法（getProgress/getStats/formatDate 等） | `pending` |
| 2C.2 | 提取 EmptyHero 组件 | components/home/EmptyHero.ets | 空状态引导视图，~80 行，无状态依赖 | `pending` |
| 2C.3 | 提取 RingProgress 组件 | components/home/RingProgress.ets | 环形进度条，~60 行，纯 @Prop 驱动 | `pending` |
| 2C.4 | 提取 HistoryRow 组件 | components/home/HistoryRow.ets | 历史记录行，~50 行 | `pending` |

### 2D: ProfilePage 瘦身

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 2D.1 | 提取 StatCell 组件 | components/profile/StatCell.ets | 统计数值展示格，~40 行 | `pending` |
| 2D.2 | 提取 Timeline 叙事组件 | components/profile/TimelineNarrative.ets | 时间线文字渲染，~60 行 | `pending` |

### 第一性原理

> **公理**: 组件的职责 = 「状态管理 + 渲染」。如果一段代码只做数据变换不涉及 @State，它不是组件职责，应在 service/utils 中。
>
> **推论**: Index.ets 的 ~40 个方法中约一半是纯业务逻辑（不读写 @State），应下沉。

### 验收标准

- Index.ets 方法数 ≤ 50（从 112 降至约 50）
- GearPage.ets < 1800 行（从 2292 降）
- HomePage.ets < 700 行（从 1104 降）
- 所有提取的子组件通过 @Prop/@Link + 回调与父组件通信
- `devecocli build` 通过

---

## 阶段 3: Wave 3 — 数据流架构重构（中风险）

**状态**: `pending`
**预计效果**: Index.ets < 800 行 / checklistRenderNonce 可能被消除
**复杂度**: 高

### 3A: checklistRenderNonce 治理

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 3A.1 | 审计所有 nonce 触发点 | pages/Index.ets | 识别所有 `this.checklistRenderNonce++` 调用点，分析每个是否可以用更精确的 @State 变更替代 | `pending` |
| 3A.2 | 评估 V1 @Watch + @Track 替代方案 | — | 上轮评估结论是「V1 下性价比不足」，但在 Wave 1 大幅消减 @State 后重新评估：内化后 @State 减少到 ~31 个，@Track 方案可行性可能提升 | `pending` |
| 3A.3 | 如可行，实施 nonce 替代方案 | pages/Index.ets | 用 @Track 精确标记需要触发更新的数组属性，替代全局 nonce。如不可行，保留 nonce 并在代码注释中说明原因 | `pending` |

### 3B: ViewModel 层评估

| # | 任务 | 文件 | 详情 | 状态 |
|---|------|------|------|------|
| 3B.1 | 评估引入 ViewModel 的收益 | — | 当前 Index.ets 的剩余 ~31 个 @State 可按域分组：checklist 核心链 (~8)、gear↔checklist 联动 (~5)、导航/UI 状态 (~8)、sheet 控制 (~10)。评估是否值得引入 ChecklistViewModel / GearViewModel 进一步分离 | `pending` |
| 3B.2 | 如收益显著，实施 ViewModel 分离 | viewmodels/ (新建) | 将 @State 集合和操作方法封装到 ViewModel class，Index.ets 通过 @State vm: ChecklistViewModel 持有 | `pending` |
| 3B.3 | 如收益不显著，记录决策并跳过 | — | 在 findings.md 记录评估过程和跳过原因 | `pending` |

### 第一性原理

> **公理**: 强制刷新 (nonce++) 是对响应式框架的「投降」—— 它承认框架无法追踪你的状态变更。在 @State 大幅消减后，框架追踪能力可能已足够。
>
> **推论**: Wave 1 是 Wave 3 的前置条件。先消减冗余 @State，再评估是否需要 nonce hack。

### 验收标准

- 如 nonce 被替代：`grep -rn 'checklistRenderNonce' entry/` 返回 0 结果
- 如 nonce 保留：有充分的评估文档说明为何保留
- ViewModel 有明确的采纳/拒绝决策记录
- `devecocli build` 通过
- 列表更新/滚动/切换 tab 无卡顿

---

## 阶段 4: Wave 4 — 验证收尾

**状态**: `pending`
**复杂度**: 中

### 任务清单

| # | 任务 | 文件 | 状态 |
|---|------|------|------|
| 4.1 | 全量 `devecocli build` 编译通过 | — | `pending` |
| 4.2 | 逐文件行数/方法数/状态数审计 | — | `pending` |
| 4.3 | 全功能手动测试矩阵（每个 tab × 每个 sheet × 每个 CRUD × 每个动画） | — | `pending` |
| 4.4 | 更新 docs/DEVELOPMENT_STANDARDS.md | docs/ | `pending` |
| 4.5 | 更新 memory/MEMORY.md 避坑清单 | memory/ | `pending` |
| 4.6 | git commit 全部变更 | — | `pending` |

### 验收标准

- Index.ets < 800 行，@State ≤ 35，方法 ≤ 50
- GearPage.ets < 1800 行
- HomePage.ets < 700 行
- 每个新建组件 < 500 行
- SheetOverlay 成员 ≤ 10（或已删除，由 SheetContainer 替代）
- 所有已知动画状态机保持完整未拆分
- 零编译错误，零功能回归

---

## 不可拆分区域清单 (§8.2 红线)

以下区域在调查中确认命中 §8.2 不可拆分规则，任何阶段均禁止拆分：

| 区域 | 所属组件 | 命中规则 | @State 数 | 行数 |
|------|---------|---------|-----------|------|
| 单项拖拽状态机 (OverlayPhase: IDLE→MENU→DRAGGING) | GearPage.ets | 拖拽坐标系 + 动画状态机 | 7 @State + 15 private | ~150 |
| 分组拖拽状态机 | GearPage.ets | 拖拽坐标系 | 5 @State | ~100 |
| UnifiedChecklistView 整体 | gear/UnifiedChecklistView.ets | 六态交互机 + geometryTransition + 拖拽坐标系（全部 5 条 §8.2 命中） | 30 vars | 1082 全部 |
| HeroCard 动画状态机 | HomePage.ets | 动画状态机 | ~8 @State | ~120 |
| ProfilePage 动画编排 | ProfilePage.ets | 动画状态机 | 18/20 @State | ~400 |
| TripDetailPage Tabs + HeadCollapse 编排 | gear/TripDetailPage.ets | 动画状态机 + HeadCollapseController | ~12 @State | ~400 |

---

## 依赖关系

```
Wave 1 (消冗) ─── 无前置依赖，零风险纯删代码
    │
    ├── 1A: Sheet @State 内化（最大收益，-46 @State）
    ├── 1B: SheetOverlay→SheetContainer（-85% props）
    └── 1C: 基础清理
    │
    ▼
Wave 2 (提取) ─── 依赖 Wave 1 完成后的稳定态
    │
    ├── 2A: Index 业务逻辑→Service（依赖 1A 完成后知道剩余方法）
    ├── 2B: GearPage 子组件提取（独立）
    ├── 2C: HomePage 瘦身（独立）
    └── 2D: ProfilePage 瘦身（独立）
    │
    ▼
Wave 3 (架构) ─── 依赖 Wave 1+2 完成后的精简态
    │
    ├── 3A: nonce 治理（依赖 1A 消减 @State 后重新评估）
    └── 3B: ViewModel 评估（依赖 2A service 层就位）
    │
    ▼
Wave 4 (验证) ─── 依赖全部完成
```

## 风险评估

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| Sheet @State 内化后 onAppear 初始化时序问题 | 高 — sheet 打开时显示旧数据 | 中 | 每个 sheet 单独验证打开/编辑/保存/取消全流程 |
| SheetContainer @BuilderParam this 丢失 | 高 — @Builder 内 this 指向错误 | 中 | §8.2 规则：@Builder 必须在使用它的 @Component 内定义 |
| GearRowCard 拆分后拖拽坐标系断裂 | 极高 — 拖拽功能失效 | 低（已标记不可拆分） | 拖拽状态机整体保留在 GearPage 中 |
| Service 层提取后 @State 更新链路断裂 | 高 — 数据变更不触发 UI 更新 | 中 | Service 返回新数据 → Index.ets 赋值给 @State，不在 service 中直接修改 @State |
| nonce 去除后列表更新丢失 | 高 — checklist 编辑后不刷新 | 中 | 分步去除，每去一个 nonce 点立即验证对应场景 |

## 量化目标汇总

| 指标 | 拆分前 | Wave 1 后 | Wave 2 后 | Wave 3 后 | 最终目标 |
|------|--------|-----------|-----------|-----------|---------|
| Index.ets 行数 | 2528 | ~1900 | ~1200 | < 800 | < 800 |
| Index.ets @State | 77 | ~31 | ~31 | ≤ 25 | ≤ 35 |
| Index.ets 方法数 | 112 | ~80 | ~50 | ~45 | ≤ 50 |
| GearPage.ets 行数 | 2292 | 2292 | ~1700 | ~1700 | < 1800 |
| SheetOverlay 成员数 | 85 | ≤ 10 | ≤ 10 | ≤ 10 | ≤ 10 |
| HomePage.ets 行数 | 1104 | 1104 | ~700 | ~700 | < 700 |
