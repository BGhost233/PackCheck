# PackCheck 项目记忆

## 工作流约定

- **每次改动即 commit**：每次修改构建验证通过后，立即 `git add -A && git commit`，保持细粒度回滚点，方便随时回滚。
- **构建命令**：`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon`
- **先出方案再动手**：任何需求先输出理解+方案+理由，确认后才写代码。

## 设计决策

- 新建行程采用「宝可梦卡牌翻转」仪式感入场动画
- 确认出发采用「滑动出发」交互（正圆滑块骑在轨道上 + 白色遮罩吞噬已滑区域 + 磁吸吸附 + 三阶段仪式 + 卡片飘走）
- 滑块到达后三阶段仪式：Phase1 锁定确认（150ms，放大+波纹+双击振动）→ Phase2 充能蓄力（400ms，卡片收缩+文字切换+飞机旋转+光晕）→ Phase3 弹射升空（微放大+推力振动+飘走），总计~1000ms
- 滑动过程增强：按下 haptic.effect.soft + 颜色加深 + 轨道下沉；滑动中绿色进度条 + 25%/50%/75% 棘轮振动
- 主题色 `#2D7D46` 山野绿
- 所有动画使用 Spring 弹性曲线，严禁 linear/ease
- 页面转场使用 `geometryTransition(id)` 无参形式（非 sharedTransition；禁止 `{ follow: true }` — 会破坏文档流布局）
- NavDestination 加 `.onBackPressed()` 拦截系统手势返回，统一走 `animateTo { pop(false) }` 保证 geometryTransition 生效
- 转场 Spring 参数：expand `springMotion(0.42, 0.73)`，collapse `springMotion(0.36, 0.78)` — 经实机调优，兼顾弹性和克制
- 转场时源页面施加 `contentBlur=12` + `contentScale=0.94` 消散效果，增强空间纵深
- Sheet 面板使用 `animateTo` + state 驱动 `translateY`（非 TransitionEffect，后者不支持 Spring 曲线）
- Sheet 弹起 dampingFraction 0.72（有过冲回弹），收回 0.88（干脆无回弹）
- 新建行程仪式卡片弹出时背景同样 scale(0.94) + blur(12) 下沉，退场通过 `onExitStart` 回调与卡片动画并行恢复（EaseOut 400ms），避免延迟感

- 多选拖拽交互设计：长按 200ms 进入拖拽，Header 原地切换内容（不销毁/重建），浮动卡片 `duration:0` 即时跟手，底部托盘 macOS Dock 磁吸放大，右滑 SwipeGesture 退出多选
- 磁吸动效参数：影响半径 140vp，scale 1.0~1.1 连续变化，translateY 0~-10vp 涌起，动画 duration 160 + EaseOut（不用 Spring 避免过度弹性）
- 分组拖拽排序设计：长按 300ms 分组 header 激活 → 浮动整组（scale 1.03, rotate -1°, elevated shadow）跟手 → 碰撞检测用累积高度+中线穿越 → 松手 spring 归位 → categoryOrder 持久化
- GearPage 搜索展开策略：搜索框不放 Column 流中（会被浮动 Header 遮挡），改用根 Stack + position(0, COLLAPSED) + zIndex(9)，展开时强制 Header 收缩 + 重置滚动位置
- GearPage 搜索联动折叠状态：`isGearGroupCollapsed()` 在有搜索关键词时直接返回 false，搜索结果所在分组自动展开，无需额外展开逻辑
- 多选拖拽 vs 点击共存：PanGesture distance 从 0 改为 5，让轻点正常走 onClick（toggle 选中），只有真正拖动才激活 Pan
- 分组折叠/展开动画：`animateTo(springMotion(0.35, 0.8))` 包裹 state 赋值 + 内容 Column 加 `.transition(TransitionEffect.OPACITY.combine(translate({y:-6})))` 实现丝滑进退场
- 行程托盘动态滚速：边缘区域 100vp，二次曲线加速 `speed = minSpeed + (maxSpeed - minSpeed) * t²`（min=2, max=12），手感自然。Timer 每次回调读 mutable field `trayScrollSpeed`，无需重启 timer 即可变速
- 行程托盘尺寸优化：位置从 screenHeight-200 → screenHeight-240，卡片从 100×80 → 88×68，间距 12→10，容纳更多行程

## 架构

- 已从 Index.ets 提取独立组件：TripCeremonyCard、EditGearPanel、EditItemPanel、GearFilterPanel
- 已提取 Sheet 面板组件到 `components/sheets/`：SheetOverlay（容器）、GearSortSheet、GenerateTripSheet、GearFormSheet、TripFormSheet、TempItemSheet、ImportSheet
- GearService.ets 导出 `class GearCalc`，ChecklistService.ets 导出 `class CheckCalc`，Index.ets 通过 namespace import 调用
- 已删除废弃组件：EdgeFade.ets
- AnimationTokens.ets 中定义了 9 个 Spring 预设：SPRING_GENERAL / PRESS / TAB / COUNTER / SCROLL / HERO_EXPAND / HERO_COLLAPSE / PANEL_ENTER / PANEL_EXIT + 时长/缩放常量
- 导航架构：单 Page（Index.ets）+ Navigation NavPathStack，两个 NavDestination（ChecklistDetail、ReviewPage）
- TripCeremonyCard 暴露 `onExitStart` 回调，退场动画启动第一帧触发，供父组件并行驱动背景恢复

## ArkUI 避坑清单（实战总结，共 34 条）

1. **linearGradient 禁用 Color.Transparent** — 它是透明黑 `#00000000`，渐变出灰中间值。正确：`'#00FFFFFF'` 同色相只变 alpha
2. **Spring 曲线忽略 duration** — `animateTo({ duration, curve: springMotion })` 中 duration 无效，时间完全由 response 决定。需要短动画就用 EaseOut。**错落延迟场景**：不要用 duration 来做延迟，用 `delay` 字段（`animateTo({ delay: index * 40, curve: springMotion })` 或 `.animation({ delay: index * 40 })`）
3. **滚动驱动动画禁止 animateTo** — scrollOffset→UI 必须同步赋值，平滑感放 `.animation()` 修饰器，不放数据源
4. **折叠 Header 必须缩小实际高度** — 不能只 opacity:0，必须 `.height(计算值)` + `.clip(true)` 真正折叠
5. **Tab 切换禁止 setTimeout** — `changeIndex()` 必须 onClick 中立即调用，弹性动画只作用于 pill，不延迟切换
6. **Stack 中组件定位要显式** — 用 `.position()` / `.align()` + `.offset()`，不依赖 margin
7. **动画不要叠加** — 同一属性不能同时有 `.animation()` 和 `animateTo()`，选一种。实战案例：WeightGauge ring 的 `.scale()` 同时有 `.animation({ curve: SPRING_PRESS() })` 修饰和 `animateTo` 驱动 → 运行时两者竞争产生卡顿/抖动。解法：去掉 `.animation()` 修饰，只保留 `animateTo` 统一驱动
8. **@Builder 回调参数 this 丢失** — 异步回调（弹窗/选择器）中 this 丢失。规则：参数只传数据，不传带 this 的回调
9. **onTouch vs onClick 冲突** — 父 `.onClick()` 拦截子事件。父只需触摸态时用 `.onTouch(TouchType.Down)` 代替
10. **geometryTransition + Navigation** — pushPath/pop 必须在 animateTo 内 + animated=false；NavDestination 加 `.transition(OPACITY)`；禁止 `{ follow: true }`；必须 `.onBackPressed()` 拦截系统返回走 animateTo
11. **覆盖层退场背景恢复必须并行** — 子组件暴露 `onExitStart`，退场第一帧触发；恢复用 EaseOut 不用 Spring
12. **波纹/粒子用固定组件** — 预置固定数量 Circle + `.animation()` 驱动，不用 ForEach 动态创建
13. **连续手势振动节奏** — 棘轮式按阈值触发，state 记录已触发阈值防重复。预设：clock.timer < effect.soft < effect.hard < effect.sharp
14. **@Builder 方法体禁止变量声明** — 只能写 UI 描述语法，计算值用 `this.xxx()` 方法或 @State
15. **折叠屏适配：position 组件必须 onAreaChange** — display 只是瞬间物理像素，折叠/分屏后要重新计算坐标
16. **ArkTS 禁止无类型对象字面量导出** — 用 `export class Xxx { static fn = fn }` 代替 `export const = {}`
17. **装饰动画静止态必须中性值** — rest state 必须是中性值（scale=1.0、opacity=0 或 1），不能停留在弹性中间值。实战案例：GearSortSheet 按压 rest 状态错误设为 `PRESS_SCALE_BOUNCE`(1.02) → 松手后元素永久放大 2%。解法：rest 必须用 `PRESS_SCALE_REST`(1.0)
18. **手势坐标是 vp，display 是物理像素** — GestureEvent/TouchEvent 坐标直接用；display.width/height 必须 px2vp()
19. **拖拽浮层 animation({ duration: 0 })** — 覆盖父级动画继承，消除插值滞后
20. **多选模式切换不改变 Header 可见性** — 不 if/else 整个 Header，内部切换内容。多选时 Header 锁定收缩态
21. **浮动 Header + List spacer 间距** — spacer = Header高度 - paddingTop - space；模式切换时同步调整
22. **浮动组件不放 Column 流式布局** — 放根 Stack 用 position + zIndex 定位，展开时强制 Header 收缩
23. **覆盖层必须在 Navigation 外层** — NavDestination 会遮挡内部 Stack 子组件，覆盖层放 Navigation 同级之后
24. **ForEach key 包含所有变化维度** — key 不止 id，拼入影响渲染的属性 + nonce 计数器
25. **搜索态绕过折叠/隐藏状态** — 状态查询方法在搜索关键词非空时返回 false，从数据源头解决
26. **PanGesture distance≥5 防吃 onClick** — distance:0 会让微小移动触发 Pan。Pan+Click 共存时 distance 至少 5
27. **if/else 条件渲染动画** — 两步：① animateTo 包裹 state 赋值 ② 组件加 `.transition(OPACITY+translate)`。缺一不可
28. **Stack 子组件禁止 height('100%')** — Stack 高度由子组件最大高度决定，子组件 `height('100%')` 形成循环依赖，运行时布局引擎给出异常大高度值。解法：需要覆盖层/绝对定位元素时，用 Column/Row 容器 + `position()` + `translate()` 代替 Stack

29. **CURVE_STANDARD 必须用 `curves.cubicBezierCurve()`** — `Curve.EaseInOut` 是 `cubic-bezier(0.42, 0, 0.58, 1.0)`（对称曲线），与 Material/HarmonyOS Standard `cubic-bezier(0.4, 0, 0.2, 1.0)` 完全不同。正确实现：`curves.cubicBezierCurve(0.4, 0.0, 0.2, 1.0)` 返回 `ICurve` 类型（非 `Curve` 枚举）。`animateTo` 的 curve 字段接受 `Curve | ICurve | string` 三种类型
30. **ForEach callback index 是 `number` 不是 optional** — ArkUI 的 ForEach 第二个参数签名是 `(item: T, index: number) => void`，index 不需要 `?` 可选标记
31. **死代码及时清理** — AnimationTokens 中导出了 8 个常量（DURATION_PULSE/TAB/ENTRANCE/GAUGE、STAGGER_DELAY_MENU/LIST/SWIPE、PANEL_SCALE_DISMISS）实际无任何消费者，属于设计阶段预留但从未实现的功能。积累会让新开发者误以为有使用场景。清理时需同步检查 DesignTokens.ets barrel re-export
32. **CURVE_LINEAR 合法场景** — 帧级匀速运动（如 setInterval 16ms 驱动的托盘自动滚动）不适合 Spring/EaseOut，匀速是正确选择。但必须通过 `CURVE_LINEAR` token 引用，不硬写 `Curve.Linear`
33. **大规模机械性修改用并行 subagent** — 跨 12+ 文件的模式化修改（如去除 Spring+duration）适合拆分为并行 subagent 批量处理，但需要事后人工复查是否有遗漏（本次 subagent 漏了 2 处 Index.ets + 误保留 1 处 DURATION_GAUGE）
34. **Colors token 补充透明色** — `Color.Transparent` 不走 token 体系，新增 `TRANSPARENT`/`PRIMARY_TRANSPARENT`/`WHITE_SEMI_TRANSPARENT` 确保所有颜色统一管理

### 补充验证结论

- HarmonyOS vibrator 预设：`haptic.clock.timer`/`effect.soft`/`effect.hard`/`effect.sharp`；`count` 参数做连击
- `backgroundColor` 可动画，用 `.animation()` 修饰器过渡
- 光晕层用独立 Column + blur + opacity，`.shadow()` color 插值不可靠
- SymbolGlyph 支持 `.rotate()` 变换
- 文字切换用 Stack + 双 Text opacity 交叉淡入
- macOS Dock 磁吸：builder 中实时算 proximity，卡片有限时性能可接受
- SwipeGesture(Horizontal) 与垂直 List 不冲突
- `@Prop` 深拷贝 + ForEach key 只含 id → 不触发重渲染。解法：key 拼入变化属性 + nonce
- `bindSheet` SheetOptions 不支持 `borderRadius`（编译通过运行报 warn），需移除

## 快速核查功能（2025-06-22）

- 首页 QuickEntries 第二个按钮从「装备库」替换为「快速核查」（装备库已有 3 条路径可达，按钮冗余）
- `nearestFutureChecklist()` 只取 dateAt >= 今天的最近行程（过去行程已结束，不需要核查）
- 按钮状态机：无未来行程→隐藏（只剩"新建行程"填满行）；未来行程 items=0→点击跳转详情页+toast"先添加装备再核查"；全勾选→"再检查一遍"；有未勾选→"快速核查"
- 点击直接设置 `selectedChecklistId` 然后 `openReviewMode()`，跳过中间的详情页，减少操作路径

## 动效 Token 体系重构记录（2025-06-24）

本次对 AnimationTokens.ets 和相关文件进行了全面审查修复，核心改动：

**修复的 P0 运行时 Bug：**
- WeightGauge `.scale()` 上同时存在 `.animation()` 和 `animateTo()` 竞争 → 删除 `.animation()` 修饰
- GearSortSheet 按压 rest state 错误使用 `PRESS_SCALE_BOUNCE`(1.02) → 改为 `PRESS_SCALE_REST`(1.0)
- `CURVE_STANDARD` 值为 `Curve.EaseInOut` 与规范定义不符 → 改为 `curves.cubicBezierCurve(0.4, 0.0, 0.2, 1.0)`

**清理的 P2 代码质量问题：**
- 全量清除 Spring+duration 混用（~50 处，跨 12 个文件：GearPage/HomePage/ChecklistDetail/TripCeremonyCard/EmptyIllustration/GearSortSheet/Index/EditGearPanel/EditItemPanel/AnimationUtils 等）
- AnimationTokens 删除 8 个无消费者的废弃导出
- Typography 删除重复常量 `FONT_FEATURE_TABULAR_NUMS`
- Index.ets 清理 19 个未使用 import
- TripCeremonyCard/AssetTrendCard/GearPage/HomePage 替换硬编码色值为 Colors token
- 全局补充箭头函数类型标注

**经验教训：**
- Spring 系列函数（`springMotion`/`responsiveSpringMotion`/`springCurve`）**完全忽略** `duration` 字段，时间由 `response` 参数唯一决定。如果需要错落延迟，必须使用 `delay` 字段
- 大批量机械修改适合 subagent 并行处理，但**必须事后逐文件复查**（本次 subagent 漏改 2 处、误保留 1 处）
- `animateTo` 的 `curve` 字段接受 `Curve | ICurve | string` 三种类型，`cubicBezierCurve()` 返回 `ICurve` 可直接使用

## 已知限制

- hvigorw 不在默认 shell PATH 中，需设置 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk` 后使用完整路径 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp`
