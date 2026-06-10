# PackCheck 架构打磨：Sheet 统一 · 下滑关闭 · GearPage 瘦身

> 三个问题的设计文档 | 第一性原理 × 用户体验标准 | 2026-06-10

---

## 0. 背景

在 2026-06-10 全项目代码审查中，发现了三个架构/交互层面的问题。它们不影响功能正确性，但每一处都在磨损用户体验的一致性和代码的可维护性。本文档以第一性原理推导每个问题的本质，定义体验目标，给出具体方案。

三个问题的共同根因：**组件边界与交互模式未经第一性原理审查，留下了"能用就行"的妥协痕迹。**

---

## 1. 问题一：bindSheet 割裂 Sheet 体系

### 1.1 背景

App 有 9 种 Sheet（新增装备、新建行程、编辑行程信息、导入装备、排序、生成行程、临时物品、编辑物品、移动分组）。前 8 种通过 `Index.ets` → `sheetMode` 状态机 → `SheetOverlay` 统一管理。唯独「移动到分组」在 GearPage 内部用 ArkUI 原生 `.bindSheet()` 自起炉灶。

**代码位置**：`GearPage.ets:1125` — 多选工具栏的「移动到分组」按钮上绑定了一个独立 Sheet。

### 1.2 第一性原理分析

**Sheet 的本质是什么？** 一个临时模态面板，从屏幕底部滑入，覆盖在主内容之上。用户对它的心理模型是物理卡片——推上来、拉下去。这个模型与 Sheet 的内容无关：无论是选排序方式还是选目标分组，都是"推上来一张卡片，做个选择，卡片退回去"。

**为什么 bindSheet 是问题？** 它不是简单的"用了不同的 API"。它意味着：
- **视觉割裂**：原生 bindSheet 使用系统默认动画曲线，不受项目 `SPRING_PANEL_ENTER/EXIT` 控制
- **空间割裂**：bindSheet 在系统层渲染，主内容不会 scale(0.94) + blur(12) 下沉——用户感知不到"卡片在我面前"的空间关系
- **交互割裂**：这个 Sheet 不能下滑关闭（系统 bindSheet 的 dragBar 只是指示器，不是完整手势），而其他 Sheet 在本次修复后都将支持下滑关闭

**第一性结论**：Sheet 是一个统一的交互范式，不是 9 种不同的东西。体系内的例外是设计债务，不是合理选择。

### 1.3 期望目标

- 所有 9 种 Sheet 走同一条路径：`sheetMode` 枚举 → `SheetOverlay` 容器 → Spring 弹入/收回
- 背景景深效果一致：scale(0.94) + blur(12)
- 下滑关闭手势对所有 Sheet 生效
- 移除 GearPage 内部的 `showMoveGroupSheet` 状态和 `MoveGroupSheetContent()` Builder

### 1.4 方案

**Step 1**：在 `SheetMode.ets` 新增 `SHEET_MOVE_GROUP`

**Step 2**：新建 `sheets/MoveGroupSheet.ets` 组件，接收 `categories: string[]` + `onSelectGroup: (group: string) => void`。内容：分组列表，每行带 `getGroupColor()` 色条 + 分组名 + 装备数量。

**Step 3**：在 `SheetOverlay.ets` 的 `build()` if-else 链中添加 `SHEET_MOVE_GROUP` 分支，渲染 `MoveGroupSheet`。在 `sheetTitle()` 中添加 `'移动到分组'` 标题。

**Step 4**：在 `Index.ets` 中：
- 新增 `openMoveGroupSheet()` 方法
- 在 GearPage 的 callback 列表添加 `onOpenMoveGroupSheet`，由 Index 处理：设置 `sheetMode = SHEET_MOVE_GROUP` → `openSheetAnimated()`
- SheetOverlay 的 `onSelectMoveGroup` 回调中执行 `batchMoveGroup` + `closeSheet()`

**Step 5**：在 `GearPage.ets` 中：
- 多选工具栏的「移动到分组」按钮 onClick 改为 `this.onOpenMoveGroupSheet()`
- 删除 `@State showMoveGroupSheet`
- 删除 `MoveGroupSheetContent()` @Builder
- 删除 `.bindSheet(...)`

**影响范围**：GearPage.ets（删代码）、SheetOverlay.ets（加分支）、Index.ets（加回调）、新增 MoveGroupSheet.ets（~60 行）

---

## 2. 问题二：SheetOverlay 缺失下滑关闭手势 + 背景景深不足

### 2.1 背景

当前 Sheet 的关闭方式只有两种：① 点击遮罩区域 ② 点击「关闭/完成」按钮。这两种方式都要求用户**精准定位一个 UI 元素**。但底部 Sheet 的物理隐喻是"从下面推上来的卡片"——用户的本能反应是把它推回去。

另外，当前 Sheet 弹出时主内容仅 scale(0.97)，而仪式卡片和页面转场统一使用 scale(0.94) + blur(12)。这个差异不是有意为之，而是 Sheet 体系的景深参数从未被统一审查。

**代码位置**：`Index.ets:1662-1689`（openSheetAnimated/closeSheet）、`SheetOverlay.ets:105-256`（卡片结构）

### 2.2 第一性原理分析

**关闭 Sheet 的本质是什么？** 是"我做完选择了，把卡片推回去"。打开是把卡片推上来（translateY: 800 → 0），关闭理应是推下去（translateY: 0 → 800）。下滑手势就是把这个物理动作交还给用户的手指——用户向下滑，卡片跟手向下移动，松手后要么弹回去（没滑够），要么飞走（滑够了）。

这和 iOS 的 Sheet dismiss、macOS 的窗口拖动、真实桌面上推开一张纸——是同一个物理直觉。

**为什么需要下滑关闭？**
- **交互入口原则**（DEVELOPMENT_STANDARDS §2.5）：功能应该长在用户已有肌肉记忆里。下滑关闭是 iOS/Android 用户已经刻在手指里的行为，不需要教育。
- **菲茨定律**：点击一个 44vp 的关闭按钮需要精确瞄准；从屏幕任意位置向下滑是 0 瞄准成本的粗粒度手势。粗粒度手势 > 精确点击。
- **连续性**：下滑是一个连续手势，用户可以中途改变主意（滑到一半推回去）；点击是一个离散动作，不可撤销。连续 > 离散。

**为什么景深要统一到 0.94+blur(12)？**
- **空间的诚实性**：Sheet 弹出时，主内容在物理上确实"更远了"——它在卡片后面。0.97 是微缩，0.94+blur(12) 是真实的后退。用户潜意识里能感知这个差异。
- **系统一致性**：同一个 App 内，仪式卡片、页面转场、Sheet 弹出是同一个"东西出现在前面"的范式。它们应该共享同一套空间纵深参数。

### 2.3 期望目标

- 在 Sheet 卡片上向下滑动超过阈值 → Sheet 关闭
- 下滑未超过阈值 → Spring 回弹到原位
- 拖拽过程中卡片跟手（无延迟）
- 拖拽超出一定范围后有阻尼感（不会无限拉远）
- Sheet 弹出时主内容 scale(0.94) + blur(12)，与仪式卡片/页面转场一致
- 下滑手势与 Sheet 内部 Scroll 不冲突

### 2.4 方案

#### 2.4.1 手势设计

在 SheetOverlay 的卡片外层 Column 上挂载 `PanGesture`：

```
PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
```

**参数选择**（以第一性原理推导）：

| 参数 | 值 | 推导 |
|------|-----|------|
| direction | Vertical | Sheet 是垂直滑入的，关闭手势必须同向 |
| distance | 5vp | 防止点击微动手误触发；GearPage 多选拖拽已验证此值合理 |
| 拖拽跟手 | animation({ duration: 0 }) | 标准要求：拖拽中用零时长消除插值延迟 |
| 阻尼系数 | 0.3 | 标准要求：超出边界后位移 × 0.3；让卡片"变重" |
| 关闭阈值 | sheet 高度的 25%（约 150vp） | iOS 标准：卡片拖动超过 1/4 即触发关闭 |
| 回弹曲线 | SPRING_GENERAL (0.35, 0.80) | 松手回弹的标准 Spring |
| 关闭曲线 | SPRING_PANEL_EXIT (0.30, 0.88) | 复用现有 Sheet 关闭曲线 |

#### 2.4.2 Scroll 冲突处理

核心矛盾：Sheet 卡片内部的 Scroll 也需要垂直手势。解决策略：

1. `PanGesture` 放在卡片外层 Column 上，而非内层 Scroll 上
2. ArkUI 的默认手势优先级是**内层优先**——Scroll 先消费手势
3. 当 Scroll 滚动到顶部（offsetY === 0）且用户继续向下滑时，Scroll 不再消费手势，手势冒泡到外层 PanGesture
4. 对不含 Scroll 的 Sheet（如排序、生成行程），PanGesture 直接在卡片上生效

不需要特殊的 `priorityGesture` 或 `NestedScrollMode`——ArkUI 的默认行为正是我们需要的。

若实测发现某些 Sheet 的 Scroll 在顶部时仍拦截手势，给对应 Scroll 添加 `.edgeEffect(EdgeEffect.None)`（顶部无回弹 = 手势透传）。

#### 2.4.3 实现细节

在 `SheetOverlay.ets` 中：

```typescript
// 新增状态
@State private sheetDragOffset: number = 0;

// 卡片 Column 上叠加 dragOffset
Column({ space: 14 }) {
  // ... 现有 header + content ...
}
.translate({ y: this.sheetTranslateY + this.sheetDragOffset })
.gesture(
  PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
    .onActionUpdate((event: GestureEvent) => {
      if (event.offsetY > 0) {
        this.sheetDragOffset = event.offsetY * 0.3; // 阻尼
      }
    })
    .onActionEnd((event: GestureEvent) => {
      if (this.sheetDragOffset > this.cardHeight * 0.25) {
        this.sheetDragOffset = 0;
        this.onClose();
      } else {
        this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
          this.sheetDragOffset = 0;
        });
      }
    })
)
```

`cardHeight` 通过 `onAreaChange` 在卡片 Column 上捕获实际高度。

#### 2.4.4 背景景深统一

在 `Index.ets` 的 `openSheetAnimated()` 中：

```diff
- this.contentScale = 0.97;
+ this.contentScale = 0.94;
+ this.contentBlur = 12;
```

在 `closeSheet()` 中：

```diff
- this.contentScale = 1.0;
+ this.contentScale = 1.0;
+ this.contentBlur = 0;
```

**影响范围**：SheetOverlay.ets（手势 + 状态）、Index.ets（景深参数 4 行改动）

---

## 3. 问题三：GearPage 职责过重（26 props / 27 @State）

### 3.1 背景

`GearPage.ets` 是装备库 Tab 的页面组件，目前 2310 行，承担了 8 个独立子系统：

1. 搜索/筛选/排序 Header
2. 装备列表（分组折叠、卡片渲染）
3. 装备行手势（左滑删除、按压反馈）
4. 多选模式 + 批量操作工具栏
5. 分组拖拽重排序
6. 装备拖拽到行程托盘
7. FAB 浮动按钮（拖拽定位 + 吸附边缘）
8. 重量编辑器弹窗

规范要求组件 props ≤ 8，当前 26；@State ≤ 10，当前 27。这是代码审查中最严重的架构违规。

### 3.2 第一性原理分析

**组件的本质是什么？** 组件是**职责的边界**。一个组件应该只做一件事——不是"一个页面"，是"一个职责"。GearPage 目前是 8 件事捆在一起：搜索栏的状态变化（展开/收起）会触发整个 2310 行组件树的重评估，包括拖拽状态、FAB 位置、列表渲染。

**为什么 props 多是有问题的？**
- 不是数字问题，是**耦合**问题。每一个 @Prop 都是从父组件伸进来的一根线。26 根线意味着 GearPage 和 Index.ets 高度纠缠——Index 需要知道 GearPage 的搜索关键词、排序方式、多选模式、展开项、滑动重置信号……
- 如果这些状态属于"装备库页面"的内部逻辑（比如搜索关键词只影响装备过滤），它们就不应该由 Index.ets 持有。Index.ets 应该只知道"装备列表"和"当前 Tab"，其他的都是 GearPage 自己的事。

**合理的目标不是恰好 8 个 props，而是让每个 prop 都有不可替代的理由。**

### 3.3 期望目标

- 核心数据 props ≤ 8（gears, categories, selectedGearCategories, gearSortMode, expandedGearId, targetWeightGram, checklists, multiSelectContext）
- 核心回调 ≤ 8（CRUD 操作：增/改/删装备、展开、切换多选、搜索）
- @State ≤ 15（从 27 降到 ~15，把独立子系统抽走）
- 删除无用 prop `gearBudget`

### 3.4 方案

采用**渐进式瘦身**——只抽取职责边界清晰、无副作用、可独立验证的子系统。一次性全拆风险高，且容易过度工程化。

#### 3.4.1 立即删除：`gearBudget` prop

GearPage 声明了 `@Prop gearBudget: number = 0`，但 Index.ets 从未传入此 prop。整个组件内也没有任何逻辑读取它。纯死代码，直接删除。

**减少**：1 @Prop

#### 3.4.2 提取 FabController（高收益、低风险）

FAB + 重量编辑器是 GearPage 中最自包含的子系统。它有自己独立的：
- 定位状态（fabX, fabY, fabDragging）
- 编辑器状态（showWeightEditor, targetWeightInput, targetWeightError）
- 手势处理（PanGesture 拖拽 + 边缘吸附）
- 屏幕尺寸感知（onAreaChange）

这些状态与装备列表、搜索、多选完全无关。

**新组件接口**：

```typescript
@Component
struct FabController {
  @Link targetWeightGram: number;
  @Prop gearCount: number = 0;
  @Prop totalWeightGram: number = 0;
  @Prop totalPriceYuan: number = 0;
  onOpenAddGear: () => void;
}
```

**减少**：GearPage 的 @State -7（fabX, fabY, fabDragging, showWeightEditor, targetWeightInput, targetWeightError, 屏幕尺寸）

**新增 prop（GearPage → FabController）**：0（targetWeightGram 本身已是 @Link，直接透传）

#### 3.4.3 提取 DragToTripOverlay（中等收益、中等风险）

装备拖拽到行程托盘是一个模态浮层。它的激活条件是 `dragMode = true`（由 GearPage 的长按手势触发），但它自己的内部状态（拖拽坐标、碰撞检测、托盘自动滚动、磁吸动画）完全是独立的。

**新组件接口**：

```typescript
@Component
struct DragToTripOverlay {
  @Prop dragMode: boolean = false;
  @Prop dragStartX: number = 0;
  @Prop dragStartY: number = 0;
  @Prop dragGearCount: number = 0;
  @Prop checklists: TripChecklist[] = [];
  @Prop selectedMultiGearIds: string[] = [];
  onAddGearsToTrip: (gearIds: string[], tripId: string) => void;
  onAddGearsToNewTrip: (gearIds: string[]) => void;
  onCancelDrag: () => void;
}
```

**关键设计决策**：`dragMode` 保留在 GearPage（因为 GearPage 需要在 build 中根据 `dragMode` 改变列表项的不透明度）。但 `dragX`, `dragY`, `dragOverTripId`, `showTripTray`, `tripCardAreas` 和自动滚动逻辑全部移入 DragToTripOverlay。

**减少**：GearPage 的 @State -5（dragX, dragY, dragOverTripId, showTripTray + 内部碰撞状态），回调 -2（onAddGearsToTrip, onAddGearsToNewTrip 移入子组件）

#### 3.4.4 提取 GroupDragController（中等收益、中等风险）

分组拖拽重排序是另一个条件激活的模态子系统（`groupDragMode = true`）。它的内部状态（拖拽分组、Y 坐标、偏移量、重排列表）只有在拖拽激活时才有意义。

**新组件接口**：

```typescript
@Component
struct GroupDragController {
  @Prop groupDragMode: boolean = false;
  @Prop dragGroupName: string = '';
  @Prop dragGroupCount: number = 0;
  @Prop dragStartY: number = 0;
  @Prop groupOrder: string[] = [];
  @Prop groupCardHeights: Map<string, number> = new Map();
  onReorderComplete: (newOrder: string[]) => void;
}
```

**减少**：GearPage 的 @State -6（groupDragGroup, groupDragY, groupDragOffsetY, groupReorderList + 内部状态）

#### 3.4.5 瘦身汇总

| 操作 | @State 减少 | @Prop 减少 | 回调减少 |
|------|------------|-----------|---------|
| 删除 gearBudget | - | 1 | - |
| FabController | 7 | - | - |
| DragToTripOverlay | 5 | - | - |
| GroupDragController | 6 | - | - |
| 统一 bindSheet | 1 | - | 1 |
| **合计** | **19** | **2** | **1** |

**瘦身后**：

- @Prop：10 → 8（删除 gearBudget、checklists 移入 DragToTripOverlay）
- 回调：16 → 15（删除 onBatchMoveGroup）
- @State：27 → 12
- 新增文件：3 个（`components/gear/FabController.ets`, `DragToTripOverlay.ets`, `GroupDragController.ets`）

### 3.5 新增文件结构

```
entry/src/main/ets/components/
├── gear/                          # 新增：装备库子组件目录
│   ├── FabController.ets          # FAB + 重量编辑器
│   ├── DragToTripOverlay.ets      # 拖拽装备到行程托盘
│   └── GroupDragController.ets    # 分组长按拖拽排序
└── sheets/
    └── MoveGroupSheet.ets         # 新增：移动分组 Sheet 内容
```

---

## 4. 实施顺序

三个问题有依赖关系，建议按以下顺序执行：

```
Task A: MoveGroupSheet 提取 + SHEET_MOVE_GROUP 常量            (问题一 Step 1-2)
Task B: SheetOverlay 添加 SHEET_MOVE_GROUP 分支 + sheetTitle   (问题一 Step 3)
Task C: Index.ets 接入 + GearPage 删除 bindSheet               (问题一 Step 4-5)
Task D: Index.ets 景深参数统一 (0.94+blur)                     (问题二 Part A)
Task E: SheetOverlay 下滑关闭手势                              (问题二 Part B)
Task F: 删除 gearBudget                                      (问题三 Step 1)
Task G: 提取 FabController                                    (问题三 Step 2)
Task H: 提取 DragToTripOverlay                                (问题三 Step 3)
Task I: 提取 GroupDragController                              (问题三 Step 4)
```

每步构建验证，每步 commit。Task A-C 是一个原子单元（Sheet 统一），Task D-E 是第二个（交互打磨），Task F-I 是第三个（组件瘦身），各自独立。

---

## 5. 验证标准

### 功能验证
- [ ] 多选装备 → 移动分组 → Sheet 从底部 Spring 弹入 → 选择分组 → 装备移动 → Sheet 关闭
- [ ] 所有 9 种 Sheet 的下滑关闭手势正常工作
- [ ] 有 Scroll 内容的 Sheet（如编辑装备）滚动到顶部后下滑关闭，未到顶部时下滑滚动内容
- [ ] FAB 拖拽、吸附边缘、重量编辑器正常
- [ ] 装备拖拽到托盘、分组拖拽重排序正常
- [ ] 装备列表的搜索、筛选、排序、分组折叠、展开详情均正常

### 体验验证
- [ ] Sheet 弹出时主内容 scale(0.94) + blur(12)，视觉上与仪式卡片转场一致
- [ ] 下滑 Sheet 时卡片贴手（无延迟），松手回弹自然（Spring）
- [ ] 下滑超过 25% 松开 → 卡片加速飞出
- [ ] 下滑不足 25% 松开 → 卡片弹回原位
- [ ] 构建通过：`hvigorw assembleApp`

---

## 6. 风险与边界

- **DragToTripOverlay 提取**：拖拽过程中 GearPage 列表项的不透明度由 `dragMode` 控制——该状态保留在 GearPage，不受提取影响
- **GroupDragController 提取**：分组卡片高度的 Map 通过 prop 传入；地基层分组较少（≤15），性能可接受
- **下滑关闭阈值 25%**：若实机测试发现偏高或偏低，可调整为固定 120vp（更保守）或 200vp（更激进）。先以 25% 上线，实测后微调
- **Scroll 冲突**：若某些 Sheet 子组件的 Scroll 在顶部仍拦截手势，在该 Scroll 上加 `.edgeEffect(EdgeEffect.None)`——这是一个已知的 ArkUI 行为，一键修复
