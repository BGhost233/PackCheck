# Changelog

## v0.7.8 (2026-06-24)

行程编辑模块完整落地 + 全面交互动效审查优化 + 行程详情页审计修复 + 全量代码审查清理。行程详情页新增「行程」Tab，支持按天/路段规划行程，与「装备」Tab 平行滑动切换。

**Phase 1-10 — 行程编辑模块**

- **Tabs 替换 Stack+if**：原生 Tabs 组件实现左右滑动切换，`onGestureSwipe` 跟手插值 Tab 标题颜色渐变（RGB hex 通道插值 `#1A1A1A` ↔ `#999999`），`SPRING_TAB(0.32, 0.82)` 加速切换动画
- **ItineraryService CRUD**：新增 `services/ItineraryService.ets` 纯函数层（`addDay`/`removeDay`/`updateDay`/`addSegment`/`removeSegment`/`updateSegment`/`insertDay`/`getDaySummary`/`getTransportIcon`/`createEmptySegment`），类型定义 `DayPatch`/`SegmentPatch`
- **ItineraryView 列表容器**：新增 `components/gear/ItineraryView.ets`，ForEach 按天渲染 DayCard，手风琴展开同时只展开一天
- **DayCard 日卡片**：新增 `components/gear/DayCard.ets`，手风琴折叠展开（`TransitionEffect.asymmetric` 进入 y:8 / 退出 y:-4）、段行（城市→城市 + 交通图标 + 时间摘要）、`cachedSummary` @Watch 缓存
- **SegmentFormSheet + DayFormSheet**：新增两个表单面板，通过 SheetOverlay 路由统一管理
- **可编辑模式**：编辑回调 + 添加路段节点 + 长按菜单交互
- **CRUD 数据贯通**：Index → TripDetailPage → ItineraryView → DayCard 回调链完整对接 + ItineraryService 持久化

**全面审查优化（commit `a705cf0`）**

- **onGestureSwipe progress 修正**：`currentOffset` 为 vp 位移（负值=内容左移=朝 index+1），修正公式 `progress = tabIndex - offset / tabsWidth`
- **Tab 标题颜色连续插值**：从阈值硬切改为 hex 通道逐字节插值（channel 153→26），跟手时零跳变
- **longPressTriggered 防双击**：DayCard 复用避坑 #45 的 flag 模式，长按后 500ms 内短路 onClick
- **head collapse 平滑重置**：`switchTab()` 时 head progress 重置包裹 `animateTo`，消除硬切
- **段行 pressed 高亮**：`@Styles segRowPressed/segRowNormal` + `stateStyles` 实现原生按压态
- **展开 asymmetric transition**：进入从下方 y:8 淡入，退出向上 y:-4 淡出，消除对称感
- **Tab 按压反馈**：`tab0Scale`/`tab1Scale` states + `.onTouch` press 三段式
- **错落入场去 setTimeout**：ItineraryView 入场直接设 `appeared = true`，去除 16ms hack

> 3 文件改动，+106/-55 行。构建通过。

**行程详情页审计修复（commits `42a9750`～`35581ba`，8 个增量 commit）**

- **数据模型变更**：DayItinerary 增加 `from`/`to` 字段，天级起止与路段解耦（commit `48a3897`）
- **表单 Sheet 接入**：DayFormSheet + SegmentFormSheet 正式接入 SheetOverlay 路由统一管理（commit `042f3eb`）
- **UI 刷新链修复**：ItineraryView / DayCard renderNonce 透传修复添加/修改后 UI 不刷新（commits `42a9750`/`71c71a8`）
- **ForEach key 稳定化**：key 从复合（`day.id + segments.length + renderNonce`）回退为纯 `day.id`，消除添加路段时整卡闪烁重建（commit `19e4d5e`）
- **空态增强**：ItineraryView 空态视觉权重提升（审计 #11，commit `35581ba`）
- **聚焦态边框**：DayFormSheet TextInput 聚焦态增加主题色边框（审计 #19，commit `35581ba`）
- **入场动效**：新增天/路段入场 stagger 错落动画（commit `6e58d38`）
- **Tab 按压 polish**：Tab 切换添加双侧对称下压效果（commit `d9e78d7`）
- **清理**：移除不存在的 `tabVisibilityNonce` 引用（commit `35581ba`）

> 8 个增量 commit，覆盖数据模型/表单接入/刷新链/动效/视觉增强。

**全量代码审查清理（commit `bded20e`）**

横跨 28 文件、净删 786 行的全项目代码卫生清理：

- **死代码清除**：AnimationUtils 280→78 行（88% 切除）、HapticUtils 76→52 行、services 三文件共删 27 死函数/453 行、constants 死 token 15 个
- **无用 import 清理**：全项目范围移除不再引用的 import 声明
- **浮动 Promise 修复**：所有 fire-and-forget 的 async 调用补 `.catch()` 显式错误处理
- **hardcode 色值 → token**：GearItemContextMenu / ReviewPage 等残留硬编码 hex 替换为 Colors token 引用
- **Timer 泄漏修复**：7 文件补 `aboutToDisappear` + `isAlive` + `timerIds[]` 体系（TripCeremonyCard 12+ timer / ReviewPage 3 / FocusedZoneView 2 等）
- **DesignTokens barrel re-export 清理**：移除引用已删除常量的 re-export 条目
- **Typography 清理**：移除已废弃 `TypographyToken` interface 和冗余导出

> 28 files，+290/-1076（净删 786 行）。构建通过。

## v0.7.7 (2026-06-14)

装备库单品拖拽真机回归 + 跨分组 spring-load 悬停展开。围绕「拖拽时兄弟项不避让 / 松手卡顿 / 目标分组折叠时无法落入」三个观感问题，从第一性原理重做避让动画、落位性能与悬停展开，全程 SPRING。

**问题 9-A — 拖拽避让丝滑让位**

- **被拖项留透明洞 + 兄弟行平移填洞**：拖动装备移动时其它装备原地不动、毫无避让感。第一性原理——拖拽的本质是「这一项要插到那个缝里」，兄弟项应实时让出落点。做法：被拖项 `opacity(0)` 留洞，新增 `gearRowShiftY(item)` 按「含被拖项的完整分组列表」算每个兄弟行的 `translateY`（向下拖：洞与落点间的行上移 `-GEAR_ROW_HEIGHT` 填洞；向上拖：落点到洞间的行下移让缝；跨分类拖入：落点及之后的行整体下移），把洞「视觉迁移」到插入点，全程 `SPRING_GENERAL`
- **新增模块常量 `GEAR_ROW_HEIGHT = 52`**（折叠态行高 44 content + 4×2 padding），让位平移量与命中检测共用，禁硬编码
- **拖拽态冻结 rect 采集（防反馈回路）**：避让平移会改变 `onAreaChange` 上报的 `globalPosition`，污染 `gearRowRects` 致命中目标漂移。`onAreaChange` 在 `gearOverlayPhase === 'dragging'` 时直接 return 冻结采集，命中检测与让位计算均基于冻结的完整列表 full index，坐标系一致

**问题 9-B — 松手 optimistic 落位去卡顿**

- **乐观更新解阻塞**：拖动松手后严重卡顿。根因——落位 `reorderGears` 内 `await store.saveGears()` 阻塞了视觉帧。改为 optimistic update：UI 先同步 `setState` 落位（`this.gears = nextGears` + `checklistRenderNonce++`），持久化抽 `persistGearsInBackground` 用 `.catch()` fire-and-forget 后台跑，不 await 阻塞
- **错帧解耦**：落位帧（reorder 重渲染）与 overlay 收起帧（chip 淡出 `animateTo`）用 `setTimeout(0)` 推迟到下一帧，避免同帧叠加卡顿

**跨分组 spring-load 悬停自动展开**

- **iOS 风格悬停展开**：拖装备到折叠分组时无法落入。第一性原理——参考 iOS 文件 App 拖到文件夹悬停自动展开。做法：拖拽命中折叠分组时启 500ms 悬停计时器，超时把该分组加入「拖拽期临时展开集合」`gearDragTempExpanded`，与持久化折叠偏好 `collapsedGearGroups` **解耦**；`isGearGroupCollapsed` 把临时展开视为不折叠，复用现有 `SPRING_GENERAL` 展开链路
- **路过收回 / 落位转正**：悬停目标切换时清旧计时器、SPRING 收回旧临时展开（路过即收）；落位到临时展开的分组时「转正」——先把它移出 `collapsedGearGroups` 并持久化、再清空临时集合（顺序关键，反了会瞬间闪折叠），用户选定「A. 转正保持展开」

> 拖拽避让让位 + rect 冻结防反馈回路沉淀至 MEMORY.md 避坑 #47；optimistic 落位 + 错帧解耦沉淀至避坑 #48。

## v0.7.6 (2026-06-14)

行程详情页顶部体验收口 + 全屏沉浸。围绕「navbar 无效空白 / 元素错位 / 折叠时上半身死板不动」三个观感问题，从第一性原理重做 navbar 布局与折叠联动，并清掉一处弱视效。

**navbar 重做**

- **删 `···` 更多菜单，换单一「逐项核查」图标入口**：右上角原 `···` 三点菜单（编辑行程 / 逐项核查 / 删除行程）收口为单个 `checkmark_shield` 图标按钮（与首页核查入口同图标，统一肌肉记忆），直接 `onClick → onOpenReview`。`onOpenEditTrip` / `onDeleteTrip` 回调接口保留待挂别处，不删数据流
- **三元素垂直居中对齐**：返回箭头 / 标题 / 右图标回归 `VerticalAlign.Center`。上一版误用 `VerticalAlign.Bottom` 想「贴近状态栏」，但 SymbolGlyph 与 Text 字形下沉量不同 → 各自的「底」不在一条线 → 散乱。第一性原理：工具条三元素本质应同线居中，「贴近状态栏」该靠压缩 navbar 高度实现，而非改对齐方式
- **高度收窄消无效空白**：navbar 高度 56 → 44 → 40（`statusBarHeight + 40`），`reservedTop()` 的 `NAV_BAR` 同步 40

**标题随折叠呼吸（方案 A）**

- **消除「折叠时上半身死板不动」割裂感**：原折叠只有 SharedInfo 日期行 height→0，navbar 标题固定不动 → 上下割裂。方案 A 让标题随 `effectiveHeadCollapse()` 插值字号（20 → 17）+ 下沉（4 → 0），走同一 `headCollapseCurve()`，与 SharedInfo 同帧「一起被压扁」。返回箭头作为导航功能锚点保持稳定（符合导航直觉，不参与呼吸）
- 新增 `titleFontSize()` / `titleOffsetY()` 两个插值方法；标题 Text 挂 `.translate({y})` + `.animation(headCollapseCurve())`

**减法**

- **删底部纯色弥散遮罩**：UnifiedChecklistView 移除 `buildBottomFade()` @Builder + Grid `.linearGradientBlur`（含 3 个 unused 常量 `BOTTOM_DIFFUSE_*` / `BOTTOM_FADE_HEIGHT`），底部不再叠一层弱感知的渐隐模糊
- **拖拽落点保持格子本色**：ZoneShell 拖拽态背景去掉 `LIGHT_PRIMARY_COLOR` 淡绿高亮，落点保持目标格 `zoneFill` 本色（高亮交给外层 border/glow 的 `zoneColor`，避免双重着色把格子本色冲淡）

**全屏沉浸（前置 effc555）**

- EntryAbility 开 `setWindowLayoutFullScreen` 去系统栏底色；避让高度经 AppStorage 下发；GearPage / HomePage / TripDetailPage 折叠头补 `statusBarHeight` 避让；删 HdsTabs `gradientMask`（留 `systemMaterialEffect`）

> 标题折叠呼吸沉淀至 DEVELOPMENT_STANDARDS §4.3（inline 塌缩范式：navbar 标题参与呼吸联动）。

## v0.7.5 (2026-06-13)

顶部折叠交互全面对齐 iOS Large Title，并抽出统一控制器消除三处重复的滚动数学。

**head 折叠交互（方案 A）**

- **跟手 1:1 + 松手就近吸附**：head 随网格滚动渐进折叠，跟手期 progress 严格 1:1 实时映射（零吸附、不抢手感，走 `SPRING_HEAD_FOLLOW = curves.responsiveSpringMotion(0.15, 1.0)`）；松手惯性停在 (0,1) 中间态时就近吸附到 0 或 1（走 `SPRING_SCROLL`），绝不留半折叠残缺态。体验范式经第一性原理 + Apple 标准自主定夺，对齐 iOS Large Title
- **TripDetailPage 基准实现**：`.onScroll` 映射 progress、`.onScrollStop` 触发吸附；SharedInfo 日期行 + ProgressBar 双层融合插值收没让渡空间，NavBar 常驻
- 新增 `SPRING_HEAD_FOLLOW` token 到 AnimationTokens.ets

**统一折叠控制器封装（refactor）**

- **新增 `utils/HeadCollapseController.ets`**：统一项目内所有「顶部随滚动折叠」的滚动数学内核（progress 计算 / 跟手 1:1 / 松手就近吸附 / 曲线分流 / 强制折叠旁路）。普通有状态 class，配置走 `HeadCollapseConfig`（collapseDistance / enableSnap / getUIContext / onChange / snapThreshold?）
- **抽象边界**：只统一「滚动数学」，**不统一 head 渲染**。项目两种互不兼容的折叠布局范式对控制器透明——inline 塌缩（TripDetailPage，head 真实兄弟节点高度归零）vs overlay 定高变形（HomePage / GearPage，head 用 `.position` 浮起靠字号/透明度变形），各自从 `onChange` 拿 progress 去插值自己的 head，避开「两种布局强行统一」的坑
- **三处迁移对齐**（各独立 commit）：TripDetail / UnifiedChecklistView 基准 → HomePage（补齐 `.onScrollStop` 吸附）→ GearPage（补齐 `.onScrollStop` 吸附）
- **GearPage 锁定态零视觉回归**：searchExpanded / multiSelect 锁定态的高度/背景/模糊视觉特判全部保留在各函数内，**不走 `setForcedCollapsed`**——搜索态视觉（纯背景 `PAGE_BG` / 零模糊）≠ progress=1（半透明毛玻璃 `#CCF8F9FA` / 模糊 40），语义不等价，只统一滚动内核

**关键经验**

- **刷新陷阱**：控制器是普通 class，改内部字段不触发 ArkUI re-render。消费页面必须持 `@State progress` 镜像，由 `onChange` 回调推动更新，渲染一律读镜像、绝不直接读 `controller.progress()`。`animateTo` 需的 `UIContext` 由页面经 config 注入

> 核心经验沉淀至 MEMORY.md 避坑 #46（普通 class 改字段不触发 re-render）+ DEVELOPMENT_STANDARDS §4.3（顶部折叠统一控制器）。

## v0.7.4 (2026-06-13)

行程详情页格子交互三 Bug 修复。修复 ChecklistRow 白底色块突兀、长按同时触发菜单和行展开/收起、上下文菜单需多次点击才能关闭的问题。

**Bug 修复**

- **ChecklistRow 白底突兀**：格子内装备行 `backgroundColor` 从 `CARD_BG`（纯白）改为 `Color.TRANSPARENT`，融入 ZoneShell 的 `zoneFill` 底色，消除视觉割裂。按压态改用 `'#33000000'` 半透明黑叠加（适配任意底色）
- **长按同时触发菜单 + 行展开/收起**：`GestureGroup(Sequence, LongPress+Pan)` 的 LongPress `onAction` 触发后松手，子节点 `.onClick()` 仍会触发（ArkUI 平台行为）。新增 `@State longPressTriggered: boolean` 标志位，LongPress 触发时置 true + 500ms 延迟重置，`onTapContent`/`onTapRow` 入口短路。ZoneGridCell + FocusedZoneView 两处同步修复
- **上下文菜单需多次点击关闭**：覆盖层 Stack 的 `hitTestBehavior` 从 `overlayPhase === 'dragging' ? None : Default` 改为 `overlayPhase === 'menu' && overlayVisible ? Default : None`——仅在菜单可见时拦截触摸，其余时刻完全透传，消除 dismissOverlay 150ms 延迟窗口内的触摸吞噬

**额外发现 & 修复**

- **FocusedZoneView 多选模式穿透**：`longPressTriggered = true` 赋值必须在 `if (isMultiSelectMode) return` 之前，否则多选模式下长按仍穿透触发 onClick toggle

> 核心经验沉淀至 MEMORY.md 避坑 #45（GestureGroup Sequence 不阻止子节点 onClick）。

## v0.7.3 (2026-06-13)

数据一致性修复 + 按压反馈补全。修复装备 mutation 后清单视图不刷新的隐蔽 bug，补齐 GearPickerSheet / GearPage 残余按压反馈空白。

**数据一致性**

- **checklistRenderNonce 补齐**：`batchDeleteGears` / `batchMoveGroup` / `executeCategoryDelete` / `executeCategoryRename` 四条路径缺失 `checklistRenderNonce++`，导致 UnifiedChecklistView ForEach 不重建、装备名称/分类变更后视图陈旧。全部补齐 + ForEach key 追加 nonce 维度（`zone + '_' + length + '_' + nonce`）
- **resolveItemName 实时查找**：ChecklistItem 显示名称改为 gear-first lookup（经 `fromGearId` 从 gears 数组实时取当前值），找不到才 fallback 到 `item.name` 快照，确保改名即时反映
- **buildGearTripCountMap 派生**：消除已死 `GearItem.tripCount` 字段依赖，运行时遍历 trips 实时计算行程计数

**按压反馈补全**

- **GearPickerSheet**：装备行（`pressedGearRowId`）、品类胶囊（`pressedCatPill`）、Zone 胶囊（`pressedZonePill`）三处新增 scale press
- **GearPage**：排序按钮（`pressedSortBtn`）、筛选胶囊（`pressedFilterPill`）、搜索胶囊（`pressedSearchBtn`）、取消文字（`pressedCancelText`）、DeleteAction（`pressedDeleteAction`）、WeightEditor 关闭按钮（`pressedWeightClose`）六处新增 scale press
- 所有按压统一使用 `PRESS_SCALE_DOWN(0.96)` + `SPRING_PRESS()` 曲线

> 核心经验沉淀至 MEMORY.md「数据一致性模式」section。

## v0.7.2 (2026-06-12)

聚焦态满铺精装修 — 向便单质感看齐的两轮真机打磨。功能不动，只修聚焦态视觉密度与点击交互。

**第一轮（commit `cfc942d`）·真机展开态三诉求**

- **诉求1 head 收缩让渡空间**：顶部日期行 + 装包进度条双层 collapse 收没，聚焦卡片满铺顶到 navbar 下沿（推翻 v0.7.1 的悬浮 `maxHeight '80%'` 方案）
- **诉求2 纯羽白实心遮罩**：聚焦背景遮罩改纯羽白实心（`PAGE_BG`）盖住网格虚影，最干净仿便单（不再用半透明压暗）
- **诉求3 近实心淡色块 + 去×键**：新增 7 个 `ZONE_*_FOCUS_BG` 近实心淡色 token，聚焦卡片用 `zoneFocusBg`；删右上角 ×键及 `closePressed`，改「点击卡片空白返回」

**第二轮（commit `1ff7cdc`）·真机审查两问题**

- **问题1 颜色加深 + 边框加粗**：`ZONE_*_FOCUS_BG` 从 8% 白底混合加深到 20%（zone 主题色肉眼明显可辨）；`ZoneShell` 新增 `focusBorder` 标志，聚焦态边框 2vp + zone 主题色实色（给卡片实体轮廓，不再飘）
- **问题2 修复点击返回失效**：点格子返回从外部给 `ZoneShell{}` 外挂 `.onClick`（被 ZoneShell 根节点自身 onClick 抢占 → 静默失效）改走 `contentClickable: true` + `onTapContent` 内部链路，复用网格态同款机制

> 两轮均 BUILD SUCCESSFUL。核心经验沉淀至 MEMORY.md 避坑 #42（自定义组件外挂 onClick 被根节点抢占）、#43（半透明色浮白底透白发灰，须用不透明混合色）。

## v0.7.1 (2026-06-11)

UI 质感提升（Phase A-E）+ 审查修订。功能骨架不动，只做视觉与交互反馈层精装修，向便单的质感看齐。

**Phase A-E 质感提升**

- **Phase A 拖动态去灰**：蒙层 dragging 阶段 opacity→0，胶囊浮起（scale 1.05 + 阴影加深）
- **Phase B 容器化 + 空轻满重**：满格子白卡加 `ZONE_*_STROKE` 极淡描边 + 阴影升级 + 标题行浅染 `ZONE_*_TINT`；空格子改「空轻满重」降权——虚线降权框 + 不进 `geometryTransition`（B-3 层级倒置：空态不抢视觉权重），列高对齐
- **Phase C 拖动物理感深化**：源位虚线空槽 + 目标格高亮微调
- **Phase D 转场重构**：抽出共享 `ZoneShell` 外壳，网格态与聚焦态两端外壳 100% 一致 → `zone_*` 共享元素转场用 `{ follow: true }` 就地放大（节点从原格几何中心连续长大到聚焦落点）；背景联动压暗 + 虚化下沉（不缩放）
- **Phase E 顶部信息区 + 进度条 + 勾选态**：元信息行图标点睛 + 数据强调；进度条填充换 `SPRING_COUNTER`；勾选完成态视觉强化

**审查修订（审查文档 packcheck-v0.7.1-review.md · Everest · commit `4405f6b`）**

- **P1/P2 统一标题行**：空态标题行原是 `buildTitleRow` 平行实现，未走 `ZoneShell` 浅染底。`ZoneShell` 新增 `contentDashed` 开关——开关打开时内容容器降级为透明无装饰占位，标题行复用统一外壳但内容区保持虚线降权（守住 B-3 空轻满重），删除 `ZoneGridCell.buildTitleRow`
- **O3 手势层统一**：聚焦态 item 行原用 `Stack(透明 Image 手势层 + ChecklistRow)`，与网格态 `Column` wrapper 不一致。统一改为 `Column(){ ChecklistRow }.gesture(LongPressGesture 400→handleLongPress)`，tap 由 ChecklistRow onClick 处理
- **O4 分隔点可见度**：列表元信息分隔点原用 `DIVIDER_COLOR(#F0F0F0)` 过淡看不见。新增 `META_SEPARATOR(#C2C2C2)` token（弱于 plain 文字 #999、强于纯背景线），TripDetailPage 分隔点改引用
- **P3 维持 / O1·O2 不改**：聚焦浮层 `maxHeight '80%'` 维持（父容器 `height('100%')` 确定 + 已有 `'60%'` 生产先例，待真机验证）；O1 分隔点本身、O2 follow:true 平滑度评估后不改

> 待真机验收（无法自动化）：P3 maxHeight '80%' 是否生效、O2 zone_* follow:true 转场平滑度、D 阶段录屏对比便单。

## v0.7.0 (2026-06-11)

带格子的核查清单（统一视图）· PackCheck 第二个灵魂。砍掉配装/清单 Tab 切换，合并为单一界面：预设身体部位格子作为分组骨架，格子里填装备 + 出发前逐项打勾。

- **统一视图重构（Phase 1-3）**：行程详情页移除配装/清单 SegmentButton，合并为 `UnifiedChecklistView`。网格态展示 7 个身体部位 Zone（2 列网格 + 杂项跨列，`ZoneGridCell`），空行程直接铺虚线空格子（去掉引导页）；点格子走 `geometryTransition` 共享元素转场放大铺满全屏聚焦态（`FocusedZoneView`）逐项核查。装备按 `category` 经 `LoadoutService.groupByZoneAll` 自动归入对应格子
- **第一批真机问题打磨（P1-P5）**：网格态双热区（圆圈勾选 / 行其余进聚焦）；降格高露 4 条摘要 + 底部渐隐遮罩；GearPickerSheet 去品类 tab 改分组折叠；新建装备入口顶部常驻 + 搜不到就建 + 临时入库二选一
- **聚焦态完整交互体系（问题4 第一批 · 4a/4b/4c）**：
  - 4a：focusedZone 三层 @Link 透传（Index→TripDetailPage→UnifiedChecklistView→FocusedZoneView）；onBackPressed 分层拦截（sheet→关闭 / 聚焦态→收起 / 否则→回首页）；收起走 `focusedCloseSignal` 信号递增保留 SPRING_HERO_COLLAPSE 退场动画
  - 4b：点格子空白 / 左右划（PanGesture Horizontal 24vp）即收起回网格，不新增返回按钮——借力 ArkUI 事件消费机制，子元素各自消费点击、仅空白冒泡触发收起
  - 4c：单击装备名手风琴展开详情（`checkOnlyHotzone` + `onTapRow` → `toggleExpand`），经 `fromGearId` 反查 GearItem 取 category/brand/note 用 Flex wrap chips 展示，同时只展开一项
- **预埋（4d 推迟 phase4）**：聚焦态长按弹二级菜单 + 长按转拖拽跨 Zone 移动。三回调（onEditItem/onRemoveItem/onMoveItemToZone）透传链已贯通 + `Index.moveItemToZone` 改 group 逻辑就绪

**Phase 4 — 连贯手势（长按菜单 + 跨 Zone 拖拽流转）· 2026-06-11 完成**

- **自绘长按浮层（阶段1）**：`GearItemContextMenu` 新建自绘组件，长按 ≥400ms 弹出装备详情悬浮缩略图（品类/重量/品牌/备注，复用 GearPage 视觉）+ 浮动菜单（编辑/移动到…/移除，红色删除）。触觉反馈 `vibrator` 轻档。支持 full 模式（网格态 LongPress+Pan）和 menu-only 模式（聚焦态仅 LongPress）
- **跨 Zone 拖拽流转（阶段2）**：`GestureGroup(Sequence, LongPress(400) + Pan(distance:5))` 绑在 ChecklistRow wrapper 上实现便单式一气呵成——长按出菜单→不松手 Pan 接管→松手落位。落点经 `onAreaChange` 预缓存 zone 全局坐标 + 轻量矩形碰撞检测判定目标格，`Index.moveItemToZone` immutable 更新 group 字段持久化
- **跟手胶囊 + 格子 glow 高亮**：拖拽态白色圆角胶囊 `position()+dragCurrentX/Y` 实时跟手；目标格子 `isDropTarget` prop 驱动 PRIMARY_COLOR 2.5vp 绿框 + `#402D7D46` 光晕 shadow；进入新 zone 时 tick 触觉反馈；源位置半透明影子占位
- **拖拽态交互细节**：蒙层 dragging 阶段 opacity→0（全程常亮）；菜单→拖拽 EASE_FADE 120ms 交叉淡入淡出；拖拽期 `enableScrollInteraction(false)` 锁 Grid 滚动；松手 SPRING_GENERAL 回弹后 resetDragState
- **gearTripCount 实时派生重构**：`computeGearTripCount(gearId, trips)` → 遍历所有行程 Set 去重计数，GearPage 排序/预览/芯片全链路改为实时调用；不再依赖 `GearItem.tripCount` 缓存字段，消除数据不同步隐患

**Phase 1-4 系统性 Bug 修复 · 多轮**

- **HitTestMode.None 不可靠**：ZoneGridCell Stack 双层常驻（空态叠在有内容态上），父层 `hitTest(None)` 不阻止子元素 onClick → 所有点击/勾选/长按被空态虚线区拦截路由到 GearPicker。修：回退 if/else 条件渲染（两种状态不可同时存在视图树）
- **格子高度异常**：if/else 替代 Stack 后丢失外层 `.height(cellHeight)` 约束，100% 在 Grid 中解析为全屏高度。修：加 Column wrapper 承载 cellHeight
- **长按手势失效**：GestureGroup 绑在下层 Image，上层 ChecklistRow.onClick 独占触摸序列 → LongPressGesture 永远等不到 400ms。修：GestureGroup 移到包裹 ChecklistRow 的 Column wrapper 上，wrapper 只有 gesture 无 onClick
- **聚焦转场退化为淡入淡出**：GridItem `visibility(Hidden)` 使元素脱离渲染树 → geometryTransition 丢失源配对端。修：改 `opacity(0)+hitTest(None)` 保留在树中
- **勾选无即时视觉反馈**：ForEach key 含 `checked` 状态 → toggle 后 key 变 → 组件销毁重建 → aboutToAppear 直设终值跳过 @Watch 弹跳动效。修：网格态/聚焦态两处 ForEach key 去掉 checked，仅 `item.id`
- **拖拽胶囊/高亮坐标错位**：全局坐标当局部坐标喂 `position()` + Pan offset 累积方式错误。修：`onAreaChange` 加空守卫防护 globalPosition undefined，新增 `longPressGlobalX/Y` + `dragCurrentX/Y` 单坐标系 `position()` 方案
- **底部渐隐灰色**：`TRANSPARENT(#00000000)`→`PAGE_BG` 渐变中段混合出灰色矩形。修：起始色改用 `#00F8F9FA` 透明羽白
- **勾选+拖拽触觉反馈补全**：ChecklistRow 勾选时 vibrator tick，进入新 drop zone 时 vibrator tick

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

v2「装备陪伴」转型 · 第一步地基层完整落地。

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

## v0.5.8 (2026-06-04)

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

## v0.5.6 (2026-05-31)

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

## v0.5.4 (2026-05-31)

装备库 5 项体验优化：交互细节打磨。

- **搜索自动展开分组**：搜索有关键词时 `isGearGroupCollapsed()` 强制返回 false，匹配结果所在折叠分组自动展开
- **拖拽浮动卡片定位修正**：浮动分组卡片 Y 坐标从 `groupDragY - 20` 调整为 `groupDragY - 14`，手指下方直接出现卡片
- **分组折叠 Spring 动画**：`animateTo(springMotion(0.35, 0.8))` + `.transition(OPACITY + translate)` 实现丝滑展开/收起
- **多选点击区域扩大**：PanGesture distance 从 0 → 5，轻点整行即可 toggle 选中（不再只有 checkbox 响应）
- **行程托盘动态滚速**：边缘加速（二次曲线 t²），minSpeed=2 / maxSpeed=12，托盘尺寸优化（卡片 88×68，间距 10）
- CLAUDE.md 新增第 25~27 条避坑：搜索态绕过折叠 / PanGesture distance 阈值 / if-else 过渡动画

## v0.5.3 (2026-05-30)

清单页 Bug 修复 + 快速核查快捷入口。

- **Bug 修复：Sheet 覆盖层被 NavDestination 遮挡** — 将 SheetOverlay/EditItemPanel/EditGearPanel/TripCeremonyCard/CompletionToast 从 Navigation 内部移至外层 Stack，确保渲染在 NavDestination 之上
- **Bug 修复：清单详情页与首页数据不一致** — ForEach key 从 `item.id` 改为 `item.id + items.length + nonce`，新增 `checklistRenderNonce` 计数器强制刷新
- **Bug 修复：GearPage bindSheet borderRadius 无效属性** — 移除 SheetOptions 中不支持的 `borderRadius`
- **快速核查 QuickEntry** — 首页第二个快捷按钮从「装备库」替换为「快速核查」，点击直接进入最近未来行程的 ReviewMode，减少操作路径
- 按钮状态机：无未来行程隐藏；items=0 跳详情页+toast；全勾选"再检查一遍"；有未勾选"快速核查"
- CLAUDE.md 新增第 23~24 条避坑：Navigation 覆盖层层级 / ForEach key 变化维度

## v0.5.2 (2026-05-30)

装备库增强：弹性回弹 + 分组拖拽排序 + Bug修复。

- 弹性回弹：`EdgeEffect.Spring` + `alwaysEnabled: true`，内容不满屏时也有 iOS 风格橡皮筋效果
- 分组拖拽排序：长按 300ms 分组 header → 浮动整组跟手拖拽 → 碰撞检测让位 → 松手归位 + 持久化 categoryOrder
- 分组按压反馈：header 按下 `scale(0.97)` + `springMotion(0.25, 0.7)` 弹性回弹
- 灰色间隙修复：topSpacer 减去 List 的 padding-top + space，消除 Header 底边与首个分组间的灰带
- 搜索框修复：从 Column 流式布局移至根 Stack + `position(0, COLLAPSED)`，搜索展开时强制 Header 收缩
- PackStore 新增 `categoryOrder` 持久化（getCategoryOrder / saveCategoryOrder）
- CLAUDE.md 新增第 21~22 条避坑：浮动 Header spacer 计算 / 浮动组件定位

## v0.5.1 (2026-05-30)

多选拖拽交互全面优化，达到 Apple/Linear 级流畅度。

- 长按响应加速：多选模式下 LongPressGesture 400ms → 200ms，手指按下几乎立即触发拖拽
- 多选原地化：进入/退出多选不再销毁/重建 Header（消除跳页感），CollapsingHeader 内部 if/else 切换内容
- 拖拽跟手修复：去除手势坐标的 `px2vp` 误用 + DragGearStack 加 `.animation({duration:0})` 消除插值滞后
- macOS Dock 磁吸动效：底部行程卡片基于距离实时计算 proximity，连续 scale/translateY 变化 + 命中时弹跳确认 + 40ms 振动反馈
- 托盘视觉升级：capsule 拖拽指示器、`#E8FFFFFF` + backdropBlur(40)、border-radius 24、增强阴影
- 手势返回：根 Stack 添加 SwipeGesture(Horizontal) 右滑退出多选模式
- CLAUDE.md 新增第 18~20 条避坑：手势坐标单位/拖拽 duration:0/多选 Header 稳定性

## v0.5.0 (2026-05-29)

质感跃迁：视觉细节打磨，从「功能完整」迈向「值得截图」。

- 等宽数字：全局数字组件加 `.fontFeature("'tnum'")`，消除数字变化时宽度抖动（WeightGauge / HomePage 倒计时 / 清单进度 等 ~31 处）
- 噪点纹理背景：64×64 grayscale noise PNG 全屏平铺覆盖层（opacity 0.025），赋予界面纸张质感
- Section Breathing 分组呼吸：首个分组 marginTop 4vp、后续分组 20vp，列表组间有节奏性留白
- 暖琥珀警示色系：新增 `AMBER_ACCENT #E8890C` / `AMBER_TINT #FFF5E6`，用于倒计时 ≤3 天 + WeightGauge 80-100% 接近目标/预算态
- 卡片底部微边框：0.5vp `#F0F0F0` 底部边框，增强卡片层次感
- 错落动画加速度曲线：staggerDelay 公式升级为 `index * 30 + index² * 4`（cap 400ms），首项极快末项从容
- DesignTokens / AnimationTokens 新增多个设计常量
- 已回滚：打勾墨水扩散效果（实机表现不佳）

## v0.4.2 (2026-05-29)

结构重构：可读性与可维护性优化。

- Sheet 组件化提取：6 个 inline @Builder Sheet 提取为独立组件到 `components/sheets/`，新增 SheetOverlay 容器组件
- 命名空间导出优化：GearService/ChecklistService 新增 `GearCalc`/`CheckCalc` class 聚合导出，Index.ets import 区从 58 行别名缩减为 2 行
- Index.ets 从 2514 行精简至 2045 行（-18.6%），零功能/UI 变化
- CLAUDE.md 新增第 16 条避坑：ArkTS `arkts-no-untyped-obj-literals` 规则

## v0.4.1 (2026-05-28)

首页行程展示修复 & 装备库折叠屏适配。

- HeroCard 响应式修复：去参数化改为内部直接读 `latestChecklist()`，删除行程后卡片立即刷新
- 分区标题视觉优化："即将启程"/"走过的路" fontSize 13 + FontWeight.Medium + TEXT_SECONDARY + left padding
- 颜色系统统一：`heroGradientStart()` 全改为绿色深浅色阶，移除 COUNTDOWN_ORANGE，整体视觉从多色警告收拢为山野绿单色系
- 行程列表紧凑化：行高 72→60vp，时间轴圆点/竖线等比缩小，底部 padding 80→32vp 让内容穿透 TabBar 毛玻璃
- FAB 折叠屏适配：根容器 onAreaChange 监听尺寸变化，折叠/展开时 FAB 自动 spring 动画吸附到正确边缘

## v0.4.0 (2026-05-28)

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

## v0.3.1 (2026-05-27)

仪式卡片交互完善 & 项目整理。

- 日期选择器修复：内联实现避免 `@Builder` 回调 this 丢失，选择日期后正确回显并应用到清单
- 日期格式补全：显示完整年月日（2026年5月27日）
- 未填名称时仅输入框水平抖动 + 边框闪红，不再整张卡片抖动
- 点击空白区域收起键盘（`onTouch(TouchType.Down)` 不阻塞子组件点击）
- 输入框字号统一为 14，与标题一致
- 项目文档和目录结构整理

## v0.3.0 (2026-05-27)

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

## v0.2.0 (2026-05-26)

首页体验升级。

- 数据排序修复（清单按创建时间倒序）
- GearPage 沉浸式折叠头部
- HomePage 折叠头部增强（滚动驱动标题缩放）
- 全屏沉浸式布局 + 窗口背景色统一 `#F8F9FA` 消除闪屏色差
- Phase tokens 引入，为动效升级打基础

## v0.1.0 (2026-05-25)

核心功能完成，首个可用版本。

- 装备库 CRUD（名称/分类/重量/价格/备注）
- 出行清单创建 & 打勾核查
- 从装备库导入物品到清单
- UI 精致化（Spring 动效、卡片圆角、主题色）
- 折叠头部基础实现
- 本地 Preferences 持久化
