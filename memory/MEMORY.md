# PackCheck 项目记忆

## 工作流约定

- **每次改动即 commit**：每次修改构建验证通过后，立即 `git add -A && git commit`，保持细粒度回滚点，方便随时回滚。
- **构建命令**：`export PATH="/Users/bghost233/Desktop/harmonyOS/command-line-tools/bin:$PATH" && hvigorw assembleApp --no-daemon`
- **先出方案再动手**：任何需求先输出理解+方案+理由，确认后才写代码。

## 设计决策

- 新建行程采用「宝可梦卡牌翻转」仪式感入场动画
- 确认出发采用「滑动出发」交互（正圆滑块骑在轨道上 + 白色遮罩吞噬已滑区域 + 磁吸吸附 + 三阶段仪式 + 卡片飘走）
- 滑块到达后三阶段仪式：Phase1 锁定确认（150ms，放大+波纹+双击振动）→ Phase2 充能蓄力（400ms，卡片收缩+文字切换+飞机旋转+光晕）→ Phase3 弹射升空（微放大+推力振动+飘走），总计~1000ms
- 滑动过程增强：按下 haptic.effect.soft + 颜色加深 + 轨道下沉；滑动中绿色进度条 + 25%/50%/75% 棘轮振动
- 主题色 `#2D7D46` 山野绿
- 所有动画使用 Spring 弹性曲线，严禁 linear/ease
- 页面转场使用 `geometryTransition(id)` 无参形式（非 sharedTransition；禁止 `{ follow: true }` — 会破坏文档流布局）
- NavDestination 加 `.onBackPressed()` 拦截系统手势返回，统一走 `animateTo { pop(false) }` 保证 geometryTransition 生效
- 转场 Spring 参数：expand `springMotion(0.42, 0.73)`，collapse `springMotion(0.36, 0.78)` — 经实机调优，兼顾弹性和克制
- 转场时源页面施加 `contentBlur=12` + `contentScale=0.94` 消散效果，增强空间纵深
- Sheet 面板使用 `animateTo` + state 驱动 `translateY`（非 TransitionEffect，后者不支持 Spring 曲线）
- Sheet 弹起 dampingFraction 0.72（有过冲回弹），收回 0.88（干脆无回弹）
- 新建行程仪式卡片弹出时背景同样 scale(0.94) + blur(12) 下沉，退场通过 `onExitStart` 回调与卡片动画并行恢复（EaseOut 400ms），避免延迟感

## 架构

- 已从 Index.ets 提取独立组件：TripCeremonyCard、EditGearPanel、EditItemPanel、GearFilterPanel
- 已删除废弃组件：EdgeFade.ets
- AnimationTokens.ets 中定义了 8 个 Spring 预设：SPRING_GENERAL / PRESS / TAB / COUNTER / SCROLL / HERO_EXPAND / HERO_COLLAPSE / PANEL_ENTER / PANEL_EXIT + 时长/缩放常量
- 导航架构：单 Page（Index.ets）+ Navigation NavPathStack，两个 NavDestination（ChecklistDetail、ReviewPage）
- TripCeremonyCard 暴露 `onExitStart` 回调，退场动画启动第一帧触发，供父组件并行驱动背景恢复

## 技术验证结论（避坑）

- HarmonyOS vibrator 可用预设：`haptic.clock.timer`（轻 tick）、`haptic.effect.soft`（柔）、`haptic.effect.hard`（重）、`haptic.effect.sharp`（锐）；支持 `count` 参数做连击
- `backgroundColor` 是 ArkUI 可动画属性，可用 `.animation()` 修饰器平滑过渡
- 波纹效果用固定数量 Circle 组件 + `.animation()` 修饰器驱动 scale/opacity，不用 ForEach 动态创建（避免 state 数组变化时序问题）
- 光晕层用独立 Column + blur + opacity 动画实现，`.shadow()` 的 color 插值不可靠
- SymbolGlyph 支持 `.rotate()` 变换（GearPage.ets 已验证）
- 文字切换用 Stack + 双 Text 的 opacity 交叉淡入实现，比条件渲染平滑
- 棘轮振动模式：在连续手势中按进度阈值触发振动，需用 state 记录已触发阈值防重复

## 已知限制

- hvigorw 不在默认 shell PATH 中，需 `export PATH="/Users/bghost233/Desktop/harmonyOS/command-line-tools/bin:$PATH"` 后使用
