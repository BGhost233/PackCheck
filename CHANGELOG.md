# Changelog

## v0.6.1 (2026-06-10)

Sheet 体系统一 & 交互打磨 & GearPage 瘦身起步 & 配装系统质量加固。

- **Sheet 体系统一**：9 种 Sheet 全部走集中式 SheetOverlay；移除 GearPage 中唯一的原生 `.bindSheet()`（移动到分组），新增 `SHEET_MOVE_GROUP` 模式 + `MoveGroupSheet` 组件
- **下滑关闭手势**：SheetOverlay 卡片新增 `PanGesture` 垂直下滑关闭（25% 高度阈值 + 0.3 边缘阻尼 + Spring 回弹），与 Scroll 内容手势自动协调
- **景深统一**：Sheet 弹出时主内容 `scale(0.94) + blur(12)`，与仪式卡片/页面转场景深参数对齐
- **GearPage 瘦身**：删除无用 `@Prop gearBudget`；删除 `showMoveGroupSheet` @State + `MoveGroupSheetContent` @Builder（@State 27→26，@Prop 10→9，回调 16→15）
- **配装系统质量加固**（三轮审查修复）：
  - Critical：7 处 @State 数组原地 splice → spread 副本（GearPage + WeightGauge）
  - Timer 泄漏：LoadoutView 去除 setTimeout 改纯属性动画；LoadoutProgressBar 新增 aboutToDisappear 清除 counterTimerId
  - 退场动画：LoadoutZoneCard + LoadoutGearItem 添加 TransitionEffect（opacity + scale 0.95）
  - Counter 脱同步：移除 displayChecked !== checked 前置判断，无条件启动新动画
  - 空态补全：GearPickerSheet 品类筛选空态文案
  - 防御：tempWeight NaN 校验；onDeleteTrip 接线；TripDetailPage 按压缩放统一；GearItemActionSheet/MoveGroupSheet 全行按压反馈
  - Token 统一：TripCeremonyCard setTimeout→onFinish + 硬编码hex→token；HomePage/GearPage CURVE_DECELERATE→Spring
- **文档重组**：删除 10 个废弃/已完成的设计/规划文档；docs/ 目录重组为 vision/v2-foundation/archive 三层结构；新增中短期路线图 ROADMAP.md

## v0.6.0 (2026-06-09)

v2「服役档案」转型 · 第一步地基层完整落地。

- **Tab 架构 2→3**：新增「我」Tab + `ProfilePage` 人生足迹年报叙事（沉浸绿幕、counter 滚动数字、拟人化文案、留白）
- **数据模型补全**：`GearItem` 加 `brand?`/`acquiredAt?`（optional）；`TripChecklist` 加 5 个结构化字段（`destination?`/`distanceKm?`/`maxAltitude?`/`ascentM?`/`durationHours?`）
- **删除趋势图链路**：`AssetTrendCard.ets` + `AssetEvent`/`AssetTotals` 接口 + `KEY_ASSET_EVENTS` 持久化链路全部删除
- **装备展开区改双段结构**：上段属性区（packing：重量/分组/品牌/价格）+ 下段陪伴区（archive：陪伴天数大数字 + 三 chip）
- **行程录入改渐进式 chip**：5 个结构化字段藏成可点亮 chip，点亮才展开输入，规避记账困境
- **配装数据种子**：新增 `GearLoadout.ets`（`BodyZone`/`LayerOrder` 枚举 + `CATEGORY_SLOT_MAP` 映射表），为第二步塔科夫配装预埋
- **人生足迹引擎**：新增 `FootprintService` 纯函数聚合（累计里程/爬升/海拔/地点数/相伴最久伙伴）
- **全局文案温柔化**：按 spec 文案词典替换军事/资产措辞
- **CATEGORY_ALL/CATEGORY_FALLBACK sentinel constants**：统一替换全项目 `'全部'`/`'其他'` 硬编码字符串

## v0.5.9 (2026-06-10)

全量代码审查修复：213 项问题一次性清零。

- **Critical 修复**：PackStore 无 try-catch → 全方法防御式错误处理 + schema 版本迁移 + hilog；`PRIMARY_FILL_SUBTLE` ARGB 字节序修正（`#2D7D4660` → `#602D7D46`）；GearFormSheet/TempItemSheet `onRename` 参数传空字符串 → 正确传递 oldName；ColorUtils `daysLeft > 0` 少算一天 → `>= 0`
- **Medium 修复**：ChecklistService 消除 `!` non-null 断言（改 `?` + 默认值）、删除死代码、统一 `formatKg` 引用；FootprintService `maxAltitude` 初始值 0 → `-Infinity`、排序稳定性、NaN 守卫、dateLabel 兜底
- **Index.ets 清理**：tabCount 常量化、`sort()` 拷贝防原地排序、CategoryInputDialog 色彩 token 化、TransitionEffect 链式组合、空 catch → hilog.warn、DatePicker 编辑模式共用逻辑消除重复、Set-based 去重替代 indexOf
- **动效合规**：TripCeremonyCard 22 处非 Spring 动画统一为 `SPRING_GENERAL`/`SPRING_PRESS`（保留 3 处 shimmer/shine 用 CURVE_STANDARD）；ChecklistDetail 去除 `setTimeout` 驱动动画改 `animateTo` + opacity(0) 初始隐藏
- **ProfilePage token 化**：硬编码色值/字号/按压缩放全部替换为 Design Token 引用；「征服」→「探索」措辞修正
- **CategoryTagGroup**：`setInterval` 泄漏修复（`aboutToDisappear` 清除）；wiggle 状态 tick→flip 简化；`as number` cast 移除；CATEGORY_ALL 常量
- **PackModels**：新增 `CATEGORY_ALL`/`CATEGORY_FALLBACK` 常量；`makeId` 加入单调递增计数器防碰撞
- **CategoryService**：`renameCategory` 返回类型从 `string[]` 改为 `RenameCategoryResult { categories, renamed }`
- **WeightGauge**：gaugeMode 切换包裹 `animateTo` 实现平滑过渡
- **TripFormSheet**：日期格式改为距今年份不同时显示年份；新增字段校验防空提交
- **EntryAbility/EntryBackupAbility**：hilog testTag 统一为 'PackCheck'，domain 0x0001；移除无意义 `await Promise.resolve()`
- **Constants 类型标注**：Layout/GearSort/SheetMode/AnimationTokens 显式 `: number`/`: string` 类型注解
- **暗色模式**：`dark/color.json` 背景从 `#F8F9FA` 修正为 `#121212`
- **module.json5**：移除 `"wearable"` deviceTypes（手表不适配本 App）
- **Press 反馈补全**：GearSortSheet/ProfileEditSheet/ImportSheet/HomePage 所有可点击元素添加 `pressScale()` 按压反馈
- **不可行项**：ArkTS 禁止对象展开运算符 `arkts-no-spread`（#6）；`@Prop` 不支持接口分组（#11）— 标记为平台限制，不改
- MEMORY.md 新增避坑经验 + 构建路径更新

## v0.5.8 (2026-07-01)

编辑模式 Bug 修复 & 装备库空态重设计。

- **修复：编辑模式删除角标不显示** — `.overlay()` 内条件渲染（`if isEditMode`）不可靠触发重绘，改为 Stack + `.position({top:-5, right:-5})` + `.clip(false)` 方案，角标点击用 `.hitTestBehavior(HitTestMode.Block)` 阻止穿透
- **修复：重命名分类变成新建** — `validateCategoryName` 和 `CategoryService.renameCategory` 的重复检测未排除 oldName，导致 "已存在" 误判。修复：校验前从列表中过滤掉 oldName
- **装备库空态重设计** — 移除漂流瓶插画和白色卡片容器（宽度与上方 AssetTrendCard 不对齐），改为透明背景 + 64vp 圆形图标 + 双行文案 + 绿色胶囊按钮的轻量空态
- MEMORY.md 新增避坑 #36：`.overlay()` 条件渲染不可靠

## v0.5.7 (2026-05-31)

装备库左滑删除修复 & 动效架构优化。

- **修复左滑删除按钮消失**：commit c51f597 将 GearRow 容器从 Stack 改为 Column 导致内容行平移后仍覆盖底层删除按钮（Column 子元素不重叠），恢复 Stack 布局
- **修复删除按钮铺满全屏**：Stack 内 `height('100%')` 无论常规流还是 position 定位都不可靠，改为固定 52vp + `alignContent: Alignment.End` 靠右对齐
- **修复左滑动效硬切无动画**：`.animation({ duration: 0 })` 与 `animateTo` 冲突（避坑 #7），移除后利用 `.animation()` 作用域规则自然隔离 translate 不被前置 animation 捕获
- **删除按钮出场动效**：条件渲染 + `TransitionEffect.asymmetric`（进场 opacity+translate Spring，退场快速淡出）
- **展开态禁止左滑**：展开详情时 `onActionUpdate`/`onActionEnd` 直接 return，避免展开态触发危险删除操作
- **删除按钮视觉升级**：从纯文字改为 trash 图标 + 文字垂直排列，全高红色区域匹配折叠态行高
- MEMORY.md 避坑 #28 补充 position 场景 + 新增 #35（animation 作用域隔离正确姿势）

## v0.5.6 (2025-06-24)

动效 Token 体系全面审查修复。

- **P0 修复：WeightGauge ring 动画冲突** — `.scale()` 同时有 `.animation()` 和 `animateTo()` 竞争导致卡顿，移除 `.animation()` 修饰
- **P0 修复：GearSortSheet rest-state 违规** — 按压松手后 scale 停留在 1.02（`PRESS_SCALE_BOUNCE`），改为 1.0（`PRESS_SCALE_REST`）
- **P0 修复：CURVE_STANDARD 曲线值错误** — 原值 `Curve.EaseInOut`(0.42,0,0.58,1) 是对称曲线，改为 `curves.cubicBezierCurve(0.4, 0, 0.2, 1.0)` 符合 HarmonyOS Standard 非对称减速曲线
- **全量清除 Spring+duration 混用** — ~50 处跨 12 个文件（GearPage/HomePage/ChecklistDetail/TripCeremonyCard/EmptyIllustration/GearSortSheet/Index/EditGearPanel/EditItemPanel/AnimationUtils 等），Spring 忽略 duration，错落延迟改用 `delay` 字段
- **AnimationTokens 死代码清理** — 删除 8 个无消费者导出（DURATION_PULSE/TAB/ENTRANCE/GAUGE、STAGGER_DELAY_MENU/LIST/SWIPE、PANEL_SCALE_DISMISS）
- **Typography 去重** — 删除重复常量 `FONT_FEATURE_TABULAR_NUMS`
- **Index.ets 清理 19 个未使用 import**
- **硬编码色值 → Colors token** — TripCeremonyCard/AssetTrendCard/GearPage/HomePage/Index 中 `Color.Transparent` 和自定义色值统一替换为 `TRANSPARENT`/`PRIMARY_TRANSPARENT`/`WHITE_SEMI_TRANSPARENT`
- **箭头函数类型标注补全** — GearPage/HomePage 排序回调等
- **DEVELOPMENT_STANDARDS.md 更新** — 3.6 节从 5 条扩展到 6 条 + 新增 CURVE_LINEAR 例外说明 + Token 导入路径政策 + 动效检查清单扩充
- MEMORY.md 避坑清单从 28 条扩展到 34 条

## v0.5.5 (2026-05-31)

装备库布局 Bug 修复。

- **修复装备卡片高度异常**：GearRow 内部 `Stack { Row().height('100%') }` 形成循环依赖导致运行时高度撑满屏幕。移除 Stack，删除按钮改用 `Column` + `position()` 绝对定位，不参与布局测量
- MEMORY.md 新增第 28 条避坑：Stack 子组件禁止 height('100%')

## v0.5.4 (2025-06-22)

装备库 5 项体验优化：交互细节打磨。

- **搜索自动展开分组**：搜索有关键词时 `isGearGroupCollapsed()` 强制返回 false，匹配结果所在折叠分组自动展开
- **拖拽浮动卡片定位修正**：浮动分组卡片 Y 坐标从 `groupDragY - 20` 调整为 `groupDragY - 14`，手指下方直接出现卡片
- **分组折叠 Spring 动画**：`animateTo(springMotion(0.35, 0.8))` + `.transition(OPACITY + translate)` 实现丝滑展开/收起
- **多选点击区域扩大**：PanGesture distance 从 0 → 5，轻点整行即可 toggle 选中（不再只有 checkbox 响应）
- **行程托盘动态滚速**：边缘加速（二次曲线 t²），minSpeed=2 / maxSpeed=12，托盘尺寸优化（卡片 88×68，间距 10）
- CLAUDE.md 新增第 25~27 条避坑：搜索态绕过折叠 / PanGesture distance 阈值 / if-else 过渡动画

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
