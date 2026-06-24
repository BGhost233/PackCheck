# 行程详情页审计发现

> 基于第一性原理 + DEVELOPMENT_STANDARDS + MEMORY 避坑清单的全面审查
> 范围：装备准备 Tab + 每日行程 Tab

---

## P0 — 功能缺陷 / 数据风险

### #3 ForEach key 含 renderNonce → 全量重建

- **文件**: `ItineraryView.ets:129`
- **现象**: ForEach key = `day.id + '_' + day.segments.length + '_' + this.renderNonce`。每次数据变更 renderNonce++，ArkUI 认为所有 key 都变了，销毁全部 DayCard 再重建。
- **影响**: 展开状态丢失、stagger 动画反复重播、无意义性能开销。
- **根因**: 违反避坑 #24「ForEach key 必须稳定，只含数据维度，不含强制刷新计数器」。
- **证据**: DayCard 的 `renderNonce` prop 声明了但从未被读取（死 prop），说明它只是为了让 key 变化触发刷新——这是错误用法。

### #7 DayCard 无删除天入口

- **文件**: `DayCard.ets`
- **现象**: `onDeleteDay` 回调已声明并从 Index.ets 传入，但 DayCard UI 中无任何按钮/手势触发它。
- **影响**: 用户无法删除一天行程，只能靠数据层操作。
- **设计缺失**: 无删除入口 = 不可逆操作死角。

### #8 路段无删除入口

- **文件**: `DayCard.ets`（路段行）
- **现象**: `onDeleteSegment` 回调已声明但未绑定到任何 UI 元素。路段行只有 onClick → 编辑。
- **影响**: 与 #7 同理，用户无法删除单个路段。

### #10 DayFormSheet 编辑模式无删除按钮

- **文件**: `DayFormSheet.ets`
- **现象**: 编辑已有天时，Sheet 只有「保存」按钮，无「删除此天」。
- **影响**: 配合 #7，删除功能完全不可达。

---

## P1 — 交互体验缺陷

### #1 DayCard 长按 / onClick 竞争

- **文件**: `DayCard.ets:88-102`
- **现象**: onClick 用 `longPressTriggered` flag 做互斥。但 `longPressTriggered` 是 plain boolean（不是 @State），修改不会触发重渲染——虽然这里不需要重渲染，但赋值时机依赖手势系统的事件顺序。
- **风险**: 避坑 #9 指出 LongPressGesture + onClick 在 ArkUI 中存在竞争窗口。快速点击可能偶发触发长按编辑。
- **体验问题**: 长按直接进编辑，无任何中间反馈（无振动、无上下文菜单、无 scale 变化提示），用户不知道长按有功能。

### #5 行程 Tab 的 Scroll 未接入 HeadCollapseController

- **文件**: `ItineraryView.ets`、`TripDetailPage.ets`
- **现象**: 装备 Tab 通过 UnifiedChecklistView 接入了 HeadCollapseController，滑动可折叠头部。但行程 Tab 使用裸 `Scroll()`，切换到行程 Tab 时 headCollapseProgress 被重置为 0。
- **影响**: 两个 Tab 头部行为不一致——装备 Tab 有沉浸式折叠，行程 Tab 始终展开。违反交互一致性原则。
- **参考**: DEVELOPMENT_STANDARDS §4.3 + 避坑 #46。

### #6 updateDay 必填字段无防御

- **文件**: `ItineraryService.ets` 的 `updateDay` 函数
- **现象**: `from`/`to` 被标记为必填（业务语义），但 `updateDay` 用 patch 语义（`undefined` = 不改，`''` = 清空），没有阻止将必填字段清空。
- **影响**: 如果 UI 层 bug 传入 `from: ''`，会产生无出发地的天。虽然当前 UI 层做了校验，但 Service 层应有兜底。

---

## P2 — 动效 / 视觉 / 一致性

### #9 日期输入用 TextInput 而非 DatePicker

- **文件**: `DayFormSheet.ets:80-89`
- **现象**: 日期字段用 `TextInput({ placeholder: '日期 YYYY-MM-DD（可选）' })`，用户需要手动输入格式化日期。
- **对比**: `TripFormSheet` 和 `ProfileEditSheet` 使用 `DatePickerDialog.show()`，点击弹出系统日期选择器。
- **影响**: 交互不一致 + 输入成本高 + 格式校验缺失。

### #12 Tab 标题显示行程名而非功能名

- **文件**: `TripDetailPage.ets:394`
- **现象**: Tab 0 标题 = `this.currentChecklist()?.title ?? '装备准备'`，实际显示的是行程名（如「周末露营」），不是功能标签「装备准备」。Tab 1 硬编码「每日行程」。
- **影响**: 两个 Tab 标题语义层级不统一——一个是内容标题，一个是功能标签。当行程名很长时可能溢出。

### #13 DayCard 展开/收起 内容动画不同步

- **文件**: `DayCard.ets:231-239`
- **现象**: 展开区域用 `if (this.isExpanded)` + `transition(TransitionEffect)`。但箭头图标旋转和内容展开可能不在同一帧启动（取决于 ArkUI 的 if/else 条件渲染时机）。
- **参考**: 避坑 #27「if/else 条件渲染的过渡动画要注意时序」。

### #14 路段行缺少错落入场

- **文件**: `DayCard.ets`（segments ForEach）
- **现象**: 当 DayCard 展开后，所有路段行同时出现。未使用 `staggerDelay(index)` 做错落入场。
- **对比**: ItineraryView 的 DayCard 列表有 stagger，但 DayCard 内部的路段列表没有。
- **标准**: DEVELOPMENT_STANDARDS 要求列表入场必须有 staggered 错落。

### #15 票务折叠区无过渡动画

- **文件**: `SegmentFormSheet.ets`
- **现象**: 票务信息区域（ticketCode/ticketSeat/ticketPrice）的展开/收起（如果有的话）缺少 transition 动画。
- **标准**: 「二级菜单/下拉/弹窗展开必须有过渡动画，严禁硬切」。

### #17 无 segments 时收缩态展示问题

- **文件**: `DayCard.ets`
- **现象**: 当一天有 from/to 但没有任何 segment 时，收缩态的摘要信息可能显示「0 段路程」或空白，引导不够清晰。
- **影响**: 用户不知道要展开才能添加路段。

### #18 添加按钮缺少按压反馈

- **文件**: `ItineraryView.ets`（「添加一天」按钮）、`DayCard.ets`（「添加路段」按钮）
- **现象**: 功能按钮可能缺少标准的 `scale 1→0.96→1.02→1.0` 三段式按压反馈。
- **标准**: 「所有可点击元素必须有按压反馈」。

---

## P3 — 健壮性 / 代码卫生

### #2 ItineraryView appeared 无退场重置

- **文件**: `ItineraryView.ets`
- **现象**: `appeared` 在 `aboutToAppear` 中设为 true，用于控制入场动画。但无 `aboutToDisappear` 重置为 false。
- **影响**: 如果组件被复用（Tab 切换），入场动画不会重播。结合 #3（renderNonce 导致重建），目前实际会重播——但修完 #3 后就不会了，需要显式处理。

### #4 DayCard 无 aboutToDisappear

- **文件**: `DayCard.ets`
- **现象**: 无生命周期清理。目前 DayCard 无定时器/动画需要清理，但如果未来加入（如长按延时），会有泄漏风险。
- **标准**: 避坑 #39「aboutToDisappear 必须清理定时器」。

### #11 空态引导弱

- **文件**: `ItineraryView.ets:52-94`
- **现象**: 空态有「还没有行程安排」+ 「添加第一天」CTA，但视觉权重偏弱（灰色小文字 + 普通按钮），缺少插图或动效引导。
- **对比**: 装备 Tab 的空态有更丰富的视觉引导。

### #16 收缩态布局弹性

- **文件**: `DayCard.ets`
- **现象**: 收缩态信息密度较高时（长地名 + 多段路程摘要），可能出现文字截断或换行导致卡片高度跳动。
- **影响**: 需要确保 `maxLines` + `textOverflow` 策略一致。

### #19 输入框缺聚焦态样式

- **文件**: `DayFormSheet.ets`、`SegmentFormSheet.ets`
- **现象**: TextInput 聚焦时无边框颜色变化或底部高亮线等视觉反馈。
- **标准**: 聚焦态是基本交互反馈，缺少会让用户不确定当前焦点位置。
