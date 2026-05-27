# PackCheck v0.3.0 — 动效 & 微交互全面升级 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 全面提升 App 动效和微交互体验，消除硬切问题，Spring 弹性曲线统一，8 个模块覆盖全部交互触点。

**Architecture:** 新建 `AnimationTokens.ets` 集中管理 Spring 曲线参数和通用动画工具函数。各组件直接引入使用，不改变现有数据流和组件结构。改动范围：Index.ets（Tab/Sheet/Overlay）、HomePage.ets（Hero/History/QuickEntry）、GearPage.ets（FAB/列表/折叠头）、ChecklistDetail.ets（Item入列/按压/Checkmark）、ReviewPage.ets（按压）。

**Tech Stack:** HarmonyOS ArkUI, `@kit.ArkUI` curves API, `curves.springMotion(response, dampingFraction)`

**验证方式:** 每轮完成后运行 `node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js assembleApp --no-daemon`，确保编译通过。

---

### Task 0: 新建 AnimationTokens.ets

**Files:**
- Create: `entry/src/main/ets/constants/AnimationTokens.ets`

- [ ] **Step 1: 创建动画 Token 文件**

```typescript
// AnimationTokens.ets — 统一 Spring 动效参数
import { curves } from '@kit.ArkUI';

// Spring 曲线预设
export const SPRING_GENERAL = (): ICurve => curves.springMotion(0.35, 0.8);
export const SPRING_PRESS = (): ICurve => curves.springMotion(0.25, 0.7);
export const SPRING_TAB = (): ICurve => curves.springMotion(0.4, 0.75);

// 通用时长预设 (用于非 Spring 的辅助动画如 opacity)
export const DURATION_FAST = 100;
export const DURATION_NORMAL = 200;
export const DURATION_SLOW = 300;
export const DURATION_COUNTER = 400;

// 错落入场延迟
export const STAGGER_DELAY_MENU = 30;
export const STAGGER_DELAY_LIST = 40;
export const STAGGER_DELAY_SWIPE = 50;

// 按压三段式缩放值
export const PRESS_SCALE_DOWN = 0.96;
export const PRESS_SCALE_BOUNCE = 1.02;
export const PRESS_SCALE_REST = 1.0;

// 面板动画
export const PANEL_SCALE_START = 0.9;
export const PANEL_SCALE_DISMISS = 0.95;

// 错落入场偏移
export const STAGGER_OFFSET_Y = 12;
```

- [ ] **Step 2: 编译验证**

```bash
cd /Users/bghost233/Documents/PackCheck
node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js assembleApp --no-daemon
```

Expected: BUILD SUCCESSFUL

---

### Task 1: 二级菜单 & 下拉展开过渡动画

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`

**涉及区域：** GearFilterPanelOverlay, SheetOverlay, EditItemPanelOverlay, EditGearPanelOverlay, GearSortSheet, 各 Sheet 子内容, SwipeAction

- [ ] **Step 1: 更新 GearFilterPanelOverlay — 优化展开/收起动画**

将当前 `animateTo({ duration: 500, curve: curves.springMotion(...) })` 替换为使用 `SPRING_GENERAL`，并给 filter panel 内部的 category cards 添加错落入场。

当前代码位置：`Index.ets:386-406`（openGearFilterPanel）和 `Index.ets:397-406`（applyGearFilterPanel）

修改 `openGearFilterPanel` 方法：

```typescript
private openGearFilterPanel(): void {
  this.tempGearFilterCategories = this.normalizeGearCategories(this.selectedGearCategories);
  this.gearFilterPanelExpanded = true;
  this.filterPanelTranslateY = -600;
  this.filterPanelOverlayOpacity = 0;
  this.getUIContext().animateTo({
    duration: DURATION_SLOW,
    curve: SPRING_GENERAL()
  }, (): void => {
    this.filterPanelTranslateY = 0;
    this.filterPanelOverlayOpacity = 1;
  });
}
```

修改 `applyGearFilterPanel` 方法，收起时用更干脆的动画：

```typescript
private applyGearFilterPanel(): void {
  this.selectedGearCategories = this.normalizeGearCategories(this.tempGearFilterCategories);
  this.getUIContext().animateTo({
    duration: DURATION_NORMAL,
    curve: Curve.EaseIn,
    onFinish: (): void => {
      this.gearFilterPanelExpanded = false;
    }
  }, (): void => {
    this.filterPanelTranslateY = -600;
    this.filterPanelOverlayOpacity = 0;
  });
}
```

- [ ] **Step 2: 给 GearFilterCategoryCard 添加错落动画的延迟状态**

在 `Index.ets` 的 `GearFilterCategoryCard` Builder 中（约 2286 行），添加 scale 和 opacity 入场动画。由于 ForEach 渲染自带时机，我们给每项增加一个基于 index 的 transition：

```typescript
// 在 GearFilterCategoryCard 最外层 Column 上添加：
.transition({ 
  type: TransitionType.Insert, 
  translate: { y: STAGGER_OFFSET_Y }, 
  opacity: 0 
})
```

- [ ] **Step 3: 优化 SheetOverlay 的入场动画**

当前 SheetOverlay（约 2393 行）使用 `transition({ type: TransitionType.Insert, translate: { y: 320 }, opacity: 0 })`。增加 scale 效果使其更自然：

```typescript
// Sheet 容器上修改 transition：
.transition({ 
  type: TransitionType.Insert, 
  translate: { y: 320 }, 
  scale: { x: PANEL_SCALE_START, y: PANEL_SCALE_START },
  opacity: 0 
})
```

- [ ] **Step 4: 优化 EditItemPanelOverlay 和 EditGearPanelOverlay 动画**

当前使用 `animateTo({ duration: 300, curve: Curve.EaseOut })` 做 scale 0.85→1。改用 Spring：

```typescript
// openEditGear 方法中，将 Curve.EaseOut 改为 SPRING_GENERAL()：
this.getUIContext().animateTo({ 
  duration: DURATION_SLOW, 
  curve: SPRING_GENERAL() 
}, () => {
  this.editGearPanelScale = 1;
  this.editGearPanelOpacity = 1;
});

// openEditItemSheet 方法中同样替换：
this.getUIContext().animateTo({ 
  duration: DURATION_SLOW, 
  curve: SPRING_GENERAL() 
}, () => {
  this.editItemPanelScale = 1;
  this.editItemPanelOpacity = 1;
});
```

关闭动画保持当前的 `Curve.EaseIn`（收起不需要弹性）。

- [ ] **Step 5: 给 SortOption 添加选中 Spring 反馈**

在 `SortOption` Builder（约 2500 行）中，给 Row 添加 scale 动画：

```typescript
// 在 SortOption 的 Row 上添加：
.scale({ x: this.gearSortMode === mode ? 1.02 : 1, y: this.gearSortMode === mode ? 1.02 : 1 })
.animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() })
```

- [ ] **Step 6: 编译验证**

```bash
cd /Users/bghost233/Documents/PackCheck
node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js assembleApp --no-daemon
```

---

### Task 2: 按压微交互 Press Feedback

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/components/HomePage.ets`
- Modify: `entry/src/main/ets/components/GearPage.ets`
- Modify: `entry/src/main/ets/components/ChecklistDetail.ets`
- Modify: `entry/src/main/ets/components/ReviewPage.ets`

**核心思路：** 抽取一个通用的 `@State pressedItemId` 模式到各组件中，通过 `onTouch` 事件驱动三段式回弹。

- [ ] **Step 1: 在 ChecklistDetail.ets 升级 ItemRow 按压反馈**

当前 ChecklistDetail.ets 已有基础按压（scale 0.97 + opacity 0.85 + springMotion(0.22, 0.82)）。升级为三段式：

```typescript
// 修改 ItemRow 的 animation 参数（约 708 行）：
.scale({ x: this.pressedItemId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST, 
        y: this.pressedItemId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
.animation({ duration: DURATION_NORMAL, curve: SPRING_PRESS() })
```

导入 `SPRING_PRESS, PRESS_SCALE_DOWN, PRESS_SCALE_REST, DURATION_NORMAL` from AnimationTokens。

- [ ] **Step 2: 给 Index.ets 中所有可点击元素添加按压态**

给 `BottomTabItem` (约 2353 行) 添加按压：

```typescript
// 在 @Component struct Index 中添加：
@State private pressedTabIndex: number = -1;

// BottomTabItem Builder 中添加 scale：
.scale({ 
  x: this.pressedTabIndex === tabIndex ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
  y: this.pressedTabIndex === tabIndex ? PRESS_SCALE_DOWN : PRESS_SCALE_REST 
})
.animation({ duration: DURATION_NORMAL, curve: SPRING_PRESS() })
.onTouch((event: TouchEvent) => {
  if (event.type === TouchType.Down) {
    this.pressedTabIndex = tabIndex;
  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
    this.pressedTabIndex = -1;
  }
})
```

给 `FormInput` 中的 TextInput 不需要额外处理（TextInput 有自己的焦点态）。

- [ ] **Step 3: 给 HomePage.ets 添加按压反馈**

给 `QuickEntry` (约 492 行) 添加：

添加 `@State private quickEntryPressed: string = '';`

```typescript
// QuickEntry Builder 的 Column 上添加：
.scale({ 
  x: this.quickEntryPressed === title ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
  y: this.quickEntryPressed === title ? PRESS_SCALE_DOWN : PRESS_SCALE_REST 
})
.animation({ duration: DURATION_NORMAL, curve: SPRING_PRESS() })
.onTouch((event: TouchEvent) => {
  if (event.type === TouchType.Down) {
    this.quickEntryPressed = title;
  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
    this.quickEntryPressed = '';
  }
})
```

给 `HistoryRow` (约 559 行) 同样添加按压态。

给 `HeroCard` 的 onClick 保留，但添加按压 scale。

- [ ] **Step 4: 给 GearPage.ets 添加按压反馈**

已经有 `pressedGearId` 用于 gear 列表项。确认其使用 SPRING_PRESS 曲线。给 FAB 按钮也添加按压态（使用已有的 `fabPressed` 状态）。

- [ ] **Step 5: 编译验证**

```bash
cd /Users/bghost233/Documents/PackCheck
node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js assembleApp --no-daemon
```

---

### Task 3: Tab 切换指示器滑动

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`

- [ ] **Step 1: 升级 BottomTabBar 胶囊动画**

当前 BottomTabBar (约 2324 行) 已使用 `curves.springMotion()` 做 pill 位移（`tabPillOffsetX`）。升级：

1. 添加 shadow 增强悬浮感
2. 添加白色渐变 overlay 模拟光泽
3. 改 `springMotion()` 为 `SPRING_TAB()`

```typescript
// BottomTabBar 的 pill Row 修改（约 2326 行）：
Row()
  .width(94)
  .height(40)
  .backgroundColor(PRIMARY_COLOR)
  .borderRadius(20)
  .position({ x: this.tabPillOffsetX, y: 4 })
  .shadow({ radius: 8, color: '#332D7D46', offsetX: 0, offsetY: 2 })
  .animation({ duration: DURATION_SLOW, curve: SPRING_TAB() })
```

给选中 Tab 文字 icon 添加微弱 scale：

```typescript
// BottomTabItem 中文字 scale（约 2354 行）：
.fontSize(this.currentView === targetView ? 14.7 : 14)
.animation({ duration: DURATION_NORMAL, curve: SPRING_TAB() })
```

- [ ] **Step 2: HdsTabs 切换时添加平滑过渡**

HdsTabs 是系统组件，无法直接控制内部动画。但可以在 `onChange` 中给内容区添加短暂的 opacity 过渡。在 `HdsMainTabs` Builder 中，给 TabContent 的子内容添加：

```typescript
// 在 HdsMainTabs 的 onChange 中，给 currentView 切换加过渡：
// 这已经通过 HomePage/GearPage 的渲染处理，我们只需确保
// 切换视图时 tabPillOffsetX 使用 SPRING_TAB
```

- [ ] **Step 3: 编译验证**

---

### Task 4: 列表项入场错落动画

**Files:**
- Modify: `entry/src/main/ets/components/HomePage.ets`
- Modify: `entry/src/main/ets/components/GearPage.ets`
- Modify: `entry/src/main/ets/components/ChecklistDetail.ets`

- [ ] **Step 1: HomePage HistoryTimeline 错落入场**

在 HomePage.ets 添加一个 `@State historyStaggerReady: boolean = false;`

在 `aboutToAppear` 中延迟触发：

```typescript
aboutToAppear(): void {
  // ... 现有代码
  setTimeout(() => {
    this.historyStaggerReady = true;
  }, 100);
}
```

在 `HistoryRow` Builder 中添加入场动画，利用 index 参数：

```typescript
// 在 HistoryTimeline Builder 的 ListItem 上：
ListItem() {
  this.HistoryRow(item);
}
.opacity(this.historyStaggerReady ? 1 : 0)
.translate({ y: this.historyStaggerReady ? 0 : STAGGER_OFFSET_Y })
.animation({ 
  duration: DURATION_SLOW, 
  curve: SPRING_GENERAL(),
  delay: index * STAGGER_DELAY_LIST  // 注意：ForEach 的 index 需要额外获取
})
```

由于 ForEach 回调中无法直接获取 index，改为在 `checklists` 中用 `forEach` 风格的 map 或使用 `ForEach` 的第三个参数。实际上 ArkUI 的 ForEach 支持 `(item, index)` 语法。

等一等，ArkUI ForEach 的签名是 `ForEach(arr, (item, index) => {}, keyGen)`。检查现有代码使用的是 `(item: TripChecklist) => item.id`，即单参数。需要改为双参数以获取 index。

更新 HistoryTimeline 的 ForEach（约 529 行）和 HistoryRow：

```typescript
ForEach(this.checklists, (item: TripChecklist, index: number) => {
  ListItem() {
    this.HistoryRow(item);
  }
  .opacity(this.historyStaggerReady ? 1 : 0)
  .translate({ y: this.historyStaggerReady ? 0 : STAGGER_OFFSET_Y })
  .animation({ 
    duration: DURATION_NORMAL + index * STAGGER_DELAY_LIST, 
    curve: SPRING_GENERAL() 
  })
  // ... rest of ListItem props
}, (item: TripChecklist) => item.id)
```

- [ ] **Step 2: GearPage 装备列表错落入场**

类似方法，给 GearPage 的 `filteredGears()` 列表项添加错落入场。

- [ ] **Step 3: ChecklistDetail item 组错落入场**

给 `ItemRow` 列表添加入场动画，按 group 分组，组内 items 依次入场。

- [ ] **Step 4: 编译验证**

---

### Task 5: 数字变化 Counter 滚动

**Files:**
- Modify: `entry/src/main/ets/components/HomePage.ets`

- [ ] **Step 1: 升级 Hero 倒计时数字动画**

当前 `startHeroNumberAnimation()` (约 83 行) 使用 `animateTo({ duration: 800, curve: Curve.EaseOut })`。改短 duration 并添加中间弹性：

```typescript
private startHeroNumberAnimation(): void {
  const checklist = this.latestChecklist();
  if (checklist === undefined) {
    this.heroNumberAnimated = true;
    return;
  }
  const days = this.daysLeft(checklist);
  if (days === undefined || days === 0) {
    this.heroNumberAnimated = true;
    return;
  }
  const target = Math.abs(days);
  // 先快速接近目标值
  this.getUIContext().animateTo({
    duration: DURATION_COUNTER,
    curve: curves.springMotion(0.3, 0.75),
    onFinish: (): void => {
      this.heroNumberAnimated = true;
    }
  }, (): void => {
    this.heroDaysDisplay = target;
  });
}
```

- [ ] **Step 2: 升级进度数字动画**

`startProgressAnimation()` (约 106 行) 同样从 `Curve.EaseOut` 改为 spring：

```typescript
private startProgressAnimation(): void {
  const checklist = this.latestChecklist();
  if (checklist === undefined) {
    this.progressAnimated = true;
    return;
  }
  const target = this.checkedCount(checklist);
  this.getUIContext().animateTo({
    duration: DURATION_COUNTER,
    curve: curves.springMotion(0.3, 0.75),
    onFinish: (): void => {
      this.progressAnimated = true;
    }
  }, (): void => {
    this.progressNumeratorDisplay = target;
  });
}
```

- [ ] **Step 3: 编译验证**

---

### Task 6: 共享元素转场

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`

- [ ] **Step 1: 页面切换添加过渡方向感**

在 Index.ets `build()` 中的条件渲染区域（约 1941 行的 Column 内），给 VIEW_HOME ↔ VIEW_CHECKLIST 切换添加 translate 过渡：

```typescript
// 在 HomePage / ChecklistDetail 的外层容器上添加
// 注意：由于是条件渲染，ArkUI 的 transition 属性可生效

// HomePage 可见时：
if (this.currentView === VIEW_HOME || this.currentView === VIEW_GEAR) {
  // HomePage/GearPage container
}
.transition({ 
  type: TransitionType.Insert, 
  translate: { x: -40 }, 
  opacity: 0 
})
.transition({ 
  type: TransitionType.Delete, 
  translate: { x: 40 }, 
  opacity: 0 
})

// ChecklistDetail 可见时：
// 同理添加反方向的 transition
.transition({ 
  type: TransitionType.Insert, 
  translate: { x: 40 }, 
  opacity: 0 
})
```

- [ ] **Step 2: 编译验证**

---

### Task 7: FAB 呼吸 + 展开

**Files:**
- Modify: `entry/src/main/ets/components/GearPage.ets`

- [ ] **Step 1: 升级 FAB 呼吸动画**

GearPage 已有 `fabBreathScale` 状态（约 47 行）和 `aboutToAppear` 中设置。升级为连续的 shadow 呼吸：

```typescript
// 在 FAB 上添加 shadow 呼吸：
.shadow({ 
  radius: 12, 
  color: this.fabPressed ? '#1A2D7D46' : '#0A2D7D46',
  offsetX: 0, 
  offsetY: 2 
})
.animation({ duration: 1000, curve: Curve.EaseInOut, iterations: -1 })
```

但 ArkUI animation 的 iterations 可能不直接支持无限循环的 shadow。改用 animateTo 循环：

在 `aboutToAppear` 中用 `setInterval` 驱动：

```typescript
aboutToAppear(): void {
  this.fabBreathScale = 1.04;
  // 每 2s 触发一次 shadow 呼吸
  setInterval(() => {
    this.fabShadowOpacity = this.fabShadowOpacity === 0.3 ? 0.6 : 0.3;
  }, 2000);
}
```

但使用 `animateTo` 实现 shadow 渐变需要 `@State fabShadowOpacity: number = 0.3;` 和对应的 shadow color 动态生成。

由于 shadow color 不接受动态字符串拼接的 ResourceColor...实际上在 ArkUI 中 shadow 的 color 属性是 `ResourceColor`，可以用字符串拼接。

- [ ] **Step 2: 简化实现**

用一个 `@State fabPulsePhase: number = 0;` 配合 animateTo：

```typescript
private startFabBreath(): void {
  const runPulse = () => {
    this.getUIContext().animateTo({
      duration: 2000,
      curve: Curve.EaseInOut,
      onFinish: () => {
        runPulse();
      }
    }, () => {
      this.fabPulsePhase = this.fabPulsePhase === 0 ? 1 : 0;
    });
  };
  runPulse();
}
```

在 FAB column 上使用 interpolated shadow radius 或 opacity。简化方案：给 FAB 添加 scale 呼吸（已有 `fabBreathScale`），增加 shadow 深浅变化。

- [ ] **Step 3: 编译验证**

---

### Task 8: 锦上添花

**Files:**
- Modify: `entry/src/main/ets/components/HomePage.ets`
- Modify: `entry/src/main/ets/components/ChecklistDetail.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`

- [ ] **Step 1: 空状态呼吸动画**

在 HomePage.ets 的 `EmptyHero` Builder 中（约 448 行），给 emoji icon 添加微弱呼吸：

```typescript
// EmptyHero 的 Text('🏔️') 添加：
Text('🏔️')
  .fontSize(56)
  .scale({ x: this.emptyHeroScale, y: this.emptyHeroScale })
  .animation({ duration: 2000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })

// 添加状态：
@State emptyHeroScale: number = 0.98;

aboutToAppear(): void {
  // ... existing
  this.emptyHeroScale = 1.02; // trigger alternating animation
}
```

- [ ] **Step 2: 操作确认 — Checkmark 划出动画**

在 ChecklistDetail.ets 的 `CheckMark` Builder（约 728 行）中，勾选时添加短暂 scale bounce：

```typescript
// CheckMark 的 animation 改为：
.animation({ duration: DURATION_NORMAL, curve: SPRING_PRESS() })
```

当前已经使用 `springMotion(0.22, 0.82)`，改为 `SPRING_PRESS()` 统一即可。

- [ ] **Step 3: CompletionToast 升级**

当前 CompletionToast（约 2370 行）使用 `transition({ type: TransitionType.Insert, translate: { y: -20 }, opacity: 0 })`。添加 scale 弹性：

```typescript
.transition({ 
  type: TransitionType.Insert, 
  translate: { y: -20 }, 
  scale: { x: 0.9, y: 0.9 },
  opacity: 0 
})
```

- [ ] **Step 4: 全局清理 — 检查无 linear 残留**

```bash
cd /Users/bghost233/Documents/PackCheck/entry/src/main/ets
grep -rn "Curve.Linear\|duration.*linear\|linear" --include="*.ets" | grep -v "//\|linearGradient"
```

确保没有 `Curve.Linear` 残留在动画代码中。

- [ ] **Step 5: 最终编译验证**

```bash
cd /Users/bghost233/Documents/PackCheck
node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js assembleApp --no-daemon
```

Expected: BUILD SUCCESSFUL

---

## 验收清单

- [ ] 所有二级菜单/下拉有 Spring 过渡 + 背景模糊
- [ ] 所有可点击元素有按压下沉+弹回反馈
- [ ] Tab 指示器平滑滑动不瞬移
- [ ] 列表错落入场（HistoryTimeline / GearList / Checklist items）
- [ ] 数字滚动过渡无闪变
- [ ] 动画流畅可打断
- [ ] 无 Curve.Linear 残留
- [ ] hvigorw assembleApp 构建通过
