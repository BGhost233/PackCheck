# 行程编辑 + 滑动切换优化

## 目标

为 TripDetailPage 实现三项优化：
1. 装备 Tab ↔ 行程 Tab 支持左右滑动切换（跟手插值 + 惯性翻页）
2. Tab 切换动画加速（SPRING_TAB response 降低）
3. 行程日程从 mock 展示升级为真实数据 CRUD 编辑

## 约束

- ArkTS + ArkUI，API 23+
- Spring 弹性曲线为唯一动画曲线
- 持久化走现有 PackStore.saveChecklists（TripChecklist.itinerary 字段 JSON 自动序列化）
- 所有常量走 token 文件，所有计算走 services/ 纯函数
- 编辑交互形态：Sheet 面板（字段多，inline 不适合）
- 文件行数 ≤ 300 行（超过则拆分）

---

## 阶段 1：Tabs 替换 + 滑动手势 `status: pending`

**目标**：将 TripDetailPage 内容区从 `Stack + if` 改为 `Tabs` 组件，原生支持左右滑动切换。

**改动文件**：
- `components/gear/TripDetailPage.ets` — 内容区改为 Tabs + TabContent
- `constants/AnimationTokens.ets` — SPRING_TAB response 调快

**实现要点**：
1. 内容区 `Stack { if(0) UnifiedChecklistView; if(1) ItineraryView }` → `Tabs(controller) { TabContent() { UnifiedChecklistView } TabContent() { ItineraryView } }`
2. `Tabs` 设置：`scrollable(true)`（默认）、`.barHeight(0)`（隐藏原生 TabBar，我们用 NavBar 自定义标题）、`loop(false)`、`index($$this.tripTabIndex)` 双向绑定
3. 利用 `onGestureSwipe(index, event)` 逐帧回调：`tripTabProgress = tripTabIndex + event.currentOffset / tabsWidth` 驱动 NavBar 标题字号/颜色实时跟手插值
4. `onAnimationStart(index, targetIndex)` 更新 tripTabIndex + headCollapseProgress 重置
5. `onChange(index)` 兜底最终同步
6. NavBar 标题的 `.animation({ curve: SPRING_TAB() })` 保留——点击切换时仍走 Spring 动画；滑动跟手时 onGestureSwipe 逐帧直接赋值 tripTabProgress 绕过动画
7. `switchTab()` 方法：改为调用 `tabController.changeIndex(targetIndex)`，不再手动 animateTo

**验证标准**：
- 左右滑可切换 Tab，标题字号/颜色跟手插值
- 点击标题仍可切换
- 切换到行程 Tab 时 headCollapseProgress 正确重置
- 构建通过

---

## 阶段 2：Tab 动画加速 `status: pending`

**目标**：让 Tab 切换感知更轻快。

**改动文件**：
- `constants/AnimationTokens.ets` — SPRING_TAB 参数调整

**实现要点**：
1. `SPRING_TAB`：response 0.40 → **0.32**，dampingFraction 0.75 → **0.82**（更快到位、更少过冲）
2. Tabs 组件 `animationDuration(200)` — 控制翻页动画快感（Tabs 内置 interpolatingSpring 默认 400ms 感觉偏慢）

**验证标准**：
- Tab 切换明显更快更脆
- 无过度弹跳/震荡
- 构建通过

---

## 阶段 3：ItineraryService CRUD 纯函数 `status: pending`

**目标**：在 services/ 层新增行程数据增删改纯函数。

**改动文件**：
- `services/ItineraryService.ets` — 新增 CRUD 函数

**新增函数**：
```typescript
// Day 层面
addDay(itinerary: DayItinerary[], afterIndex?: number): DayItinerary[]
removeDay(itinerary: DayItinerary[], dayId: string): DayItinerary[]
updateDay(itinerary: DayItinerary[], dayId: string, patch: DayPatch): DayItinerary[]

// Segment 层面
addSegment(itinerary: DayItinerary[], dayId: string, segment: RouteSegment, afterIndex?: number): DayItinerary[]
removeSegment(itinerary: DayItinerary[], dayId: string, segmentId: string): DayItinerary[]
updateSegment(itinerary: DayItinerary[], dayId: string, segmentId: string, patch: SegmentPatch): DayItinerary[]

// 辅助
reorderDays(itinerary: DayItinerary[], orderedIds: string[]): DayItinerary[]
makeSegmentId(): string
makeDayId(): string
```

**DayPatch / SegmentPatch**：partial 更新接口（可选字段），定义在 PackModels.ets。

**验证标准**：
- 所有函数 immutable（返回新数组，不修改入参）
- 构建通过

---

## 阶段 4：数据模型补充 `status: pending`

**目标**：在 PackModels.ets 新增编辑所需的 patch 接口。

**改动文件**：
- `models/PackModels.ets` — 新增 DayPatch、SegmentPatch 接口

```typescript
export interface DayPatch {
  date?: string;
  note?: string;
}

export interface SegmentPatch {
  from?: string;
  to?: string;
  transport?: TransportMode;
  departTime?: string;
  arriveTime?: string;
  note?: string;
  ticket?: TicketInfo;
  accommodation?: string;
}
```

**验证标准**：
- 类型定义正确，构建通过

---

## 阶段 5：SegmentFormSheet 表单面板 `status: pending`

**目标**：新建路段编辑 Sheet 面板组件（新增 + 编辑复用同一表单）。

**新建文件**：
- `components/sheets/SegmentFormSheet.ets`

**表单字段**（top → bottom）：
1. 出发地 `from`（TextInput，必填）
2. 到达地 `to`（TextInput，必填）
3. 交通方式 `transport`（Chip 选择器：飞机/火车/大巴/自驾/徒步/骑行/轮船/其他）
4. 出发时间 `departTime`（TimePicker 或 TextInput "HH:mm"）
5. 到达时间 `arriveTime`（同上）
6. 票务信息折叠区（可选展开）：车次号 code、座位 seat、价格 price
7. 住宿 `accommodation`（TextInput，可选）
8. 备注 `note`（TextInput，可选）

**交互**：
- 新增模式：标题"添加路段"，提交按钮"添加"
- 编辑模式：标题"编辑路段"，提交按钮"保存"，预填现有数据
- 通过 SheetOverlay 容器包装（统一遮罩 + Spring 弹出收回）

**验证标准**：
- 表单可输入所有字段
- 提交回调返回完整 RouteSegment
- 构建通过

---

## 阶段 6：DayFormSheet 天编辑面板 `status: pending`

**目标**：新建"天"编辑 Sheet（编辑日期和备注，简单表单）。

**新建文件**：
- `components/sheets/DayFormSheet.ets`

**表单字段**：
1. 日期 `date`（DatePicker 或 TextInput "YYYY-MM-DD"）
2. 当天备注 `note`（TextArea）

**交互**：
- 点击 DayCard 收缩态的日期/备注区域触发
- 新增天时弹出，填完后创建 DayItinerary
- 编辑天时预填

**验证标准**：
- 构建通过

---

## 阶段 7：ItineraryView 改为可编辑模式 `status: pending`

**目标**：ItineraryView 从纯展示升级为 CRUD 交互容器。

**改动文件**：
- `components/gear/ItineraryView.ets`
- `components/gear/DayCard.ets`

**ItineraryView 改动**：
- 底部增加"+ 添加一天"按钮（仅行程非空时显示，空态按钮已有）
- 回调增加：`onAddDay`、`onEditDay(dayId)`、`onDeleteDay(dayId)`、`onAddSegment(dayId)`、`onEditSegment(dayId, segId)`、`onDeleteSegment(dayId, segId)`

**DayCard 改动**：
- 展开态时间线每段可点击（触发 onEditSegment）
- 展开态末尾增加"+ 添加路段"节点（点击触发 onAddSegment）
- 收缩态长按弹 ActionSheet 菜单：编辑日期/备注 | 删除这天
- 展开态每段左滑删除（或长按菜单删除，待定用长按菜单更安全）

**验证标准**：
- 点击段落、添加按钮正确触发回调
- 构建通过

---

## 阶段 8：TripDetailPage + Index 回调链路贯通 `status: pending`

**目标**：将编辑操作从 ItineraryView → TripDetailPage → Index.ets 贯通，完成持久化。

**改动文件**：
- `components/gear/TripDetailPage.ets` — 新增 itinerary 编辑回调 props + Sheet 状态管理
- `pages/Index.ets` — 新增 itinerary CRUD 方法（调用 ItineraryService + saveChecklists）

**Index.ets 新增方法**：
```typescript
private async updateItinerary(nextItinerary: DayItinerary[]): Promise<void>
  → 更新 currentChecklist.itinerary → saveChecklists
```

**TripDetailPage Sheet 管理**：
- 维护 `@State segmentFormMode: 'add' | 'edit'`
- 维护 `@State editingSegment: RouteSegment | undefined`
- 维护 `@State editingDayId: string`
- Sheet 打开/关闭通过 state 驱动 SheetOverlay

**验证标准**：
- 添加/编辑/删除 day/segment 完整生效
- 数据持久化后重启 App 仍在
- 构建通过

---

## 阶段 9：去除 Mock 数据 `status: pending`

**目标**：ItineraryView 不再显示 mock，空 itinerary 展示空态 → 引导用户创建第一天。

**改动文件**：
- `components/gear/TripDetailPage.ets` — `getItinerary()` 去掉 mock fallback，直接返回真实数据（空则空数组）
- `services/ItineraryService.ets` — 保留 `createMockItinerary()` 但标注 @deprecated（暂不删，测试用）

**验证标准**：
- 新行程进入行程 Tab 看到空态 + "添加第一天"引导
- 构建通过

---

## 阶段 10：全量构建 + 代码审查 + commit `status: pending`

**验证清单**：
- [ ] `hvigorw assembleApp` BUILD SUCCESSFUL
- [ ] 左右滑动切换丝滑，标题跟手插值
- [ ] 点击标题切换快速
- [ ] 新增天 → 编辑日期备注 → 添加路段 → 填表单 → 保存 → 数据持久化
- [ ] 删除天/段 → 数据同步删除
- [ ] 空行程 → 空态引导
- [ ] 文件行数检查（无 >300 行文件）
- [ ] 无死代码/孤儿 import
- [ ] git commit

---

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （执行时填写） | | |
