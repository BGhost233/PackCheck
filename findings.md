# 研究发现 — 10 问题根因定位

## 问题1 — 长按直角深灰矩形（ChecklistRow.ets）
- 第144行 `.backgroundColor(this.pressed ? '#33000000' : TRANSPARENT)`
- 半透明黑 + Row 无圆角 → 直角深灰矩形，割裂
- 收缩态 + 聚焦态共用此组件（聚焦态第255行 checkOnlyHotzone:true）
- 第68行 onCheckedChange 内已有 hapticTick()（仅状态翻转触发）

## 问题5 — 收缩态展示数（ZoneGridCell.ets）
- 第32行 `MAX_PREVIEW_ITEMS: number = 4` → 改 5
- GRID_ROW_HEIGHT=32、GRID_CHECK_SIZE=20

## 问题2 — 选择装备 Sheet（GearPickerSheet.ets，742行）
- 第196-207行列表 `Scroll(){...}.layoutWeight(1).scrollBar(BarState.Off)` — **无 EdgeEffect.Spring**（滑动僵硬根因）
- head 第117-133行（36vp 标题+搜索+已选汇总）**固定不折叠**
- 列表态/新建态 Stack 叠加；buildCategorySection 第413行分组可折叠；buildGearRow 第474行

## 问题6 — 创建卡标题扫光（TripCeremonyCard.ets，1166行）
- shimmer 第964-972行：60vp 宽光带在 20vp 高 clip(true) 标题行平移
- 用 SHIMMER_WHITE_FAINT / SHIMMER_GREEN_GLOSS
- startTitleShimmer() 第248-261行循环
- **确认是创建行程大卡片（TripCeremonyCard），非其它**

## 问题7 — 核查卡片滑动（ReviewPage.ets，324行）
- 卡片仅 `.translate({x: reviewDragX})` 跟手平移（第202行）
- 松手后 reviewIndex 直接跳变 = 硬切，无旋转/缩放/透明度/飞出飞入
- PanGesture 第203-217行

## 问题8 — 庆祝动画（Index.ets，2789行）★根因在此
- showAchievement() 第1940行：**同时**弹 CompletionToast（🎉emoji 顶部横幅 @Builder 第2695行）+ showToastMessage('全部就绪，出发吧！')
- 两个庆祝叠加 + emoji 风 + 无精致动效。调用点第1913/1936行
- 关联：LoadoutProgressBar.ets 第133-138行 celebrateScale 1.04；HomePage.ets checkCelebration() 第433行 heroRingCelebrateScale=1.35 + CELEBRATE_GOLD 金色脉冲
- **用户选：克制高级方向**

## 问题4 — 网格底部两格消失（UnifiedChecklistView.ets，1043行）★疑似根因
- buildGridState 第837-930行
- ForEach(GRID_SINGLE_ZONES) 前 6 zone 双列（=3行），杂项格第881行单独跨2列（=1行），共 4 行
- 第921-930行：columnsTemplate('1fr 1fr')，width/height 100%，padding bottom:100，scrollBar Off，**有 edgeEffect Spring**，**未见 .cachedCount()**
- cellHeight 反算第824-828行：usable = visibleHeight - GRID_GUTTER*2.8，h=usable/2.8（FIRST_SCREEN_ROWS=2.8）
- 疑似：Grid 默认虚拟化回收屏幕外 GridItem，末行某滚动位置被回收消失 → 需 cachedCount 足量
- **必须构建复现确认是 cachedCount 还是高度计算**

## 问题10 — 编辑菜单（EditGearPanel.ets，260行）
- 居中大弹窗，name 第120行 / note 第177行 都 48vp 大文本框
- 字段竖排 16vp 间距，松散
- 用 SPRING_PANEL_ENTER/EXIT

## 问题9 — 单品长按拖动（GearPage.ets，2092行）★最复杂
- 已有 group 级拖拽 groupDragMode（第124、1952-2052行：splice+spring 让位+碰撞检测+持久化 categoryOrder，**可复用**）
- 单品长按当前 = bindContextMenu（第1526-1539行 ResponseType.LongPress），**无单品级拖拽**
- 多选后长按拖到行程 dragMode（第1350-1373行 GestureGroup LongPress 400ms + Pan，可参考范式）
- 行程详情页范式：UnifiedChecklistView handleGridLongPress 第653行 + handleDragUpdate/End + checkAutoScroll 边缘自动滚动 + buildLongPressOverlay 第952行（长按弹菜单 overlayPhase: idle→menu→dragging）

## 问题3 — Check 震动（ChecklistRow.ets）
- 第68行已有 hapticTick（仅 toggle 完成触发），需改「按下即响」（onTouch Down）

---

## 通用约束（来自 DEVELOPMENT_STANDARDS + 避坑 46 条）
- 构建命令：`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon`
- 避坑 #7：同属性禁 .animation()+animateTo() 并存
- 避坑 #17：静止态必须中性值
- 避坑 #38：@State 数组禁原地 mutation
- 避坑 #44/#45：hitTestBehavior/GestureGroup 不阻止子 onClick
- 避坑 #46：随滚动折叠必走 HeadCollapseController
- token 文件：Colors/Typography/Layout/AnimationTokens.ets，禁硬编码
- Spring 预设：SPRING_GENERAL(0.35/0.8)、SPRING_PRESS(0.25/0.7)、SPRING_SCROLL(0.45/0.85)、SPRING_PANEL_ENTER/EXIT、SPRING_CEREMONY_*、SPRING_CHEVRON
- 触觉 HapticUtils：hapticTick/hapticSoft/hapticSharp/hapticTime/hapticPreset
- 主题色 #2D7D46 / 背景 #F8F9FA / 琥珀 #E8890C / CELEBRATE_GOLD
