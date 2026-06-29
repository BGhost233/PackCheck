# PackCheck 项目记忆

## 工作流约定

- **构建命令**：
  ```bash
  cd /Users/bghost233/Documents/PackCheck && \
  export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" && \
  export PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" && \
  node "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js" assembleApp --no-daemon 2>&1 | grep -E "ERROR|BUILD"
  ```
- **备用（无 DevEco Studio）**：SDK 路径换 `/Users/bghost233/Desktop/harmonyOS/command-line-tools/sdk`，hvigor 路径换 `command-line-tools/hvigor/bin/hvigorw.js`

## 关键设计决策（只记规则，不记参数）

- 所有动画 Spring 弹性曲线，参数统一在 AnimationTokens.ets
- 顶部折叠统一走 `HeadCollapseController`：跟手 1:1 + 松手就近吸附。三页已对齐（Home/Gear/TripDetail）
- `geometryTransition` 两种语境：跨页（`trip-*`）无参形式 + 同页放大（`zone_*`）`{ follow: true }`
- NavDestination `.onBackPressed()` 拦截系统返回，走 `animateTo { pop(false) }` 保 geometryTransition
- Sheet 面板：SheetContainer 纯壳容器 + `@BuilderParam` trailing lambda，Index.ets 直接构建子 Sheet 内容；`animateTo` + state 驱动 `translateY`（TransitionEffect 不支持 Spring）
- HDS 只做「材质/视效层增强」，不做框架替换。唯一替换：`Navigation` → `HdsNavigation`
- hdsEffect `pressShadow` 只在「高频按压点进去卡片」上叠加（Hero 卡/装备卡）
- Tab visibilityNonce 只在一处递增（`onAnimationStart` 或 `triggerBlurPulse`），`onChange` 不递增
- 主题色 `#2D7D46` 山野绿；元信息分隔点 `META_SEPARATOR(#C2C2C2)`
- 拖拽避让：让位计算与命中检测必须基于同一坐标系（含被拖项完整列表）
- 拖拽松手 optimistic update：UI 先同步 setState，持久化 fire-and-forget 后台跑
- 聚焦态收起：借力事件消费机制（子消费不冒泡），点空白 + 左右划收起
- 行程 Tab 用原生 Tabs 组件双 Tab 滑动，`onGestureSwipe` 跟手颜色插值

## 架构速查

- 单 Page（Index.ets）+ Navigation NavPathStack，NavDestination：ChecklistDetail、ReviewPage
- Sheet 层级：Index.ets → SheetContainer（纯 UI 壳）→ trailing lambda 条件渲染各子 Sheet（AddGear/EditGear/Import/GearPicker/…）
- 统一核查清单：UnifiedChecklistView → ZoneShell → ZoneGridCell / FocusedZoneView → ChecklistRow
- GearService(`GearCalc`: 筛选/排序/统计/格式化 8 个纯函数) / ChecklistService(`CheckCalc`: CRUD + clone + 倒计时/分组/重量/日期显示 9 个纯函数) / LoadoutService / ItineraryService / FootprintService / CategoryService
- PackStore schema v2，singleton `getPackStore()` + 防抖 flush + 运行时验证 + 容量告警；`makeId()` = `Date.now()` + 单调计数器
- @Prop→@State 内化模式：EditItemPanel/EditGearPanel/DayFormSheet/SegmentFormSheet/TripCeremonyCard
- clone helper 铁律：DayItinerary/RouteSegment/TicketInfo 在 ItineraryService，ChecklistItem/TripChecklist 在 ChecklistService
- 事务化更新：category 删除/重命名先构建完整新状态，批量持久化成功后才赋 @State
- EntryBackupAbility：onBackupEx/onRestoreEx 结构化返回，Preferences 框架自动备份
- 上帝组件瘦身 Wave 1-2 已完成（纯计算下沉 + @Builder 提取），后续 Phase 5-9 见 `.planning/god-component-split/next_plan.md`
- `CATEGORY_ALL`（哨兵 '全部'）/ `CATEGORY_FALLBACK`（受保护 '其他'）在 PackModels.ets

## ArkUI 避坑清单（54 条）

1. `linearGradient` 禁用 `Color.Transparent` — 用 `'#00FFFFFF'` 同色相只变 alpha
2. Spring 曲线忽略 duration — 时间由 response 决定；错落用 `delay` 字段
3. 滚动驱动动画禁止 animateTo — 用 `.animation()` 修饰器
4. 折叠 Header 必须缩小实际 `.height()` + `.clip(true)`
5. Tab 切换禁止 setTimeout — changeIndex 必须立即调用
6. Stack 中组件定位用 `.position()` / `.align()` + `.offset()`
7. 同一属性不能同时有 `.animation()` 和 `animateTo()`
8. @Builder 回调参数 this 丢失 — 参数只传数据
9. 父 `.onClick()` 拦截子事件 — 用 `.onTouch(TouchType.Down)` 代替
10. geometryTransition 跨页无参 / 同页 `{ follow: true }`；源节点隐藏用 `opacity(0)+hitTest(None)` 不能 `visibility(Hidden)`
11. 覆盖层退场背景恢复必须并行 — 暴露 `onExitStart`
12. 波纹/粒子用固定组件 + `.animation()` 驱动
13. 连续手势振动棘轮式按阈值触发
14. @Builder 方法体禁止变量声明
15. 折叠屏 position 组件必须 onAreaChange
16. ArkTS 禁止无类型对象字面量导出
17. 装饰动画静止态必须中性值（scale=1.0）
18. 手势坐标 vp，display 物理像素必须 px2vp()
19. 拖拽浮层 `animation({ duration: 0 })` 覆盖父级动画继承
20. 浮动 Header + List spacer = Header高度 - paddingTop - space
21. 浮动组件放根 Stack + position + zIndex
22. 覆盖层必须在 Navigation 外层
23. ForEach key 包含所有变化维度（拼入属性 + nonce）
24. 搜索态绕过折叠/隐藏 — 查询方法在关键词非空时返回 false
25. PanGesture distance≥5 防吃 onClick
26. if/else 条件渲染动画：animateTo 包 state + 组件加 .transition()
27. Stack 子组件禁止 `height('100%')` — position 后同样不可靠
28. `Curve.EaseInOut` ≠ Material Standard — 用 `curves.cubicBezierCurve(0.4, 0, 0.2, 1.0)`
29. ForEach callback index 是 number 不是 optional
30. 死代码及时清理 — 预留常量无消费者就删
31. CURVE_LINEAR 合法场景：帧级匀速运动（如 timer 驱动滚动）
32. 大规模机械性修改用并行 subagent + 事后人工复查
33. Colors token 补充透明色常量
34. `.animation()` 作用域隔离：只捕获它与前一个 `.animation()` 之间的属性
35. `.overlay()` 对 @Builder 内条件渲染不可靠 — 改用 Stack + if + position
36. `.shadow()` + `backdropBlur` 产生亮色伪影 — 暗色场景移除 shadow
37. @State 数组禁止原地 mutation — 必须 spread 副本再赋值
38. aboutToDisappear 必须清 timer
39. ForEach 退场动画需显式加 `.transition()`
40. counter 动画无条件启动新动画 + clearInterval 取消旧的
41. 自定义组件外挂 `.onClick` 被根节点自身 onClick 抢占 — 走内部回调链路
42. 半透明色浮白底发灰 — 用不透明预混色 + 实色边框
43. `hitTestBehavior(None)` 不可靠阻止子 onClick — 用 if 条件渲染移除
44. `GestureGroup(Sequence)` 不阻止子 onClick — 用 flag + setTimeout 短路
45. 普通 class 改字段不触发 re-render — 控制器必配 @State 镜像 + onChange 回调
46. 拖拽避让冻结 rect 采集防反馈回路
47. 拖拽落位 optimistic update — 不 await 持久化
48. `@Watch` 必须写在 `@Prop`/`@State` 声明上（属性装饰器）
49. Tabs `onGestureSwipe` currentOffset 是 vp 位移非 progress — 除以 tabsWidth 归一化
50. `build()` 裸 if/else 产生隐式 Column 居中 — 必须显式根容器
51. TabContent keep-alive 下 onAppear 不再触发 — 靠 visibilityNonce @Watch 重播动画
52. 子组件表单编辑禁止父组件持有 N 个 @State+onChange — 用 @Prop→@State 内化模式（initialXxx + aboutToAppear + onSave 回调）
53. 禁止手写 DayItinerary/RouteSegment/TicketInfo/ChecklistItem 对象字面量 — 必须走 clone helper（新增字段遗漏概率随手写处数 N 指数增长）
54. 多关联数据源操作必须事务化 — 先构建完整新状态 → 批量 save → 全成功后赋 @State，中间失败则 return

## 重构决策模式（可复用经验）

- **超级中继反模式判定**：中间组件 Props 中 >80% 是透传给子组件的 → 用 `@BuilderParam` trailing lambda 让调用者直接构建内容，消灭中间层
- **维护税公式**：`新增 Feature 改动点数 × 每点行数 = 维护税`。改动点 ≥3 处且每处 ≥5 行 → 优先架构重构而非继续累加
- **一刀切 vs 渐进迁移**：旧架构无法局部改良（中继层本身就是问题）→ 干净替换；旧架构只是膨胀（可拆子模块）→ 渐进瘦身
- **计划驱动开发**：复杂重构先写 `.planning/` 目录（task_plan + findings + 量化分析 + 方案对比），执行阶段近零返工
- **编译可行性前置验证**：实施前在 findings.md 中做 ArkUI 语法验证（条件渲染 + @BuilderParam + @Prop 组合），避免实施中踩坑
- **行数 ≠ 复杂度**：SheetContainer 重构后 Index.ets 行数反增（2260→2345），但改动点从 3→1、接口从 67→11 — 衡量标准是信息熵而非行数

## 补充验证

- vibrator 预设：`haptic.clock.timer`/`effect.soft`/`effect.hard`/`effect.sharp`
- `backgroundColor` 可动画，用 `.animation()` 修饰器
- ArkTS 禁止 `{ ...obj }` 展开 — 逐字段赋值
- `@Prop` 不支持 interface 类型，只能 class 或基础类型
- `bindSheet` SheetOptions 不支持 `borderRadius`
- hdsEffect 沉浸视效仅真机渲染，模拟器不生效
