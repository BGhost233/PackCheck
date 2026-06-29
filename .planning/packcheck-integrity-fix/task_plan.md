# PackCheck 完整性修复计划

> **目标**: 从第一性原理出发，系统修复对抗性审计发现的全部 23 个问题，消灭数据丢失、运行时崩溃、状态不一致三类根因。
>
> **最高约束**: 用户体验不可降级。后端随便复杂，前端每一层必须丝滑。
>
> **方法论**: 分 6 个阶段，按依赖关系排序——底层模型 → 存储层 → 服务层 → 组件层 → UI 层 → 验证收尾。每阶段内 P0 先行，P1/P2 顺带。

---

## 阶段 0：模型层防腐 — "一切对象构造必须经过工厂"

**状态**: `done` ✅
**预计改动**: 3 个文件 | 复杂度: 中

### 任务清单

| # | 问题 ID | 优先级 | 任务 | 文件 | 状态 |
|---|---------|--------|------|------|------|
| 0.1 | P0-02 | P0 | 为 `DayItinerary` 创建 `cloneDayItinerary(source, overrides?)` + `cloneDayItineraryFull(...)` | services/ItineraryService.ets | `done` ✅ |
| 0.2 | P0-02 | P0 | 为 `RouteSegment` 创建 `cloneRouteSegment(source, overrides?)` + `cloneRouteSegmentFull(...)` | services/ItineraryService.ets | `done` ✅ |
| 0.3 | P0-02 | P0 | 为 `TicketInfo` 创建 `cloneTicketInfo(source, overrides?)` | services/ItineraryService.ets | `done` ✅ |
| 0.4 | P2-06 | P2 | 为 `TripChecklist` 创建 `createChecklist(title, date, dateAt, destination)` 工厂函数 | services/ChecklistService.ets | `done` ✅ |
| 0.5 | P0-02 | P0 | 将 ItineraryService.ets 中 6 处手写 DayItinerary 字面量全部替换为 clone helper | services/ItineraryService.ets | `done` ✅ |
| 0.6 | P0-02 | P0 | 将 ChecklistService.buildItemsFromGears 中手写 ChecklistItem 替换为 cloneChecklistItemFull | services/ChecklistService.ets | `done` ✅ |
| 0.7 | P0-02 | P0 | 将 Index.ets 中 actionSheetItem 初始化替换为工厂函数 | pages/Index.ets | `done` ✅ |

### 第一性原理

> **公理**: 如果一个 interface 有 N 个字段，那么项目中存在 M 处手写该 interface 字面量，则新增一个字段时必须改 M 处。当 M > 1 时，遗漏概率 = 1 - (1 - p)^M，随 M 指数增长。
>
> **推论**: M 必须 = 1。所有对象构造收敛到唯一的 clone/factory 函数。

### 验收标准

- `grep -rn 'as DayItinerary' entry/` 返回 0 结果（或仅在 clone helper 内部）
- `grep -rn 'as RouteSegment' entry/` 同上
- 所有 clone helper 的字段列表与 interface 定义 1:1 对应
- `devecocli build` 通过

---

## 阶段 1：存储层加固 — "数据在边界处校验，在持久化处保护"

**状态**: `done` ✅
**预计改动**: 2 个文件 | 复杂度: 高

### 任务清单

| # | 问题 ID | 优先级 | 任务 | 文件 | 状态 |
|---|---------|--------|------|------|------|
| 1.1 | P1-03 | P1 | `safeParseArray<T>` 增加运行时字段验证：为每个 model 编写 `validate` 函数，反序列化后逐条校验，丢弃不合法记录并 log | services/PackStore.ets | `done` ✅ |
| 1.2 | P1-01 | P1 | Preferences 容量检测：flush 前计算 JSON 大小，接近 1MB 阈值时 warn 并触发压缩策略 | services/PackStore.ets | `done` ✅ |
| 1.3 | P1-02 | P1 | save 失败回滚：flush 失败时保留旧数据、通知上层 | services/PackStore.ets | `done` ✅ |
| 1.4 | P1-05 | P1 | 消灭 fire-and-forget：所有 `putSync`/`flush` 调用的返回值/异常必须被处理 | services/PackStore.ets | `done` ✅ |
| 1.5 | P2-08 | P2 | `migrateSchema` 填充实际迁移逻辑 | services/PackStore.ets | `done` ✅ |
| 1.6 | P1-04 | P1 | GearPage 私有 PackStore 实例消灭：改为 singleton `getPackStore()` | components/GearPage.ets + pages/Index.ets | `done` ✅ |

### 第一性原理

> **公理**: 持久化层是用户数据的最后一道防线。任何通过 JSON 反序列化进入内存的数据，其结构完整性等于零，直到被验证。
>
> **推论**: 反序列化 = 类型转换 + 验证。只做类型转换（`as T`）等于没做。

### 验收标准

- 构造恶意 JSON（缺字段、错类型、超大体积），注入 Preferences，启动 app 不 crash
- GearPage 中 `grep -n 'new PackStore' entry/` 返回 0 结果
- `devecocli build` 通过

---

## 阶段 2：服务层事务性 — "状态变更要么全做，要么全不做"

**状态**: `done` ✅
**预计改动**: 2 个文件 | 复杂度: 中

### 任务清单

| # | 问题 ID | 优先级 | 任务 | 文件 | 状态 |
|---|---------|--------|------|------|------|
| 2.1 | P1-06 | P1 | category delete/rename 事务化：先构建完整新状态，一次性赋值 @State，失败时不改任何状态 | pages/Index.ets | `done` ✅ |
| 2.2 | P2-03 | P2 | `deleteChecklist` 原子化 | pages/Index.ets | `done` ✅ |
| 2.3 | P2-01 | P2 | nonce 模式 review：评估后保留——V1 下 @Watch+@Track 替代方案性价比不足 | pages/Index.ets | `done` ✅ (保留现状) |

### 第一性原理

> **公理**: UI = f(State)。如果状态变更不是原子的，则存在中间帧 UI = f(半成品State)，用户会看到闪烁/错位/crash。
>
> **推论**: 所有多字段状态变更必须在一个同步块内完成，或者使用「构建新状态 → 一次性替换」模式。

### 验收标准

- 删除最后一个 checklist 时 UI 无闪烁
- 重命名分类后，该分类下所有 gear 同步更新，无遗漏
- `devecocli build` 通过

---

## 阶段 3：组件层安全 — "运行时永远不崩"

**状态**: `done` ✅
**预计改动**: 4 个文件 | 复杂度: 中

### 任务清单

| # | 问题 ID | 优先级 | 任务 | 文件 | 状态 |
|---|---------|--------|------|------|------|
| 3.1 | P0-01 | P0 | ReviewPage zone review marking 错位修复：flingCard 回调 currentIndex 匹配验证 | components/ReviewPage.ets | `done` ✅ |
| 3.2 | P1-09 | P1 | HomePage forced unwrap (`!`) 替换为安全访问 + 局部变量 | components/HomePage.ets | `done` ✅ |
| 3.3 | P1-08 | P1 | GearPage overlay 状态泄漏修复：sheet 关闭时清理临时状态 | components/GearPage.ets | `done` ✅ |
| 3.4 | P1-07 | P1 | 所有 TextInput 加 `maxLength` 约束 | 全局 | `done` ✅ |
| 3.5 | P2-10 | P2 | 数值输入验证：weight/price 等范围校验 | Index.ets 相关表单 | `done` ✅ |
| 3.6 | P2-04 | P2 | Sheet 退出动画期间点击穿透 | pages/Index.ets | `deferred` ⏳ (需 ArkUI 底层支持) |
| 3.7 | P2-05 | P2 | Sheet 关闭后表单数据未清理：@Prop→@State 内化模式已解决 | pages/Index.ets | `done` ✅ |

### 第一性原理

> **公理**: 用户能触达的每一个交互路径，都必须有确定的行为。`undefined` 访问 = crash = 体验归零。
>
> **推论**: 所有 optional 数据的消费点必须有 fallback，所有动画中间态必须不可交互。

### 验收标准

- 无 `!` forced unwrap 残留（`grep -rn '()!' entry/` + `grep -rn '\]!' entry/` 只在确实安全的场景存在）
- 所有 TextInput 有 maxLength
- Sheet 动画期间快速连点不触发多次弹出
- `devecocli build` 通过

---

## 阶段 4：UI 层规范化 — "所有视觉参数走 token"

**状态**: `done` ✅
**预计改动**: 5+ 个文件 | 复杂度: 高（改动面广）

### 任务清单

| # | 问题 ID | 优先级 | 任务 | 文件 | 状态 |
|---|---------|--------|------|------|------|
| 4.1 | P1-10 | P1 | 消灭 250+ 处硬编码 `fontSize`：全部替换为 `Typography.*` token | 全局 | `done` ✅ |
| 4.2 | P1-10 | P1 | 消灭硬编码色值：替换为 `Colors.*` token | 全局 | `done` ✅ |
| 4.3 | P1-10 | P1 | 消灭硬编码间距/尺寸：替换为 `Layout.*` token | 全局 | `done` ✅ |
| 4.4 | P1-10 | P1 | 消灭硬编码动画时长/曲线：替换为 `AnimationTokens.*` | 全局 | `done` ✅ |
| 4.5 | P2-02 | P2 | 长列表性能：ForEach → LazyForEach | components/GearPage.ets | `deferred` ⏳ (当前列表规模不足以触发性能瓶颈) |

### 第一性原理

> **公理**: 设计系统的本质是「一处修改，全局生效」。硬编码 = 设计系统失效 = 每次改设计要改 250+ 处。
>
> **推论**: 任何视觉参数出现超过 1 次，就必须是 token。

### 验收标准

- `grep -rn 'fontSize(' entry/` 结果中不含数字字面量（如 `fontSize(14)`），全部为 `fontSize(Typography.xxx)`
- `grep -rn '#[0-9a-fA-F]' entry/ --include='*.ets'` 返回 0 结果（颜色字面量归零）
- `devecocli build` 通过
- 视觉回归：改动前后截图 diff 为 0

---

## 阶段 5：架构治理 — "God Component 瘦身"

**状态**: `partial` ⚠️ (5.1-5.5 deferred, 5.6-5.7 done)
**预计改动**: 10+ 个文件（新建 + 重构） | 复杂度: 极高

### 任务清单

| # | 问题 ID | 优先级 | 任务 | 文件 | 状态 |
|---|---------|--------|------|------|------|
| 5.1 | P0-03 | P0 | Index.ets 拆分方案设计 | 设计文档 → 代码 | `deferred` ⏳ (独立大 PR) |
| 5.2 | P0-03 | P0 | 提取 SheetController | 新建 controllers/SheetController.ets | `deferred` ⏳ |
| 5.3 | P0-03 | P0 | 提取 ChecklistEditorComponent | 新建 components/ChecklistEditor.ets | `deferred` ⏳ |
| 5.4 | P0-03 | P0 | 提取 ItineraryEditorComponent | 新建 components/ItineraryEditor.ets | `deferred` ⏳ |
| 5.5 | P0-03 | P0 | Index.ets 瘦身后验证 | pages/Index.ets | `deferred` ⏳ |
| 5.6 | P2-07 | P2 | TicketInfo.note 死字段清理：确认无 UI 入口，保留为 optional 兼容字段 | models/PackModels.ets | `done` ✅ |
| 5.7 | P2-09 | P2 | EntryBackupAbility 实现：升级为 onBackupEx/onRestoreEx 结构化返回 | entrybackupability/ | `done` ✅ |

### 第一性原理

> **公理**: 一个模块的复杂度上限 ∝ 人脑工作记忆容量（7±2 个概念）。2571 行 / 90 个 @State / 99 个方法远超此限。
>
> **推论**: 必须按单一职责拆分。每个组件只负责一个「概念域」。

### 验收标准

- Index.ets < 800 行
- 每个新组件 < 500 行
- 所有数据流通过 `@Prop` / `@Link` / 回调显式传递，无隐式共享
- `devecocli build` 通过
- 全功能手动测试通过（每个 tab、每个 sheet、每个 CRUD 操作）

---

## 阶段 6：验证收尾

**状态**: `done` ✅
**改动**: Typography/Layout token 补充 + 4 处残留 fontSize 修复 + DEVELOPMENT_STANDARDS.md + MEMORY.md

### 任务清单

| # | 任务 | 状态 |
|---|------|------|
| 6.1 | 全量 `devecocli build` 编译通过 | `done` ✅ |
| 6.2 | 逐项验证 23 个问题的修复状态（3 组并行 agent 审计） | `done` ✅ |
| 6.3 | 更新 `docs/DEVELOPMENT_STANDARDS.md`（§4.6 内化模式 / §5.2.1 clone 铁律 / §5.2.2 事务模式 / §7.2 备份恢复） | `done` ✅ |
| 6.4 | 更新 `memory/MEMORY.md` 避坑清单（51→54 条） | `done` ✅ |
| 6.5 | git commit Phase 6 变更 | `pending` |

---

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| git commit -m 含换行被 terminal 工具拒绝 | 1 | 改为单行 commit message |
| DEVELOPMENT_STANDARDS.md §7.3 编号重复 | 1 | 将无障碍从 7.3 改为 7.4 |
| 验证发现 4 处残留 fontSize 硬编码 | 1 | 新增 FONT_SIZE_PANEL_TITLE=17 + ICON_SIZE_XS=7 token 并替换 |

---

## 依赖关系

```
阶段 0 (模型防腐) ─── 无前置依赖                          ✅ done
    │
    ▼
阶段 1 (存储加固) ─── 依赖阶段 0 的 validate 函数          ✅ done
    │
    ▼
阶段 2 (服务事务) ─── 依赖阶段 0+1 的 clone/factory        ✅ done
    │
    ▼
阶段 3 (组件安全) ─── 依赖阶段 1 的 singleton PackStore    ✅ done
    │
    ▼
阶段 4 (UI token) ─── 可与阶段 2/3 并行，无强依赖          ✅ done
    │
    ▼
阶段 5 (架构拆分) ─── 5.6/5.7 done, 5.1-5.5 deferred     ⚠️ partial
    │
    ▼
阶段 6 (验证收尾) ─── 依赖全部完成                         ✅ done
```

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 阶段 5 拆分引入回归 | 高 | 每拆一个组件立即 build + 手动测试 |
| Token 替换导致视觉偏差 | 中 | 改前截图，改后对比 |
| ItineraryService clone helper 遗漏字段 | 高 | 与 interface 定义 1:1 对照自动校验 |
| GearPage PackStore 改 singleton 后初始化时序 | 中 | 用 `aboutToAppear` 生命周期保证初始化顺序 |

## 总结

**23 个审计问题处置统计**:

- P0: 3 个 — 2 个完全修复 (P0-01, P0-02)，1 个部分修复 (P0-03 拆分 deferred，但底层安全已修)
- P1: 10 个 — 10 个全部修复
- P2: 10 个 — 7 个修复，3 个 deferred (P2-01 nonce 保留、P2-02 LazyForEach、P2-04 sheet 动画穿透)

**Deferred 项目说明**: 5.1-5.5 (God Component 拆分) 是独立大重构，需要单独 PR；P2-02 和 P2-04 受限于当前场景规模和 ArkUI 底层能力。
