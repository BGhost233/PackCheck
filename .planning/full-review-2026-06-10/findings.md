# PackCheck 全项目审查报告 (Apple 标准)

> 审查日期：2026-06-10 | 代码规模：48 个 .ets 文件，~50,000 行  
> 方法：4 路并行 agent 逐文件审查 + 独立代码走读 + 规范交叉验证  
> 标准：DEVELOPMENT_STANDARDS.md + Apple HIG 级交互标准

---

## 0. 总体评价

项目处于 **v0.6.1+ 配装系统集成** 阶段。核心架构（中心状态管理器、3 Tab、Sheet 体系统一、双视图配装）稳固。上一轮 P1 修复（async/await、geometryTransition、共享信息区、misc 缓存）均已正确应用。本轮审查聚焦于**跨文件的动效一致性违规、按压反馈缺失、以及多处的 Spring+duration 混用**。

---

## 🔴 Critical — 动效规范违规

### CR-1. 多处 Spring + duration 同时使用（DEVELOPMENT_STANDARDS §3.6 第 1 条禁止项）

Spring 系列曲线完全忽略 `duration` 字段，时间由 `response` 参数唯一决定。同时使用会导致开发者对动画时长产生错误预期。

| # | 文件 | 行号 | 代码 |
|---|------|------|------|
| 1 | TripDetailPage.ets | 133-134 | `animateTo({ duration: 100, curve: SPRING_PRESS() }, ...)` |
| 2 | TripDetailPage.ets | 137-138 | `animateTo({ duration: 200, curve: SPRING_GENERAL() }, ...)` |
| 3 | TripDetailPage.ets | 86 | `.transition(TransitionEffect.OPACITY.animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() }))` |
| 4 | TripDetailPage.ets | 109 | 同上 |
| 5 | TripDetailPage.ets | 252 | `animateTo({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() }, ...)` |
| 6 | LoadoutView.ets | 204-208 | `.animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL(), delay: staggerDelay(index) })` |
| 7 | LoadoutView.ets | 125 | `.animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() })` |
| 8 | LoadoutView.ets | 131, 138, 151 | 同上模式重复 |
| 9 | LoadoutView.ets | 253 | `.animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL(), delay: 200 })` |
| 10 | LoadoutView.ets | 236-237 | `animateTo({ duration: 100, curve: SPRING_PRESS() }, ...)` |
| 11 | LoadoutView.ets | 239-240 | `animateTo({ duration: 200, curve: SPRING_GENERAL() }, ...)` |
| 12 | GearPage.ets | 多处 | 历史遗留，上一轮审查标注但未修复 |

**修复**：删除所有 `duration:` 参数，仅保留 `curve:`。如需延迟，使用 `delay:` 字段（仅 `.animation()` 修饰器支持）或 `setTimeout` + `animateTo` 组合。

---

## 🟡 Medium — 缺失交互反馈

### M-1. TripDetailPage `···` 按钮无按压反馈

**文件**：`TripDetailPage.ets:156-169`

「···」更多菜单按钮使用裸 `onClick`，无 `onTouch`、无 `scale`、无 `SPRING_PRESS()`。按项目规范，所有可点击元素必须有按压反馈。

**修复**：添加 `@State private menuScale: number = 1.0`，`.scale({ x: this.menuScale, y: this.menuScale }).animation({ curve: SPRING_PRESS() }).onTouch(...)`。

### M-2. TripDetailPage `···` 菜单仅映射到编辑操作

**文件**：`TripDetailPage.ets:167-168`

Spec §3.6 要求 `···` 包含三项：编辑行程信息、核查复盘、删除行程。当前仅映射到 `onOpenEditTrip`。

**修复**：`···` 点击后呼出一个 ActionSheet 或使用现有 Sheet 模式展示三个选项。或至少添加 `onOpenEditProfile` 和 `onOpenReview` 两个回调。

### M-3. TripDetailPage 共享信息区不可点击

**文件**：`TripDetailPage.ets:177-191`

Spec §3.2 要求共享信息区（日期+结构化字段）tap 可编辑（→ ProfileEditSheet）。当前仅展示文本，无 `onClick`。

**修复**：添加 `.onClick(() => { this.onOpenEditProfile(); })`。

### M-4. LoadoutView `onTapLayerBadge` 仍映射到 `onLongPressItem`

**文件**：`LoadoutView.ets:200`

```typescript
onTapLayerBadge: this.onLongPressItem  // ❌ 应该是 this.onLayerChange
```

层级 badge tap 本应触发层级切换，但错误映射到长按菜单处理程序。上一轮审查标注了此问题但在本次修复中未被修正。

### M-5. TripDetailPage `animateTo` 与 `this.getUIContext().animateTo` 混用

**文件**：`TripDetailPage.ets:132, 136, 252`

TripDetailPage 使用全局 `animateTo()`（不带前缀），而 `GearPickerSheet`、`LoadoutGearItem` 等使用 `this.getUIContext().animateTo()`。两种方式在大多数场景下功能等效，但 `getUIContext()` 是 ArkUI 推荐的显式绑定方式。不一致容易在组件销毁/重建时导致动画泄漏。

**修复**：统一使用 `this.getUIContext().animateTo()`。

### M-6. 多处硬编码颜色/值

| # | 文件 | 行号 | 值 | 应使用 |
|---|------|------|-----|--------|
| 1 | TripDetailPage.ets | 245 | `'#0D000000'` (shadow color) | `SHADOW_SUBTLE` 或定义新 token |
| 2 | TripDetailPage.ets | 238 | `'transparent'` (backgroundColor) | `TRANSPARENT` from Colors.ets |
| 3 | LoadoutView.ets | 229 | `'#33000000'` (FAB shadow) | `OVERLAY_DIM` 或 `SHADOW_*` token |
| 4 | LoadoutZoneCard.ets | 30 | `'#78909C'` (zoneColor default) | `ZONE_MISC_COLOR` |

### M-7. ForEach key 未包含全部变化维度

| # | 文件 | 行号 | 当前 key | 问题 |
|---|------|------|---------|------|
| 1 | GearPickerSheet.ets | 109-111 | `(gear: GearItem) => gear.id` | 正确——gear 的属性变化会触发重渲染 |
| 2 | LoadoutZoneCard.ets | 73-82 | `(item: ChecklistItem) => item.id` | 不足——`item.checked` 变化不改变 id，勾选状态可能不更新。根据 MEMORY.md 避坑 #24，key 应包含所有影响渲染的维度。建议：`item.id + '_' + item.checked.toString()` |

---

## 🔵 Low — 代码质量与细节

### L-1. LoadoutProgressBar 重复实现 counter 动画

**文件**：`LoadoutProgressBar.ets:102-128`

`animateCounter` 函数使用 `setTimeout` + `Date.now()` + easeOutCubic，与 `AnimationUtils.counterAnimate` 功能重复。且未处理并发动画取消（快速勾选时多个 timer 同时运行）。

### L-2. LoadoutProgressBar 动画无并发防护

**文件**：`LoadoutProgressBar.ets:28-31, 102-128`

如果用户快速勾选/取消，`onCheckedChange` 被多次触发，多个 `animateCounter` 循环同时运行竞争写入 `displayChecked`。应存储 timer ID 并在新动画启动时清除旧循环。

### L-3. GearPickerSheet Zone chip 颜色使用字符串拼接

**文件**：`GearPickerSheet.ets:294`

`.backgroundColor(this.isSelected(gear.id) ? PRIMARY_COLOR : '#33' + this.getZoneColor(assignSlot(gear).zone).substring(1))` — 字符串拼接添加透明度不可靠。应在 `Colors.ets` 中定义 Zone 颜色的半透明变体。

### L-4. GearPickerSheet 品类筛选使用 CategoryTagGroup 单选模式

**文件**：`GearPickerSheet.ets:72-81`

`CategoryTagGroup` 新增了 `mode: 'single'` prop 但旧代码中的多选逻辑（`handleMultiSelect`）在 single 模式下是死代码。single 模式的交互路径需要确保所有旧逻辑分支都有正确的新处理。

### L-5. ChecklistDetail 内部多处缺失按压反馈

**文件**：`ChecklistDetail.ets`

以下元素有 `onClick` 但无按压动画：NavBar 返回按钮、Header 标题/日期行、GroupHeader、ActionChip、MiniActionButton。这是历史遗留问题，在先前的代码审查中已记录但未批量修复。

### L-6. GearSortSheet 按压反馈使用了错误的 rest state

**文件**：`GearSortSheet.ets:50-57`

按压动画的 rest state 使用 `PRESS_SCALE_REST` (1.0)，但没有 bounce 阶段（1.0→0.96→1.02→1.0）。规范要求三段式按压反馈。

### L-7. ReviewPage translate 使用了错误参数

**文件**：`ReviewPage.ets:150`

`.translate({ x: this.reviewDragX, y: 0 })` — 之前有无效的 `z: 0` 参数，已修正。目前正确。

### L-8. TripCeremonyCard 光晕层动画参数不完整

**文件**：`TripCeremonyCard.ets:612-634`

光晕层使用 `CURVE_DECELERATE` 而非 Spring 曲线。前一轮审查已修复 22 处，此项为遗漏。

---

## 📊 跨模块统计

### 按压反馈缺失清单

| 组件 | 缺失元素 |
|------|---------|
| TripDetailPage | ··· 更多菜单按钮 |
| TripDetailPage | Segment 标签 |
| TripDetailPage | 共享信息区 |
| ChecklistDetail | NavBar 返回、Header 标题/日期、GroupHeader、ActionChip、MiniActionButton |
| GearSortSheet | SortOption 行（缺少 bounce 阶段） |
| GearItemActionSheet | 「移动到」「查看详情」「移除」「取消」四行 |
| GearPickerSheet | 装备行（仅 zone chip 有色变，整行无 scale 反馈） |
| LoadoutView | 空态引导按钮（使用 Button 原生效果，非自定义 Spring 动画） |

### Spring+duration 混用清单

| 文件 | 数量 | 典型模式 |
|------|------|---------|
| TripDetailPage.ets | 7 | `animateTo({ duration: N, curve: SPRING_*() })` |
| LoadoutView.ets | 12 | `.animation({ duration: DURATION_NORMAL, curve: SPRING_*() })` |
| GearPage.ets | 3 | 历史遗留 |

---

## ✅ 已确认修复正确的问题

以下上一轮审查的问题已在最新 commit (12320d9) 中正确修复：

1. ✅ `geometryTransition('trip-' + id)` — 已添加到 TripDetailPage NavDestination
2. ✅ `transition opacity 0.99 → 0` — 已修正
3. ✅ `async/await saveChecklists` — toggleGearInTrip/addTempGearToTrip/moveItemToZone/removeItemFromTrip 全部改为 async/await
4. ✅ `onActionViewDetail` — 已添加 `returnToHome()` + `currentTabIndex = 1`
5. ✅ 共享信息区 — 已添加 `buildSharedInfo()` 显示日期+结构化字段
6. ✅ `···` 更多菜单 — 已添加（但实现不完整，见 M-2）
7. ✅ GearPickerSheet 临时添加行按压反馈 — 已添加
8. ✅ `closeTempOverlay setTimeout` → `animateTo onFinish` — 已修复
9. ✅ LoadoutZoneCard misc 缓存 — 已添加 `miscMapCache` + `@Watch`

---

## 🎯 优先修复建议 (Top 5)

| 优先级 | 问题 | 改动量 | 影响 |
|--------|------|--------|------|
| P0 | 清理所有 Spring+duration 混用（~22 处） | ~22 行删除 | 动画行为符合规范，避免开发者困惑 |
| P1 | `onTapLayerBadge` 回调修正 | 1 行 | 层级切换功能恢复正常 |
| P1 | `···` 菜单补全（编辑/核查/删除三选项） | ~15 行 | 完整的功能入口 |
| P1 | 共享信息区添加 tap 编辑入口 | 1 行 | 用户可编辑行程信息 |
| P2 | `ForEach` key 加入 checked 状态 | ~3 处 | 勾选渲染可靠性 |
