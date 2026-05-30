# GearPage UI 打磨 Round 2

## 目标
修复构建验证后发现的 4 个视觉/交互问题 + 2 个额外优化点，达到 Apple/HarmonyOS 原生级体验标准。

## 涉及文件
- `entry/src/main/ets/components/GearFilterPanel.ets` — 筛选面板
- `entry/src/main/ets/components/GearPage.ets` — 主列表页

---

## Phase 1: 筛选面板空白修复 — `complete`

### 问题
面板固定 `height('52%')` 导致分组少时底部大量空白；分组多时上下 padding 松散。

### 改动
1. Column 移除 `height('52%')`，改为无固定高度 + `.constraintSize({ maxHeight: '60%' })`
2. Scroll 移除 `layoutWeight(1)`，不设固定高度（自适应内容）
3. Flex padding: `top: 8→4`, `bottom: 16→12`
4. Column space: `10→8`
5. 标题行 padding `top: 14→12`, `bottom: 4→2`

### 预期效果
面板高度随 Chip 数量自然撑开，少分组时紧凑无空白，多分组时最大不超过 60% 触发滚动。

### 风险
- ✅ constraintSize 是基础 API，无兼容问题
- ⚠️ 需要确保 Scroll 不设 layoutWeight 时仍能正确计算高度

---

## Phase 2: 分组标签弹性按压反馈 — `complete`

### 问题
现有按压只有 scale 0.93 缩小，无过冲回弹，视觉不够活泼。

### 改动
1. 移除 CategoryChip 上的 `.animation()` 修饰器（避免与 animateTo 冲突——避坑第7条）
2. onTouch Down: `animateTo({ curve: springMotion(0.18, 0.65) })` 驱动 scale→0.88, 背景色加深
3. onTouch Up/Cancel: `animateTo({ curve: springMotion(0.22, 0.62) })` 驱动 scale→1.0, 背景色恢复
4. dampingFraction 0.62~0.65 产生明显过冲（弹跳感）

### 预期效果
按下→缩小 → 松手→过冲放大到 ~1.04 → 弹回 1.0，整个过程 ~350ms，有弹性 Q 弹感。

### 风险
- ✅ animateTo 是正确的离散事件驱动方式
- ⚠️ 需移除 `.animation()` 修饰器以避免双层动画（避坑第7条）

---

## Phase 3: 列表滑动遮挡修复（Header 底部渐融） — `complete`

### 问题
CollapsingHeader 纯色背景在内容从下方滑入时硬切，视觉上像「被吃掉」。

### 改动
1. List 的 `.backgroundColor(CARD_BG)` → `Color.Transparent`（让背景透明，只有卡片自身白色）
2. CollapsingHeader Stack 底部加一个 16vp 高的 Column + linearGradient 渐隐条
3. 渐变色：从 `gearHeaderBgColor()` 动态取（跟随 progress）→ `'#00F8F9FA'`（透明同色，避坑第1条）
4. 渐隐条设 `.hitTestBehavior(HitTestMode.None)` 不拦截触摸

### 预期效果
列表内容在 Header 底边自然「消融」淡出，而非硬切消失。

### 风险
- ✅ linearGradient 基础 API
- ✅ 遵守透明白规则（同色相只变 alpha）
- ⚠️ List 背景透明后需确认 PAGE_BG 从父容器穿透正常

---

## Phase 4: 长按预览动效优化 — `complete`

### 问题
bindContextMenu 进入/退出动画僵硬，几乎硬切，缺乏弹性。

### 改动
1. bindContextMenu 参数中添加 `transition` 字段：
   - 进入：`TransitionEffect.scale({ x: 0.9, y: 0.9 }).combine(TransitionEffect.OPACITY)` + spring(0.35, 0.78)
   - 退出：`TransitionEffect.scale({ x: 0.95, y: 0.95 }).combine(TransitionEffect.OPACITY)` + spring(0.28, 0.85)
2. `previewAnimationOptions.scale` 从 `[0.95, 1.08]` → `[0.92, 1.05]`
3. `borderRadius` 从 16 → 20（匹配 PreviewCard 圆角）

### 预期效果
长按浮起有弹性过冲感，退出有柔和缩回，不再硬切。

### 风险
- ⚠️ `transition` 字段在 API 23 的 bindContextMenu 中是否支持需验证
- ✅ 如果不支持会被忽略，不会崩溃（降级为系统默认动画）
- ✅ previewAnimationOptions 调整无风险

---

## Phase 5: 预览卡片宽度自适应 — `complete`

### 问题
GearPreviewCard 固定 280vp 宽度，折叠屏/大屏偏窄。

### 改动
1. `.width(280)` → `.width('72%')`
2. `.constraintSize({ maxWidth: 320, minWidth: 240 })` 防止极端尺寸

### 预期效果
普通手机约 280vp（不变），折叠屏展开时自动变宽。

### 风险
- ✅ 百分比宽度 + constraintSize 基础 API

---

## Phase 6: 构建验证 + Commit — `complete`

### 6.1 hvigorw assembleApp 通过
### 6.2 回归清单
- [ ] 筛选面板展开后无多余空白
- [ ] 筛选标签按压有弹性回弹
- [ ] 列表上滑时 Header 底部渐融自然
- [ ] 长按预览进入/退出有弹性动画
- [ ] 预览卡片宽度自适应
- [ ] 普通点击、搜索、排序、多选不受影响

### 6.3 Git commit

---

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （待填充） | | |
