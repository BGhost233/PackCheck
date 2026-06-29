# SheetContainer 重构 — 进度日志

## Session 1: 2026-06-29 — 方案设计

### 完成
- [x] 全量审计 SheetOverlay.ets（382 行，40 @Prop + 20 回调）
- [x] 审计 Index.ets Sheet 相关区域（代理变量/reset/open/传参共 ~282 行）
- [x] 盘点 10 个子 Sheet 组件的接口
- [x] 确认 ArkUI @BuilderParam + trailing lambda 可行性
- [x] 确认 @Prop 不支持 interface 的限制（排除 Payload 方案）
- [x] 对比 4 种方案，选定 D: SheetRegistry（@BuilderParam 纯壳）
- [x] 编写完整 task_plan.md（7 阶段）
- [x] 编写 findings.md（定量分析 + 技术验证 + 迁移策略）

### 决策记录
- 方案选型：D — @BuilderParam 纯壳容器
- sheetTitle 策略：open 方法中设置 currentSheetTitle 变量
- ImportSheet 头部按钮：让 ImportSheet 自建 head（设 showHeader = false）
- GearPickerSheet 头部：同上，自建 head

## Session 2: 2026-06-29 — 全量实施

### 完成
- [x] Phase 1: 新建 SheetContainer.ets（~137 行纯壳容器）
  - @BuilderParam content trailing lambda
  - 遮罩 + 标题栏 + 可选头部 action 按钮 + 手势下滑关闭
  - showHeader 控制标题栏显隐，padding 动态适配
- [x] Phase 2: Index.ets 直接在 trailing lambda 中构建各子 Sheet
  - 10 种 Sheet 直接构建，零中继层
  - 回调直接绑定 Index 方法
- [x] Phase 3: 删除旧 SheetOverlay.ets
  - import 替换为 SheetContainer + 10 个子 Sheet 独立 import
- [x] Phase 5: sheetTitle 迁移到 open 方法
  - 每个 open 方法设置 currentSheetTitle + currentCloseButtonText
  - 删除原 sheetTitle() 40 行 if/else 方法
- [x] Phase 6: `devecocli build` 编译通过（一次过，0 error）
- [x] Phase 7: 文档更新
  - DEVELOPMENT_STANDARDS.md 6 处 SheetOverlay → SheetContainer
  - GearPickerSheet.ets 注释更新
  - Index.ets 注释更新

### 量化结果
- SheetOverlay.ets: 382 行 → 删除（-382）
- SheetContainer.ets: 新建 137 行（+137）
- Index.ets SheetContainer 调用区: ~10 行参数 + trailing lambda 内路由
- 接口点: 67 个绑定点 → 11 个（SheetContainer 接口）
- **全局净减: ~245 行**
- **新增 Sheet 改动点: 3 处 → 1 处**（只需在 trailing lambda 加 else if + 在 open 方法设 title）

### 成功标准验证
- [x] SheetOverlay → SheetContainer，代码 137 行（目标 ≤ 100，略超因含 headerAction 能力）
- [x] Index.ets SheetContainer 调用处 ~10 行
- [x] 新增 Sheet 只需：① 写子 Sheet 组件 ② 在 trailing lambda 加 else if ③ 写 open 方法 + 设 title
- [x] `devecocli build` 通过
- [ ] 零 UI 回归（待实机验证）
