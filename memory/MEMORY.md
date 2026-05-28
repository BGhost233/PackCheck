# PackCheck 项目记忆

## 工作流约定

- **每次改动即 commit**：每次修改构建验证通过后，立即 `git add -A && git commit`，保持细粒度回滚点，方便随时回滚。
- **构建命令**：`export PATH="/Users/bghost233/Desktop/harmonyOS/command-line-tools/bin:$PATH" && hvigorw assembleApp --no-daemon`
- **先出方案再动手**：任何需求先输出理解+方案+理由，确认后才写代码。

## 设计决策

- 新建行程采用「宝可梦卡牌翻转」仪式感入场动画
- 确认出发采用「滑动出发」交互（正圆滑块骑在轨道上 + 白色遮罩吞噬已滑区域 + 磁吸吸附 + 卡片飘走）
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

## 已知限制

- hvigorw 不在默认 shell PATH 中，需 `export PATH="/Users/bghost233/Desktop/harmonyOS/command-line-tools/bin:$PATH"` 后使用
