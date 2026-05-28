# PackCheck v0.2.0 — 首页体验升级 设计文档

## 目标

提升 PackCheck 首页的用户体验，包括：折叠头部、HDS 沉浸光感修复、数据排序修复、视觉一致性/动效/微交互/材质层次感打磨。

---

## 1. HDS 沉浸光感修复

**根因分析：**
- SDK 枚举值已验证：`MaterialType.IMMERSIVE = 101`, `MaterialLevel.ADAPTIVE = 10`，值正确
- 可能原因：`supportHdsTabs` 在部分设备上为 false（API < 23），或 HdsTabs 缺少显式宽高导致 bar 未正确渲染
- 也可能 `barFloatingStyle` 中的 `gradientMask.maskColor` 格式问题（当前用 `'#66F1F3F5'`，可能需要 ARGB 格式）

**修复方案：**
1. HdsTabs 添加 `.width('100%').height('100%')` 确保正确填充
2. `gradientMask.maskColor` 改用标准颜色格式
3. 添加 `barBottomMargin: 28` 确保悬浮效果可见
4. 作为兜底：增强旧 `BottomTabBar` 的视觉效果（backdropBlur + 微投影）

---

## 2. 数据排序修复

**根因：** `HomePage.latestChecklist()` 直接取 `checklists[0]`，但 Preferences 中的初始数据按创建时间正序存储，导致 `[0]` 是最老的。

**修复方案：**
- 在 `Index.loadAppData()` 中，加载后按 `createdAt` 降序排序 checklists
- HomePage 中 `latestChecklist()` 保持不变（仍取 `[0]`），但数据已确保 `[0]` 是最新的

---

## 3. 折叠头部（方案 B：全融入 Scroll）

### 架构

```
Scroll
├── Header（动态缩放）
│   ├── 主标题 "PackCheck" | 28sp → 16sp
│   └── 状态文案 "N 个行程进行中" → 淡出
├── HeroCard（opacity + scale 基于 scrollOffset）
│   ├── 行程标题
│   ├── 倒计时数字
│   ├── 日期/重量信息
│   └── 环形进度
├── QuickEntries（常驻，吸附到折叠头下方）
│   ├── 新建行程
│   └── 装备库
├── HistoryTimeline
└── ...底部留白
```

### 滚动行为

| scrollOffset | Header | HeroCard | QuickEntries |
|---|---|---|---|
| 0 | 28sp, opacity=1 | scale=1, opacity=1 | 原位 |
| 80-200 | 渐进缩小 → 16sp | 渐进缩小淡出 | 保持可见 |
| 200+ | 16sp 固定 | 完全隐藏 | 吸附在 Header 下方 |

### 实现细节

- 使用 `Scroller` + `onDidScroll` 监听滚动偏移
- Header 变换：`fontSize = lerp(28, 16, progress)`
- HeroCard 变换：`scale = lerp(1, 0, progress)`, `opacity = lerp(1, 0, progress)`
- 动画插值曲线使用 ease-out，进步平滑（progress = clamp(scrollOffset / 200, 0, 1)）
- 顶部留安全距离（状态栏高度）

---

## 4. UI/UX 打磨

### 4.1 视觉一致性
- 统一卡片圆角层级：大卡片 20，中卡片 16，小卡片 12，chip 18
- 统一间距节奏：页面边距 20，段间距 24，项间距 12
- 阴影层级系统：Hero（radius=12, alpha=0.04） > 普通卡片（radius=8, alpha=0.03） > 按钮（无阴影）
- 颜色使用克制：主题色仅用于关键交互元素，大面积使用中性色

### 4.2 动效增强
- 倒计时数字：从 0 滚动到目标值（800ms ease-out，已实现，微调）
- 环形进度条：页面加载时从 0 stroke 到实际值（springMotion）
- 列表项入场：交错动画，每项延迟 50ms
- 折叠头部：跟随手指自然回弹（springMotion，已符合项目规范）

### 4.3 微交互细节
- 点击 HeroCard 进入清单：scale 反馈（0.97 → 1，springMotion）
- 下拉刷新：edgeEffect Spring
- Toast 入场：translate + opacity 过渡
- 空状态插画：已有（🏔️），保持

### 4.4 材质与层次感
- HDS 悬浮 TabBar：沉浸光感材质（IMMERSIVE + ADAPTIVE），底部渐变遮罩
- 降级 BottomTabBar：backdropBlur(20) + 柔和投影
- 弹窗遮罩：backdropBlur(20) + 半透明黑
- 筛选面板：毛玻璃 + 圆角底部

---

## 5. 改动文件

| 文件 | 改动 |
|---|---|
| `pages/Index.ets` | 数据排序、HdsTabs 宽高修复、BottomTabBar 降级增强 |
| `components/HomePage.ets` | 折叠头部重构、动画系统、UI 打磨 |

---

## 6. 验收标准

1. ✅ 构建通过 `hvigorw assembleApp --no-daemon`
2. ✅ API >= 23 设备上 HDS TabBar 显示沉浸光感效果
3. ✅ API < 23 设备上降级 BottomTabBar 显示毛玻璃效果
4. ✅ 首页顶部卡片显示最新行程（按创建时间降序）
5. ✅ 向下滚动时头部渐进折叠，Hero 卡片淡出
6. ✅ 向上滚动时头部渐进展开，Hero 卡片恢复
7. ✅ 快捷入口始终可见可触达
8. ✅ 动画使用 springMotion 曲线
9. ✅ 主题色 `#2D7D46` 使用正确
10. ✅ 无硬编码数据、无 console.log 残留
