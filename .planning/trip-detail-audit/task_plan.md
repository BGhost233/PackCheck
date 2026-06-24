# 行程详情页审计修复计划

> 19 个问题，按优先级分批修复
> 每批修复后 `devecocli build` 验证

---

## 批次 1：P0 — 功能缺陷修复

### Task 1.1: 修复 ForEach key（#3）

**问题**: `ItineraryView.ets:129` ForEach key 含 `renderNonce`，导致每次数据变更全量销毁重建 DayCard。

**方案**:
1. **移除 renderNonce 出 ForEach key**。新 key = `day.id + '_' + day.from + '_' + day.to + '_' + day.segments.length`，只包含数据维度。
2. **删除 ItineraryView 的 `renderNonce` prop**（不再需要）。
3. **删除 DayCard 的 `renderNonce` prop**（死 prop，从未被读取）。
4. **清理 Index.ets / TripDetailPage.ets 中传入 renderNonce 的地方**。
5. 验证：数据变更后 DayCard 不重建、展开状态保持、stagger 不重播。

**影响文件**: `ItineraryView.ets`, `DayCard.ets`, `TripDetailPage.ets`, `Index.ets`

---

### Task 1.2: 添加删除天入口（#7 + #10）

**问题**: DayCard 和 DayFormSheet 都没有删除天的 UI 入口。

**方案**:
1. **DayFormSheet 编辑模式底部加「删除此天」按钮**（红色文字按钮，放在「保存」按钮下方）。
2. 新增 `onDeleteDay?: () => void` 回调 prop。
3. 点击后弹出确认对话框（AlertDialog），确认后调用 `onDeleteDay()`。
4. **SheetOverlay** 传入 `onDeleteDay` 回调，调用 Index.ets 的 `handleDeleteDay`。
5. 删除后关闭 Sheet。
6. **DayCard 不加删除按钮**——遵循「交互入口原则」，删除是低频危险操作，放在编辑 Sheet 里更安全。

**影响文件**: `DayFormSheet.ets`, `SheetOverlay.ets`, `Index.ets`

---

### Task 1.3: 添加删除路段入口（#8）

**问题**: 路段行没有删除入口。

**方案**:
1. **SegmentFormSheet 编辑模式底部加「删除此路段」按钮**（同 Task 1.2 风格）。
2. 新增 `onDeleteSegment?: () => void` 回调 prop。
3. 确认对话框 → 调用 `onDeleteSegment()`。
4. **SheetOverlay** 传入回调。
5. 同样不在 DayCard 的路段行上加删除按钮——进编辑 Sheet 后再删。

**影响文件**: `SegmentFormSheet.ets`, `SheetOverlay.ets`, `Index.ets`

---

## 批次 2：P1 — 交互体验修复

### Task 2.1: 修复长按/点击竞争 + 增强反馈（#1）

**问题**: DayCard 长按直接触发编辑，无反馈；onClick 用 plain boolean 做互斥有竞争风险。

**方案**:
1. **长按触发时加 scale 动画反馈**：长按开始 → scale 0.96（SPRING_PRESS），长按完成 → scale 1.02 → 1.0 弹回 + 触发编辑。
2. **将 `longPressTriggered` 改为 @State**，确保状态变更可追踪（虽然不影响渲染，但更规范）。
3. **加 50ms 延迟到 onClick 判断**：在 `onAction` end 事件后设置 flag，onClick 检查 flag——但实际上当前模式已经可用，只需确保 `longPressTriggered` 在 onClick 之后重置（用 setTimeout 0ms）。
4. 验证：快速点击不触发长按，长按有视觉反馈。

**影响文件**: `DayCard.ets`

---

### Task 2.2: 行程 Tab 接入 HeadCollapseController（#5）

**问题**: 行程 Tab 使用裸 Scroll，头部不折叠。

**方案**:
1. 在 `ItineraryView.ets` 中创建 `HeadCollapseController` 实例。
2. 将 Scroll 的 `onScroll` / `onScrollStop` 接入 controller。
3. 通过回调 `onHeadCollapseChange: (progress: number) => void` 向 TripDetailPage 报告 progress。
4. TripDetailPage 在 Tab 切换到行程 Tab 时，使用 ItineraryView 报告的 progress 驱动头部折叠。
5. 配置参数与装备 Tab 一致（相同 maxCollapse/threshold）。

**影响文件**: `ItineraryView.ets`, `TripDetailPage.ets`

---

### Task 2.3: updateDay 必填字段防御（#6）

**问题**: `updateDay` patch 语义允许将 from/to 清空。

**方案**:
1. 在 `updateDay` 中加防御：如果 patch.from === '' 或 patch.to === ''，忽略该字段（视为 undefined，即不修改）。
2. 或者更严格：如果 from/to 被传入空字符串，抛出警告日志但不执行清空。
3. 选方案 1（更安全、不破坏现有流程）。

**影响文件**: `ItineraryService.ets`

---

## 批次 3：P2 — 动效 / 视觉 / 一致性

### Task 3.1: 日期字段改用 DatePickerDialog（#9）

**问题**: DayFormSheet 日期用 TextInput，其他表单用 DatePickerDialog。

**方案**:
1. 将日期 TextInput 替换为点击触发 `DatePickerDialog.show()` 的 Row/Text 组件。
2. 显示已选日期或 placeholder 文字。
3. 日期格式化与 TripFormSheet 一致（YYYY-MM-DD）。
4. 保持「可选」语义——用户可以不选日期。

**影响文件**: `DayFormSheet.ets`

---

### Task 3.2: Tab 标题统一为功能标签（#12）

**问题**: Tab 0 标题显示行程名而非「装备准备」。

**方案**:
1. Tab 0 标题固定为 `'装备准备'`，Tab 1 保持 `'每日行程'`。
2. 行程名显示在头部折叠区的主标题位置（已有 SharedInfo 展示行程名）。
3. Tab 标题只做功能导航，不承载内容信息。

**影响文件**: `TripDetailPage.ets`

---

### Task 3.3: DayCard 展开/收起动画时序对齐（#13）

**问题**: 箭头旋转和内容展开可能不在同一帧。

**方案**:
1. 箭头旋转使用 `animateTo` + SPRING_GENERAL，与 `if (isExpanded)` 的 transition 使用相同曲线。
2. 确保 `isExpanded` 状态变更在 `animateTo` block 内触发。
3. 避坑 #27：if/else 条件渲染的 transition 需要在状态变更的同一个 animateTo 闭包内。

**影响文件**: `DayCard.ets`

---

### Task 3.4: 路段行错落入场（#14）

**问题**: DayCard 展开后路段行同时出现。

**方案**:
1. 路段行的 transition 加上 `staggerDelay(index)` 延迟。
2. 效果：translateY(12vp→0) + opacity(0→1)，间隔 30ms。
3. 使用 `TransitionEffect.asymmetric`，入场有 stagger，退场同步消失（避免收起时等待过长）。

**影响文件**: `DayCard.ets`

---

### Task 3.5: 票务区过渡动画（#15）

**问题**: SegmentFormSheet 票务展开/收起无动画。

**方案**:
1. 检查票务区是否有 if/else 展开逻辑。如果有，加 `transition(TransitionEffect)` + SPRING_GENERAL。
2. 如果票务区始终显示（无折叠），则此问题不存在，标记为 N/A。
3. 需要先确认当前 SegmentFormSheet 的票务区渲染逻辑。

**影响文件**: `SegmentFormSheet.ets`（待确认）

---

### Task 3.6: 无 segments 时收缩态优化（#17）

**问题**: 天有 from/to 但无 segment 时，收缩态摘要不清晰。

**方案**:
1. 收缩态显示「出发地 → 目的地」+ 小字提示「展开添加路段」。
2. 如果 segments 为空，摘要区显示虚线引导而非「0 段路程」。

**影响文件**: `DayCard.ets`

---

### Task 3.7: 按钮按压反馈补全（#18）

**问题**: 部分添加按钮缺少三段式按压反馈。

**方案**:
1. 检查 ItineraryView「添加一天」按钮、DayCard「添加路段」按钮是否有 `pressHandler` + scale 动画。
2. 缺少的统一补上：`onTouch(AnimationUtils.pressHandler(setter))` + `scale(cardScale)`。
3. 使用 `SPRING_PRESS` 曲线。

**影响文件**: `ItineraryView.ets`, `DayCard.ets`

---

## 批次 4：P3 — 健壮性 / 代码卫生

### Task 4.1: ItineraryView appeared 退场重置（#2）

**问题**: appeared 无 aboutToDisappear 重置。

**方案**:
1. 添加 `aboutToDisappear()` 生命周期钩子。
2. 重置 `appeared = false`。
3. 修完 #3 后（ForEach key 不含 renderNonce），Tab 切换回来时组件不会重建，aboutToAppear 也不会重触发——需要确认是否需要重播入场动画。如果不需要，可以保持 appeared = true 不重置。
4. **决策**：首次进入播放入场动画，Tab 切换回来不重播。所以不重置 appeared。但 aboutToDisappear 仍然加上，用于未来可能的清理需求。

**影响文件**: `ItineraryView.ets`

---

### Task 4.2: DayCard 加 aboutToDisappear（#4）

**问题**: 无生命周期清理钩子。

**方案**:
1. 添加空的 `aboutToDisappear()` 钩子，留注释说明「预留清理位」。
2. 如果 Task 2.1 引入了 setTimeout，在这里清理。

**影响文件**: `DayCard.ets`

---

### Task 4.3: 空态视觉增强（#11）

**问题**: 空态引导偏弱。

**方案**:
1. 加大空态图标/插图尺寸。
2. 提示文字用 Typography token 的 Body_M 而非灰色小字。
3. CTA 按钮用主题色填充而非边框样式。
4. 可选：加入微动效（图标轻微 breathe 动画）。

**影响文件**: `ItineraryView.ets`

---

### Task 4.4: 收缩态文字截断策略（#16）

**问题**: 长地名可能导致卡片高度跳动。

**方案**:
1. 地名区域加 `maxLines(1)` + `textOverflow({ overflow: TextOverflow.Ellipsis })`。
2. 摘要区域同样限制单行。
3. 确保卡片高度固定（收缩态）。

**影响文件**: `DayCard.ets`

---

### Task 4.5: 输入框聚焦态样式（#19）

**问题**: TextInput 聚焦时无视觉反馈。

**方案**:
1. 给 DayFormSheet 和 SegmentFormSheet 的 TextInput 统一设置 `.onFocus` / `.onBlur` 状态。
2. 聚焦时底部显示主题色线条，或边框变为主题色。
3. 使用 `@State focusedField: string` 追踪当前聚焦字段。
4. 样式：border 从 `Colors.BORDER_LIGHT` 变为 `Colors.PRIMARY`，过渡 200ms。

**影响文件**: `DayFormSheet.ets`, `SegmentFormSheet.ets`

---

## 依赖关系

```
Task 1.1 (#3 ForEach key) → 必须先做，后续 #2/#14 的动画行为依赖于此
Task 1.2 (#7+#10 删除天) 和 Task 1.3 (#8 删除路段) → 可并行
Task 2.2 (#5 HeadCollapse) → 独立，可随时做
Task 3.3 (#13 展开动画) → 依赖 Task 1.1 完成后验证
Task 4.1 (#2 appeared) → 依赖 Task 1.1 完成后确认策略
其余 Task 互相独立
```

## 验证策略

每个 Task 完成后：
1. `devecocli build` 构建通过
2. 人工验证交互行为（描述验证步骤）
3. `git add -A && git commit`
