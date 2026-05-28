# 研究发现

## HarmonyOS 共享元素转场机制

### 两套 API 对比

| 特性 | `geometryTransition` | `sharedTransition` |
|------|---------------------|-------------------|
| 适用路由 | 组件内 if/else + animateTo；**兼容 Navigation NavPathStack** | **仅 router 页面路由** |
| 动画控制 | 跟随 animateTo 的 curve/duration | 自身 options 中配置 |
| 效果 | 同步 frame、position、borderRadius | 同步位置+大小 |
| API 版本 | API 10 起生效，API 11 新增 options | API 7 起支持 |

**结论**：PackCheck 使用 Navigation + NavPathStack，**必须用 geometryTransition**，sharedTransition 不可用。

### geometryTransition 配合 NavPathStack 的官方用法

来源：华为「一镜到底动效」最佳实践文档中的搜索转场示例

```typescript
// 源页面
Search({ placeholder: 'Search' })
  .geometryTransition('SEARCH_ID', { follow: true })
  .onTouch((event) => {
    if (event.type === TouchType.Up) {
      this.getUIContext().animateTo({
        curve: curves.interpolatingSpring(0, 1, 342, 38)
      }, () => {
        this.pageInfos.pushPath({ name: 'TargetPage' }, false);
      })
    }
  })

// 目标页面
NavDestination() {
  Search({ placeholder: 'DevEco Studio' })
    .geometryTransition('SEARCH_ID')
    .transition(TransitionEffect.opacity(0.99))
}
.transition(TransitionEffect.OPACITY)
.onBackPressed(() => {
  this.getUIContext().animateTo({
    curve: curves.interpolatingSpring(0, 1, 342, 38)
  }, () => {
    this.pageInfos.pop(false);
  })
  return true;
})
```

**关键点**：
1. `pushPath(..., false)` — 第二个参数 false 禁用系统默认转场
2. `pop(false)` — 同上
3. NavDestination 本身加 `.transition(TransitionEffect.OPACITY)`
4. 目标组件可以加 `.transition(TransitionEffect.opacity(0.99))` 辅助（避免 opacity 完全为 1 导致 geometryTransition 不生效的 edge case）
5. `.onBackPressed()` 拦截系统手势返回，统一走 animateTo + pop(false)

### GeometryTransitionOptions — follow: true 的坑

```typescript
interface GeometryTransitionOptions {
  follow?: boolean  // 默认 false
  // true: 始终在树上的组件跟随做共享动画
}
```

**实测结论（2025-06-16）**：
- `{ follow: true }` 会让组件**脱离文档流**，在 Scroll + Column({ space }) 布局中导致卡片消失或重叠
- 官方示例中源页面用 `{ follow: true }` 但目标页面不用 — 这在简单场景可行，但在复杂滚动列表中不稳定
- **PackCheck 最终方案**：源页面和目标页面都用无参 `.geometryTransition(id)`，不加 `{ follow: true }`
- 无参形式只在转场瞬间接管组件位置，常态下不影响文档流布局

### 推荐动画曲线

| 场景 | 曲线 | 说明 |
|------|------|------|
| 官方搜索转场 | `interpolatingSpring(0, 1, 342, 38)` | settling ~400ms |
| 官方 NodeController | `springMotion(0.6, 0.9)` | 较慢较柔 |
| PackCheck 展开 | `springMotion(0.35, 0.78)` | 与项目体系一致，微欠阻尼 |
| PackCheck 收回 | `springMotion(0.32, 0.82)` | 略快，阻尼稍高 |

### pushPath vs pushPathByName

- `pushPathByName(name, param, animated)` — 项目当前用法，animated=true 启用系统动画
- `pushPath({ name, param }, animated)` — 官方推荐配合 geometryTransition 使用
- 两者功能等价，但 `pushPath` 的对象参数形式更灵活
- **animated 必须传 false**，否则系统动画和 geometryTransition 会冲突

---

## 当前 SheetOverlay 实现分析

- 使用 `if (sheetMode !== SHEET_NONE)` 条件渲染
- 入场：`TransitionEffect.translate({y:320}).combine(scale(0.9)).combine(opacity(0))`
- 退场：`TransitionEffect.translate({y:320}).combine(opacity(0))`
- closeSheet：`animateTo({ duration: 250, curve: Curve.EaseOut })` 设置 `sheetMode = SHEET_NONE`

**问题**：TransitionEffect 的默认动画曲线不支持自定义 Spring，表现为线性/系统标准曲线。

**解决方案**：改为 animateTo + state 驱动 translateY，入场/退场分别用不同的 Spring 曲线。

---

## 当前导航架构

- 单 Page 架构：只有 `pages/Index.ets`
- Navigation + NavPathStack 容器
- 两个 NavDestination：`ChecklistDetail` 和 `ReviewPage`
- NavDestinationMap @Builder 映射路由名到组件
- 当前用 `pushPathByName('ChecklistDetail', undefined, true)` 导航
- returnToHome 用 `this.navPathStack.pop(true)` 返回

---

## 第三方规格书评审意见

来源：`/Volumes/WenshuSpace/packcheck-transition-spec.md`

**可采纳的点**：
- geometryTransition 方向正确
- Spring 参数合理（0.38/0.78 展开，0.30/0.88 收回）
- animateTo 替代 TransitionEffect 的方案正确
- 背景毛玻璃建议合理

**需要修正的点**：
- 规格书写 `navPathStack.pushPathByName('ChecklistDetail', checklistId)` — 应改为 `pushPath({ name: 'ChecklistDetail' }, false)`
- 规格书中 setTimeout(16ms) 等下一帧的做法不够优雅 — 改用条件渲染 + aboutToAppear 触发
- 规格书未提到 NavDestination 需要加 `.transition(TransitionEffect.OPACITY)` — 这是关键配置
