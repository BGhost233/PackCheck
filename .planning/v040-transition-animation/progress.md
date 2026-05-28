# 进度日志

## 会话 1 — 规划阶段

### 完成的工作
- 探索了项目当前导航架构（Navigation + NavPathStack，单 Page）
- 确认了 SheetOverlay 的当前实现（TransitionEffect + 条件渲染）
- 确认了所有 pushPathByName 调用点（4处）
- 查阅了华为官方文档：geometryTransition API、sharedTransition API、一镜到底最佳实践
- 评审了第三方规格书（packcheck-transition-spec.md）
- 确定技术方案：geometryTransition + animateTo 包裹 pushPath(false)
- 确定 Sheet 方案：animateTo + state 驱动 translateY 替代 TransitionEffect
- 创建了完整的 task_plan.md、findings.md

### 关键决策
1. 选择 geometryTransition 而非 sharedTransition（后者不支持 Navigation 路由）
2. 选择 geometryTransition 而非 Overlay Layer 手动方案（前者更简洁，API 23 应该稳定）
3. Sheet 改为 animateTo + state 驱动而非 TransitionEffect.animation(spring)（后者对 Spring 支持有 bug）
4. 保留 Overlay Layer 作为 fallback 方案

## 会话 2 — 执行阶段

### 完成的工作
- 阶段 1：AnimationTokens 新增 4 个 Spring 预设（HERO_EXPAND/COLLAPSE/PANEL_ENTER/EXIT）
- 阶段 2：HomePage HeroCard + HistoryRow 绑定 geometryTransition
- 阶段 3：ChecklistDetail 外层容器绑定 geometryTransition + NavDestination 加 transition
- 阶段 4：所有导航操作改为 animateTo 包裹 pushPath/pop(false)
- 阶段 5：SheetOverlay 移除 TransitionEffect，改为 state 驱动 translateY + opacity + backdropBlur
- 阶段 6：contentScale 联动、EditGearPanel/EditItemPanel/GearFilterPanel Spring 统一、全局 Curve 审计

### 当前状态
- **全部 6 阶段完成** ✅
- 实机验证通过，已修复后续问题

### 遇到的问题
- hvigorw 不在命令行 PATH 中，无法从终端构建验证，改用代码审查确认正确性

## 会话 3 — 实机验证修复

### 实机发现的问题
1. **HeroCard 消失不显示** — `{ follow: true }` 让组件脱离文档流，非转场态下位置异常
2. **历史行程返回闪白** — `follow: true` 导致组件布局重绘闪帧
3. **系统手势返回无转场效果** — 侧滑/右滑绕过 returnToHome()，直接 pop(true) 导致 geometryTransition 无法被驱动

### 修复方案
1. 移除所有 `{ follow: true }` 参数，改用 `.geometryTransition(id)` 无参形式
2. 移除为解决布局而添加的外层占位 Column 包裹
3. NavDestination 加 `.onBackPressed()` 拦截系统手势返回，统一走 `returnToHome()`

### 关键经验
- `geometryTransition({ follow: true })` 在复杂滚动列表场景下不可用，会破坏文档流
- 无参形式 `geometryTransition(id)` 只在转场瞬间接管组件，不影响常态布局
- Navigation 的系统手势返回不经过组件逻辑，必须通过 `.onBackPressed()` 拦截
