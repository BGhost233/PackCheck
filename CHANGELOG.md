# Changelog

## v0.5.3 (2025-06-22)

清单页 Bug 修复 + 快速核查快捷入口。

- **Bug 修复：Sheet 覆盖层被 NavDestination 遮挡** — 将 SheetOverlay/EditItemPanel/EditGearPanel/TripCeremonyCard/CompletionToast 从 Navigation 内部移至外层 Stack，确保渲染在 NavDestination 之上
- **Bug 修复：清单详情页与首页数据不一致** — ForEach key 从 `item.id` 改为 `item.id + items.length + nonce`，新增 `checklistRenderNonce` 计数器强制刷新
- **Bug 修复：GearPage bindSheet borderRadius 无效属性** — 移除 SheetOptions 中不支持的 `borderRadius`
- **快速核查 QuickEntry** — 首页第二个快捷按钮从「装备库」替换为「快速核查」，点击直接进入最近未来行程的 ReviewMode，减少操作路径
- 按钮状态机：无未来行程隐藏；items=0 跳详情页+toast；全勾选"再检查一遍"；有未勾选"快速核查"
- CLAUDE.md 新增第 23~24 条避坑：Navigation 覆盖层层级 / ForEach key 变化维度

## v0.5.2 (2025-06-21)

装备库增强：弹性回弹 + 分组拖拽排序 + Bug修复。

- 弹性回弹：`EdgeEffect.Spring` + `alwaysEnabled: true`，内容不满屏时也有 iOS 风格橡皮筋效果
- 分组拖拽排序：长按 300ms 分组 header → 浮动整组跟手拖拽 → 碰撞检测让位 → 松手归位 + 持久化 categoryOrder
- 分组按压反馈：header 按下 `scale(0.97)` + `springMotion(0.25, 0.7)` 弹性回弹
- 灰色间隙修复：topSpacer 减去 List 的 padding-top + space，消除 Header 底边与首个分组间的灰带
- 搜索框修复：从 Column 流式布局移至根 Stack + `position(0, COLLAPSED)`，搜索展开时强制 Header 收缩
- PackStore 新增 `categoryOrder` 持久化（getCategoryOrder / saveCategoryOrder）
- CLAUDE.md 新增第 21~22 条避坑：浮动 Header spacer 计算 / 浮动组件定位

## v0.5.1 (2025-06-20)

多选拖拽交互全面优化，达到 Apple/Linear 级流畅度。

- 长按响应加速：多选模式下 LongPressGesture 400ms → 200ms，手指按下几乎立即触发拖拽
- 多选原地化：进入/退出多选不再销毁/重建 Header（消除跳页感），CollapsingHeader 内部 if/else 切换内容
- 拖拽跟手修复：去除手势坐标的 `px2vp` 误用 + DragGearStack 加 `.animation({duration:0})` 消除插值滞后
- macOS Dock 磁吸动效：底部行程卡片基于距离实时计算 proximity，连续 scale/translateY 变化 + 命中时弹跳确认 + 40ms 振动反馈
- 托盘视觉升级：capsule 拖拽指示器、`#E8FFFFFF` + backdropBlur(40)、border-radius 24、增强阴影
- 手势返回：根 Stack 添加 SwipeGesture(Horizontal) 右滑退出多选模式
- CLAUDE.md 新增第 18~20 条避坑：手势坐标单位/拖拽 duration:0/多选 Header 稳定性

## v0.5.0 (2025-06-19)

质感跃迁：视觉细节打磨，从「功能完整」迈向「值得截图」。

- 等宽数字：全局数字组件加 `.fontFeature("'tnum'")`，消除数字变化时宽度抖动（WeightGauge / HomePage 倒计时 / 清单进度 等 ~31 处）
- 噪点纹理背景：64×64 grayscale noise PNG 全屏平铺覆盖层（opacity 0.025），赋予界面纸张质感
- Section Breathing 分组呼吸：首个分组 marginTop 4vp、后续分组 20vp，列表组间有节奏性留白
- 暖琥珀警示色系：新增 `AMBER_ACCENT #E8890C` / `AMBER_TINT #FFF5E6`，用于倒计时 ≤3 天 + WeightGauge 80-100% 接近目标/预算态
- 卡片底部微边框：0.5vp `#F0F0F0` 底部边框，增强卡片层次感
- 错落动画加速度曲线：staggerDelay 公式升级为 `index * 30 + index² * 4`（cap 400ms），首项极快末项从容
- DesignTokens / AnimationTokens 新增多个设计常量
- 已回滚：打勾墨水扩散效果（实机表现不佳）

## v0.4.2 (2025-06-18)

结构重构：可读性与可维护性优化。

- Sheet 组件化提取：6 个 inline @Builder Sheet 提取为独立组件到 `components/sheets/`，新增 SheetOverlay 容器组件
- 命名空间导出优化：GearService/ChecklistService 新增 `GearCalc`/`CheckCalc` class 聚合导出，Index.ets import 区从 58 行别名缩减为 2 行
- Index.ets 从 2514 行精简至 2045 行（-18.6%），零功能/UI 变化
- CLAUDE.md 新增第 16 条避坑：ArkTS `arkts-no-untyped-obj-literals` 规则

## v0.4.1 (2025-06-17)

首页行程展示修复 & 装备库折叠屏适配。

- HeroCard 响应式修复：去参数化改为内部直接读 `latestChecklist()`，删除行程后卡片立即刷新
- 分区标题视觉优化："即将启程"/"走过的路" fontSize 13 + FontWeight.Medium + TEXT_SECONDARY + left padding
- 颜色系统统一：`heroGradientStart()` 全改为绿色深浅色阶，移除 COUNTDOWN_ORANGE，整体视觉从多色警告收拢为山野绿单色系
- 行程列表紧凑化：行高 72→60vp，时间轴圆点/竖线等比缩小，底部 padding 80→32vp 让内容穿透 TabBar 毛玻璃
- FAB 折叠屏适配：根容器 onAreaChange 监听尺寸变化，折叠/展开时 FAB 自动 spring 动画吸附到正确边缘

## v0.4.0 (2025-06-16)

动效与转场优化。

- 共享元素一镜到底转场：HeroCard / 历史行程卡片 → ChecklistDetail 使用 `geometryTransition` 实现从卡片位置连续展开到全屏，返回时收缩回原位
- geometryTransition 修复：移除 `{ follow: true }`（破坏文档流），改用无参形式；NavDestination 加 `.onBackPressed()` 拦截系统手势返回
- 转场参数调优：expand `springMotion(0.42, 0.73)`、collapse `springMotion(0.36, 0.78)`，兼顾弹性感和克制
- 转场时源页面 blur(12) + scale(0.94) 消散效果，增强空间纵深
- Sheet 面板 Spring 弹性动画：底部面板使用 `animateTo` + state 驱动 `translateY`，弹起带过冲回弹（dampingFraction 0.72），收回干脆无回弹（0.88）
- Sheet 背景遮罩改为毛玻璃效果（`backdropBlur(16)` + 浅色半透明）
- Sheet 展开时主内容 `scale(0.97)` 景深联动
- 新建行程仪式卡片弹出时背景 scale(0.94) + blur(12) 下沉效果，退场时与卡片动画同步恢复（通过 `onExitStart` 回调实现并行）
- EditGearPanel / EditItemPanel / GearFilterPanel 退出动画统一为 `SPRING_PANEL_EXIT`
- AnimationTokens 新增 4 个 Spring 预设：SPRING_HERO_EXPAND / HERO_COLLAPSE / PANEL_ENTER / PANEL_EXIT
- 移除所有面板级 `Curve.EaseIn` 残留，微交互短 duration 保持 EaseOut 不变

## v0.3.1 (2025-06-15)

仪式卡片交互完善 & 项目整理。

- 日期选择器修复：内联实现避免 `@Builder` 回调 this 丢失，选择日期后正确回显并应用到清单
- 日期格式补全：显示完整年月日（2025年6月15日）
- 未填名称时仅输入框水平抖动 + 边框闪红，不再整张卡片抖动
- 点击空白区域收起键盘（`onTouch(TouchType.Down)` 不阻塞子组件点击）
- 输入框字号统一为 14，与标题一致
- 项目文档和目录结构整理

## v0.3.0 (2025-06-14)

动效 & 微交互全面升级。

- 创建 AnimationTokens 统一管理 Spring 曲线参数
- 底部胶囊 Tab 果冻 pill 切换动效
- GearPage 分组折叠/展开 + 箭头旋转动画
- 清单 100% 完成庆祝动画
- WeightGauge 环形入场 + pill stagger 错落入场
- 底部渐变遮罩（edge fade）
- WeightGauge 重量/价格环切换
- TripCeremonyCard 宝可梦卡牌翻转入场 + 滑动出发交互
- 滑轨重设计：正圆 48vp 滑块骑在 36vp 轨道上，白色遮罩吞噬已滑区域
- 组件提取：TripCeremonyCard、EditGearPanel、EditItemPanel、GearFilterPanel

## v0.2.0 (2025-06-13)

首页体验升级。

- 数据排序修复（清单按创建时间倒序）
- GearPage 沉浸式折叠头部
- HomePage 折叠头部增强（滚动驱动标题缩放）
- 全屏沉浸式布局 + 窗口背景色统一 `#F8F9FA` 消除闪屏色差
- Phase tokens 引入，为动效升级打基础

## v0.1.0 (2025-06-12)

核心功能完成，首个可用版本。

- 装备库 CRUD（名称/分类/重量/价格/备注）
- 出行清单创建 & 打勾核查
- 从装备库导入物品到清单
- UI 精致化（Spring 动效、卡片圆角、主题色）
- 折叠头部基础实现
- 本地 Preferences 持久化
