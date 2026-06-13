# 研究发现

## 现有代码结构摸底

### ChecklistRow 按压现状
- 文件：`entry/src/main/ets/components/gear/ChecklistRow.ets`
- 第 47 行：`@State private pressed: boolean = false`
- 第 148-162 行：`.scale({ x: pressed ? 0.96 : 1.0 })` + `.animation({ curve: SPRING_PRESS() })` + `onTouch`
- **问题**：`checkOnlyHotzone=true`（网格态+聚焦态都用此模式）时，`onTouch` 直接 return，按压反馈被跳过
- **问题**：scale 值硬编码 `0.96/1.0`，未使用 token

### GearPage 按压参考实现
- 文件：`entry/src/main/ets/components/GearPage.ets`
- 驱动状态：`@State private pressedGearId: string = ''`
- 三件套：`.backgroundColor(pressed ? GROUP_HEADER_BG : CARD_BG)` + `.scale(PRESS_SCALE_DOWN/REST)` + `.animation({ curve: SPRING_PRESS() })` + `.onTouch()`
- 只做 scale 0.96 + 背景色切换，无 translateY，无三段式回弹

### 菜单关闭逻辑现状
- 文件：`UnifiedChecklistView.ets`
- `overlayPhase` 状态机：`'idle' | 'menu' | 'dragging'`
- 关闭时用 `animateTo` 驱动退场动画，`onFinish` 回调中才重置 `overlayPhase = 'idle'`
- 动画期间 `overlayPhase` 仍为 `'menu'`，蒙层仍在，阻塞交互

### 聚焦态手势现状
- 文件：`FocusedZoneView.ets`
- 手势：`GestureGroup(Sequence, LongPress 400ms → Pan 纵向 5vp)`
- LongPress → `handleLongPress(item)` → 触觉反馈 + `onLongPressItem(item)` → 弹浮层菜单
- Pan → 格子内排序（纵向 translateY 让位）
- **缺失**：无「菜单→继续拖→排序」的过渡；无边缘检测→收缩→跨Zone

### 添加入口现状
- 折叠态：`ZoneGridCell.buildCountTrailing()` 有小型「+」按钮（标题右侧）
- 展开态：`FocusedZoneView.buildAddRow()` 在 List 末尾（底部虚线框）
- 空格子：虚线占位框居中（不受本次改动影响）

### 多选现状
- 菜单已有「选择多个」选项 → 递增 `multiSelectSignal` 进多选模式
- 多选模式下有顶部工具栏（批量移除）
- **缺失**：无批量拖拽能力

## ArkUI 技术约束

- `.animation()` 修饰器：声明式，状态变 → 属性变 → 自动 Spring 过渡，不阻塞交互
- `animateTo`：命令式，`onFinish` 回调前状态未变，可能阻塞
- geometryTransition：两端必须共用 ZoneShell + 相同 id，`follow:true` 用于同页放大
- GestureGroup(Sequence)：LongPress → Pan 是序列手势，Pan 在 LongPress 成功后才激活
- `onTouch` 与 `GestureGroup` 不冲突：onTouch 是底层触摸事件，Gesture 是高层手势识别
