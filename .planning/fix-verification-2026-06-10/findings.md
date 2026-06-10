# PackCheck 修复验证报告 & 补充审查

> 验证日期：2026-06-10 | 针对 commit `09e6250` 的修复验证  
> 上一轮报告：35 findings (7 Critical, 20 Medium, 8 Low)

---

## 修复验证：逐项核实

### Critical 修复（7 项）

| # | 问题 | 状态 | 验证 |
|---|------|------|------|
| CR-1 | @State 数组原地修改 ×7 | ❌ **未修复** | GearPage.ets:585-586 `/splice/` 仍存在；:2187-2200 仍直接 splice。WeightGauge.ets:256-268 `const indices = this.pillEntranceIndices` 仍取同引用后赋回。**这是上一轮最重要的 bug，必须修复** |
| CR-2 | DesignTokens barrel 缺 token | ✅ 已修复 | 12 个 Zone/Layer token + 7 个 ZONE_*_TINT 已添加 re-export |
| CR-3 | tabsController 反同步 | ✅ 已修复 | Index.ets 新增 `this.tabsController.changeIndex(1)` |
| CR-4 | onActionViewDetail 动画竞争 | ✅ 已修复 | Sheet exit → onFinish → Nav pop 完整序列化 |
| CR-5 | Spring+duration 混用 ~22 处 | ✅ 已修复 | ChecklistDetail(3x)、LoadoutView(12x)、TripDetailPage(7x) 全部移除 `duration:` |
| CR-6 | ChecklistDetail 按压反馈缺失 | ✅ 已修复 | 新增 4 个 @State + onTouch handler（MiniAction/backPressed/Group/Chip） |
| CR-7 | GearSortSheet 三段式按压 | ✅ 已修复 | 新增 `PRESS_SCALE_BOUNCE` 阶段 + `__bounce_` sentinel |

### Medium 修复（20 项）

| 已修复 | 问题 |
|--------|------|
| ✅ | LoadoutProgressBar 并发 counter 动画 → 新增 `counterTimerId` 取消机制 |
| ✅ | LoadoutProgressBar 死 import CURVE_DECELERATE → 已删除 |
| ✅ | LoadoutView FAB shadow 硬编码 `'#33000000'` → `OVERLAY_DIM` |
| ✅ | LoadoutView `animateTo` → `this.getUIContext().animateTo()` |
| ✅ | LoadoutZoneCard 硬编码 `'#78909C'` → `ZONE_MISC_COLOR` |
| ✅ | LoadoutZoneCard ForEach key → `item.id + '_' + checked` |
| ✅ | TripDetailPage `...` 菜单仅单选项 → `bindMenu` 三选项（编辑/核查/删除） |
| ✅ | TripDetailPage `...` 菜单无按压 → 新增 `menuScale` |
| ✅ | TripDetailPage 共享信息区不可点 → 新增 tap 编辑入口 + `infoScale` 按压 |
| ✅ | TripDetailPage `'transparent'` → `TRANSPARENT` |
| ✅ | TripDetailPage `'#0D000000'` → `SHADOW_MICRO` |
| ✅ | GearPickerSheet `'#33'` 拼接 → 新增 7 个 `ZONE_*_TINT` token |
| ✅ | GearPickerSheet `closeTempOverlay` 动画曲线 → 保持 SPRING_PRESS（原审查建议 SPRING_PANEL_EXIT，可接受） |

| 未修复 | 问题 | 影响 |
|--------|------|------|
| ❌ | GearPage.ets @Prop count 9 > 8 | 架构违规 |
| ❌ | GearPage.ets CURVE_DECELERATE 5 处 | 非 Spring 曲线 |
| ❌ | HomePage.ets `'F8F9FA'` 硬编码 + CURVE_DECELERATE | 历史遗留 |
| ❌ | ProfilePage.ets ForEach 缺 key + 死按压状态 | 列表渲染风险 |
| ❌ | TripCeremonyCard.ets 硬编码 hex + setTimeout | 大量历史债务 |
| ❌ | GearItemActionSheet 全行无按压反馈 | 交互粗糙 |
| ❌ | MoveGroupSheet 全行无按压反馈 | 交互粗糙 |
| ❌ | SheetOverlay header 按钮无按压 | 交互粗糙 |

---

## 🆕 补充审查：修复引入的新问题

### NEW-1. GearSortSheet 按压使用了 setTimeout 做 bounce 延时

**文件**：`GearSortSheet.ets:66-73`

```typescript
setTimeout(() => {
  this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
    this.pressedOption = '';
  });
}, 80);
```

三段式按压的 bounce→rest 过渡通过 `setTimeout(80ms)` 实现。80ms 硬编码不与任何 AnimationTokens 时长对齐。bounce 阶段使用 `SPRING_PRESS()`（response 0.25, damping 0.7），该 spring 的 settle 时间约为 ~200ms，但 setTimeout 仅等 80ms 就触发 rest——rest 动画会在 bounce 还没完成时就开始，视觉上产生跳变。

**修复**：用 `animateTo({ onFinish: ... })` 替代 setTimeout 延时：
```typescript
this.getUIContext().animateTo({ curve: SPRING_PRESS(), onFinish: () => {
  this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
    this.pressedOption = '';
  });
}}, () => { this.pressedOption = '__bounce_' + mode; });
```

### NEW-2. TripDetailPage `bindMenu` 的 `onDisappear` 回调未重置 `showMoreMenu`

**文件**：`TripDetailPage.ets:202`

```typescript
.bindMenu(this.showMoreMenu, [...], {
  onDisappear: () => { this.showMoreMenu = false; }
})
```

`onDisappear` 在菜单**消失后**才触发。在菜单显示期间，如果因为其他原因（如系统返回手势、Sheet 弹出）导致组件被销毁，`showMoreMenu` 没有机会被清理——但这不是严重的 bug，因为 `@State` 随组件销毁而释放。不过如果用户快速操作（打开菜单→立刻关闭→再打开），`showMoreMenu` 在 `onDisappear` 之前就被重置，可能导致第二次打开时的时序问题。**实际影响极低**，仅作记录。

### NEW-3. TripDetailPage 新增 `onDeleteTrip` callback 未在 Index.ets 中接线

**文件**：`TripDetailPage.ets:53`

新增了 `onDeleteTrip: () => void = () => {}` 回调，但 `Index.ets:1866-1875` 的 TripDetailPage 实例化中**未传入**此回调。用户点击 `···` →「删除行程」会触发空回调，什么都不会发生。

**修复**：在 `Index.ets` 的 TripDetailPage 实例化中添加：
```typescript
onDeleteTrip: () => { this.confirmDeleteChecklist(); }
```

### NEW-4. TripDetailPage 共享信息区按压缩放值 0.97 非标准

**文件**：`TripDetailPage.ets:228`

```typescript
this.infoScale = 0.97; // ← 应使用 PRESS_SCALE_DOWN (0.96)
```

与 TripDetailPage 返回按钮使用 `0.9` 一样，0.97 不是项目标准的 `PRESS_SCALE_DOWN`(0.96)。虽然差异仅 0.01，但规范应统一。

---

## 🔴 仍然存在的 Critical Bug（必须修复）

### GearPage.ets — 4 处 @State 数组原地修改

| 行号 | 代码 | 问题 |
|------|------|------|
| 585-587 | `const next = this.collapsedGearGroups; next.splice(idx, 1); this.collapsedGearGroups = next;` | splice 同引用，不触发重渲染 |
| 2187-2188 | `this.groupReorderList.splice(...)` | 直接修改 @State 数组 |
| 2199-2200 | `this.groupReorderList.splice(...)` | 同上 |

**修复**：
```typescript
// 585-587 → 
const next = [...this.collapsedGearGroups];
next.splice(idx, 1);
this.collapsedGearGroups = next;

// 2187-2188 → 
const next = [...this.groupReorderList];
next.splice(currentIdx, 1);
next.splice(i, 0, this.groupDragGroup);
this.groupReorderList = next;
```

### WeightGauge.ets — 3 处 @State 数组原地修改

| 行号 | 代码 | 问题 |
|------|------|------|
| 256-258 | `const indices = this.pillEntranceIndices; indices[0] = true; this.pillEntranceIndices = indices;` | 同引用 |
| 260-262 | 同上 pattern | 同引用 |
| 264-266 | 同上 pattern | 同引用 |

**修复**：
```typescript
const indices = [...this.pillEntranceIndices];
indices[0] = true;
this.pillEntranceIndices = indices;
```

---

## ✅ 优雅实现值得肯定的地方

1. **`onActionViewDetail` 动画序列化**（Index.ets:2355-2383）——将 Sheet 关闭 → Nav pop → Tab 切换串行化，用 `onFinish` 回调链保证动画不竞争。这是正确的实现方式。

2. **Zone 颜色半透明 token 体系**（Colors.ets:93-100）——为每个 Zone 定义了 `ZONE_*_TINT` token（20% opacity），替代了之前脆弱的字符串拼接。设计干净。

3. **`bindMenu` 三选项**（TripDetailPage.ets:199-203）——用原生 ContextMenu 实现 `···` 菜单，比自定义 Sheet 更轻量且符合系统交互规范。

4. **`counterTimerId` 并发防护**（LoadoutProgressBar.ets:104-107）——用 `clearInterval` 取消上一轮动画再启动新轮，解决了计数器数字抖动问题。

5. **ForEach key 含 checked 状态**（LoadoutZoneCard.ets:97, 132）——`item.id + '_' + (item.checked ? '1' : '0')` 确保勾选变化时 ArkUI 正确识别需要重渲染的行。

---

## 📊 总结

| 类别 | 已修复 | 未修复 | 新增 |
|------|--------|--------|------|
| Critical | 6/7 | 1 (7 处数组 mutation) | 0 |
| Medium | 13/20 | 7 (历史遗留) | 0 |
| Low | 大部分 | 部分 | 4 |

**核心结论**：修复质量**良好**——22 处 Spring+duration 清理干净、按压反馈补全、token 体系完善、动画序列化正确。但 **GearPage 和 WeightGauge 的 7 处 @State 数组原地修改未被修复**——这是上一轮最重要的 bug，会导致分组折叠/拖拽排序/仪表动画在真机上不刷新。此外 TripDetailPage 的 `onDeleteTrip` 未接线会导致删除功能无响应。
