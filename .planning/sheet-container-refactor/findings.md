# SheetContainer 重构 — 研究发现

## 1. 当前体系定量分析

### 1.1 SheetOverlay.ets 结构（382 行）

| 区域 | 行数 | 内容 |
|------|------|------|
| import | 42 | 引入 10 个子 Sheet + 常量 + model |
| @Prop 声明区 | 95 | 40 个 @Prop + 20 个回调声明 |
| build() | 195 | 标题栏 + if/else 路由 + 手势 |
| sheetTitle() | 40 | 按 sheetMode 返回中文标题 |
| @State private | 10 | sheetDragOffset + cardHeight |

### 1.2 Index.ets 关联区域

| 区域 | 行数 | 内容 |
|------|------|------|
| private 代理变量声明 | 32 | 为 Sheet 传参准备的临时变量 |
| reset 方法 | 32 | resetGearForm/resetTripForm/resetDayForm/resetSegForm |
| open 方法 | ~80 | 15 个 openXxx 方法，设置代理变量 + sheetMode |
| SheetOverlay 传参 | 138 | `SheetOverlay({ prop: value, ... })` 调用 |
| **总计 Sheet 相关代码** | **~282** | 占 Index.ets 总行数 2260 的 12.5% |

### 1.3 子 Sheet 组件一览

| 组件 | 接收的 @Prop | 接收的回调 | 备注 |
|------|-------------|-----------|------|
| GearFormSheet | 7 (editingGearId, categories, initial×5) | 5 (onSave, onRename, onDelete, onReorder, onAddCategory) | 与 TempItemSheet 共享 category 回调 |
| TripFormSheet | 8 (isEditMode, initial×7) | 1 (onConfirm) | 新建/编辑共用，isEditMode 控制 |
| ProfileEditSheet | 6 (initial×6) | 1 (onConfirm) | — |
| TempItemSheet | 3 (categories, initial×2) | 5 (同 GearForm 的 category 回调) | — |
| ImportSheet | 2 (gears, categories) | 2 (onImport, onAddGearFromImport) | — |
| GearSortSheet | 1 (gearSortMode) | 1 (onSelectSort) | 最简单 |
| GearPickerSheet | 4 (gears @Watch, categories, selectedItemIds, preselectZone) | 3 (onToggleGear, onAddGear, onClose) | 有自建 head |
| GearItemActionSheet | 2 (item, displayName) | 4 (onMoveToZone, onViewDetail, onRemove, onClose) | — |
| DayFormSheet | 5 (editingDayId, initial×4) | 3 (onSubmitDay, onSubmitEdit, onDeleteDay) | — |
| SegmentFormSheet | 12 (editingSegmentId, initial×11) | 2 (onSubmit, onDeleteSegment) | 最多 props |

**总计**：40 个 @Prop + 27 个回调 = **67 个绑定点**，全部经 SheetOverlay 中继。

## 2. ArkUI @BuilderParam 可行性

### 2.1 基本用法（已验证可行）

```typescript
@Component
struct SheetContainer {
  @BuilderParam content: () => void;
  
  build() {
    Column() {
      // 标题栏...
      this.content()  // 渲染传入的内容
    }
  }
}

// 调用方
SheetContainer() {
  // trailing lambda 即 @BuilderParam content
  GearFormSheet({ ... })
}
```

### 2.2 条件渲染兼容性

`@BuilderParam` 的 trailing lambda 在 `if` 条件渲染下正常工作。关键是 SheetContainer 组件本身在 `if` 内被 remount：

```typescript
// Index.ets build() 中
if (this.sheetMode.length > 0) {
  SheetContainer({
    sheetTitle: this.currentSheetTitle,
    sheetTranslateY: this.sheetTranslateY,
    // ...
  }) {
    // @BuilderParam trailing lambda
    if (this.sheetMode === SHEET_GEAR) {
      GearFormSheet({ ... })
    } else if (...)
  }
}
```

每次 `sheetMode` 从 '' 变为非空值时，整个 SheetContainer 被 remount，其中的子 Sheet 也会 remount（触发 aboutToAppear）。

### 2.3 已知限制

- trailing lambda 内的 `this` 引用是**调用方组件实例**（Index），不是 SheetContainer — 这正好是我们想要的
- @BuilderParam 不支持传参数（无参 builder）—— 但我们不需要传参，内容直接引用 Index 的变量
- 一个组件只能有一个 @BuilderParam 使用 trailing lambda 语法（多个需要具名传参）— 我们只需要一个 content 槽

### 2.4 替代方案：@Builder + wrapBuilder

如果 trailing lambda 有问题，备选：

```typescript
@Builder
function sheetContent() { ... }

SheetContainer({
  content: wrapBuilder(sheetContent)
})
```

## 3. 重构后的架构

### 3.1 文件结构变化

```
sheets/
├── SheetContainer.ets   ← 新建，~80 行，纯容器壳
├── GearFormSheet.ets    ← 不变
├── TripFormSheet.ets    ← 不变
├── ...                  ← 不变
└── SheetOverlay.ets     ← 删除
```

### 3.2 数据流变化

**Before（三跳）**：
```
Index open方法 → Index private代理变量 → SheetOverlay @Prop → 子Sheet @Prop
```

**After（一跳）**：
```
Index open方法 → Index private代理变量 → 子Sheet @Prop (直接在Index的@Builder中传入)
```

### 3.3 SheetContainer 接口设计

```typescript
@Component
export struct SheetContainer {
  // 动画控制
  @Prop sheetTranslateY: number = 800;
  @Prop sheetOverlayOpacity: number = 0;
  
  // 标题
  @Prop sheetTitle: string = '';
  @Prop showHeader: boolean = true;  // GearPickerSheet 自建 head
  
  // 错误
  @Prop errorText: string = '';
  
  // 行为
  onClose: () => void = () => {};
  
  // Import sheet 专用：头部追加按钮
  @Prop showImportAddButton: boolean = false;
  onImportAdd: () => void = () => {};
  
  // 内容槽
  @BuilderParam content: () => void;
  
  // 手势状态（内部）
  @State private sheetDragOffset: number = 0;
  @State private cardHeight: number = 600;
}
```

**总计：8 个 @Prop + 2 回调 + 1 @BuilderParam = 11 个接口点**（vs 原来 67 个）

## 4. 迁移策略

### 4.1 回调处理

原来：Index → lambda → SheetOverlay 回调 prop → 子 Sheet 回调 prop
现在：Index → 直接绑定到子 Sheet 回调 prop

例如 GearFormSheet 的 onSave：
```typescript
// Before (Index.ets SheetOverlay 传参区)
onSaveGear: (name, cat, w, p, n) => { this.handleSaveGear(name, cat, w, p, n) }

// After (Index.ets @Builder 中直接传)
GearFormSheet({
  onSave: (name, cat, w, p, n) => { this.handleSaveGear(name, cat, w, p, n) }
})
```

结果：回调绑定代码行数不变，但不再经过 SheetOverlay 中继声明。

### 4.2 sheetTitle 处理

采用最简方案：在每个 open 方法中设置 `this.currentSheetTitle`：

```typescript
openAddGear() {
  this.resetGearForm();
  this.currentSheetTitle = '添加装备';
  this.sheetMode = SHEET_GEAR;
}
```

删除 SheetOverlay 的 sheetTitle() 方法（40 行）。

### 4.3 Import Sheet 头部按钮

Import Sheet 在标题栏有一个 "+ 添加装备" 按钮。处理方式：
- SheetContainer 提供 `showImportAddButton` + `onImportAdd` 两个简单接口
- 或者让 Import Sheet 自建完整 head（设 showHeader = false）

推荐后者——让 ImportSheet 像 GearPickerSheet 一样自建 head，进一步简化 SheetContainer。

## 5. 行数预估

| 文件 | Before | After | 差值 |
|------|--------|-------|------|
| SheetOverlay.ets | 382 | 0 (删除) | -382 |
| SheetContainer.ets (新建) | 0 | ~80 | +80 |
| Index.ets SheetOverlay调用区 | 138 | ~10 | -128 |
| Index.ets @Builder sheetContent | 0 | ~110 | +110 |
| Index.ets reset/open 方法 | ~112 | ~125 (加 title 设置) | +13 |
| Index.ets private 变量 | 32 | 32 (保留) | 0 |
| **净变化** | — | — | **-307** |

实际 Index.ets 净变化 = -128 + 110 + 13 = **-5 行**（几乎持平，但结构显著改善）。
全局净减 **-307 行**，其中 SheetOverlay → SheetContainer 的功能密度从 382 → 80（5倍提升）。

## 6. @Prop limitations 备忘（来自 MEMORY.md）

- **@Prop 不支持 interface 类型**，只能 class 或基础类型 — 排除了 Payload union type 方案
- **@Prop 是单向同步（父→子）**，子组件修改不影响父 — 当前 initialXxx 模式正确利用了这点
- **@Watch 必须写在装饰器声明上** — GearPickerSheet 的 @Prop @Watch gears 写法正确
- **@State 数组必须 spread 副本** — 不影响本次重构，但需注意 categories、gears 等数组传参
