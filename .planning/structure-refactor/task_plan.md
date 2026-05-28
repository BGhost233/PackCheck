# PackCheck 项目结构重构

## 目标
在绝对不影响现有功能和 UI 的前提下，将 Index.ets（2514 行 God Component）拆分为清晰的分层架构，提升可读性、可维护性和未来扩展性。

## 阶段

### Phase 1: Sheet 组件化提取 [done]
- 将 Index.ets 中 6 个 @Builder Sheet 提取为独立组件到 `components/sheets/`
- 提取 SheetOverlay 容器组件（遮罩 + Sheet 路由）
- 清理 Index.ets 未使用的 imports
- 实际效果：Index.ets 2514→2103 行（减少 ~400 行）
- 构建验证通过，已 commit

### Phase 2: ViewModel 分层 [deferred]
- 创建 `viewmodels/` 目录
- 提取 AppState（UI 编排状态）
- 提取 GearState（装备域状态 + 操作）
- 提取 ChecklistState（清单域状态 + 操作）
- 使用 @ObservedV2 + @Trace 实现响应式
- **暂缓原因**：与 Phase 3 强耦合，需同时改所有子组件接口，风险较高，留待后续迭代

### Phase 3: 简化子组件接口 [deferred]
- 子组件接收 ViewModel 引用替代 N 个 @Prop + callback
- 与 Phase 2 为原子操作，必须一起做

### Phase 4: 拆分 Models [deferred]
- PackModels.ets → GearModel.ets + ChecklistModel.ets + index.ets
- 工具函数移到对应 Model 文件
- 保留 index.ets 统一 re-export 向后兼容

### Phase 5: 构建验证 + 最终确认 [deferred]
- hvigorw assembleApp 全量构建
- 验证所有功能不受影响
- git commit

## 约束
- 零 UI 变化：所有渲染逻辑、动效参数、交互行为完全不变
- 每步构建验证：每个 Phase 完成后 assembleApp
- 向后兼容：旧 import 路径通过 re-export 保持可用

## 决策记录
- 2025-06-18: Phase 1 完成后评估，Phase 2+3 因强耦合（ViewModel 创建必须同时改子组件接口）且改动面大（涉及所有 14 个组件文件），决定暂缓，Phase 1 已是收益最大的一步
