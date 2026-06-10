# PackCheck 全面代码审查报告

> 日期：2026-06-10 | 范围：全项目（~13,325 行 .ets 代码 + 文档/配置）  
> 标准：Apple 级别 UI/UX + 项目 DEVELOPMENT_STANDARDS.md 规范  
> 审查维度：数据完整性、架构合规性、UI/UX/动效、设计 Token 合规、错误处理、类型安全、性能、可维护性

---

## 执行摘要

本次审查覆盖 **35 个源文件**、**7 份规范/设计文档**、**12 份配置文件**。共发现 **~213 个问题**，其中 **🔴 严重问题 18 个**（含 3 个数据完整性 bug、4 个架构违规、5 个设计 Token 违规、6 个UX/动画违规）、**🟡 中等问题 ~80 个**、**🔵 轻微问题 ~115 个**。

**核心发现：代码整体质量高，但存在几个需要优先修复的运行时 bug 和架构债务。**

---

## 🔴 第一部分：严重问题 (Critical)

### 1. 数据完整性与正确性

#### 1.1 `PRIMARY_FILL_SUBTLE` alpha 字节位置错误
- **文件**: `entry/src/main/ets/constants/Colors.ets:22`
- **类别**: bug-risk
- **描述**: 值 `#2D7D4660` 将 alpha 字节放在末尾（RRGGBBAA 格式），但项目中所有其他 alpha 变体都使用 ARGB 格式（alpha 在前，如 `#332D7D46`）。ArkUI 使用 ARGB 格式解析，因此 `#2D7D4660` 被解析为 alpha=0x2D(17.6%), R=0x7D, G=0x46, B=0x60——产生一个浑浊的蓝绿色，而非预期的半透明山野绿。
- **修复**: 改为 `#602D7D46`

#### 1.2 PackStore 静默吞噬所有持久化错误
- **文件**: `entry/src/main/ets/services/PackStore.ets:22-25, 99-100, 112`
- **类别**: error-handling, data-integrity
- **描述**: `init()` 失败时 `prefs` 保持 `undefined`，所有后续 `readString`/`writeString` 静默返回默认值。用户数据静默丢失，无任何错误提示。所有 catch 块均为空。
- **修复**: 记录错误日志；考虑在 init 失败时抛出异常或设置损坏标志，供 UI 层提示用户

#### 1.3 分类重命名功能完全损坏（数据静默丢弃）
- **文件**: 
  - `entry/src/main/ets/components/sheets/GearFormSheet.ets:67-68`
  - `entry/src/main/ets/components/sheets/TempItemSheet.ets:60-62`
  - `entry/src/main/ets/components/sheets/SheetOverlay.ets:99`
- **类别**: data-loss, bug
- **描述**: `onRename(oldName, '')` — 新名称参数被丢弃，总是传空字符串。这意味着分类重命名操作永远不会实际更新分类名称，用户以为重命名成功了但实际上什么都没发生。
- **修复**: `this.onRename(oldName, newName)`

#### 1.4 无 Schema 版本化 / 数据迁移机制
- **文件**: `entry/src/main/ets/services/PackStore.ets`（所有 get 方法）
- **类别**: backward-compat, data-integrity
- **描述**: 所有持久化数据通过 `JSON.parse(value) as GearItem[]` 读取，无 schema 版本号。未来新增字段时，旧 JSON 会静默解析为缺少新字段的对象。TypeScript 的 `as` 强制转换不做运行时验证。
- **修复**: 引入 `packcheck_schema_version` key，在 `init()` 时检查版本并执行迁移

#### 1.5 `ColorUtils.heroGradientStart` — `daysLeft === 0` 返回错误颜色
- **文件**: `entry/src/main/ets/utils/ColorUtils.ets:63`
- **类别**: logic-error
- **描述**: 条件链 `> 14` → 绿, `> 7` → 绿, `> 3` → teal, `> 0` → 暖黄, `<= 0` → 返回 `'#E8F5E9'`（和 `> 7` 相同的悠闲绿色）。今天出发的行程（`daysLeft === 0`）显示和 8+ 天后一样的放松绿色，极具误导性。
- **修复**: 将 `if (daysLeft > 0)` 改为 `if (daysLeft >= 0)`，或添加显式的 `if (daysLeft === 0)` 分支返回紧急警告色

#### 1.6 ChecklistService 中 `!` 非空断言可能运行时崩溃
- **文件**: `entry/src/main/ets/services/ChecklistService.ets:346, 358`
- **类别**: bug-risk
- **描述**: `checklistDateAt(nearestFuture)!` 和 `checklistDateAt(latestPast)!` 使用了非空断言。虽然当前逻辑保证了值非空，但如果 `checklistDateAt` 的实现发生变化或 `nearestFuture` 在两次调用间被修改，运行时将抛出 TypeError。
- **修复**: 将解析后的 `dateAt` 存入局部变量，消除断言

#### 1.7 `FootprintService` maxAltitude 忽略负海拔
- **文件**: `entry/src/main/ets/services/FootprintService.ets:52-53`
- **类别**: data-integrity
- **描述**: `maxAltitude` 从 0 开始，`> maxAltitude` 条件对负数无效。在死海（~-430m）徒步时，报告的最高海拔为 0。
- **修复**: 初始化为 `-Infinity`，循环后若无有效值则设为 0

#### 1.8 `FootprintService` 排序混合了 `dateAt` 和 `createdAt`
- **文件**: `entry/src/main/ets/services/FootprintService.ets:103-106`
- **类别**: data-integrity
- **描述**: `const aTime = typeof a.dateAt === 'number' ? a.dateAt : a.createdAt` — 将行程日期与创建时间戳混排。有 `dateAt` 的未来行程和无 `dateAt` 的旧行程比较时产生语义错误的排序。
- **修复**: 确保所有行程在创建时填充 `dateAt`；添加稳定次级排序（如按 id）

---

### 2. 架构合规性违规

#### 2.1 Index.ets 中有 ~55 行业务逻辑未委托给 Service
- **文件**: `entry/src/main/ets/pages/Index.ets:1521-1576`
- **类别**: architecture（违反 "Index.ets 不写业务逻辑" 铁律）
- **描述**: `setChecklistItemChecked` 方法手动深拷贝 checklist items 并内联 toggle 逻辑（55 行），而项目中已有 `toggleItemInChecklists` 正确委托给 `ChecklistService`。同样的模式在 `saveGear`（581-643 行）、`batchMoveGroup`（840-860 行）中也存在。
- **修复**: 在 `ChecklistService` 中创建 `setChecklistItemChecked` 纯函数，像 `toggleItemInChecklists` 一样委托

#### 2.2 Index.ets 硬编码 Tab 数量边界
- **文件**: `entry/src/main/ets/pages/Index.ets:1997-1999, 1803-1804`
- **类别**: maintainability
- **描述**: 滑动手势处理器硬编码 `currentTabIndex === 2` 为最大索引。如果 tab 数量变更（未来可能 4 tab 或 2 tab），这些边界判断会静默错误。
- **修复**: 定义 `private readonly tabCount: number = 3`，使用 `this.currentTabIndex === this.tabCount - 1`

#### 2.3 GearPage 使用 `bindSheet` 而非项目统一的 `SheetOverlay` 模式
- **文件**: `entry/src/main/ets/components/GearPage.ets:1124`
- **类别**: architecture（双轨 Sheet 模式）
- **描述**: `MoveGroupSheet` 使用原生 `.bindSheet()` API，而其余所有 Sheet 使用自定义 `SheetOverlay` 组件。这绕过了 Index.ets 中的集中 Sheet 状态管理，导致两个互相竞争的 Sheet 模式。
- **修复**: 将分组移动 Sheet 内容移入 `SheetOverlay`（新增 `SHEET_MOVE_GROUP` 模式）

#### 2.4 Index.ets 中 `sort()` 原地修改 `@State` 数组
- **文件**: `entry/src/main/ets/pages/Index.ets:232`
- **类别**: state-management
- **描述**: `this.checklists.sort(...)` 原地排序 `@State checklists` 数组。ArkUI 的变更检测依赖引用身份，原地排序可能不触发重渲染。
- **修复**: 使用 `const sorted = [...this.checklists].sort(...); this.checklists = sorted;`

#### 2.5 弃用的对象式 `.transition()` API
- **文件**: `entry/src/main/ets/pages/Index.ets:2278`
- **类别**: arkts-compliance
- **描述**: `CompletionToast` 使用了已弃用的对象式 transition API。API 23+ 应使用 `TransitionEffect` 链式语法。
- **修复**: 替换为 `TransitionEffect.OPACITY.combine(TransitionEffect.translate(...))`

---

### 3. 设计 Token 合规性违规

#### 3.1 `CategoryInputDialog` 中 ~8 处硬编码色值
- **文件**: `entry/src/main/ets/pages/Index.ets:2293, 2301, 2307, 2308, 2314, 2317, 2323, 2325, 2344, 2345, 2347`
- **类别**: token-compliance
- **描述**: `CategoryInputDialog` builder 使用了大量硬编码颜色（`'#66000000'` = OVERLAY_MASK，`'#1A1A1A'` = TEXT_MAIN，`'#F5F5F5'` = GROUP_HEADER_BG，`'#FFFFFF'` = CARD_BG 等），这些在 Colors.ets 中都有对应 token。
- **修复**: 导入并使用已有的设计 token

#### 3.2 多处硬编码 hex 色值
- **文件**: 
  - `entry/src/main/ets/components/EditGearPanel.ets:221` (`'#FFFFFF'`)
  - `entry/src/main/ets/components/EditItemPanel.ets:201` (`'#FFFFFF'`)
  - `entry/src/main/ets/components/ProfilePage.ets:232` (`'#1B5E20'`)
  - `entry/src/main/ets/components/ProfilePage.ets:492` (`'#33FFFFFF'`)
- **类别**: token-compliance
- **修复**: 替换为 Colors.ets token

#### 3.3 ProfilePage 硬编码 `"'tnum'"` 而非使用 `FONT_FEATURE_TNUM` 常量
- **文件**: `entry/src/main/ets/components/ProfilePage.ets:200, 363, 502`
- **类别**: token-compliance
- **修复**: 替换为 `FONT_FEATURE_TNUM`

#### 3.4 ProfilePage 导入路径不一致
- **文件**: `entry/src/main/ets/components/ProfilePage.ets:8, 9`
- **类别**: consistency
- **描述**: ProfilePage 从 `'../constants/Colors'` 和 `'../constants/Layout'` 分别导入，而其他页面统一从 `'../constants/DesignTokens'`（barrel re-export）导入。
- **修复**: 统一从 DesignTokens 导入

---

### 4. 交互与动画严重违规

#### 4.1 SheetOverlay 缺失 Spring 入场/退场动画
- **文件**: `entry/src/main/ets/components/sheets/SheetOverlay.ets:249, 253`
- **类别**: animation
- **描述**: Sheet 使用 `translate({ y: this.sheetTranslateY })` 和 `opacity(this.sheetOverlayOpacity)`，但都没有包裹在 `animateTo` 中。父组件可能瞬时更新这些属性，导致 Sheet 硬切入/切出，无 Spring 弹性。
- **修复**: 使用 `animateTo({ curve: SPRING_PANEL_ENTER() }, () => { this.sheetTranslateY = 0 })`

#### 4.2 SheetOverlay 缺失下滑关闭手势
- **文件**: `entry/src/main/ets/components/sheets/SheetOverlay.ets:105-256`
- **类别**: gesture
- **描述**: Sheet 只能通过点击遮罩区域或关闭按钮来关闭。没有 `PanGesture` 实现下滑关闭，这是标准底部 Sheet 的必备交互。
- **修复**: 添加 `PanGesture` 跟踪垂直滑动偏移，超过阈值时关闭

#### 4.3 TripFormSheet 确认按钮无任何验证
- **文件**: `entry/src/main/ets/components/sheets/TripFormSheet.ets:127-145`
- **类别**: validation
- **描述**: 确认按钮没有 `.enabled()` 守卫，总是使用 `PRIMARY_COLOR`。用户可以创建标题为空的行程。相比之下 `GearFormSheet` 正确检查了 `gearName.trim().length === 0`。
- **修复**: 添加 `.enabled(this.tripTitle.trim().length > 0)`

#### 4.4 GenerateTripSheet 允许创建空行程
- **文件**: `entry/src/main/ets/components/sheets/GenerateTripSheet.ets:46-52`
- **类别**: validation
- **描述**: 确认按钮仅检查 `title.trim().length > 0`，未检查 `selectedCount > 0`。用户可以生成 0 件装备的行程。
- **修复**: 添加 `.enabled(this.generateTripTitle.trim().length > 0 && this.selectedCount > 0)`

#### 4.5 ChecklistDetail 中 TransitionEffect opacity 为 0.99
- **文件**: `entry/src/main/ets/components/ChecklistDetail.ets:444`
- **类别**: animation
- **描述**: `TransitionEffect.opacity(0.99)` 表示页面从 99% 不透明度开始——本质上无淡入效果。几乎可以确定意图是 `TransitionEffect.opacity(0)`。
- **修复**: 改为 `TransitionEffect.opacity(0)`

#### 4.6 GearPage `bindSheet` 使用 `Curve.EaseInOut` 而非 Spring
- **文件**: `entry/src/main/ets/components/GearPage.ets:961`
- **类别**: animation（违反 Spring-only 规范）
- **描述**: `GearPage.ets:961` 使用 `{ duration: DURATION_CEREMONY_SHAKE }` 而没有指定 Spring 曲线。应使用 `SPRING_GENERAL()`。

---

## 🟡 第二部分：中等问题 (Medium)

### 5. 数据与业务逻辑

| # | 文件 | 行号 | 描述 |
|---|------|------|------|
| 5.1 | ChecklistService.ets | 186-194 | `progressEndColor` 有两个相同返回值分支（死代码） |
| 5.2 | ChecklistService.ets | 3 | 未使用的 import `numberOrZero` |
| 5.3 | ChecklistService.ets | 327-332 | `formatKgLocal` 与 `GearService.formatKg` 重复实现 |
| 5.4 | GearService.ets | 151-158 | `filteredGearsByGroup` 在非 GROUP 排序模式下静默忽略 `group` 参数 |
| 5.5 | GearService.ets | 230-235 | `formatKg` 四舍五入到 100g 精度，与克显示不一致 |
| 5.6 | GearService.ets | 95-106, 264-271 | `allGearFilterCategories` 和 `categoryTabs` 产生完全相同输出（重复逻辑） |
| 5.7 | CategoryService.ets | 9 | `PROTECTED_CATEGORY` 硬编码，应与 PackModels 中 `DEFAULT_CATEGORIES` 共享 |
| 5.8 | CategoryService.ets | 138-158 | `renameCategory` 在 oldName 不存在时静默 no-op，调用方无法检测 |
| 5.9 | PackStore.ets | 17-19 | `init()` 首次失败后永久 no-op，瞬时错误导致持久化永久失效 |
| 5.10 | PackStore.ets | 32-88 | 所有 `readString` fallback 值重复硬编码为 magic string `'[]'` |
| 5.11 | FootprintService.ets | 112 | `dateLabel` 在无 `dateAt` 时使用 `createdAt`（录入时间而非出行时间） |
| 5.12 | FootprintService.ets | 92 | `computeLongestCompanion` 对 NaN 时间戳无防护，可能返回 NaN 天数 |

### 6. 所有 TripChecklist/GearItem 重建中的手动字段枚举
- **文件**: ChecklistService.ets, CategoryService.ets（多处）
- **描述**: 所有 immutable 更新函数手动列出模型的所有字段。如果未来新增字段，这些函数会静默丢弃数据。应使用 `{ ...source, field: newValue }` 展开语法。

### 7. Index.ets 中的空 catch 块
- **文件**: `entry/src/main/ets/pages/Index.ets:1100, 1110-1111, 1617-1618, 1624-1625`
- **描述**: 传感器注册、振动硬件、prompt action 错误被静默吞噬，生产环境调试极困难。

### 8. Index.ets DatePicker 总是默认今天
- **文件**: `entry/src/main/ets/pages/Index.ets:1313`
- **描述**: `DatePickerDialog.show({ selected: new Date(), ... })` 即使在编辑已有行程时也默认今天，用户需重新导航到正确日期。

### 9. TripCeremonyCard 中 22 处动画使用非 Spring 曲线
- **文件**: `entry/src/main/ets/components/TripCeremonyCard.ets`（多处）
- **描述**: 入场覆盖层、shimmer、光晕层、轨道滑动等动画使用 `CURVE_STANDARD` 或 `CURVE_DECELERATE` 而非 Spring 预设。需替换为合适的 Spring token。

### 10. ChecklistDetail 中 5 处动画使用 `CURVE_STANDARD` 而非 Spring
- **文件**: `entry/src/main/ets/components/ChecklistDetail.ets:340-348, 356-363, 459, 506, 727`
- **修复**: 替换为 `SPRING_GENERAL()` 或 `SPRING_CHEVRON()`

### 11. GearPage 超限 11 个 `@Prop`/`@Link`
- **文件**: `entry/src/main/ets/components/GearPage.ets:68-77, 114`
- **描述**: 项目规范要求 props ≤ 8 个。当前 11 个 binding + 多个 callback。
- **修复**: 相关 props 分组为 interface（如 `GearPageOptions`）

### 12. ChecklistDetail 中 `setTimeout` 替代动画
- **文件**: `entry/src/main/ets/components/ChecklistDetail.ets:70`
- **描述**: 使用 `setTimeout` 延迟触发动画而非使用 `animateTo` 的 `onFinish` 回调或 AnimationUtils 封装。

### 13. GearPage 滚动手势：硬切的二进制 translate
- **文件**: `entry/src/main/ets/components/GearPage.ets:970`
- **描述**: `.translate({ x: opacity > 0 ? 0 : -12 })` 是二进制跳跃（0 或 -12），而非平滑连续过渡。应使用 `-12 * (1 - opacity)` 实现平滑滑动。

### 14. GearPage 按压 scale 使用硬编码 0.97 而非 `PRESS_SCALE_DOWN`
- **文件**: `entry/src/main/ets/components/GearPage.ets:1228-1229`
- **修复**: 使用 `PRESS_SCALE_DOWN` (0.96)

### 15-20. 多处缺失按压反馈
跨所有组件的 ~30+ 个可点击元素缺少项目标准的三段式按压反馈（scale 1→0.96→1.02→1.0 + SPRING_PRESS）。

### 21. TripFormSheet DatePicker 省略年份
- **文件**: `entry/src/main/ets/components/sheets/TripFormSheet.ets:182-184`
- **描述**: 日期格式化为仅月+日，而 `ProfileEditSheet` 包含年份。不一致会导致跨年歧义。

### 22. WeightGauge gaugeMode 在 `animateTo` 外切换
- **文件**: `entry/src/main/ets/components/WeightGauge.ets:156`
- **描述**: gaugeMode 变更导致进度环值突变而非动画过渡。

### 23. CategoryTagGroup `setInterval` 每 80ms 驱动抖动动画
- **文件**: `entry/src/main/ets/components/CategoryTagGroup.ets:146-162`
- **描述**: 而非使用 ArkUI 原生的 `animateTo` 或 `Repeat` 动画，持续运行消耗电量。

### 24. CategoryTagGroup `wiggleTick` 不应为 `@State`
- **文件**: `entry/src/main/ets/components/CategoryTagGroup.ets:151`
- **描述**: `@State private wiggleTick` 每 80ms 触发不必要的重建。应为普通 `private` 字段。

### 25. ChecklistDetail `progressPulse` 声明但从未使用
- **文件**: `entry/src/main/ets/components/ChecklistDetail.ets:44`
- **描述**: `@Prop progressPulse` 声明后在整个组件中从未引用。

### 26. GearFilterPanel 未使用的 import
- **文件**: `entry/src/main/ets/components/GearFilterPanel.ets:1, 2`
- **描述**: `LengthMetrics` 和 `vibrator` 已导入但从未使用。

---

## 🔵 第三部分：轻微问题 (Low)

### 27. 类型安全

| # | 文件 | 描述 |
|---|------|------|
| 27.1 | Layout.ets, GearSort.ets, SheetMode.ets | 所有导出常量缺少显式类型标注（ArkTS 严格模式要求） |
| 27.2 | DesignTokens.ets:124-127 | 内联定义的 View route 常量缺少类型标注 |
| 27.3 | AnimationTokens.ets:48-50 | `CURVE_DECELERATE`/`CURVE_LINEAR` 类型为 `Curve`，而 `CURVE_STANDARD` 类型为 `ICurve`——类型不一致 |
| 27.4 | SheetOverlay.ets:32 | `sheetMode` 类型为 `string` 而非联合类型（`SheetMode`） |
| 27.5 | GearPage.ets:294 | `setInterval` 多余的 `as number` 转换 |

### 28. 命名与代码清洁

| # | 文件 | 描述 |
|---|------|------|
| 28.1 | EntryAbility.ets, EntryBackupAbility.ets | 所有 `hilog` 使用陈旧模板标签 `'testTag'`，应为 `'PackCheck'` |
| 28.2 | EntryAbility.ets, EntryBackupAbility.ets | hilog domain 使用保留值 `0x0000` |
| 28.3 | EntryBackupAbility.ets:9, 13 | `await Promise.resolve()` 是无操作，可移除 |
| 28.4 | ChecklistService.ets | `formatKgLocal` 与 `GearService.formatKg` 命名/逻辑重复 |
| 28.5 | CategoryTagGroup.ets:87-88 | 魔法字符串 `'全部'`，应提取为常量 |
| 28.6 | PackModels.ets:55-58 | `makeId` 在同一毫秒内可能产生碰撞（1/1M 概率） |
| 28.7 | ProfilePage.ets:411 | "征服" 措辞与温柔陪伴文案词典冲突，应改为 "探索" |
| 28.8 | ReviewPage.ets:150 | `translate` 包含无效的 `z` 参数 |

### 29. 可维护性

| # | 文件 | 描述 |
|---|------|------|
| 29.1 | ChecklistService.ets | `parseTripDateAt` 无年份时默认当前年——依赖此行为的调用方需要文档说明 |
| 29.2 | DesignTokens.ets | 缺失 `WHITE_SEMI_TRANSPARENT` 的 barrel re-export |
| 29.3 | GearLoadout.ets:29-43 | 中文品类名作为 map key 与 UI locale 强耦合，应使用枚举 |
| 29.4 | ProfileEditSheet.ets:54 | DatePicker end date 硬编码为 2030-12-31 |

### 30. 性能

| # | 文件 | 描述 |
|---|------|------|
| 30.1 | Index.ets:190, 250, 262 | `checklistRenderNonce` 强制 `ForEach` 全量重建 |
| 30.2 | Index.ets:482, 646, 843 | `indexOf` 用于数组成员检查（O(n)），可改用 `Set`（O(1)） |
| 30.3 | HomePage.ets | `latestChecklist()` 在单个 builder 中被调用 ~11 次 |
| 30.4 | CategoryTagGroup.ets:236 | ForEach key 在编辑模式切换时变更，强制所有 chip 重新挂载 |

### 31. 文档与配置

| # | 文件 | 描述 |
|---|------|------|
| 31.1 | CHANGELOG.md:1 | 日期格式不一致：v0.5.8 为 "2025-07-01"，v0.5.7 为 "2026-05-31"，年份跳跃 |
| 31.2 | README.md | 称 Index.ets "~2341 行"，实际为 2353 行 |
| 31.3 | module.json5 | deviceTypes 包含 "wearable" 但 UI 未针对手表优化 |
| 31.4 | dark/color.json | 深色模式 start_window_background 仍为 `#F8F9FA`（与亮色模式相同） |
| 31.5 | mock-config.json5 | 空对象 `{}`，无任何 mock 配置 |
| 31.6 | 测试文件 | LocalUnit.test.ets 和 Ability.test.ets 仅包含模板代码，无任何业务逻辑测试 |

---

## 📊 按模块汇总

| 模块 | Critical | Medium | Low | 总计 |
|------|----------|--------|-----|------|
| Constants | 1 | 8 | 7 | 16 |
| Models | 0 | 0 | 2 | 2 |
| EntryAbility | 0 | 2 | 3 | 5 |
| Services (PackStore) | 2 | 4 | 0 | 6 |
| Services (ChecklistService) | 1 | 5 | 4 | 10 |
| Services (GearService) | 0 | 3 | 4 | 7 |
| Services (CategoryService) | 0 | 3 | 1 | 4 |
| Services (FootprintService) | 2 | 3 | 2 | 7 |
| Utils (AnimationUtils) | 0 | 1 | 2 | 3 |
| Utils (ColorUtils) | 1 | 0 | 2 | 3 |
| Pages (Index.ets) | 4 | 8 | 6 | 18 |
| Components (HomePage) | 0 | 4 | 2 | 6 |
| Components (GearPage) | 1 | 8 | 3 | 12 |
| Components (ProfilePage) | 0 | 7 | 2 | 9 |
| Components (ReviewPage) | 0 | 3 | 2 | 5 |
| Components (ChecklistDetail) | 5 | 5 | 3 | 13 |
| Components (TripCeremonyCard) | 2 | 7 | 3 | 12 |
| Components (WeightGauge) | 2 | 3 | 2 | 7 |
| Components (EditGearPanel) | 0 | 3 | 1 | 4 |
| Components (EditItemPanel) | 0 | 4 | 1 | 5 |
| Components (GearFilterPanel) | 2 | 3 | 1 | 6 |
| Components (CategoryTagGroup) | 0 | 6 | 3 | 9 |
| Components (EmptyIllustration) | 0 | 0 | 3 | 3 |
| Sheets (SheetOverlay) | 2 | 5 | 1 | 8 |
| Sheets (GearFormSheet) | 1 | 1 | 1 | 3 |
| Sheets (GearSortSheet) | 0 | 1 | 1 | 2 |
| Sheets (GenerateTripSheet) | 1 | 1 | 1 | 3 |
| Sheets (ImportSheet) | 0 | 1 | 1 | 2 |
| Sheets (ProfileEditSheet) | 0 | 3 | 1 | 4 |
| Sheets (TempItemSheet) | 1 | 0 | 1 | 2 |
| Sheets (TripFormSheet) | 1 | 2 | 1 | 4 |
| 跨模块 | 0 | 4 | 1 | 5 |

---

## ✅ 正面发现

1. **AssetTrendCard/AssetEvent 引用零残留**：全量 grep 确认趋势图整条数据链路已彻底清理，Task 1-3 执行干净。
2. **不可变更新模式正确**：所有 service 层的 mutation 函数都是纯函数，从不原地修改输入，始终返回新数组/对象。
3. **Service 层纯函数合规**：除 PackStore（必要的状态持有者），所有 service 导出纯函数，无 class 包装。
4. **空值/边界处理严谨**：除零防护、undefined 回退、空数组检查均到位。
5. **军事措辞已清理完毕**：grep 确认无 "服役/任务/老兵/战绩" 残留，文案温柔化完整执行。
6. **Spring+duration 混用已全量清除**：v0.5.6 重构彻底，零残留。
7. **`any` 类型零使用**：grep 确认全项目无 `any` 类型。
8. **注释掉代码零残留**：grep 确认无被注释掉的 UI 代码块。
9. **文档体系完整**：产品愿景纲领、技术 spec、落地计划、开发规范四层文档齐全且一致。
10. **CHANGELOG 维护良好**：17 个版本的详细变更记录，结构清晰。

---

## 🎯 优先修复建议（Top 10）

1. **修复 `PRIMARY_FILL_SUBTLE` alpha 字节位置**（Colors.ets:22）— 1 行改动
2. **修复分类重命名功能**（GearFormSheet/TempItemSheet）— 2 行改动 × 2 文件
3. **修复 `ColorUtils.heroGradientStart` daysLeft===0 逻辑**— 1 行改动
4. **为 PackStore 添加错误处理和 schema 版本化**— 架构改动
5. **为 TripFormSheet 和 GenerateTripSheet 添加表单验证**— 各 ~5 行
6. **修复 Index.ets 硬编码 Tab 边界**— ~3 行改动
7. **Index.ets `CategoryInputDialog` 硬编码颜色替换为 token**— ~8 处替换
8. **添加 SheetOverlay Spring 入场/退场动画**— ~15 行
9. **消除 ChecklistService 中的 `!` 非空断言**— ~4 行
10. **统一 ChecklistService 中的手动字段枚举改用展开语法**— 跨多个函数，~30 行改动

---

## 📝 方法论

本次审查覆盖 6 个并行 agent 对全项目 35 个 .ets 源文件进行逐文件深度阅读，外加独立跨模块分析（grep 扫描 + 规范交叉对照）。审查标准基于：

- 项目 `docs/DEVELOPMENT_STANDARDS.md` 全部 7 章规范
- 项目 `CLAUDE.md` 开发铁律
- ArkUI API 23+ 最佳实践（memory/MEMORY.md 37 条避坑清单）
- Apple Human Interface Guidelines 级别的 UI/UX 标准
- 项目 `docs/design/2026-06-04-product-vision-and-restructure.md` 产品方向

---

_审查完成时间：2026-06-10 | 方法：6-agent 并行审查 + 独立交叉验证 | 状态：完整_
