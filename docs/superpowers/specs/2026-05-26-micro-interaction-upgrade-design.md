# PackCheck v0.3.0 — 动效 & 微交互全面升级 设计文档

## 目标

全面提升 App 动效和微交互体验，消除"硬切"问题，让每一个操作都有丝滑的过渡和真实的物理反馈感。核心原则：**一切以用户体验为最高优先级，拒绝生硬，拒绝线性，拥抱 Spring 弹性。**

## Spring 曲线参数

统一使用 `curves.springMotion(response, dampingFraction)`，严禁 Linear：

| 用途 | response | dampingFraction | 代码 |
|------|----------|----------------|------|
| 通用过渡 | 0.35 | 0.8 | `curves.springMotion(0.35, 0.8)` |
| 按压反馈 | 0.25 | 0.7 | `curves.springMotion(0.25, 0.7)` |
| Tab 滑动 | 0.4 | 0.75 | `curves.springMotion(0.4, 0.75)` |

## 模块清单

### 1. 二级菜单 & 下拉展开过渡动画 (⭐⭐⭐)

**涉及文件：** `Index.ets`

**下拉展开型（筛选/排序/分组选择）：**
- 容器高度：0 → 目标值，Spring 弹性
- 子项错落入场：每项延迟 30ms，opacity 0→1 + translateY(8vp→0)，duration 200ms
- 背景蒙层：blur radius 0→20，duration 300ms，ease-out + rgba(0,0,0,0.15) 淡入
- 收起：反向播放

**悬浮弹出型（编辑面板等）：**
- 出现：scale 0.9→1.0 + opacity 0→1，Spring 弹性带 overshoot
- 背景：rgba(0,0,0,0.3) 淡入 + backdropBlur(16)
- 消失：scale 1.0→0.95 + opacity 淡出

**侧滑展开型（swipe 操作按钮）：**
- 按钮从右侧滑入，Spring 弹性
- 多按钮间错落延迟 50ms

### 2. 按压微交互 Press Feedback (⭐⭐⭐)

**适用：** 所有可点击元素（卡片/列表项/Tab/FAB/图标按钮）

**三段式回弹：**
- 按下：scale 1.0 → 0.96 + 阴影内收，~100ms
- 松开：scale 0.96 → 1.02 → 1.0，~250ms，springMotion(0.25, 0.7)
- 长按：scale 保持 0.96 + rotate(-1°) 暗示拖拽

**涉及文件：** `Index.ets`, `HomePage.ets`, `GearPage.ets`, `ChecklistDetail.ets`, `ReviewPage.ets`

### 3. Tab 切换指示器滑动 (⭐⭐⭐)

**涉及文件：** `Index.ets` (BottomTabBar, HdsTabs)

- 选中态胶囊背景：translateX + Spring 平滑滑动
- 目标 Tab 文字：scale 1.0→1.05 + 颜色渐变，springMotion(0.4, 0.75)
- 离开 Tab 文字：scale 回 1.0 + 颜色回默认
- 胶囊整体 shadow 悬浮感
- 选中 Tab 白色渐变 overlay 模拟光泽

### 4. 列表项入场错落动画 (⭐⭐)

**涉及文件：** `HomePage.ets` (HistoryTimeline), `GearPage.ets`, `ChecklistDetail.ets`

- 每项：translateY(12vp)→0 + opacity 0→1，Spring 曲线
- 相邻项延迟 40ms（瀑布注入效果）
- 仅首次渲染播放

### 5. 数字变化 Counter 滚动 (⭐⭐)

**涉及文件：** `HomePage.ets` (HeroCard 倒计时数字, RingProgress)

- 数字从旧值滚动到新值，~400ms
- 曲线 ease-out，避免"闪变"要"流动"

### 6. 共享元素转场 (⭐⭐)

**涉及文件：** `Index.ets`

- 列表→详情时，相同元素从原位飞到新位
- 使用 ArkUI `sharedTransition` / `geometryTransition`
- 制造页面连续性和空间感

### 7. FAB 呼吸 + 展开 (⭐)

**涉及文件：** `GearPage.ets`

- 静态：微弱呼吸光效，shadow opacity 0.3↔0.6，2s 周期
- 展开：图标旋转 45°（+变×），子选项 staggered 弹出

### 8. 锦上添花 (⭐)

**涉及文件：** 全局

- 下拉刷新：跟手弹性 + Spring 回弹
- 空状态呼吸：插画 scale 0.98↔1.02
- 操作确认：checkmark 划出 / item 滑出消失
- 滚动视差：顶部标题与列表不同速率

## 技术约束

- 统一 Spring 弹性曲线，严禁 linear
- 每个动效 200-400ms 感知时长，不拖沓
- 性能优先：超屏幕范围不播放
- 动画可打断：快速操作时立即切到目标态
- 颜色：主题色 `#2D7D46`，蒙层用纯黑低透明度

## 验收标准

- [ ] 所有二级菜单/下拉有 Spring 过渡 + 背景模糊
- [ ] 所有可点击元素有按压下沉+弹回反馈
- [ ] Tab 指示器平滑滑动不瞬移
- [ ] 列表错落入场
- [ ] 数字滚动过渡无闪变
- [ ] 动画流畅可打断
- [ ] 无 linear 残留
- [ ] 构建通过
