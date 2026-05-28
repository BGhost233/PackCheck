# PackCheck v0.4.0 — 动效与转场优化

## 目标

消除两处「硬切」体验断裂点，对标 Apple 原生应用的转场流畅度：
1. 清单首页卡片 → 行程详情页：从卡片位置展开的共享元素一镜到底转场
2. 装备库底部面板：Spring 弹性升起/收回，有物理回弹感

## 技术方案

### 需求 1：geometryTransition 共享元素转场

**原理**：ArkUI 的 `geometryTransition(id)` API 可在两个互斥出现的组件间做几何形变无缝过渡（位置 + 大小 + 圆角连续插值）。配合 Navigation NavPathStack 使用时，需要将路由操作包裹在 `animateTo` 闭包内。

**关键约束（来自官方文档）**：
- `geometryTransition` 必须配合 `animateTo` 使用才有动画效果
- `pushPath()` / `pop()` 必须放在 `animateTo` 闭包内
- `pushPath` 的 animated 参数必须传 `false`（禁用系统默认转场）
- NavDestination 需要加 `.transition(TransitionEffect.OPACITY)` 配合
- 同一个 id 只能绑定两个组件（一个 in、一个 out）
- 绑定处的组件会同步圆角（borderRadius）

**动画曲线**：`curves.springMotion(0.35, 0.78)` — 与项目 Spring 体系一致（response 0.35），dampingFraction 0.78 比默认 0.8 略低，展开有舒展感

**实现方式**：
```typescript
// HomePage 侧 — HeroCard
Column() { ... }
  .geometryTransition('trip-' + checklist.id, { follow: true })

// ChecklistDetail 侧 — 头部区域
Column() { ... }
  .geometryTransition('trip-' + this.selectedChecklistId, { follow: true })

// 触发导航（Index.ets）
this.getUIContext().animateTo({
  curve: curves.springMotion(0.35, 0.78)
}, () => {
  this.navPathStack.pushPath({ name: 'ChecklistDetail' }, false);
})

// 返回（ChecklistDetail）
this.getUIContext().animateTo({
  curve: curves.springMotion(0.32, 0.82)
}, () => {
  this.navPathStack.pop(false);
})
```

**NavDestination 配置**：
```typescript
NavDestination() { ... }
  .hideTitleBar(true)
  .transition(TransitionEffect.OPACITY)
```

**Fallback 方案**：如果 geometryTransition 在 NavPathStack 场景下有兼容性问题（闪帧/位置跳变），切换到 Overlay Layer 方案 — 用 `componentUtils.getRectangleById()` 获取卡片坐标，在 Stack 顶层手动动画。

---

### 需求 2：Sheet 弹性升起/收回

**原理**：将 SheetOverlay 从 `TransitionEffect`（不支持 Spring 曲线）改为 `animateTo` + state 驱动 translateY，实现真正的 Spring 弹性动画。

**动画参数**：
- 弹起：`springMotion(0.38, 0.72)` — dampingFraction 0.72 < 1，有过冲回弹（约 5-8vp）
- 收回：`springMotion(0.30, 0.88)` — 高阻尼，干脆利落不回弹

**实现方式**：
```typescript
// 新增 State
@State sheetTranslateY: number = 800  // 初始在屏幕外
@State sheetOverlayOpacity: number = 0

// 打开
private openSheetAnimated(): void {
  // sheetMode 已设置，DOM 已渲染
  this.sheetTranslateY = 800;
  this.sheetOverlayOpacity = 0;
  this.getUIContext().animateTo({
    curve: curves.springMotion(0.38, 0.72)
  }, () => {
    this.sheetTranslateY = 0;
    this.sheetOverlayOpacity = 1;
  });
}

// 关闭
private closeSheetAnimated(): void {
  this.getUIContext().animateTo({
    curve: curves.springMotion(0.30, 0.88),
    onFinish: () => {
      this.sheetMode = SHEET_NONE;  // 动画完成后再移除 DOM
    }
  }, () => {
    this.sheetTranslateY = 800;
    this.sheetOverlayOpacity = 0;
  });
}

// 面板绑定
.translate({ y: this.sheetTranslateY })
.opacity(this.sheetOverlayOpacity)  // 背景遮罩
```

**额外优化**：
- 背景遮罩从 `#66000000` 改为 `backdropBlur(16)` + `#26000000`（毛玻璃层次感）
- 展开时主内容 scale(0.97) 联动缩小（景深效果）

---

## 执行阶段

### 阶段 1：AnimationTokens 扩展 [status: pending]
- 新增 `SPRING_HERO_EXPAND`：`springMotion(0.35, 0.78)` — 卡片展开
- 新增 `SPRING_HERO_COLLAPSE`：`springMotion(0.32, 0.82)` — 卡片收回
- 新增 `SPRING_PANEL_ENTER`：`springMotion(0.38, 0.72)` — 面板弹起
- 新增 `SPRING_PANEL_EXIT`：`springMotion(0.30, 0.88)` — 面板收回
- 构建验证 → commit

### 阶段 2：共享元素转场 — HomePage 侧 [status: pending]
- HeroCard 组件添加 `.geometryTransition('trip-' + checklist.id, { follow: true })`
- HistoryRow 组件添加 `.geometryTransition('trip-' + item.id, { follow: true })`
- 确保卡片有明确的 borderRadius（16vp）以便转场时圆角过渡
- 构建验证 → commit

### 阶段 3：共享元素转场 — ChecklistDetail 侧 [status: pending]
- ChecklistDetail 头部容器添加匹配的 `.geometryTransition('trip-' + selectedChecklistId, { follow: true })`
- NavDestination 添加 `.transition(TransitionEffect.OPACITY)`
- 头部容器确保有初始 borderRadius(16vp)，展开到全屏后为 0
- 构建验证 → commit

### 阶段 4：共享元素转场 — 导航逻辑改造 [status: pending]
- `openChecklist()` 改为 `animateTo(SPRING_HERO_EXPAND) { pushPath(..., false) }`
- 所有 `pushPathByName('ChecklistDetail', undefined, true)` 替换为新方式
- `returnToHome()` 改为 `animateTo(SPRING_HERO_COLLAPSE) { pop(false) }`
- ChecklistDetail 的 `onBackPressed` 回调改为 `animateTo + pop(false)`
- 展开时背景内容加 scale(0.97) 联动（可选，视效果调整）
- 构建验证 → commit

### 阶段 5：Sheet 弹性动画改造 [status: pending]
- 新增 `@State sheetTranslateY` 和 `@State sheetOverlayOpacity`
- 移除 SheetOverlay 上的 `TransitionEffect` 和 closeSheet 中的 `Curve.EaseOut`
- `openAddGear()` 等入口设置 sheetMode 后调用 `openSheetAnimated()`
- `closeSheet()` 改为 `closeSheetAnimated()`：animateTo 退场 → onFinish 移除 DOM
- Sheet 面板 `.translate({ y: sheetTranslateY })`
- 背景遮罩 `.opacity(sheetOverlayOpacity)` + `backdropBlur(16)` + 颜色改为 `#26000000`
- 构建验证 → commit

### 阶段 6：细节打磨与验证 [status: pending]
- 展开时主内容 scale 缩小联动效果调试
- EditGearPanel / EditItemPanel 的 Spring 参数统一为 SPRING_PANEL_ENTER/EXIT
- 全局检查：确保无 linear/ease 曲线残留
- 端到端测试：所有转场路径（HeroCard、HistoryRow、新建行程→详情、装备生成行程→详情）
- 所有 Sheet 场景：添加装备、新建行程、排序、导入、生成行程
- 构建验证 → commit

---

## 涉及文件

| 文件 | 改动内容 |
|------|---------|
| `entry/src/main/ets/constants/AnimationTokens.ets` | 新增 4 个 Spring 预设 |
| `entry/src/main/ets/components/HomePage.ets` | HeroCard/HistoryRow 加 geometryTransition |
| `entry/src/main/ets/components/ChecklistDetail.ets` | 头部加 geometryTransition + NavDestination 加 transition |
| `entry/src/main/ets/pages/Index.ets` | 导航改造 + Sheet 动画改造 |
| `entry/src/main/ets/components/EditGearPanel.ets` | Spring 参数统一（如需） |
| `entry/src/main/ets/components/EditItemPanel.ets` | Spring 参数统一（如需） |

---

## 验收标准

### 需求 1 验收
- [ ] 点击 HeroCard → ChecklistDetail 有从卡片位置连续展开的动画，无跳切
- [ ] 点击历史行程列表项 → 对应 ChecklistDetail 有连续展开动画
- [ ] 新建行程后自动进入详情时也有展开动画
- [ ] 返回时详情页收缩回原始卡片位置，无跳切
- [ ] 动画曲线为 Spring，有自然减速感和微弱舒展感
- [ ] 展开/收回全程 60fps 无掉帧
- [ ] 展开过程中圆角从 16vp 连续过渡到 0

### 需求 2 验收
- [ ] 点击添加装备 → 面板从底部 Spring 弹性升起，有可感知的过冲回弹
- [ ] 关闭面板 → 面板 Spring 弹性收回底部，干脆利落无回弹
- [ ] 背景遮罩与面板位移联动，使用毛玻璃效果
- [ ] 所有 SheetOverlay 场景统一生效（添加装备、新建行程、排序、导入、生成行程）
- [ ] 动画全程 Spring 曲线，零 linear/ease

### 通用验收
- [ ] 构建通过（`hvigorw assembleApp`），无 crash
- [ ] 无 linear/ease 曲线残留
- [ ] 每个阶段改动后有 git commit

---

## 风险与应对

| 风险 | 概率 | 应对 |
|------|------|------|
| geometryTransition 在 NavPathStack 场景下闪帧/位置跳变 | 低 | 切换到 Overlay Layer 手动动画方案 |
| HeroCard 内容多，转场时内部元素跳变 | 中 | 内容元素在转场期间用 opacity 过渡，详情页用 staggered 延迟入场 |
| pushPath API 签名与 pushPathByName 不同导致参数传递问题 | 低 | 检查 API 文档，可能需要通过 NavPathStack params 传递 checklistId |
| Sheet animateTo 与条件渲染时机冲突（DOM 未挂载就触发动画） | 中 | 使用 aboutToAppear 或延迟一帧触发动画 |

---

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （待填充） | | |
