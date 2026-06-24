# PackCheck 项目记忆

## 工作流约定

- **每次改动即 commit**：每次修改构建验证通过后，立即 `git add -A && git commit`，保持细粒度回滚点，方便随时回滚。
- **构建命令**（推荐，多轮验证有效）：
  ```bash
  cd /Users/bghost233/Documents/PackCheck && \
  export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" && \
  export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" && \
  node "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js" assembleApp --no-daemon 2>&1 | grep -E "ERROR|BUILD"
  ```
  用 DevEco-Studio 内置的 hvigor + node + SDK，必须导出 `DEVECO_SDK_HOME`。`grep -E "ERROR|BUILD"` 过滤出关键行。任务名 `assembleApp` 对当前工程**有效**（与 CLAUDE.md 铁律2 一致，已多次 BUILD SUCCESSFUL）。
  （历史备注：曾尝试 `assembleHap --mode module -p product=default`，亦可，但统一以 `assembleApp` 为准。）
- **备用命令行构建**（DevEco Studio 未安装时）：
  ```bash
  cd /Users/bghost233/Documents/PackCheck && \
  export DEVECO_SDK_HOME="/Users/bghost233/Desktop/harmonyOS/command-line-tools/sdk" && \
  export PATH="/Users/bghost233/Desktop/harmonyOS/command-line-tools/tool/node/bin:$PATH" && \
  node "/Users/bghost233/Desktop/harmonyOS/command-line-tools/hvigor/bin/hvigorw.js" assembleApp --no-daemon 2>&1 | grep -E "ERROR|BUILD"
  ```
  Desktop 路径为独立 command-line-tools 安装，SDK 路径比 DevEco-Studio 多一层 `command-line-tools/sdk`。两套均验证 BUILD SUCCESSFUL。
- **先出方案再动手**：任何需求先输出理解+方案+理由，确认后才写代码。

## 设计决策

- 新建行程采用「宝可梦卡牌翻转」仪式感入场动画
- 确认出发采用「滑动出发」交互（正圆滑块骑在轨道上 + 白色遮罩吞噬已滑区域 + 磁吸吸附 + 三阶段仪式 + 卡片飘走）
- 滑块到达后三阶段仪式：Phase1 锁定确认（150ms，放大+波纹+双击振动）→ Phase2 充能蓄力（400ms，卡片收缩+文字切换+飞机旋转+光晕）→ Phase3 弹射升空（微放大+推力振动+飘走），总计~1000ms
- 滑动过程增强：按下 haptic.effect.soft + 颜色加深 + 轨道下沉；滑动中绿色进度条 + 25%/50%/75% 棘轮振动
- 主题色 `#2D7D46` 山野绿；列表元信息分隔点用 `META_SEPARATOR(#C2C2C2)`（弱于 plain 文字 #999、强于背景线；不要用 `DIVIDER_COLOR(#F0F0F0)` — 过淡看不见）
- 所有动画使用 Spring 弹性曲线，严禁 linear/ease
- **顶部折叠范式统一（对齐 iOS Large Title）**：项目内所有 head 随滚动折叠场景（首页/装备库/行程详情）统一走 `HeadCollapseController`。体验决策（第一性原理+Apple 标准自主定）：跟手期 progress 严格 1:1 实时映射（零吸附、不抢手感，走 `SPRING_HEAD_FOLLOW`）；松手惯性停在 (0,1) 中间态才就近吸附到 0 或 1（走 `SPRING_SCROLL`），绝不留半折叠残缺态。两种互不兼容的布局范式对控制器透明：inline 塌缩（TripDetailPage，head 真实兄弟节点高度归零）vs overlay 定高变形（HomePage/GearPage，head 用 `.position` 浮起靠字号/透明度变形）
- `geometryTransition` 两种语境，参数不同（详避坑 #10）：跨页 Navigation 转场（`trip-*`）用**无参形式**（follow:true 会破坏文档流布局）；同页就地放大（`zone_*` 网格态↔聚焦态）用 **`{ follow: true }`**，前提是两端 `ZoneShell` 外壳 100% 一致 + 同帧赋值
- NavDestination 加 `.onBackPressed()` 拦截系统手势返回，统一走 `animateTo { pop(false) }` 保证 geometryTransition 生效
- 转场 Spring 参数：expand `springMotion(0.42, 0.73)`，collapse `springMotion(0.36, 0.78)` — 经实机调优，兼顾弹性和克制
- 转场时源页面施加 `contentBlur=12` + `contentScale=0.94` 消散效果，增强空间纵深
- Sheet 面板使用 `animateTo` + state 驱动 `translateY`（非 TransitionEffect，后者不支持 Spring 曲线）
- Sheet 弹起 dampingFraction 0.72（有过冲回弹），收回 0.88（干脆无回弹）
- 新建行程仪式卡片弹出时背景同样 scale(0.94) + blur(12) 下沉，退场通过 `onExitStart` 回调与卡片动画并行恢复（EaseOut 400ms），避免延迟感

- 多选拖拽交互设计：长按 200ms 进入拖拽，Header 原地切换内容（不销毁/重建），浮动卡片 `duration:0` 即时跟手，底部托盘 macOS Dock 磁吸放大，右滑 SwipeGesture 退出多选
- 磁吸动效参数：影响半径 140vp，scale 1.0~1.1 连续变化，translateY 0~-10vp 涌起，动画 duration 160 + EaseOut（不用 Spring 避免过度弹性）
- 分组拖拽排序设计：长按 300ms 分组 header 激活 → 浮动整组（scale 1.03, rotate -1°, elevated shadow）跟手 → 碰撞检测用累积高度+中线穿越 → 松手 spring 归位 → categoryOrder 持久化
- GearPage 搜索展开策略：搜索框不放 Column 流中（会被浮动 Header 遮挡），改用根 Stack + position(0, COLLAPSED) + zIndex(9)，展开时强制 Header 收缩 + 重置滚动位置
- GearPage 搜索联动折叠状态：`isGearGroupCollapsed()` 在有搜索关键词时直接返回 false，搜索结果所在分组自动展开，无需额外展开逻辑
- GearPage 左滑删除与展开详情互斥：展开态禁止左滑手势（`onActionUpdate`/`onActionEnd` 中 `if (expandedGearId === item.id) return`），删除按钮固定 52vp 高度匹配折叠态行高
- 多选拖拽 vs 点击共存：PanGesture distance 从 0 改为 5，让轻点正常走 onClick（toggle 选中），只有真正拖动才激活 Pan
- 分组折叠/展开动画：`animateTo(springMotion(0.35, 0.8))` 包裹 state 赋值 + 内容 Column 加 `.transition(TransitionEffect.OPACITY.combine(translate({y:-6})))` 实现丝滑进退场
- **装备库单品拖拽避让设计（问题9-A，v0.7.7）**：被拖项 `opacity(0)` 留透明洞，`gearRowShiftY(item)` 按「含被拖项的完整分组列表」full index 算兄弟行 translateY 把洞「视觉迁移」到插入点（向下拖洞与落点间行上移填洞、向上拖落点到洞间行下移让缝、跨分类拖入落点及之后整体下移），全程 SPRING_GENERAL。模块常量 `GEAR_ROW_HEIGHT=52`（44 content + 4×2 padding）让位量与命中检测共用。**关键**：让位计算与 `hitTestGearDrop` 必须基于同一坐标系（含被拖项完整列表），否则洞迁移与命中点对不上
- **装备库拖拽 spring-load 悬停自动展开设计（v0.7.7）**：拖到折叠分组悬停 500ms 自动展开（参考 iOS 文件 App 拖入文件夹）。「拖拽期临时展开集合」`gearDragTempExpanded` 与持久化折叠偏好 `collapsedGearGroups` 解耦，`isGearGroupCollapsed` 把临时展开视为不折叠复用现有 SPRING 展开链路。悬停目标切换清旧计时器 + SPRING 收回旧临时展开（路过即收）。落位转正：先移出 `collapsedGearGroups` 并持久化、**再**清空临时集合（顺序反了会瞬间闪折叠）。dismissGearOverlay/cancel 路径兜底全收，幂等
- 行程托盘动态滚速：边缘区域 100vp，二次曲线加速 `speed = minSpeed + (maxSpeed - minSpeed) * t²`（min=2, max=12），手感自然。Timer 每次回调读 mutable field `trayScrollSpeed`，无需重启 timer 即可变速
- 行程托盘尺寸优化：位置从 screenHeight-200 → screenHeight-240，卡片从 100×80 → 88×68，间距 12→10，容纳更多行程

### Tab 切换 visibilityNonce 单点递增规则（2026-06-24 修复）

- **问题**：HdsTabs `onAnimationStart` + `onChange` 双重递增 `homeVisibilityNonce`，导致子组件 `@Watch` 回调被连续触发两次——第一次 stagger 刚启动就被第二次 reset 打断，造成闪烁 + HeroCard 倒计时归零
- **修复铁律**：visibilityNonce 只在**一处**递增。滑动切换→`onAnimationStart`；点击切换→`triggerBlurPulse`。`onChange` 是兜底确认回调，**不递增 nonce**（只做 swipeReset）
- **配套**：`onTabVisibilityNonceChange` 中 reset 后必须**主动调用** `startHeroNumberAnimation()` + `startProgressAnimation()`——TabContent keep-alive 下 `.onAppear` 不会再触发
- DayCard 删除了冗余的绿色「展开添加路段 ›」提示——违反交互入口原则（点击卡片即可展开，不需要额外文字入口）

### HDS（@kit.UIDesignKit）使用边界（2026-06-13 落地）

- **核心结论：HDS 在本项目只做「材质/视效层增强」，不做「框架替换」。** 项目所有自绘顶栏（HomePage Hero 卡 / GearPage 搜索工具栏 / 各页 HeadCollapseController 折叠导航）保真度高于 HDS 标准组件，替换 = 降质，已否决。
- **唯一框架级替换：根容器 `Navigation` → `HdsNavigation`**（Index.ets）。零视觉风险，因为 `.hideTitleBar(true)`。SDK 已验证 `HdsNavigation(pathInfos?: NavPathStack)` 直接承接既有 `navPathStack`；`.navDestination(builder)` 的 `NavDestinationBuilder = (name, pageInfos) => void` 与现有行内 `NavDestinationMap` 签名兼容，**无需 routerMap 迁移**。`HdsNavigationAttribute extends CommonMethod`，`.mode()/.hideTitleBar()/.backgroundColor()/.expandSafeArea()` 全部继承可用。`geometryTransition('trip-*')` 跨页共享元素转场与 HdsNavigation 兼容（构建+实测通过）。
- **hdsEffect 按压视效叠加范式**：在「高频 + 按压语义纯粹的点进去卡片」上叠 `pressShadow`。做法：`@State pressShadow` 或复用已有按压态 id，节点上加 `.visualEffect(new hdsEffect.HdsEffectBuilder().pressShadow(按下?BLEND_GRADIENT:NONE).buildEffect())`，在既有 `.onTouch` Down/Up 里切。已落地：HomePage Hero 卡、GearPage 装备卡（normal 模式，多选 compact 行不加）。
- **⚠️ hdsEffect 沉浸视效模拟器不渲染，仅真机生效**（不影响构建）。设计/验收需 push 真机。
- **被否决的叠加点**：TripDetailPage 无独立核心卡片（NavBar 是 icon 按钮、SharedInfo 是文字行）；真正卡片 `ZoneShell` 已被 `geometryTransition('zone_*')` 共享元素转场 + 长按转拖拽浮层占用，叠 pressShadow 感知极弱且与转场材质冲突 → 不做。原则：不往最复杂的交互节点塞视效。
- **SDK 类型定义事实源**：`/Applications/DevEco-Studio.app/Contents/sdk/default/hms/ets/api/@hms.hds.hdsBaseComponent.d.ets`。API 签名不确定时直接读它，不靠搜索猜。

### 聚焦态完整交互体系（问题4，v0.7.0）

- **4a 收起态透传链**：focusedZone 由 Index `@State` 源 → TripDetailPage `@Link` → UnifiedChecklistView `@Link` → FocusedZoneView `@Prop active` 三层透传。onBackPressed 分层拦截：sheet 打开→closeSheet / focusedZone≠null→focusedCloseSignal++ / else→returnToHome
- **4a 收起保留动画技巧**：Index 不直接改 focusedZone（会丢 SPRING_HERO_COLLAPSE 转场动画），而是递增 `focusedCloseSignal: number`，下游组件 @Watch 后调组件内 `closeFocus()` 走正常退场
- **4b 点空白/左右划收起**（v0.7.2 修正实现）：借力 ArkUI 事件消费机制——子元素各自 `.onClick` 消费自己的点击不冒泡，只有点空白区才冒泡触发收起。配 `PanGesture({direction: Horizontal, distance: 24})` 左右划也收起，不新增返回按钮。
  - **⚠️ 关键修正**：收起点击**不能**在 `FocusedZoneView` 外部给 `ZoneShell{}` 实例外挂 `.onClick`——会被 ZoneShell 根节点自身已有的 `.onClick` 抢占而失效（详见避坑 #42）。正确做法：复用 ZoneShell 内部已验证的链路，传 `contentClickable: true` + `onTapContent: () => onClose()`，与网格态 `ZoneGridCell` 进聚焦的机制完全一致。`gesture(PanGesture)` 外挂则不受此限制，左右划仍外挂在 ZoneShell 实例上有效
- **4c 单击装备名展开详情（手风琴）**：ChecklistRow 用 `checkOnlyHotzone: true` 让 check 圆圈只负责勾选、行其余调 `onTapRow` → `toggleExpand(item.id)`（SPRING_GENERAL 手风琴 toggle，同时只展开一个）。详情 buildItemDetail 经 fromGearId 反查 GearItem 取 category/brand/note，用 Flex wrap chips 展示。ForEach key 拼入展开态 `(expandedItemId===item.id?'e':'c')`。进退聚焦时 onActiveChange 重置 expandedItemId
- **4d 长按菜单 + 拖拽跨区（推迟 phase4）**：onEditItem/onRemoveItem/onMoveItemToZone 三回调透传链已贯通到 FocusedZoneView 并预埋注释，Index.moveItemToZone 改 group 逻辑已就绪。手势消费方（长按弹菜单 + 长按不松手转拖拽收缩网格跨 Zone）留待 phase4。方案建议见 plan §六：阈值分流（短按展开/长按菜单）+ 收缩网格拖放

### 行程编辑模块（v0.7.8，2026-06-24）

- **TripDetailPage Tab 架构**：从 Stack+if 切换改为原生 Tabs 组件，双 Tab（装备/行程）左右滑动切换。Tab 标题用 `onGestureSwipe` 跟手颜色插值——`currentOffset` 为 vp 位移（负值=内容左移=朝 index+1），progress 公式：`tabIndex - offset / tabsWidth`。颜色从阈值硬切改为 RGB hex 通道逐字节插值（channel 153↔26），跟手时零跳变
- **DaySummary 缓存范式**：DayCard 用 `@Prop @Watch('onDayChange') day` 驱动 `cachedSummary` 重算，build 中 O(1) 读。注意 `@Watch` 必须写在 `@Prop` 声明上（`@Prop @Watch('onDayChange') day: ItineraryDay`），不能作为独立装饰器
- **TransitionEffect.asymmetric 非对称进退场**：展开进入从下方 `translate({y:8})` + 淡入，退出向上 `translate({y:-4})` + 淡出。比对称 transition 更有方向感
- **stateStyles 原生按压态**：`@Styles segRowPressed() { .backgroundColor('#0D000000') }` + `@Styles segRowNormal() { .backgroundColor(Color.Transparent) }` + `.stateStyles({ pressed: segRowPressed, normal: segRowNormal })`——零额外 @State 实现按压高亮
- **switchTab head collapse 重置**：切 Tab 时需重置 headProgress 到 0，必须包裹 `animateTo` 否则硬切（头部瞬间弹回无过渡）。正确：`animateTo({ curve: SPRING_SCROLL() }, () => { this.headProgress = 0 })`
- **ItineraryService 纯函数层**：`getDaySummary`/`getTransportIcon`/`addDay`/`insertDay`/`removeDay`/`updateDay`/`addSegment`/`removeSegment`/`updateSegment`/`createEmptySegment` 均为 immutable 操作（返回新 itinerary 对象），持久化由调用方统一处理
- **新组件文件**：`components/gear/ItineraryView.ets`、`components/gear/DayCard.ets`、`components/sheets/SegmentFormSheet.ets`、`components/sheets/DayFormSheet.ets`、`services/ItineraryService.ets`
- **DayItinerary 数据模型**：v0.7.8 后增加 `from`/`to` 字段，天级起止与路段解耦

## 架构

- 已从 Index.ets 提取独立组件：TripCeremonyCard、EditGearPanel、EditItemPanel、GearFilterPanel
- 已提取 Sheet 面板组件到 `components/sheets/`：SheetOverlay（容器）、GearSortSheet、GenerateTripSheet、GearFormSheet、TripFormSheet、TempItemSheet、ImportSheet
- GearService.ets 导出 `class GearCalc`，ChecklistService.ets 导出 `class CheckCalc`，Index.ets 通过 namespace import 调用
- 已删除废弃组件：EdgeFade.ets、EmptyIllustration.ets、WeightGauge.ets
- CategoryService.ets 导出 `renameCategory` 返回 `RenameCategoryResult { categories: string[], renamed: number }`
- FootprintService.ets 提供足迹/海拔/距离统计
- PackModels.ets 导出 `CATEGORY_ALL`（哨兵常量替代魔法字符串 '全部'）和 `CATEGORY_FALLBACK`（受保护分类 '其他'）
- `makeId()` 使用 `Date.now()` + 模块级单调递增计数器防碰撞
- PackStore.ets schema 版本化（v1），初始化失败时 `initFailed` 标志位阻止写入
- AnimationTokens.ets 中定义了 9 个 Spring 预设：SPRING_GENERAL / PRESS / TAB / COUNTER / SCROLL / HERO_EXPAND / HERO_COLLAPSE / PANEL_ENTER / PANEL_EXIT + 时长/缩放常量；另有 `SPRING_HEAD_FOLLOW = curves.responsiveSpringMotion(0.15, 1.0)`（跟手近 1:1）供顶部折叠专用
- **HeadCollapseController.ets（utils/，统一折叠数学内核）**：普通有状态 class，抽象边界 = 只统一「滚动数学」（progress 计算/跟手 1:1/松手就近吸附/曲线分流/强制折叠），**不统一 head 渲染**。配置走 `HeadCollapseConfig`：collapseDistance(折叠总位移 vp)/enableSnap/getUIContext(注入)/onChange(progress,snapping)/snapThreshold?。关键方法：`progress()` 返 forcedCollapsed?1:scrollProgress；`curve()` 分流(吸附/强折走 SCROLL、跟手走 HEAD_FOLLOW)；`handleScroll(scroller)` 挂 Grid.onScroll / List·Scroll.onDidScroll；`handleScrollStop(scroller)` 挂 .onScrollStop 做中间态吸附(scrollTo+animateTo)；`setForcedCollapsed(forced)` 旁路强折（聚焦/搜索）。三处已迁移对齐：TripDetailPage(UnifiedChecklistView 持控制器、TripDetail 只消费回调)、HomePage、GearPage。⚠️ GearPage 锁定态（searchExpanded/multiSelect）**不走 setForcedCollapsed**——搜索态视觉（纯背景 PAGE_BG/零模糊）≠ progress=1（半透明毛玻璃 #CCF8F9FA/模糊40），保留 bg/blur 特判、零视觉回归
- 导航架构：单 Page（Index.ets）+ Navigation NavPathStack，两个 NavDestination（ChecklistDetail、ReviewPage）
- TripCeremonyCard 暴露 `onExitStart` 回调，退场动画启动第一帧触发，供父组件并行驱动背景恢复
- **统一核查清单视图（v0.7.0 第二灵魂）**：行程详情页砍掉配装/清单 SegmentButton 切换，合并为单一 `UnifiedChecklistView`。组件结构：
  - `UnifiedChecklistView`（容器）：网格态展示 7 个身体部位 Zone（2 列网格 + 杂项跨列），管理 focusedZone / focusedCloseSignal 透传
  - `ZoneShell`（v0.7.1 抽出）：网格态与聚焦态**共用同一外壳**（标题行浅染 `ZONE_*_TINT` + `ZONE_*_STROKE` 描边），两端 100% 一致是 `zone_*` geometryTransition `{ follow: true }` 就地放大不退化的前提。`@Prop contentDashed` 开关：为 true 时内容容器降级为透明无装饰占位（供空态复用外壳但不抢视觉权重）
  - `ZoneGridCell`：单个格子卡片，满格走 `ZoneShell` 白卡、点击触发 `zone_*` 转场；空格子走 `ZoneShell(contentDashed:true)` 的虚线降权框（`buildEmptyContent`）**不进 geometryTransition**—「空轻满重」B-3：空态不抢视觉权重。已删 `buildTitleRow` 平行实现
  - `FocusedZoneView`：全屏聚焦态，点格子放大铺满全屏逐项核查；内含 ChecklistRow 列表 + buildItemDetail 手风琴详情 + buildAddRow。item 行长按手势用 `Column` wrapper + `LongPressGesture`（O3：与网格态统一，不用透明 Stack 图层）。
    - **v0.7.2 满铺精装修**：顶部日期行 + 进度条双层 collapse 收没让渡空间，卡片满铺顶到 navbar 下沿（不再悬浮 maxHeight '80%'）；遮罩改纯羽白实心（`PAGE_BG`）盖住网格虚影；聚焦卡片用 `ZONE_*_FOCUS_BG`（20% 白底混合的近实心淡色，浮在白遮罩上不能用半透明否则透白发灰）+ `focusBorder: true`（2vp zone 主题色实色边框，给卡片实体轮廓）；去掉右上角 ×键，改「点卡片空白返回」（见 4b 修正）
  - `ChecklistRow`：单行装备，契约 `checkOnlyHotzone=true` → check 圆圈负责勾选、行其余区域调 `onTapRow`（聚焦态用于展开详情）
  - Zone 映射：`BodyZone` 枚举 + `CATEGORY_SLOT_MAP` 在 `constants/GearLoadout.ets`；`groupByZoneAll`/`groupByZone`/`sortItemsByLayer` 等聚合函数在 `services/LoadoutService.ets`。装备按 `category` 查表自动归入格子
- `ChecklistItem { id, name, group, checked, weight?, price?, fromGearId? }`（无 category/note/brand；聚焦态详情经 fromGearId 反查 GearItem 取 category/brand/note）
- **结构防腐铁律已成文**（2026-06-14）：DEVELOPMENT_STANDARDS 第八章 + CLAUDE.md 会话启动第一动作。新增代码前必须 grep-before-add（先查全仓有无同名/同义实现再写）；判死代码看可达性（入口无调用点 → 整链不可达 → 可删）；拆分看阈值（>300行/>10 @State/>8 props/>60行方法），但动画状态机、geometryTransition 两端、拖拽浮层、Index 容器、内联 @Builder **不拆**
- **targetWeightGram/WeightTargetEditor 死代码已清理**（commit `63f079a`）：openWeightEditor 无调用点 → showWeightEditor 永 false → 整套不可达。跨 GearPage/Index/PackStore 删除，PackStore 的 KEY_GEAR_TARGET_WEIGHT 从未被真实写入（无孤儿数据）。WeightGauge.ets 是全仓无实例化的孤立组件，其 targetWeight prop 与本链路无关

## ArkUI 避坑清单（实战总结，共 52 条）

1. **linearGradient 禁用 Color.Transparent** — 它是透明黑 `#00000000`，渐变出灰中间值。正确：`'#00FFFFFF'` 同色相只变 alpha
2. **Spring 曲线忽略 duration** — `animateTo({ duration, curve: springMotion })` 中 duration 无效，时间完全由 response 决定。需要短动画就用 EaseOut。**错落延迟场景**：不要用 duration 来做延迟，用 `delay` 字段（`animateTo({ delay: index * 40, curve: springMotion })` 或 `.animation({ delay: index * 40 })`）
3. **滚动驱动动画禁止 animateTo** — scrollOffset→UI 必须同步赋值，平滑感放 `.animation()` 修饰器，不放数据源
4. **折叠 Header 必须缩小实际高度** — 不能只 opacity:0，必须 `.height(计算值)` + `.clip(true)` 真正折叠
5. **Tab 切换禁止 setTimeout** — `changeIndex()` 必须 onClick 中立即调用，弹性动画只作用于 pill，不延迟切换
6. **Stack 中组件定位要显式** — 用 `.position()` / `.align()` + `.offset()`，不依赖 margin
7. **动画不要叠加** — 同一属性不能同时有 `.animation()` 和 `animateTo()`，选一种。实战案例：WeightGauge ring 的 `.scale()` 同时有 `.animation({ curve: SPRING_PRESS() })` 修饰和 `animateTo` 驱动 → 运行时两者竞争产生卡顿/抖动。解法：去掉 `.animation()` 修饰，只保留 `animateTo` 统一驱动
8. **@Builder 回调参数 this 丢失** — 异步回调（弹窗/选择器）中 this 丢失。规则：参数只传数据，不传带 this 的回调
9. **onTouch vs onClick 冲突** — 父 `.onClick()` 拦截子事件。父只需触摸态时用 `.onTouch(TouchType.Down)` 代替
10. **geometryTransition 分两种语境**—跨页 Navigation（`trip-*` 首页→详情）：pushPath/pop 必须在 animateTo 内 + animated=false；NavDestination 加 `.transition(OPACITY)`；用**无参形式**（`{ follow: true }` 会破坏文档流布局）；必须 `.onBackPressed()` 拦截系统返回走 animateTo。同页就地放大（`zone_*` UnifiedChecklistView 网格态↔聚焦态）：反而要用 **`{ follow: true }`** 让节点从原格几何中心连续长大到落点，前提是两端 `ZoneShell` 外壳 100% 一致 + 同帧赋值；隐藏源节点用 `opacity(0)+hitTest(None)` 不能 `visibility(Hidden)`（后者脱离渲染树丢失配对端）
11. **覆盖层退场背景恢复必须并行** — 子组件暴露 `onExitStart`，退场第一帧触发；恢复用 EaseOut 不用 Spring
12. **波纹/粒子用固定组件** — 预置固定数量 Circle + `.animation()` 驱动，不用 ForEach 动态创建
13. **连续手势振动节奏** — 棘轮式按阈值触发，state 记录已触发阈值防重复。预设：clock.timer < effect.soft < effect.hard < effect.sharp
14. **@Builder 方法体禁止变量声明** — 只能写 UI 描述语法，计算值用 `this.xxx()` 方法或 @State
15. **折叠屏适配：position 组件必须 onAreaChange** — display 只是瞬间物理像素，折叠/分屏后要重新计算坐标
16. **ArkTS 禁止无类型对象字面量导出** — 用 `export class Xxx { static fn = fn }` 代替 `export const = {}`
17. **装饰动画静止态必须中性值** — rest state 必须是中性值（scale=1.0、opacity=0 或 1），不能停留在弹性中间值。实战案例：GearSortSheet 按压 rest 状态错误设为 `PRESS_SCALE_BOUNCE`(1.02) → 松手后元素永久放大 2%。解法：rest 必须用 `PRESS_SCALE_REST`(1.0)
18. **手势坐标是 vp，display 是物理像素** — GestureEvent/TouchEvent 坐标直接用；display.width/height 必须 px2vp()
19. **拖拽浮层 animation({ duration: 0 })** — 覆盖父级动画继承，消除插值滞后
20. **多选模式切换不改变 Header 可见性** — 不 if/else 整个 Header，内部切换内容。多选时 Header 锁定收缩态
21. **浮动 Header + List spacer 间距** — spacer = Header高度 - paddingTop - space；模式切换时同步调整
22. **浮动组件不放 Column 流式布局** — 放根 Stack 用 position + zIndex 定位，展开时强制 Header 收缩
23. **覆盖层必须在 Navigation 外层** — NavDestination 会遮挡内部 Stack 子组件，覆盖层放 Navigation 同级之后
24. **ForEach key 包含所有变化维度** — key 不止 id，拼入影响渲染的属性 + nonce 计数器
25. **搜索态绕过折叠/隐藏状态** — 状态查询方法在搜索关键词非空时返回 false，从数据源头解决
26. **PanGesture distance≥5 防吃 onClick** — distance:0 会让微小移动触发 Pan。Pan+Click 共存时 distance 至少 5
27. **if/else 条件渲染动画** — 两步：① animateTo 包裹 state 赋值 ② 组件加 `.transition(OPACITY+translate)`。缺一不可
28. **Stack 子组件禁止 height('100%')** — Stack 高度由子组件最大高度决定，常规流子组件 `height('100%')` 形成循环依赖，运行时给出异常大高度值。**补充：position() 脱离布局流后 `height('100%')` 同样不可靠**——它引用的是上层容器约束高度（可能是 List/Column 可用高度）而非 Stack 被其他子元素撑开的自然高度。解法：需要底层覆盖元素时用固定高度 + Stack `alignContent` 对齐，不用任何形式的 `height('100%')`

29. **CURVE_STANDARD 必须用 `curves.cubicBezierCurve()`** — `Curve.EaseInOut` 是 `cubic-bezier(0.42, 0, 0.58, 1.0)`（对称曲线），与 Material/HarmonyOS Standard `cubic-bezier(0.4, 0, 0.2, 1.0)` 完全不同。正确实现：`curves.cubicBezierCurve(0.4, 0.0, 0.2, 1.0)` 返回 `ICurve` 类型（非 `Curve` 枚举）。`animateTo` 的 curve 字段接受 `Curve | ICurve | string` 三种类型
30. **ForEach callback index 是 `number` 不是 optional** — ArkUI 的 ForEach 第二个参数签名是 `(item: T, index: number) => void`，index 不需要 `?` 可选标记
31. **死代码及时清理** — AnimationTokens 中导出了 8 个常量（DURATION_PULSE/TAB/ENTRANCE/GAUGE、STAGGER_DELAY_MENU/LIST/SWIPE、PANEL_SCALE_DISMISS）实际无任何消费者，属于设计阶段预留但从未实现的功能。积累会让新开发者误以为有使用场景。清理时需同步检查 DesignTokens.ets barrel re-export
32. **CURVE_LINEAR 合法场景** — 帧级匀速运动（如 setInterval 16ms 驱动的托盘自动滚动）不适合 Spring/EaseOut，匀速是正确选择。但必须通过 `CURVE_LINEAR` token 引用，不硬写 `Curve.Linear`
33. **大规模机械性修改用并行 subagent** — 跨 12+ 文件的模式化修改（如去除 Spring+duration）适合拆分为并行 subagent 批量处理，但需要事后人工复查是否有遗漏（本次 subagent 漏了 2 处 Index.ets + 误保留 1 处 DURATION_GAUGE）
34. **Colors token 补充透明色** — `Color.Transparent` 不走 token 体系，新增 `TRANSPARENT`/`PRIMARY_TRANSPARENT`/`WHITE_SEMI_TRANSPARENT` 确保所有颜色统一管理
35. **`.animation()` 作用域隔离 translate 的正确姿势** — `.animation()` 只捕获它与前一个 `.animation()` 之间的属性变化。利用此规则：`.backgroundColor(...).animation({ press }).translate(...)` — animation 只作用于 backgroundColor，translate 在其后不被捕获，可由 `animateTo` 自由驱动。**禁止**用 `.animation({ duration: 0 })` 来"隔离"——它会与 `animateTo` 冲突（避坑 #7），导致 translate 变化无动画（硬切）
36. **`.overlay()` 对 @Builder 内条件渲染不可靠** — `.overlay(this.MyBuilder(), ...)` 中如果 Builder 内部有 `if (stateVar)` 条件分支，当 stateVar 变化时 overlay 内容**不会重新渲染**。解法：放弃 `.overlay()`，改用 Stack 包裹 + 子组件直接写 `if` 条件渲染 + `.position()` 绝对定位 + `.clip(false)` 允许溢出。需要阻止点击穿透时用 `.hitTestBehavior(HitTestMode.Block)`
37. **`.shadow()` + `backdropBlur` 产生亮色伪影** — 当组件设置了 `.shadow({ color: '#1A000000', ... })` 且位于 `backdropBlur` 层之上时，ArkUI 渲染管线会在 shadow 区域产生可见的亮色半透明圆角矩形轮廓（ghost artifact）。即使 shadow color 是纯黑低透明度，合成结果仍为亮色。**根因**：shadow 的离屏缓冲区与 blur 层的混合模式冲突，blur 对 shadow 的半透明像素做了反向提亮。**解法**：在暗色覆盖层/毛玻璃场景中直接移除 `.shadow()`（全屏暗背景下 shadow 本身无视觉意义）。若必须保留阴影效果，改用手动 Column + blur + opacity 模拟（参见避坑 #90 光晕层方案）

38. **@State 数组禁止原地 mutation** — `splice()/push()/unshift()` 不触发 UI 刷新（引用不变）。**必须 spread 副本再操作再赋值**：`const arr = [...this.items]; arr.splice(i, 1); this.items = arr;`。七处同类 bug 复现于 GearPage + WeightGauge
39. **组件 aboutToDisappear 必须清 timer** — `if/else` 条件渲染销毁组件时 `setTimeout`/`setInterval` 不会自动清除。必须在 `aboutToDisappear()` 中 `clearInterval(id)` / `clearTimeout(id)`。否则 stale `this` 引用上调 `animateTo` 抛运行时异常
40. **ForEach 退场动画** — ForEach diff 移除节点默认无动画（瞬间消失）。需在子组件根容器加 `.transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({x:0.95,y:0.95})).animation({curve: SPRING_GENERAL()}))`。入场同理
41. **counter 动画 onCheckedChange 不做相等判断** — `if (display !== target)` 在快速连击时 display 可能卡在中间值导致判断失效。正确做法：无条件启动新动画，在 `animateCounter` 头部 `clearInterval` 取消旧动画即可

42. **自定义组件外挂 `.onClick` 被组件根节点自身 onClick 抢占** — 给自定义组件实例（如 `ZoneShell{...}`）在外部链式挂 `.onClick()`，事件绑到组件根节点（如 ZoneShell 根 Column）。若该根节点**自身已经有 `.onClick`**（即便回调因开关为 false 而空跑），它仍会注册并**消费**点击事件，外层挂的 onClick 拿不到 → 外挂点击静默失效。实战：FocusedZoneView 外挂 `.onClick` 收起聚焦态完全无反应。**解法**：不外挂，改走组件内部已暴露的点击回调链路（ZoneShell 的 `contentClickable: true` + `onTapContent`）。**注意**：`.gesture(PanGesture)` 外挂在自定义组件实例上**可以**生效（机制与 onClick 不同），所以左右划返回外挂没问题——别因 onClick 失效误判 gesture 也失效

43. **半透明色浮在白底上会「透白发灰」** — 聚焦卡片浮在纯白/羽白实心遮罩之上时，卡片填充若用半透明色（如降低 alpha 的 zone 色），底下的白会透上来把颜色冲淡发灰，且整体偏「飘」无实体感。**解法**：用**不透明实心混合色**——把 zone 主题色与白色按百分比预混成 hex 常量（如 20% 公式 `白*0.8 + color*0.2`：Head #42A5F5 → #D9EDFD）。token 化为 `ZONE_*_FOCUS_BG`。配 2vp 实色边框补实体轮廓。淡到 8% 几乎纯白辨不出 zone 色，20% 是肉眼可辨 + 不刺眼的平衡点

44. **`hitTestBehavior(HitTestMode.None)` 不可靠阻止子元素 `.onClick()`** — 父容器设 `hitTestBehavior(HitTestMode.None)` 时，其**子元素**自身注册的 `.onClick()` 仍可能拦截点击事件（平台 bug）。典型场景：Sheet/蒙层组件常驻 Stack 中，visible=false 时父 Stack 设 `HitTestMode.None`，但内部全屏 Column 的 `.onClick()` 仍吞掉所有点击 → 整页无法交互。**解法**：对含有 `.onClick()` 的不可见组件，**必须用 `if` 条件渲染将其从视图树中移除**，不能依赖 `hitTestBehavior(None)` 来屏蔽。退场动画需求时可延迟清空条件变量（如 400ms 后置 null）保留退场过渡。实战：`GearDetailSheet` 常驻 UnifiedChecklistView Stack 导致网格态全页无响应；`ZoneGridCell` 空态/内容态也用 if/else 而非双层常驻，同理

45. **`GestureGroup(Sequence, LongPress+Pan)` 不阻止子节点 onClick 触发** — 当 `GestureGroup(GestureMode.Sequence, LongPressGesture, PanGesture)` 绑在 wrapper Column 上时，LongPress `onAction` 触发后松手，子节点（如 ChecklistRow）的 `.onClick()` 仍会在 touchUp 时触发——ArkUI 的 Sequence 手势完成不消费后续 click 事件。**后果**：长按弹菜单后松手，同时触发行展开/收起（onClick），造成双重响应。**解法**：在 wrapper 上维护 `@State longPressTriggered: boolean = false`，LongPress `onAction` 中置 true + `setTimeout(() => { this.longPressTriggered = false }, 500)` 延迟重置；所有 onClick 回调（`onTapContent`/`onTapRow`）入口处 `if (this.longPressTriggered) return` 短路。**注意**：flag 赋值必须在任何 early return（如 `if (isMultiSelectMode) return`）**之前**，否则特定模式下长按仍会穿透触发 onClick

46. **普通 class 改字段不触发 ArkUI re-render（控制器必配 @State 镜像）** — ArkUI 的依赖收集只订阅 `build()` 中读到的 `@State`/`@Link` 等装饰器状态。把状态放到一个**普通 class 实例**里（如 `HeadCollapseController` 的 `scrollProgress` 字段），改它**不会**触发任何 re-render——即使 build 里调了 `controller.progress()`。**后果**：滚动变了但 head 不动（画面定格）。**解法**：页面持一个 `@State progress` 镜像，控制器通过 `onChange(progress, snapping)` 回调推动页面 `this.headProgress = progress`（这才是装饰器赋值、触发刷新）；渲染处一律读 `this.headProgress` 镜像，**绝不**直接读 `controller.progress()`。**配套**：控制器无 `getUIContext()`，`animateTo` 需的 `UIContext` 必须由页面经 config 注入（`getUIContext: () => this.getUIContext()`）。适用于任何「逻辑抽到普通 class 但要驱动 UI」的场景

47. **拖拽避让用 translate 模拟时必须冻结 rect 采集（防反馈回路）** — 拖拽排序做兄弟项让位动画（被拖项 `opacity(0)` 留洞 + 兄弟行 `.translate({y})` 平移填洞）时，若被平移的节点同时挂了 `onAreaChange` 采集 `globalPosition` 喂给命中检测，会形成致命反馈回路：让位平移 → globalPosition 漂移 → 命中检测读到漂移后的 rect → 重算落点 → 让位量再变 → 抖动/命中目标乱跳。**解法**：`onAreaChange` 回调在拖拽态（`gearOverlayPhase === 'dragging'`）直接 `return` 冻结采集，整个拖拽过程命中检测基于「拖拽开始前冻结的 rect 集合」。**配套**：让位计算（`gearRowShiftY`）与命中检测（`hitTestGearDrop`）必须基于**同一坐标系**——统一用「含被拖项的完整列表」full index，不能一个用剔除后列表一个用完整列表，否则洞的视觉位置与命中插入点对不上

48. **拖拽落位卡顿 = await 持久化阻塞视觉帧（optimistic + 错帧解耦）** — 拖拽松手落位若在重排函数里 `await store.saveGears()` 再 setState，持久化 I/O 会阻塞落位动画帧造成明显卡顿。**解法 optimistic update**：UI 先同步 setState 落位（`this.gears = next; this.renderNonce++`），持久化抽独立方法 fire-and-forget 后台跑——`private persistInBackground(next) { this.store.save(next).catch(e => console.error(...)) }`，**不 await**（floating promise 必须 `.catch()` 显式处理否则 ArkTS 警告）。**配套错帧解耦**：落位帧（reorder 重渲染）与覆盖层收起帧（chip 淡出 `animateTo`）若同帧触发仍会叠加卡顿，用 `setTimeout(() => this.dismissOverlay(), 0)` 把收起推到下一帧

49. **`@Watch` 必须写在 `@Prop`/`@State` 声明上，不能作为独立行装饰器** — ArkUI V1 中 `@Watch('methodName')` 是**属性装饰器**，必须紧跟 `@Prop`/`@State`/`@Link` 同行声明：`@Prop @Watch('onDayChange') day: ItineraryDay`。若把 `@Watch('onDayChange')` 单独放一行在方法上方，编译报错「装饰器不匹配」。与 TypeScript 装饰器语法不同——ArkUI 的 @Watch 是属性级别的响应式监听，不是方法装饰器

50. **Tabs `onGestureSwipe` 的 `currentOffset` 是 vp 位移（非 progress 0-1）** — `TabsController.onGestureSwipe(index, event)` 中 `event.currentOffset` 是当前内容相对于初始位置的**像素位移**（单位 vp），不是 0-1 归一化值。负值=内容左移=朝 index+1 滑动。计算连续 progress 的正确公式：`progress = currentTabIndex - currentOffset / tabsWidth`（需除以单页宽度归一化）。**常见错误**：直接把 offset 当 progress 用 → 颜色/指示器飙出范围

51. **`build()` 裸 `if/else` 产生隐式 Column 居中** — 当 `@Component` 的 `build()` 方法内直接写 `if/else`（不包在显式 Column/Stack/Row 里），ArkUI 编译器会隐式包裹一层 Column 作为根容器。这个隐式 Column 的默认行为：**当子内容高度不满容器时，内容会被垂直居中放置**——而非顶部对齐。**后果**：组件被父层 `.height('100%')` 约束时，少量内容悬浮在屏幕正中央，上半部分大片空白。实战：ItineraryView 只有 1 个 DayCard 时内容居中于屏幕中部。**解法**：`build()` 必须有**显式根容器**——`Column().width('100%').height('100%').justifyContent(FlexAlign.Start)`。**铁律：禁止 `build()` 根节点为裸 `if/else`、裸 `@Builder` 调用、或裸 `ForEach`**

52. **TabContent keep-alive 下 `onAppear` 不再触发（入场动画重播靠 nonce）** — HdsTabs/Tabs 的 TabContent 默认 keep-alive，子组件首次挂载后**切走再切回不会触发 `aboutToAppear` / `.onAppear`**。**后果**：若入场动画（如 HeroCard 数字滚动、stagger 错落）仅在 `onAppear` 启动，切回后动画不重播（停在 reset 态）。**解法**：父层维护 `@State visibilityNonce` 每次切至此 tab 递增，子组件 `@Prop @Watch('onNonceChange') nonce` 监听变化主动重启动画。**关键**：nonce 只在一处递增（`onAnimationStart` 或 `triggerBlurPulse`），不要 `onAnimationStart` + `onChange` 双重递增——否则 `@Watch` 回调被连续调两次，第二次 reset 打断第一次刚启动的动画造成闪烁

### 补充验证结论

- HarmonyOS vibrator 预设：`haptic.clock.timer`/`effect.soft`/`effect.hard`/`effect.sharp`；`count` 参数做连击
- `backgroundColor` 可动画，用 `.animation()` 修饰器过渡
- 光晕层用独立 Column + blur + opacity，`.shadow()` color 插值不可靠
- SymbolGlyph 支持 `.rotate()` 变换
- 文字切换用 Stack + 双 Text opacity 交叉淡入
- macOS Dock 磁吸：builder 中实时算 proximity，卡片有限时性能可接受
- SwipeGesture(Horizontal) 与垂直 List 不冲突
- `@Prop` 深拷贝 + ForEach key 只含 id → 不触发重渲染。解法：key 拼入变化属性 + nonce
- `bindSheet` SheetOptions 不支持 `borderRadius`（编译通过运行报 warn），需移除

## 快速核查功能（2026-06-22）

- 首页 QuickEntries 第二个按钮从「装备库」替换为「快速核查」（装备库已有 3 条路径可达，按钮冗余）
- `nearestFutureChecklist()` 只取 dateAt >= 今天的最近行程（过去行程已结束，不需要核查）
- 按钮状态机：无未来行程→隐藏（只剩"新建行程"填满行）；未来行程 items=0→点击跳转详情页+toast"先添加装备再核查"；全勾选→"再检查一遍"；有未勾选→"快速核查"
- 点击直接设置 `selectedChecklistId` 然后 `openReviewMode()`，跳过中间的详情页，减少操作路径

## 数据一致性模式（2026-06-13）

- **checklistRenderNonce 强制刷新**：任何修改装备属性（名称/分类等）的操作，执行后必须 `checklistRenderNonce++` 强制 @Watch 重算缓存。覆盖路径：batchDeleteGears / batchMoveGroup / executeCategoryDelete / executeCategoryRename / updateGear / createGear（后两者经 GearPickerSheet 关闭后已由其他 nonce 链路覆盖）。**注**：v0.7.7-perf 后 ForEach key 已改为 `zoneKey(zone)` 内容哈希（不再直接拼 nonce），但 nonce++ 仍触发 @Watch → 重算 zoneKey → 精确重建变化 zone
- **resolveItemName 实时查找**：ChecklistItem 只存 `fromGearId`，显示名称优先从 gears 数组按 id 查找当前值，找不到才 fallback 到 item.name 快照。确保装备改名后清单即时反映
- **PRESS_SCALE_DOWN 全局按压常量**：AnimationTokens 导出 `PRESS_SCALE_DOWN = 0.96`，所有可点击元素按压缩放统一引用此常量 + `SPRING_PRESS()` 曲线。FAB 和底部 Tab bar 例外（有独立反馈机制）
- **forceFlush() 页面退出持久化**：NavDestination `.onBackPressed()` / `.onDisAppear()` 中调 `PackStore.forceFlush()` 确保编辑数据不丢

## 性能优化模式（2026-06-14）

> 全面性能优化完成（8 步），改动 6 文件，构建验证通过。详见 `docs/PERF_OPTIMIZATION_PLAN.md`。

- **cache-on-@Watch 范式**：build 中被多次调用的计算方法（getter），改为 `@State cachedXxx` + `@Watch` 在数据源变化时一次性算好，build 中 O(1) 读缓存。已落地：GearPage（`rebuildGearCache` 缓存 filteredGears/groups/byGroup）、TripDetailPage（`cachedTrip`/`cachedMetaSegments`）。**注意**：缓存字段用 `private` + `@State`，方法返回改为直接返回缓存值
- **父级构建 + @Prop 下发去冗余**：同一索引/映射在多个子组件中独立构建时，提升到父组件一次构建、`@Prop` 下发。已落地：`UnifiedChecklistView` 构建 `gearIndexMap: Map<string, GearItem>`，下发给 7× `ZoneGridCell` + 1× `FocusedZoneView`，消除 8→1 次 `buildGearIndex` 重复遍历
- **ForEach key 内容哈希化（zoneKey）**：ForEach key 从全局 nonce（导致所有格子重建）改为 zone 维度的内容哈希 `zone + '_' + length + checkedBits`（如 `"Head_3_101"`），只有真正变化的 zone 触发 diff 重建。已落地：`UnifiedChecklistView.zoneKey(zone)`
- **拖拽索引预算 O(1) 查表**：拖拽开始时预算 `dragItemIndexMap: Map<string, number>`，`gearRowShiftY` 中 O(1) 取 index 替代 O(N) `findIndex`。已落地：`GearPage`
- **`display.getDefaultDisplaySync()` 一次性缓存**：IPC 跨进程调用从每帧重复改为 `aboutToAppear` 一次性缓存 `screenWidthVp`/`screenHeightVp`。已落地：`UnifiedChecklistView`
- **`groupByZoneAll` 单次遍历分桶**：从 7×`.filter()` 的 O(7N) 改为预初始化 Map + 单次遍历分桶 O(N)。已落地：`services/LoadoutService.ets`
- **⚠️ checklistRenderNonce 与 zoneKey 共存**：zoneKey 精确化后 nonce 仍保留（数据一致性模式中 5 条 mutation 路径仍递增 nonce），但 ForEach key 不再拼 nonce，改为读 zone 内容哈希——两者不冲突（nonce 递增触发 @Watch → 重算 zoneKey → 仅变化 zone 的 key 变了 → 精确重建）

## 已知限制

- 构建路径不在默认 shell PATH 中，需按「工作流约定」里那套完整命令调用（含 DEVECO_SDK_HOME 导出）
- ArkTS 禁止对象展开运算符 `{ ...obj }` — 编译错误 `arkts-no-spread`，展平属性需逐字段赋值
- `@Prop` 装饰器不支持接口（interface）类型分组，只能 `@Prop` 基础类型或 class 实例
