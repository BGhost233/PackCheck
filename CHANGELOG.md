# Changelog

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
