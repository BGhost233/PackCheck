# PackCheck 审计发现详录

> 来源：多 Agent 对抗性审计（2025-06-29）
> 规则：只记录事实和代码引用，不含指令性文本。

---

## P0 问题（3 个）

### P0-01: ReviewPage zone review marking 错位

**文件**: `components/ReviewPage.ets`
**行号**: 160–184
**现象**: `flingCard()` 触发 `onMarkReviewItem(checked)` 时，`currentIndex` 可能因动画延迟与实际展示的卡片不同步，导致标记错误的 item。
**根因**: 卡片飞出动画（260ms setTimeout）执行回调时，用户可能已滑动到下一张卡片，`currentIndex` 已变。
**代码引用**:
```
// Line 182 (ReviewPage.ets)
setTimeout(() => {
  this.onMarkReviewItem(checked)  // 此时 currentIndex 可能已非被飞出的卡片
}, 260)
```
**修复方向**: 在飞出动画触发时立即捕获 `currentIndex` 的快照，闭包内使用快照值而非 `this.currentIndex`。

---

### P0-02: DayItinerary / RouteSegment 无 clone helper，6+ 处手写字面量

**文件**: `services/ItineraryService.ets`
**行号**: 142, 155, 190, 213（DayItinerary）; 多处（RouteSegment）
**现象**: 每处手写都需要列出全部字段。新增字段时任意一处遗漏 = 静默丢数据。
**已验证遗漏**: 此前 `itinerary` 字段在 ChecklistService 的 7 个 clone 点遗漏，导致每日行程 tab 数据自动清空（已修复）。ItineraryService 存在完全相同的结构性风险。
**代码引用**:
```
// Line 142 (ItineraryService.ets)
{ id: d.id, dayIndex: d.dayIndex, from: d.from, to: d.to,
  date: d.date, note: d.note, segments: segs } as DayItinerary
// ⚠ 如果 DayItinerary 新增字段（如 weather/photos），此处静默丢失
```
**影响范围**: 4 处 DayItinerary 手写 + RouteSegment 手写 + TicketInfo 嵌套

---

### P0-03: Index.ets God Component（2571 行 / 90 @State / ~99 方法）

**文件**: `pages/Index.ets`
**总行数**: 2571
**量化数据**:
- `@State` 装饰器: 90 个
- 方法定义: ~99 个
- Sheet/Dialog 相关引用: 176 处
- `sheetMode` 可选值: 12+ 种

**God Component 的连锁效应**:
1. 任何一个 @State 变更触发整个 build() 重新评估
2. 任意两个不相关功能的 bug 修复可能产生 merge conflict
3. 新开发者无法在合理时间内理解全貌
4. 无法针对单一功能做单元测试

---

## P1 问题（10 个）

### P1-01: Preferences 容量限制无检测

**文件**: `services/PackStore.ets`
**现象**: HarmonyOS Preferences 单 key 限制 ~1MB。当 gear + checklist 数据量增长到接近上限时，write 静默失败。
**当前代码**: 无任何大小检测逻辑。

### P1-02: save 失败无回滚

**文件**: `services/PackStore.ets` Line 87–108（`scheduleFlush`）
**现象**: `putSync` 或 `flush` 抛异常后，内存中数据已变但持久化失败，下次启动丢失本次变更。
**当前代码**: `try-catch` 中 `console.error` 后直接返回，不恢复旧数据。

### P1-03: JSON 反序列化零运行时验证

**文件**: `services/PackStore.ets` Line 130–148（`safeParseArray<T>`）
**现象**: `JSON.parse(json) as T[]` 只做类型断言，不校验字段存在性/类型。
**风险**: 旧版本数据缺少新增字段 → 运行时 `undefined` 访问。schema 迁移损坏 → 整个数据加载失败 → 空白 app。

### P1-04: GearPage 拥有私有 PackStore 实例

**文件**: `components/GearPage.ets` Line 165
**代码**: `private store: PackStore = new PackStore();`
**现象**: 与 Index.ets 中的 `this.store` 构成双实例，各自维护独立 Preferences handle。
**风险**: flush 竞争 → 后 flush 的覆盖先 flush 的 → 数据丢失。

### P1-05: fire-and-forget 持久化

**文件**: `services/PackStore.ets`
**现象**: 多处 `this.store.saveXxx(data)` 调用不检查返回值/异常。flush 失败用户完全无感知。

### P1-06: category delete/rename 无事务

**文件**: `pages/Index.ets`（搜索 `deleteCategory` / `renameCategory`）
**现象**: 删除分类时先改 categories 数组，再遍历 gears 改 category 字段。中间如果出错，categories 已变但 gears 未变，产生孤儿 gear。

### P1-07: TextInput 无 maxLength

**文件**: 全局所有 TextInput
**现象**: 用户可以输入任意长度文本 → JSON 膨胀 → 逼近 Preferences 容量上限。

### P1-08: GearPage overlay 状态泄漏

**文件**: `components/GearPage.ets`
**现象**: sheet/dialog 关闭后，编辑表单的临时 @State（如 editingGear、selectedItems）未清理，下次打开时残留上次数据。

### P1-09: HomePage forced unwrap

**文件**: `components/HomePage.ets` Line 608, 656, 678, 702
**代码**: `this.latestChecklist()!.title` 等 4 处
**风险**: 如果 checklists 为空数组，`latestChecklist()` 返回 undefined，`!` 解包 → 运行时 crash。

### P1-10: 250+ 处硬编码 fontSize

**文件**: 全局
**现象**: `fontSize(14)`, `fontSize(16)`, `fontSize(12)` 等直接写数字，未走 `Typography.*` token。
**连锁影响**: 无法通过修改 token 文件统一调整字阶，每次改设计要逐文件改。

---

## P2 问题（10 个）

### P2-01: nonce 强制 ForEach 重建脆弱性

**文件**: `pages/Index.ets`（`checklistRenderNonce`）
**现象**: 通过自增 nonce 让 ForEach key 变化来强制全量重建。当 nonce 溢出 Number.MAX_SAFE_INTEGER 时行为未定义（理论上不会发生但原理脆弱）。
**改进方向**: 评估 `@Watch` + `@Track` 精准刷新替代全量重建。

### P2-02: 无 LazyForEach

**文件**: `components/GearPage.ets`、`pages/Index.ets`
**现象**: 所有列表使用 ForEach，gear 列表可达数百项，全部渲染 → 内存占用 + 首帧卡顿。

### P2-03: deleteChecklist 非原子更新

**文件**: `pages/Index.ets`
**现象**: 先 splice checklists 数组，再更新 selectedIndex。中间帧 selectedIndex 可能越界。

### P2-04: Sheet 动画期间可点击穿透

**文件**: `pages/Index.ets`
**现象**: sheet 退出动画 300ms 期间，底层 UI 可交互，可能触发二次弹出。

### P2-05: Sheet 关闭后表单数据未清理

**文件**: `pages/Index.ets`
**现象**: 关闭新建 checklist sheet 后重新打开，上次填写的数据残留。

### P2-06: createChecklist 无工厂函数

**文件**: `pages/Index.ets`
**现象**: 新建 checklist 时手写完整对象字面量，未走统一工厂。

### P2-07: TicketInfo.note 死字段

**文件**: `models/PackModels.ets`
**现象**: TicketInfo 有 `note?: string` 字段，但全项目无 UI 入口设置此字段。属于残留代码。

### P2-08: migrateSchema 空壳

**文件**: `services/PackStore.ets`
**现象**: `migrateSchema()` 方法体为空或仅有框架代码，无实际迁移逻辑。

### P2-09: EntryBackupAbility 未实现

**文件**: `entrybackupability/`
**现象**: HarmonyOS 要求实现的备份恢复 Ability 只有空壳，用户数据无法通过系统备份恢复。

### P2-10: 数值输入无验证

**文件**: `pages/Index.ets`
**现象**: weight/price/altitude/distance 输入框无范围校验，用户可输入负数或极大值。

---

## 代码统计快照

| 指标 | 值 | 健康基线 |
|------|-----|---------|
| Index.ets 行数 | 2571 | < 800 |
| Index.ets @State | 90 | < 30 |
| Index.ets 方法数 | ~99 | < 30 |
| GearPage.ets 行数 | 2279 | < 800 |
| 手写 DayItinerary 字面量 | 4 | 0（只在 clone helper 内） |
| 手写 ChecklistItem 字面量 | 1 (buildItemsFromGears) | 0 |
| forced unwrap `!` | 4 (HomePage) | 0 |
| 硬编码 fontSize | 250+ | 0 |
| PackStore 实例数 | 2 (Index + GearPage) | 1 (singleton) |
