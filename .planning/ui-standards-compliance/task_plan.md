# UI 规范全面合规改造计划

## 目标
一劳永逸修复所有 18 个组件文件中存在的 UI 规范违规问题，包括：硬编码色值（146 处）、禁用动画曲线（~25 处）、硬编码 duration（~70 处）、裸调 springMotion（~55 处）、按压反馈缺失（8 个文件）、列表错落缺失（3 个文件）。

## 约束
- 每完成一个阶段必须构建验证（`hvigorw assembleApp`）
- 每批次验证通过后 commit
- 纯替换工作不改变任何运行时逻辑
- 仪式动画（TripCeremonyCard）的部分 EaseOut 场景（shimmer 循环）通过 token 化保留而非强制换 Spring

---

## 阶段 1: Colors.ets 扩充 + 全局色值替换 [status: pending]

### 1.1 扩充 Colors.ets（新增 ~35 个 token）
新增分层：
- 基础色：WHITE, BLACK, TRANSPARENT
- 遮罩层：OVERLAY_MASK(#66000000), OVERLAY_MASK_LIGHT(#4D000000), OVERLAY_DIM(#33000000), OVERLAY_SUBTLE(#26000000)
- 阴影系：SHADOW_DEFAULT(#1A000000), SHADOW_LIGHT(#14000000), SHADOW_SUBTLE(#0A000000), SHADOW_MICRO(#08000000), SHADOW_MEDIUM(#28000000)
- 功能色：DISABLED_COLOR(#CCCCCC), PLACEHOLDER_COLOR(#BBBBBB), CHIP_BORDER(#E0E0E0), PROGRESS_INACTIVE(#90A4AE)
- 状态色：PRIMARY_PRESSED(#1F5C32), PRIMARY_PRESSED_DEEP(#256B3A), DANGER_TINT(#FFF0F0), ERROR_BORDER(#FF4444), CELEBRATE_GOLD(#FFD700)
- 输入/卡片：INPUT_BG(#F7F8F7), CARD_FOOTER_BG(#F0F4F0), CHIP_BG_DEFAULT(#F5F7F5)
- 毛玻璃：GLASS_BG(#B0FFFFFF), GLASS_BG_HEAVY(#EBFFFFFF), GLASS_BG_MEDIUM(#E8FFFFFF), GLASS_BG_LIGHT(#EEFFFFFF)
- 主色透明度变体：PRIMARY_STROKE_FAINT(#332D7D46), PRIMARY_STROKE_GHOST(#0A2D7D46), PRIMARY_SHADOW(#1A2D7D46), PRIMARY_SHADOW_LIGHT(#262D7D46), PRIMARY_HALF(#802D7D46), PRIMARY_FILL_SUBTLE(#2D7D4660), PRIMARY_GRADIENT_START(#1F2D7D46), PRIMARY_GRADIENT_END(#4D2D7D46), PAGE_BG_TRANSLUCENT(#66F8F9FA)
- 白色变体：WHITE_SECONDARY(#CCFFFFFF)

### 1.2 全局替换（按文件）
替换顺序（文件 → 硬编码数）：
1. GearPage.ets — 39 处
2. TripCeremonyCard.ets — 27 处
3. ChecklistDetail.ets — 10 处
4. GearFilterPanel.ets — 8 处
5. HomePage.ets — 8 处
6. EditGearPanel.ets — 7 处
7. EditItemPanel.ets — 7 处
8. AssetTrendCard.ets — 6 处
9. ChecklistService.ets — 5 处
10. EntryAbility.ets — 5 处
11. ImportSheet.ets — 5 处
12. ReviewPage.ets — 4 处
13. GearFormSheet.ets — 4 处
14. TempItemSheet.ets — 4 处
15. SheetOverlay.ets — 3 处
16. EmptyIllustration.ets — 2 处
17. WeightGauge.ets — 2 处
18. GenerateTripSheet.ets — 2 处
19. TripFormSheet.ets — 1 处
20. Index.ets — 3 处

### 1.3 ColorUtils.ets 重构
将分组色和渐变色改为引用 Colors.ets 中的 token（新增 GROUP_COLORS 映射）。

### 1.4 DesignTokens.ets barrel re-export 更新
新增色值全部加入 re-export。

**验证**: 构建通过 + 所有 .ets 文件中无 `'#` 开头的硬编码（排除 Colors.ets 定义本身和 ColorUtils.ets 中不可避免的计算色）

---

## 阶段 2: AnimationTokens.ets 扩充 + 全局 duration/curve 替换 [status: pending]

### 2.1 扩充 AnimationTokens.ets
新增 Duration tokens:
- DURATION_PULSE = 50（极短脉冲）
- DURATION_PRESS = 150（按压视觉反馈）
- DURATION_HEADER = 250（Header 缩放）
- DURATION_ENTRANCE = 500（通用入场）
- DURATION_GAUGE = 600（仪表盘弧线）
- DURATION_GAUGE_COUNTER = 800（仪表盘数字滚动）
- DURATION_CHART_DRAW = 1200（图表绘制）
- DURATION_TICK = 32（ticker 帧级动画）

Ceremony 专用 Duration:
- DURATION_CEREMONY_OVERLAY = 300
- DURATION_CEREMONY_SHINE = 400
- DURATION_CEREMONY_STAGGER = 150
- DURATION_CEREMONY_SHIMMER = 1200
- DURATION_CEREMONY_SHAKE = 80

新增 Spring tokens:
- SPRING_SWIPE_RESET: springMotion(0.35, 0.72) — 侧滑重置
- SPRING_CHEVRON: springMotion(0.22, 0.82) — 折叠箭头
- SPRING_FAB_SNAP: springMotion(0.28, 0.76) — FAB 吸附
- SPRING_SEARCH: springMotion(0.35, 0.82) — 搜索栏展开
- SPRING_FILTER_PRESS: springMotion(0.18, 0.65) — 筛选按压
- SPRING_FILTER_RELEASE: springMotion(0.22, 0.62) — 筛选释放
- SPRING_CEREMONY_FLIP: springMotion(0.35, 0.78) — 仪式翻转
- SPRING_CEREMONY_DISMISS: springMotion(0.25, 0.8) — 仪式消失

Bezier 曲线 token（用于不适合 Spring 的场景）:
- CURVE_DECELERATE: Curve.EaseOut 的 token 化引用（shimmer/仪式退场）

### 2.2 全局替换（按文件）
替换顺序：
1. GearPage.ets — ~40 处（最多）
2. TripCeremonyCard.ets — ~34 处
3. ChecklistDetail.ets — ~8 处
4. HomePage.ets — ~5 处
5. WeightGauge.ets — ~5 处
6. AssetTrendCard.ets — ~3 处
7. GearFilterPanel.ets — ~2 处
8. EmptyIllustration.ets — ~2 处
9. Index.ets — ~6 处

### 2.3 规则
- `Curve.EaseInOut` 全部替换为 Spring（无例外）
- `Curve.EaseOut` 大部分替换为 Spring；仅 shimmer 循环动画保留为 `CURVE_DECELERATE`
- `Curve.Linear` 仅 ticker 帧级定时保留为 `CURVE_LINEAR`
- 裸调 `curves.springMotion(x, y)` 全部替换为命名 token

**验证**: 构建通过 + grep 确认无裸调 springMotion/禁用曲线

---

## 阶段 3: 按压反馈全面补充 [status: pending]

### 3.1 需补充按压的文件及元素
1. GearFormSheet.ets — 确认按钮、取消按钮
2. GenerateTripSheet.ets — 生成按钮
3. ImportSheet.ets — 导入按钮、选项卡
4. TempItemSheet.ets — 确认按钮、取消按钮
5. TripFormSheet.ets — 确认按钮
6. EditGearPanel.ets — 确认/取消/删除/关闭按钮
7. EditItemPanel.ets — 确认/取消/删除按钮
8. ReviewPage.ets — 所有操作按钮 + 卡片

### 3.2 实现方式
使用 AnimationUtils 中已封装的:
- `pressScale(isPressed)` 计算 scale 值
- `pressHandler(setter)` 生成 onTouch 回调
- `pressAnimationOptions()` 生成 animation 配置

每个需要按压的组件新增 `@State xxxPressed: boolean = false`

### 3.3 GearPage 装备行
当前用 `backgroundColor` 变色作按压反馈，不规范。改为标准 `scale` 三段式。

### 3.4 GearSortSheet
当前基于选中态静态设 scale，改为 onTouch 动态响应。

### 3.5 WeightGauge StatPill
补充按压反馈。

**验证**: 构建通过 + 所有可点击元素有 `.onTouch` + `.scale` + `.animation`

---

## 阶段 4: 列表错落入场 + ReviewPage 动效 [status: pending]

### 4.1 需添加错落入场的文件
1. GearPage.ets — 装备列表 ForEach
2. ChecklistDetail.ets — 物品列表 ForEach
3. AssetTrendCard.ets — 数据点入场

### 4.2 实现方式
使用 AnimationUtils:
- `staggeredTranslateY(isEntered)` → 初始 12vp 偏移
- `staggeredOpacity(isEntered)` → 初始 0 透明度
- `staggeredAnimationOptions(index)` → 生成 delay+duration+curve

每个组件新增 `@State listEntered: boolean = false`，aboutToAppear 中 setTimeout 20ms 设 true 触发。

### 4.3 ReviewPage 动效补充
- 页面入场：整体 opacity 0→1 + translateY 12→0（SPRING_GENERAL）
- 卡片按压：标准三段式
- 核查项列表：错落入场

**验证**: 构建通过 + 视觉确认列表有错落入场效果

---

## 阶段 5: Index.ets 细节修复 + 最终验证 [status: pending]

### 5.1 Index.ets
- `#F8F9FA` → `PAGE_BG`
- `#66F8F9FA` → `PAGE_BG_TRANSLUCENT`
- `#262D7D46` → `PRIMARY_SHADOW_LIGHT`

### 5.2 全局最终验证
- 全项目 grep `'#[0-9A-Fa-f]'` 确认无遗漏硬编码色值
- 全项目 grep `Curve\.EaseInOut|Curve\.EaseOut|Curve\.Linear` 确认仅在 token 定义处存在
- 全项目 grep `curves\.springMotion\(` 确认仅在 AnimationTokens.ets 中存在
- 全项目 grep `duration:` 确认值均来自 token 常量

**验证**: 完整构建通过 + 所有 grep 检查零违规

---

## 可行性分析

| 风险点 | 评估 | 应对 |
|--------|------|------|
| 色值替换引入拼写错误 | 低 — 纯文本替换，编译器会立即报错 | 每 5 个文件构建验证一次 |
| Spring 替换改变动效感受 | 中 — 参数微调可能改变视觉效果 | 新 token 参数保持与原值一致或极近 |
| 按压反馈新增 @State 影响渲染 | 低 — boolean 状态轻量 | 每个文件改完验证 |
| 错落入场时机不当导致闪烁 | 低 — 已有 HomePage 成功先例 | 复用相同模式 |
| TripCeremonyCard 仪式动画复杂 | 中 — 多段时序动画互相依赖 | 仅替换值为 token，不改逻辑 |

## 工作量估算
- 阶段 1: Colors.ets 扩充 + 20 个文件色值替换（约 146 处）
- 阶段 2: AnimationTokens.ets 扩充 + 9 个文件动画替换（约 95 处）
- 阶段 3: 8+ 个文件按压反馈补充
- 阶段 4: 4 个文件列表错落/动效补充
- 阶段 5: 收尾验证
