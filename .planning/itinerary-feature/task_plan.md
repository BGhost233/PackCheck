# 每日行程功能（Itinerary Feature）— Phase 1 展示层

## 目标

为 PackCheck 行程详情页新增「每日行程」Tab，以时间线形式展示每天的路线、交通、票务信息。Phase 1 仅做数据模型 + UI 展示 + 动效，不做编辑表单。

## 约束

- ArkTS + ArkUI，API 23+，遵循 DEVELOPMENT_STANDARDS.md 全部规范
- 所有动画 Spring 曲线，时长/颜色/字号走 token
- 向后兼容：TripChecklist 新增 optional 字段，旧数据无影响
- 构建验证：每步改完 `hvigorw assembleApp` 通过才继续
- 每步通过即 commit

## 阶段

### 阶段 1：数据模型定义 `[pending]`

**目标**：在 PackModels.ets 中新增 Itinerary 相关 interface，TripChecklist 扩展 optional 字段。

**具体任务**：
1. 新增 `TransportMode` type union（flight/train/bus/drive/walk/bike/boat/other）
2. 新增 `TicketInfo` interface（type/code?/seat?/price?/note?）
3. 新增 `RouteSegment` interface（id/from/to/transport/departTime?/arriveTime?/note?/ticket?/accommodation?）
4. 新增 `DayItinerary` interface（id/dayIndex/date?/segments/note?）
5. TripChecklist 新增 `itinerary?: DayItinerary[]`
6. 构建验证 + commit

**影响文件**：`models/PackModels.ets`

---

### 阶段 2：ItineraryService 纯函数层 `[pending]`

**目标**：提供数据派生、一致性保障的纯函数。

**具体任务**：
1. 新建 `services/ItineraryService.ets`
2. 实现 `deriveTripMeta(itinerary: DayItinerary[]): Partial<TripChecklist>`
   - 首日 date → TripChecklist.dateAt/date
   - 首段 departTime + 末段 arriveTime → 推算 durationHours（可选）
3. 实现 `getDaySummary(day: DayItinerary): { from: string, to: string, mainTransport: TransportMode, departTime?: string, arriveTime?: string }`
   - 从 segments 首尾提取收缩态所需数据
4. 实现 `getTransportIcon(mode: TransportMode): Resource`
   - 交通方式 → SymbolGlyph 图标映射
5. 构建验证 + commit

**影响文件**：`services/ItineraryService.ets`（新增）

---

### 阶段 3：常量补充（Colors / Layout / AnimationTokens） `[pending]`

**目标**：为时间线 UI 补充必要的 token。

**具体任务**：
1. Colors.ets：新增 `TIMELINE_LINE`（时间线竖线色）、`TIMELINE_NODE`（节点圆点色，复用 PRIMARY_COLOR 或新增）、`TIMELINE_NODE_EMPTY`（空心节点色）
2. Layout.ets：新增 `TIMELINE_LINE_WIDTH`(1vp)、`TIMELINE_NODE_SIZE`(6vp)、`TIMELINE_LEFT_MARGIN`(时间线左侧缩进)、`DAY_CARD_RADIUS`(20vp，复用 CARD_RADIUS 即可)
3. AnimationTokens.ets：评估是否需要新增 token（大概率不需要，复用 SPRING_GENERAL + staggerDelay 即可）
4. 构建验证 + commit

**影响文件**：`constants/Colors.ets`、`constants/Layout.ets`（可能）、`constants/AnimationTokens.ets`（可能）

---

### 阶段 4：NavBar 双标题 Tab 切换器 `[pending]`

**目标**：TripDetailPage NavBar 中间改为双标题（装备准备 / 每日行程），支持点击切换 + 左右滑动连续插值。

**具体任务**：
1. TripDetailPage 新增 `@State tripTabIndex: number = 0`（0=装备，1=行程）
2. 新增 `@State tripTabProgress: number = 0`（0~1 连续值，滑动跟手驱动）
3. 改造 `buildNavBar()`：中间区域从单 Text 改为 Row 内两个 Text
   - 激活态：fontSize 20fp / fontWeight Medium / TEXT_MAIN
   - 非激活态：fontSize 14fp / fontWeight Regular / TEXT_TERTIARY
   - 字号随 `tripTabProgress` 连续插值：`14 + 6 * weight`（weight 0~1）
   - 颜色随 progress 渐变（opacity 或 color 插值）
   - 字重在 progress > 0.5 时瞬间切换
4. 点击非激活标题：`animateTo(SPRING_TAB)` 切换 tripTabIndex + tripTabProgress
5. 与现有 headCollapseProgress 折叠呼吸正交：
   - 激活标题 fontSize = `(14 + 6 * tabWeight) - 3 * collapseProgress`（展开 20→折叠 17）
   - 非激活标题不参与折叠呼吸（保持 14fp）
6. 构建验证 + commit

**影响文件**：`components/gear/TripDetailPage.ets`

**技术风险**：
- 两个 Text 宽度随字号变化时布局抖动——可能需要固定宽度或 `constraintSize`
- 折叠呼吸 × Tab 切换两个 progress 叠加时动画冲突——需确保两个维度独立驱动

---

### 阶段 5：内容区 Swiper + Tab 联动 `[pending]`

**目标**：NavBar 下方内容区改为 Swiper（左右滑动切内容），与 NavBar 双标题实时联动。

**具体任务**：
1. TripDetailPage 中 `UnifiedChecklistView` 外层包 Swiper 或手动 PanGesture 方案
   - 方案 A：`Swiper` 组件 + `.onGestureSwipe()` 回调输出 progress
   - 方案 B：自定义 PanGesture（与首页 HdsTabs 同范式，更可控）
   - **倾向方案 B**：Swiper 的 onGestureSwipe 回调粒度不够细，且与 HeadCollapseController 的滑动手势可能冲突
2. 手势实现：
   - 根容器绑定水平 PanGesture（distance ≥ 10 避免误触垂直滚动）
   - Move 时计算 `deltaX / containerWidth` → 更新 `tripTabProgress`
   - Up 时判断是否过半 + 速率判断 → `animateTo(SPRING_TAB)` 吸附到 0 或 1
3. 内容切换：
   - progress = 0 时只渲染 UnifiedChecklistView（装备）
   - progress = 1 时只渲染 ItineraryView（行程）
   - 滑动中两者并排 translateX 滑动（类似 iOS UIPageViewController）
4. 确保竖向滚动（Grid/List）和横向 Tab 滑动互不干扰
5. 构建验证 + commit

**影响文件**：`components/gear/TripDetailPage.ets`

**技术风险**：
- 水平 PanGesture + 垂直 List 滚动手势竞争——需要方向锁定逻辑（首次移动方向确定后锁定该方向）
- 切换时如果两个重内容并存会有渲染压力——用 `if` 条件渲染 + 退场时延迟 300ms 销毁

---

### 阶段 6：DayCard 组件（收缩态） `[pending]`

**目标**：实现单天行程卡片的收缩态展示。

**具体任务**：
1. 新建 `components/gear/DayCard.ets`
2. Props 设计：
   - `@Prop day: DayItinerary` — 当天数据
   - `@Prop isExpanded: boolean` — 是否展开
   - `onToggle?: () => void` — 点击切换回调
3. 收缩态布局：
   - 白底卡片、圆角 20vp（CARD_RADIUS token）
   - 顶部：Day N · 日期（Subtitle Medium + Caption 灰色）
   - 中间：起点 ──icon──→ 终点（水平 Row，文字 Body Medium，icon 用 SymbolGlyph 对应交通方式）
   - 如果多种交通方式，icon 取 segments[0] 的 transport（主交通）
   - 底部左右：出发时间 / 到达时间（Caption 灰色，用 AMBER_ACCENT 数字？还是保持 TEXT_TERTIARY？倾向后者克制）
   - 最底部：整天备注单行截断（Body Medium / TEXT_TERTIARY，前缀 📝 或无）
   - 无数据的字段隐藏不留白
4. 按压反馈：`PRESS_SCALE_DOWN(0.96)` + `SPRING_PRESS`
5. 构建验证 + commit

**影响文件**：`components/gear/DayCard.ets`（新增）

---

### 阶段 7：DayCard 展开态 + 手风琴动效 `[pending]`

**目标**：实现展开态时间线 UI + 收缩↔展开 Spring 动画。

**具体任务**：
1. 展开态布局（在 DayCard 内部，收缩态下方追加内容）：
   - 左侧时间线：垂直竖线（TIMELINE_LINE 色，TIMELINE_LINE_WIDTH 宽）+ 节点圆点（TIMELINE_NODE_SIZE，PRIMARY_COLOR 实心）
   - 每个 segment 对应两个节点（from + to），相邻 segment 的 to 与下一个 from 合并为一个节点
   - 节点右侧内容：
     - 地名（Subtitle Medium）
     - 时间（Caption / TEXT_TERTIARY）
     - 交通方式 icon + 票务 Chip（如果有 ticket）
     - 住宿信息（如果有 accommodation）
     - 该段备注（如果有 note）
   - 票务 Chip 样式：小圆角胶囊，浅灰底，Body Medium，内容如"CA4567 · 经济舱 · ¥1280"
   - 整天备注底部独立区域
2. 展开/收起动效：
   - `animateTo({ curve: SPRING_GENERAL() }, () => { this.onToggle?.() })`
   - 展开时：内容区 height 从 0 到自然高度（`.clip(true)` 裁切），节点 stagger 入场（opacity 0→1 + translateY -6→0，delay = index × 40ms）
   - 收起时：整体 opacity 1→0 + translateY 0→-6（200ms），然后 height 归零
3. 手风琴互斥：由 ItineraryView 管理 `expandedDayId`，同一时间只有一天展开
4. 构建验证 + commit

**影响文件**：`components/gear/DayCard.ets`

**技术风险**：
- ArkUI 的 height 动画对「内容撑高」的动态高度支持情况——可能需要 `constraintSize + animateTo` 配合
- 时间线竖线"生长"效果如果性能不佳，可降级为整体淡入

---

### 阶段 8：ItineraryView 组件（列表 + 空态） `[pending]`

**目标**：Itinerary Tab 的容器组件，管理天列表 + 空态。

**具体任务**：
1. 新建 `components/gear/ItineraryView.ets`
2. Props 设计：
   - `@Prop itinerary: DayItinerary[]` — 行程数据
   - `@Prop gearItems: GearItem[]` — 预留（Phase 2 关联用）
3. 空态展示（itinerary 为空或 undefined 时）：
   - 居中布局，视觉重心偏上 1/3
   - 虚线 + 空心圆点（表达"时间线等你填充"）
   - 主文案："还没有行程安排"（Subtitle Medium / TEXT_SECONDARY）
   - 副文案："记录每天的路线，出发时不再手忙脚乱"（Body Medium / TEXT_TERTIARY）
   - "添加第一天" 文字链按钮（PRIMARY_COLOR，点击预留 onAdd 回调）
   - 入场动画：opacity(0→1) + translateY(8→0)，150ms
4. 有数据时：
   - `List` 或 `Scroll + Column` 垂直滚动（倾向 List，性能更好且天数可能多）
   - `ForEach` 渲染 DayCard，key = `day.id + '_' + (isExpanded ? 'e' : 'c')`
   - 列表入场：stagger 错落（index × 30ms，translateY 12→0 + opacity 0→1）
   - 底部 padding 预留 Tab 栏高度（防穿透）
5. 管理 `@State expandedDayId: string = ''`（手风琴互斥状态）
6. 构建验证 + commit

**影响文件**：`components/gear/ItineraryView.ets`（新增）

---

### 阶段 9：Mock 数据 + 集成联调 `[pending]`

**目标**：在现有行程数据上挂载 mock itinerary 数据，端到端验证完整流程。

**具体任务**：
1. 在 `services/ItineraryService.ets` 中新增 `createMockItinerary(): DayItinerary[]`
   - 模拟一个 3-4 天的户外行程（成都→日隆→大本营→长坪沟→成都）
   - 涵盖：飞机、大巴、徒步、多种交通混合、票务信息、住宿、备注
2. TripDetailPage 中：如果当前行程的 itinerary 为空，自动填充 mock 数据（仅开发期）
3. 端到端验证：
   - Tab 切换流畅（NavBar 双标题插值 + 内容滑动联动）
   - 收缩态正确显示首尾地名 + 交通图标
   - 展开态时间线渲染正确
   - 手风琴互斥正常
   - 折叠呼吸与 Tab 切换正交无冲突
   - 空态展示正确
4. `deriveTripMeta` 在有 itinerary 时正确派生行程日期
5. 构建验证 + commit

**影响文件**：`services/ItineraryService.ets`、`components/gear/TripDetailPage.ets`

---

### 阶段 10：清理 + 最终验证 `[pending]`

**目标**：移除 mock 逻辑、全面自查、确保结构防腐。

**具体任务**：
1. Mock 数据标记 `// TODO: Phase 2 移除，改为真实数据` 或用 feature flag 开关
2. 结构防腐自查（对照 DEVELOPMENT_STANDARDS §8.7）：
   - 新增组件行数是否在 300 行内
   - 新增文件位置对照 §1.1 决策树
   - 无硬编码色值/字号/时长
   - 无死代码/孤儿 import
   - grep 确认无重复实现
3. 全量构建验证
4. 最终 commit

**影响文件**：全部新增/改动文件

---

## 技术决策记录

| 决策 | 选择 | 理由 |
|------|------|------|
| Tab 切换方式 | 自定义 PanGesture（非 Swiper） | Swiper onGestureSwipe 粒度不够，且与 HeadCollapseController 垂直滚动可能冲突 |
| 内容区渲染策略 | if 条件渲染（非双页面常驻） | 减少内存压力，切换时用 transition 补动画 |
| 手风琴策略 | 同时只展开一天 | 屏幕有限，多展开易迷失；后续可轻松改为多展开 |
| 数据一致性 | itinerary 为源，TripChecklist.dateAt 为派生 | 避免双源冲突，单向数据流 |
| 时间线竖线动效 | 若性能允许做 height 生长，否则降级整体淡入 | 实机表现优先 |
| NavBar 标题布局 | 两个 Text + 固定间距 Row | 避免字号变化时宽度抖动 |

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （待补充） | | |

## 文件清单（最终态）

| 文件 | 状态 | 说明 |
|------|------|------|
| `models/PackModels.ets` | 修改 | +4 interface, TripChecklist +1 field |
| `services/ItineraryService.ets` | 新增 | 数据派生 + mock 函数 |
| `constants/Colors.ets` | 修改 | +2~3 时间线 token |
| `constants/Layout.ets` | 修改 | +3~4 时间线尺寸 token |
| `components/gear/TripDetailPage.ets` | 修改 | NavBar 双标题 + Tab 滑动 + ItineraryView 接入 |
| `components/gear/DayCard.ets` | 新增 | 单天卡片（收缩/展开两态） |
| `components/gear/ItineraryView.ets` | 新增 | 行程 Tab 容器（列表 + 空态） |
