# 大文件压缩 — 研究发现

## 2026-06-29: 初始分析

### 五大文件现状

| 文件 | 行数 | @State | 可压缩性 | 瓶颈 |
|------|------|--------|---------|------|
| Index.ets | 2345 | ~68 | 中 | 28 个表单代理 @State 可内化；NavDestinationMap/Tab 手势/openSheet 不可动 |
| GearPage.ets | 2063 | ~30 | 高 | CollapsingHeader ~199 行 + GearFab ~49 + GearPreviewCard ~93 + 纯计算 ~80 可提取；拖拽状态机 ~250 行不可动 |
| TripCeremonyCard.ets | 1231 | ~15 | 中 | 里程碑列表 + 统计摘要 + 头部可拆；动画编排区需审计后判断 |
| UnifiedChecklistView.ets | 1082 | 30 vars | 无 | §8.2 五条全命中，禁止任何拆分 |
| ChecklistService.ets | 1036 | 0 | 极高 | 纯逻辑文件，按 CRUD/Stats/IO 三域拆分零风险 |

### 压缩方法分类

1. **文件拆分（零风险）**: ChecklistService → 3 子模块。纯 re-export，不改逻辑。
2. **子组件提取（低-中风险）**: GearPage CollapsingHeader/Fab/PreviewCard。需确保不切断拖拽。
3. **@State 内化（中风险）**: Index.ets 表单代理 → Sheet 内部。需验证 onAppear 时序。
4. **纯计算下沉（零风险）**: 各文件 → service/utils。纯函数搬家。
5. **渲染子组件提取（低风险）**: TripCeremonyCard 里程碑/摘要/头部。

### 不可压缩区域确认

UnifiedChecklistView.ets 1082 行全部不可动的根因：
- 六态交互机 (VIEW/EDIT/REVIEW/PACK/DRAG/REORDER) 共享同一组 @State
- geometryTransition 配对要求 from/to 在同一组件树
- 拖拽坐标系 (dragStartY/dragCurrentY/dragOverIndex) 必须与渲染同组件
- 手势链 (LongPress→Pan→Release) 的 onAction 闭包捕获 this
- 动画状态机 (animateTo 的嵌套序列) 跨越多个 @State

任何拆分尝试都会导致上述 5 个约束中至少 3 个断裂。

### 优先级排序依据

```
收益/风险比 = 可删行数 / (风险系数 × 验证成本)

Phase 1: ChecklistService  → 700行/0风险 = ∞     ← 最优
Phase 2: GearPage 提取     → 600行/中风险 = 高    ← 次优（单笔最大）
Phase 3: TripCeremonyCard  → 330行/低风险 = 中高  ← 独立无依赖
Phase 4: Index.ets 内化    → 300行/中风险 = 中    ← 需逐 Sheet 验证
Phase 5: 碎片收尾          → 150行/零风险 = 高    ← 最后收割
```
