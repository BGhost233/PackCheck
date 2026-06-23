# PackCheck 路线图

> 最后更新：2026-06-14 | 当前版本：v0.7.7（已完成）
> 文档清理：2026-06-13 — 已删除所有已完成的 plan 文件（地基层/UX修复/质感提升），仅保留 specs 作为设计参考。

---

## 已完成

### ✅ 第一步 · 地基层（v0.6.0）

v2「装备陪伴」转型的基础全部就位：3 Tab、数据字段、人生足迹年报、装备双段展开、渐进 chip 录入、配装数据种子。

### ✅ Sheet 体系统一 + 配装质量加固（v0.6.1）

9 种 Sheet 全部走集中式 SheetOverlay + 下滑关闭手势 + 景深参数统一。配装系统三轮深度审查修复（7 Critical @State mutation + timer 泄漏 + 退场动画 + counter 脱同步 + 空态 + NaN 防御 + 按压反馈补全）。

### ✅ 顶部折叠交互统一（v0.7.5）

head 随滚动折叠全面对齐 iOS Large Title（跟手 1:1 + 松手就近吸附），抽出 `utils/HeadCollapseController.ets` 统一滚动数学内核，消除 TripDetail/Home/Gear 三处重复实现。抽象边界：只统一滚动数学、不统一 head 渲染（inline 塌缩 vs overlay 定高变形两种范式透明）。详见 DEVELOPMENT_STANDARDS §4.3。

---

## 🟢 已完成（v0.7.0）—— 带格子的核查清单（统一视图）

> **来源**：产品愿景纲领 §4（v3 修订）+ 技术 spec §6 + 地基层计划第二步。这是 PackCheck 的第二个灵魂。
>
> **进度**：Phase 1-5 全部完成（2026-06-23）。统一核查清单视图已从配装/清单双 Tab 切换全面重构为单一网格界面，含全屏聚焦态、长按菜单、跨 Zone 拖拽流转、gearTripCount 实时派生。仅剩行程→装备自动反哺闭环。

### 背景

纲领文档定义了两个灵魂：装备陪伴（经历连接）和带格子的核查清单（科学打包）。前者已在地基层落地。后者的核心是：预设身体部位格子作为清单的分组骨架，用户在格子里填装备 + 出发前逐项打勾，一个统一界面完成全部。

### 任务清单

- [x] **合并配装/清单为统一视图**：砍掉行程详情页的 SegmentButton（配装/清单 Tab 切换），合并为单一 `UnifiedChecklistView`（Phase 1）
- [x] **格子始终可见**：7 个身体部位分区始终展示（2 列网格 + 杂项跨列），用 `GearLoadout.ets` 的 `BodyZone` 枚举 + `groupByZoneAll`
- [x] **空态设计**：空行程直接铺虚线空格子（不再有引导页），点「+」进 GearPickerSheet（Phase 1 + P1）
- [x] **全屏聚焦态**：点格子 `geometryTransition` 共享元素转场放大铺满全屏，逐项核查（Phase 3）
- [x] **真机交互打磨**：网格态双热区 + 降格高露 4 条 + 底部渐隐 + GearPickerSheet 去品类 tab 改分组折叠 + 新建装备顶部常驻/搜不到就建/临时入库二选一（P1-P5，第一批真机问题）
- [x] **聚焦态交互体系（问题4 第一批）**：点空白/左右划收起回网格、单击装备名手风琴展开详情、onBackPressed 分层拦截（4a/4b/4c）
- [x] **聚焦态长按菜单 + 拖拽跨区**（Phase 4，**已完成**）：自绘长按浮层（GearItemContextMenu）+ `GestureGroup(Sequence, LongPress(400)+Pan(5))` 跨 Zone 拖拽流转 + 跟手胶囊 + drop zone glow 高亮 + 勾选/拖拽触觉反馈
- [ ] **行程→装备自动反哺闭环**：填完行程足迹自动喂给装备陪伴卡片（地基层已铺好 `fromGearId` 关联、`FootprintService` 聚合，缺的是创建行程时自动更新关联装备统计的触发逻辑）

### 参考文档
- `docs/v2-foundation/specs/2026-06-22-unified-checklist-view-design.md`（**主 spec**：统一核查清单视图完整设计，含 UI/交互/技术/路线）
- `docs/vision/2026-06-04-product-vision-and-restructure.md` §4（v3 修订：格子即清单，一体不分家）
- `docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md` §6（带格子的核查清单 spec）
- `entry/src/main/ets/constants/GearLoadout.ets`（已预埋的格子分组映射数据）

---

## 🟢 已完成（v0.7.1）—— UI 质感提升 + 审查修订

> **来源**：质感提升设计论证（plan 文件已归档删除）+ 外部审查文档（Everest, 2026-06-23）。
>
> **进度**：Phase A-E 全部完成（2026-06-23），其后按审查文档落地 P1/P2/O3/O4 修订。

### 背景

v0.7.0 功能骨架已完整，但与便单的质感差距主要在容器存在感、状态对比度、交互物理感三件事。本阶段仅做视觉与交互反馈层精装修，不碰信息架构。

### 任务清单（按 Phase A→E 顺序）

- [x] **Phase A — 拖动态去灰**：蒙层 dragging 阶段 opacity→0 + 胶囊浮起（scale 1.05 + 阴影加深）
- [x] **Phase B — 容器化**：满格子白卡加 `ZONE_*_STROKE` 极淡描边 + 阴影升级 + 标题行浅染 `ZONE_*_TINT` 背景；空格子「空轻满重」降权（虚线框 + 不进 geometryTransition）；列高对齐
- [x] **Phase C — 拖动物理感深化**：源位虚线空槽 + 目标格高亮微调
- [x] **Phase D — 展开态+转场重构**：抽共享 `ZoneShell` 外壳 → 两端外壳 100% 一致让 `geometryTransition` 就地放大（zone_* 用 `{ follow: true }`）→ 背景联动压暗/虚化下沉（不缩放）
- [x] **Phase E — 顶部信息区 + 进度条 + 勾选态**：元信息行图标点睛 + 进度条 SPRING_COUNTER 填充 + 勾选完成态强化

### 审查修订（commit `4405f6b`）

- [x] **P1/P2**：空态标题行复用统一 `ZoneShell`（新增 `contentDashed` 开关，内容区降级为虚线占位），消除 `buildTitleRow` 平行实现
- [x] **O3**：聚焦态 item 行长按手势从透明 `Stack` 图层统一为 `Column` wrapper + `LongPressGesture`，与网格态一致
- [x] **O4**：列表元信息分隔点新增 `META_SEPARATOR(#C2C2C2)` token（弱于正文、强于背景线），修正旧 `DIVIDER_COLOR` 过淡看不见
- [x] **P3**：聚焦浮层 `maxHeight '80%'` 维持（父容器 `height('100%')` 确定，沿用 `'60%'` 生产先例）；O1/O2 评估后不改

### 待真机验收（无法自动化）

- [ ] P3 maxHeight '80%' 百分比在真机生效；O2 zone_* `{ follow: true }` 转场平滑度；D 阶段录屏对比便单

### 参考文档
- CHANGELOG.md v0.7.1 条目（施工记录）

---

## 🟢 已完成（v0.7.2）—— 聚焦态满铺精装修

> **来源**：真机打磨反馈，第一轮 + 第二轮，2026-06-12 完成。

- [x] 顶部日期行 + 进度条双层 collapse 收没，聚焦卡片满铺顶到 navbar 下沾
- [x] 纯羽白实心遮罩（PAGE_BG）盖住网格虚影
- [x] 新增 7 个 `ZONE_*_FOCUS_BG` 近实心淡色 token（20% 白底混合）+ 2vp zone 主题色边框
- [x] 去右上角 ×键，改「点卡片空白返回」——复用 ZoneShell contentClickable + onTapContent 内部链路

---

## 🟢 已完成（v0.7.3）—— 数据一致性 + 按压反馈补全

> **来源**：数据审计 + 动效审计，2026-06-13 完成。

- [x] **checklistRenderNonce 修复**：4 条装备 mutation 路径（batchDelete/batchMove/categoryDelete/categoryRename）缺失 nonce 递增，导致 UnifiedChecklistView 渲染不刷新 → 全部补齐 + ForEach key 拼入 nonce
- [x] **resolveItemName 实时查找**：ChecklistItem 显示名称优先从 gears 数组实时查找，fallback 到快照，确保改名后即时反映
- [x] **GearPickerSheet 按压反馈**：装备行 / 品类胶囊 / Zone 胶囊三处补全 scale press
- [x] **GearPage 按压反馈**：排序按钮 / 筛选胶囊 / 搜索胶囊 / 取消文字 / DeleteAction / WeightEditor 关闭按钮补全
- [x] **buildGearTripCountMap 派生**：消除已死 GearItem.tripCount 字段，运行时遍历 trips 实时计算

---

## 🟢 已完成（v0.7.4）—— 行程详情页格子交互三 Bug 修复

> **来源**：真机测试反馈，2026-06-13 完成。

- [x] **ChecklistRow 白底突兀**：装备行背景色从 `CARD_BG` 改为透明，融入 ZoneShell 底色
- [x] **长按穿透触发 onClick**：新增 `longPressTriggered` 标志位防止 GestureGroup Sequence 完成后子节点 onClick 双重触发（ZoneGridCell + FocusedZoneView）
- [x] **上下文菜单关闭困难**：覆盖层 hitTestBehavior 改为仅菜单可见时拦截，其余时刻完全透传
- [x] **FocusedZoneView 多选模式保护**：`longPressTriggered` 赋值移至 early return 之前

---

## 🟢 已完成（v0.7.6）—— 行程详情页顶部体验收口 + 全屏沉浸

> **来源**：真机观感反馈，2026-06-14 完成。

- [x] **navbar 重做**：删 `···` 更多菜单换单一「逐项核查」图标入口（统一首页核查肌肉记忆）+ 三元素垂直居中对齐 + 高度 56→40 消无效空白
- [x] **标题随折叠呼吸（方案 A）**：标题随 `effectiveHeadCollapse()` 插值字号（20→17）+ 下沉（4→0），与 SharedInfo 同帧被压扁，消除「上半身死板不动」割裂感
- [x] **减法**：删底部纯色弥散遮罩（`buildBottomFade` + linearGradientBlur）+ 拖拽落点保持格子本色
- [x] **全屏沉浸**：EntryAbility 开 `setWindowLayoutFullScreen`，避让高度经 AppStorage 下发，三页折叠头补 statusBar 避让

---

## 🟢 已完成（v0.7.7）—— 装备库单品拖拽真机回归 + 跨分组 spring-load 悬停展开

> **来源**：真机验收回归，2026-06-14 完成。承接 v0.7.0 问题9 单品拖拽排序/跨分类移动的真机体验打磨。

- [x] **问题9-A 拖拽避让丝滑让位**：被拖项留透明洞 + `gearRowShiftY` 算兄弟行 translateY 把洞视觉迁移到插入点（全程 SPRING）；拖拽态冻结 `onAreaChange` rect 采集防命中反馈回路
- [x] **问题9-B 松手 optimistic 落位去卡顿**：`reorderGears` 去 await、持久化抽 `persistGearsInBackground` fire-and-forget；落位帧与 overlay 收起帧用 `setTimeout(0)` 错帧解耦
- [x] **跨分组 spring-load 悬停自动展开**：拖到折叠分组悬停 500ms 自动展开（临时展开集合与持久化偏好解耦）；路过收回、落位转正保持展开

---

## 🟢 已完成（v0.7.7-perf）—— 全面性能优化

> **来源**：2026-06-14 全项目代码审计，识别 P0-P3 级性能问题 11 项，实施 8 步优化。

- [x] **`groupByZoneAll` 单次分桶**：7×filter O(7N) → 预初始化 Map + 单次遍历 O(N)
- [x] **`display.getDefaultDisplaySync()` 缓存**：IPC 跨进程调用从每帧重复→`aboutToAppear` 一次性缓存
- [x] **GearPage 缓存体系**：`rebuildGearCache()` 在 @Watch 中一次性计算 filteredGears/groups/byGroup，build 帧计算量减少 80%+
- [x] **拖拽索引预算 O(1)**：`dragItemIndexMap` 进入拖拽态预算，`gearRowShiftY` 从 O(N²)→O(1)/帧
- [x] **TripDetailPage 缓存**：`cachedTrip` + `cachedMetaSegments` 消除 build 中重复线性扫描和数组重构
- [x] **gearIndex 父级构建 @Prop 下发**：8 个子组件各自构建 → 父级 1 次构建下发，消除 7N 冗余遍历
- [x] **ForEach key 精确化（zoneKey）**：全局 nonce 导致 7 格全重建 → zone 维度内容哈希，勾选操作重建从 7 格→1 格
- [x] 构建验证通过（BUILD SUCCESSFUL in 10s）

### 参考文档
- `docs/PERF_OPTIMIZATION_PLAN.md`（完整方案 + 预估收益）

---

## 🟡 中期（v0.8.0）—— 组件架构瘦身

> **来源**：2026-06-10 代码审查 §3 + 本次设计文档 Tasks G-H-I。

### 背景

GearPage 当前 ~2270 行，26 个 @State，9 个 @Prop，承担 8 个独立子系统。需要将自包含的子系统提取为独立组件，降低耦合度和单个文件复杂度。

### 任务清单

- [ ] **提取 FabController**：FAB 拖拽定位 + 边缘吸附 + 重量编辑器弹窗。减少 GearPage @State -7。接口：`@Link targetWeightGram` + `@Prop gearCount/totalWeightGram/totalPriceYuan` + `onOpenAddGear`
- [ ] **提取 DragToTripOverlay**：装备拖拽到行程托盘的模态浮层。减少 GearPage @State -5，回调 -2。接口：`@Prop dragMode/dragStartX/dragStartY/checklists/selectedMultiGearIds` + `onAddGearsToTrip/onAddGearsToNewTrip/onCancelDrag`
- [ ] **提取 GroupDragController**：分组长按拖拽重排序。减少 GearPage @State -6。接口：`@Prop groupDragMode/dragGroupName/dragGroupCount/dragStartY/groupOrder/groupCardHeights` + `onReorderComplete`
- [ ] **GearPage 最终状态**：@Prop ~8，回调 ~13，@State ~12，组件行数 ~1600（符合规范）

### 参考文档
- 原设计方案文件已删除，核心内容已整合到此路线图中

---

## 🟣 远期（v1.0.0）—— 智能 & 沉淀

> 这些是产品愿景中的第三步（智能）内容，优先级低于统一清单视图，但在其完成后自然成为下一步。

### L2 智能 PackCheck

- [ ] 按行程类型/目的地/历史主动提示"你这次可能需要带 X"
- [ ] 还没打勾的装备置顶提醒
- [ ] 基于历史行程的智能推荐

### 轻量成就卡分享

- [ ] 「我」Tab 生成可分享的成就卡图片（非主轴、克制、锦上添花）
- [ ] 包含关键数字（累计里程/爬升/相伴最久伙伴）+ 留白设计

### 体验打磨

- [ ] 深色模式完整支持（Colors token 体系已预留，`dark/color.json` 已配置启动色）
- [ ] 平板/折叠屏适配验证（module.json5 已声明 tablet/2in1）
- [x] 无障碍：关键操作元素添加 `.accessibilityText()`（2026-06-12 已补全核心路径）
- [x] 全局按压反馈补全（v0.5.9–v0.7.3 逐步补齐，仅剩 FAB/Tab bar 等有独立反馈机制的元素例外）

### 可选的体验增强

- [ ] 行程内「已装包」勾选清单交互（L1 packing，`ChecklistItem.checked` 数据底座已就绪）
- [ ] 装备陪伴履历时间轴下钻（第二步可后置）
- [ ] 授权导入两步路/佳明/Strava 轨迹自动算里程/海拔（远期）

---

## 📊 版本总览

| 版本 | 状态 | 核心交付 |
|------|------|---------|
| v0.1–v0.5 | ✅ | 核心闭环 + 动效体系 + 质感打磨 |
| v0.6.0 | ✅ | v2 地基层：3 Tab / 人生足迹 / 双段展开 / 渐进 chip / 配装种子 |
| v0.6.1 | ✅ | Sheet 统一 / 下滑关闭 / 文档重组 |
| v0.7.0 | ✅ 已完成 | 带格子的核查清单统一视图（第二灵魂） |
| v0.7.1 | ✅ 已完成 | UI 质感提升（容器化 + 转场重构 + 拖动深化）+ 审查修订 P1/P2/O3/O4 |
| v0.7.2 | ✅ 已完成 | 聚焦态满铺精装修（遮罩/淡色块/边框/去×键） |
| v0.7.3 | ✅ 已完成 | 数据一致性修复 + 按压反馈补全 |
| v0.7.4 | ✅ 已完成 | 行程详情页格子交互三 Bug 修复 |
| v0.7.5 | ✅ 已完成 | 顶部折叠交互统一（对齐 iOS Large Title：跟手 1:1 + 松手就近吸附） |
| v0.7.6 | ✅ 已完成 | 行程详情页顶部收口（navbar 三元素居中 + 换核查图标 + 标题随折叠呼吸）+ 全屏沉浸 |
| v0.7.7 | ✅ 已完成 | 装备库单品拖拽回归（避让让位 + optimistic 落位去卡顿 + spring-load 悬停展开） |
| v0.7.7-perf | ✅ 已完成 | 全面性能优化（cache-on-@Watch + gearIndex 上提 + zoneKey 精确化 + 拖拽 O(1)） |
| v0.8.0 | 🟡 中期 | GearPage 组件瘦身 |
| v1.0.0 | 🟣 远期 | 智能 PackCheck + 成就卡 + 深色模式 |

---

## 🔗 关键文档索引

| 文档 | 用途 | 路径 |
|------|------|------|
| 开发规范 | 架构/设计语言/动效/组件规范（每次写代码前必读） | `docs/DEVELOPMENT_STANDARDS.md` |
| ArkUI 避坑 | 48 条实战踩坑记录（动效/手势/布局问题先查） | `memory/MEMORY.md` |
