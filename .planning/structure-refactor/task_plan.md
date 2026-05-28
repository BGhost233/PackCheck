# PackCheck 项目结构重构

## 目标
在绝对不影响现有功能和 UI 的前提下，将 Index.ets（2514 行 God Component）拆分为清晰的分层架构，提升可读性、可维护性和未来扩展性。

## 阶段

### Phase 1: Sheet 组件化提取 [in_progress]
- 将 Index.ets 中 8 个 @Builder Sheet 提取为独立组件到 `components/sheets/`
- 提取 SheetOverlay 容器组件
- 提取公共 @Builder（FormInput、DatePickerField、CategoryTags）
- 预期 Index 减少 ~600 行

### Phase 2: ViewModel 分层 [pending]
- 创建 `viewmodels/` 目录
- 提取 AppState（UI 编排状态）
- 提取 GearState（装备域状态 + 操作）
- 提取 ChecklistState（清单域状态 + 操作）
- 使用 @ObservedV2 + @Trace 实现响应式
- 预期 Index 再减 ~1400 行

### Phase 3: 简化子组件接口 [pending]
- 子组件接收 ViewModel 引用替代 N 个 @Prop + callback
- ChecklistDetail: 7 @Prop + 11 callback → 1-2 个 ViewModel 引用
- GearPage / HomePage 同理

### Phase 4: 拆分 Models [pending]
- PackModels.ets → GearModel.ets + ChecklistModel.ets + index.ets
- 工具函数移到对应 Model 文件
- 保留 index.ets 统一 re-export 向后兼容

### Phase 5: 构建验证 + 最终确认 [pending]
- hvigorw assembleApp 全量构建
- 验证所有功能不受影响
- git commit

## 约束
- 零 UI 变化：所有渲染逻辑、动效参数、交互行为完全不变
- 每步构建验证：每个 Phase 完成后 assembleApp
- 向后兼容：旧 import 路径通过 re-export 保持可用
