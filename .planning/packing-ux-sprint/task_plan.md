# PackCheck 格子系统 UX 优化 Sprint

## 目标

基于用户反馈，修复格子系统的 4 个 Bug + 完成 5 项核心交互升级，提升 packing 体验到 Apple 级水准。

## 约束

- 遵循 v3 产品愿景：格子 = 带格子的核查清单，统一界面无 Tab 切换
- 所有动画 Spring 弹性曲线，从 AnimationTokens 引用
- 新增字段 optional 向后兼容
- 每次改动构建验证 + git commit

## 涉及文件

| 文件 | 改动类型 |
|------|----------|
| `pages/Index.ets` | Bug 修复（状态刷新） |
| `components/gear/UnifiedChecklistView.ets` | 拖拽自动滚动、多选模式 |
| `components/gear/FocusedZoneView.ets` | 装备详情 Sheet 替代手风琴、格子内排序 |
| `components/gear/ZoneGridCell.ets` | 折叠态添加按钮 |
| `components/sheets/GearPickerSheet.ets` | 性能优化（LazyForEach） |
| `components/gear/GearDetailSheet.ets` | **新建** — 底部半屏装备详情面板 |

---

## Phase 1: P0 Bug 修复 [status: pending]

修复 4 个影响基本可用性的 Bug，确保状态刷新链路可靠。

### Task 1.1: #2 多选添加装备只显示第一个 [pending]

**根因分析**：
- `toggleGearInTrip` 每次点击都走 `applyChecklistState` → `nonce++`
- GearPickerSheet 的 `selectedItemIds` 来自 `@Prop`（`currentTripGearIds()`）
- 问题在于：`applyChecklistState` 是 async（内含 `store.saveChecklists`），连续快速点击时第二次 toggle 可能基于旧 checklists 计算，导致 `findIndex` 误判为"已存在"而执行移除

**修复方案**：
1. `toggleGearInTrip` 改为同步优先更新 UI 状态，async 只负责持久化
2. 确保 `applyChecklistState` 中 `this.checklists` 赋值在 `await` 之前
3. 验证：连续快速点击 5 个装备，全部正确添加且 Picker 中全部显示已选中态

### Task 1.2: #9 装备库编辑后格子内不即时更新 [pending]

**根因分析**：
- `saveGear()` 已有 `this.gears = nextGears` + `checklistRenderNonce++`
- 但 UnifiedChecklistView 通过 `@Prop gears` 接收，ZoneGridCell 内的 ChecklistRow 通过 `fromGearId` 反查 gears 数组获取展示数据
- 如果 `@Prop gears` 传递链路中某一层做了浅比较优化（引用相同则跳过），新 gears 数组（虽然内容变了但 item.id 没变）可能不触发子组件重渲染

**修复方案**：
1. 确认 gears 传递链路：Index(@State gears) → UnifiedChecklistView(@Prop) → ZoneGridCell(@Prop) → ChecklistRow
2. 在 ChecklistRow 的 ForEach key 中拼入 gear 的 name+weight hash，确保 gear 属性变化时 key 变化触发重建
3. 或者：在 `saveGear` 后对受影响的 ChecklistItem 做浅拷贝（改 id 后缀），强制 ForEach 重建
4. 验证：编辑装备名称 → 返回格子视图 → 名称立即更新

### Task 1.3: #7 长按删除装备无即时反馈 [pending]

**根因分析**：
- 删除操作通过浮层菜单「移除」触发 → `onRemoveItem(item)` → Index 层 `removeItemFromChecklists` → `applyChecklistState`
- `applyChecklistState` 未包裹在 `animateTo` 中（`animated` 参数默认 false）
- ForEach 节点移除无退场动画 → 视觉上"突然消失"或因重建延迟"无反应"

**修复方案**：
1. 删除操作调用 `applyChecklistState(nextChecklists, true)` 启用动画
2. FocusedZoneView 的 ListItem 添加 `.transition({ type: TransitionType.Delete, opacity: 0, translate: { x: -40 }, scale: { x: 0.8, y: 0.8 } })`
3. 删除后立即关闭浮层（`dismissOverlay` 先于状态更新，避免浮层残留）
4. 验证：长按→移除→浮层收起→该行 Spring 滑出消失

### Task 1.4: #8 装备多时添加有延迟 [pending]

**根因分析**：
- GearPickerSheet 用 `Scroll > Column > ForEach`（非虚拟化），全量渲染
- `groupedGears()` 每次 build 重算（filter + sort + group），无缓存
- 每次 toggle 触发父级 nonce++ → GearPickerSheet 整体重建 → 重算 groupedGears → 全量 ForEach

**修复方案**：
1. `groupedGears` 结果缓存为 `@State cachedGroups`，仅在 `gears`/`searchText`/`selectedItemIds` 变化时通过 `@Watch` 重算
2. 将 `Scroll > Column > ForEach` 改为 `List > ForEach`（List 自带虚拟化回收）
3. 如果 List 改动量过大，退而求其次：默认折叠非当前 Zone 的品类组，减少首屏渲染量
4. 验证：100+ 装备库，点击添加响应 < 100ms

---

## Phase 2: P1 核心交互升级 [status: pending]

### Task 2.1: #6 折叠态有装备时也加添加按钮 [pending]

**设计**：
- ZoneGridCell `buildContentCell` 底部，预览行/折叠提示行之后
- 圆形 24vp 按钮，TEXT_HINT 色（`Colors.TEXT_HINT`），opacity 0.5
- 图标：`sys.symbol.plus`，12vp
- 点击 → `onTapEmpty(zone)` 打开 GearPickerSheet
- 按压反馈：`PRESS_SCALE_DOWN` + `SPRING_PRESS()`
- 不占用额外高度（absolute 定位在卡片右下角，或 inline 但高度极小 28vp）

**实现路径**：
1. ZoneGridCell.ets `buildContentCell` 末尾加 `buildInlineAddButton()`
2. 按钮样式：Row 居中，height 28vp，虚线底边（与空态呼应但更轻）
3. 绑定 onClick + 按压手势

### Task 2.2: #3 装备详情底部半屏 Sheet [pending]

**设计**：
- 替换 FocusedZoneView 中的手风琴展开（`expandedItemId` + `buildItemDetail`）
- 点击装备行 → 弹出底部半屏 Sheet（覆盖聚焦态，z-index 更高）
- Sheet 高度：屏幕 55%（可下拉关闭）

**动效规格**：
- 升起：`SPRING_PANEL_ENTER()`（response 0.38, damping 0.72），translateY(screenH → 0) + 蒙层 opacity(0→0.3)
- 收回：`SPRING_PANEL_EXIT()`（response 0.30, damping 0.88），translateY(0 → screenH) + 蒙层淡出
- 下拉手势关闭：PanGesture vertical，实时跟手 translateY，松手时 velocity > 800 或 offset > 120vp → 收回，否则弹回
- 内部错落入场（Sheet 升起后 150ms 开始）：
  - 装备名标题：delay 0, translateY(12→0) + opacity(0→1), SPRING_GENERAL
  - 属性 chips 行：delay 50ms
  - 备注区：delay 100ms
  - 编辑按钮：delay 150ms

**Sheet 内容结构**：
```
┌─────────────────────────────┐
│         ━━━━ (拖拽条)        │
│                             │
│  装备名称（20vp semibold）    │
│  品类 badge │ 重量 │ 品牌    │
│                             │
│  ─────────────────────────  │
│  备注内容（若有）             │
│                             │
│  ┌─────────────────────┐    │
│  │      编辑装备        │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

**编辑态**：
- 点击「编辑」→ 按钮 Spring 缩小消失，字段 Spring 切换为 TextInput
- 顶部出现「取消」「保存」按钮（Spring 弹入）
- 保存后 → TextInput Spring 切换回只读文本，触觉反馈 `haptic.effect.soft`

**实现路径**：
1. 新建 `components/gear/GearDetailSheet.ets`（自绘 Sheet 组件）
2. FocusedZoneView 中移除 `expandedItemId` 逻辑，点击装备行改为调 `onTapItem(item)` 回调
3. UnifiedChecklistView 层接收回调，管理 `detailSheetItem` 状态，渲染 GearDetailSheet overlay
4. GearDetailSheet 内部管理编辑态切换

### Task 2.3: #12 拖拽到页面边缘自动滚动 [pending]

**设计**：
- 拖拽中手指进入顶部/底部 80vp 热区 → 自动滚动
- 滚动速度：`speed = ((80 - distanceToEdge) / 80) * 10` vp/帧（越靠边越快）
- 滚动期间持续更新 `zoneRects`（通过 Grid 的 `onScrollFrameBegin` 或定时重收集）

**技术难点**：
- 当前 `enableScrollInteraction(false)` 锁死了 Grid 滚动
- 需要改为：禁止用户触摸滚动，但允许程序化 `gridScroller.scrollBy()`
- `zoneRects` 在滚动后失效 → 需要在 auto-scroll 每帧后重新 hitTest

**实现路径**：
1. 新增 `@State autoScrollTimer: number = -1`
2. `handleDragUpdate` 中检测边缘热区，进入时启动 `setInterval(16)`
3. interval 回调：`gridScroller.scrollBy(0, speed)` + 重新收集 zoneRects（或用 scrollOffset 补偿）
4. 离开热区 / `handleDragEnd` 时 `clearInterval`
5. 将 `enableScrollInteraction` 改为始终 true，但在 dragging 阶段通过 `onScrollFrameBegin` 返回 `{ offsetRemain: 0 }` 阻止用户触摸滚动（只允许程序化滚动）

---

## Phase 3: P2 拖拽体系完善 [status: pending]

### Task 3.1: #10 格子内排序 + 拖到边缘跨格子 [pending]

**设计**：
- 聚焦态长按装备 → 进入排序模式（区别于弹菜单）
- 触发条件：长按 400ms 后不松手，继续 Pan → 排序模式；长按后松手 → 弹菜单（现有逻辑）
- 排序中：被拖项浮起（scale 1.03 + shadow 24），其他项根据拖拽 Y 位置实时让位（translateY ±itemHeight，SPRING_GENERAL）
- 拖到左/右边缘 40vp → 触发 closeFocus + 保持 overlay 胶囊 → 网格态跨 Zone 拖拽

**状态机扩展**：
```
overlayPhase: 'idle' | 'menu' | 'dragging' | 'reordering'
```

**实现路径**：
1. FocusedZoneView 中 LongPress+Pan 手势改为：LongPress 触发 → 等待 Pan 开始
   - 如果 Pan 开始（手指移动 > 5vp）→ 进入 `'reordering'`
   - 如果 LongPress 结束（手指抬起）→ 进入 `'menu'`（现有逻辑）
2. `'reordering'` 模式下：
   - 被拖项从列表中"浮起"（opacity 0 占位 + overlay 跟手副本）
   - 其他项根据拖拽 Y 计算插入位置，实时 translateY 让位
   - 松手 → 计算最终位置 → `items.splice` 重排 → 持久化
3. 拖到边缘检测 → `onRequestCloseFocusWithDrag(item)` → 父层 closeFocus 但保持 overlay

### Task 3.2: #1 多选批量拖拽 [pending]

**设计**：
- 长按菜单新增「选择多个」项
- 进入多选模式：
  - 每行左侧 Spring 弹入 checkbox（translateX -24→0 + opacity）
  - 顶部出现工具栏：「已选 N 件」+「移动到…」+「取消」
  - 底部添加行隐藏
- 多选后可：
  - 点击「移动到…」→ 弹出 Zone 选择 Sheet → 批量移动
  - 长按任一选中项 → 批量拖拽（胶囊显示堆叠 3 层 + 数量 badge）

**实现路径**：
1. FocusedZoneView 新增 `@State isMultiSelectMode: boolean`
2. 多选态 UI：checkbox 列 + 顶部工具栏
3. 批量拖拽复用 overlay 系统，胶囊样式改为堆叠卡片
4. 松手逻辑：批量调用 `onMoveItemToZone` 或新增 `onMoveItemsToZone(ids[], zone)`

---

## Phase 4: 验证与文档更新 [status: pending]

### Task 4.1: 全量构建验证 [pending]
- `hvigorw assembleApp` 通过
- 无新增 lint 警告

### Task 4.2: 交互验证清单 [pending]
- [ ] 多选添加 5 个装备，全部即时显示
- [ ] 编辑装备名称，格子内即时更新
- [ ] 删除装备，Spring 退场动画流畅
- [ ] 100+ 装备库打开 Picker 无卡顿
- [ ] 折叠态点击 + 按钮打开 Picker
- [ ] 聚焦态点击装备弹出详情 Sheet，动效灵动
- [ ] 详情 Sheet 下拉手势关闭流畅
- [ ] 拖拽到屏幕边缘自动滚动
- [ ] 聚焦态内拖动排序
- [ ] 多选模式批量移动

### Task 4.3: 路线图文档更新 [pending]
- 更新产品愿景文档的路线图 section
- 记录延后项（#11 自建格子、#4 配件格子、#5 装备库排序）

---

## 延后项（记录）

| # | 内容 | 延后原因 | 预计时机 |
|---|------|----------|----------|
| #11 | 用户自建格子（自定义名称+颜色） | 架构变更大，BodyZone 从枚举→动态数组 | v2 地基层重构后 |
| #4 | 新增「配件」格子 | 与 #11 统一规划预设格子增减 | 与 #11 一起 |
| #5 | 装备库长按拖动排序 | 独立功能，不影响核心流程 | Phase 3 之后 |

---

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （待记录） | | |
