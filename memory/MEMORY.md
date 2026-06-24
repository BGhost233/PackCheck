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
- Sheet 面板用 `animateTo` + state 驱动 `translateY`（TransitionEffect 不支持 Spring）
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
- 统一核查清单：UnifiedChecklistView → ZoneShell → ZoneGridCell / FocusedZoneView → ChecklistRow
- GearService(`GearCalc`) / ChecklistService(`CheckCalc`) / LoadoutService / ItineraryService / FootprintService / CategoryService
- PackStore schema v1，`initFailed` 阻止写入；`makeId()` = `Date.now()` + 单调计数器
- `CATEGORY_ALL`（哨兵 '全部'）/ `CATEGORY_FALLBACK`（受保护 '其他'）在 PackModels.ets

## ArkUI 避坑清单（52 条）

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
20. 多选模式切换不改变 Header 可见性 — 内部切换内容
21. 浮动 Header + List spacer = Header高度 - paddingTop - space
22. 浮动组件放根 Stack + position + zIndex
23. 覆盖层必须在 Navigation 外层
24. ForEach key 包含所有变化维度（拼入属性 + nonce）
25. 搜索态绕过折叠/隐藏 — 查询方法在关键词非空时返回 false
26. PanGesture distance≥5 防吃 onClick
27. if/else 条件渲染动画：animateTo 包 state + 组件加 .transition()
28. Stack 子组件禁止 `height('100%')` — position 后同样不可靠
29. `Curve.EaseInOut` ≠ Material Standard — 用 `curves.cubicBezierCurve(0.4, 0, 0.2, 1.0)`
30. ForEach callback index 是 number 不是 optional
31. 死代码及时清理 — 预留常量无消费者就删
32. CURVE_LINEAR 合法场景：帧级匀速运动（如 timer 驱动滚动）
33. 大规模机械性修改用并行 subagent + 事后人工复查
34. Colors token 补充透明色常量
35. `.animation()` 作用域隔离：只捕获它与前一个 `.animation()` 之间的属性
36. `.overlay()` 对 @Builder 内条件渲染不可靠 — 改用 Stack + if + position
37. `.shadow()` + `backdropBlur` 产生亮色伪影 — 暗色场景移除 shadow
38. @State 数组禁止原地 mutation — 必须 spread 副本再赋值
39. aboutToDisappear 必须清 timer
40. ForEach 退场动画需显式加 `.transition()`
41. counter 动画无条件启动新动画 + clearInterval 取消旧的
42. 自定义组件外挂 `.onClick` 被根节点自身 onClick 抢占 — 走内部回调链路
43. 半透明色浮白底发灰 — 用不透明预混色 + 实色边框
44. `hitTestBehavior(None)` 不可靠阻止子 onClick — 用 if 条件渲染移除
45. `GestureGroup(Sequence)` 不阻止子 onClick — 用 flag + setTimeout 短路
46. 普通 class 改字段不触发 re-render — 控制器必配 @State 镜像 + onChange 回调
47. 拖拽避让冻结 rect 采集防反馈回路
48. 拖拽落位 optimistic update — 不 await 持久化
49. `@Watch` 必须写在 `@Prop`/`@State` 声明上（属性装饰器）
50. Tabs `onGestureSwipe` currentOffset 是 vp 位移非 progress — 除以 tabsWidth 归一化
51. `build()` 裸 if/else 产生隐式 Column 居中 — 必须显式根容器
52. TabContent keep-alive 下 onAppear 不再触发 — 靠 visibilityNonce @Watch 重播动画

## 补充验证

- vibrator 预设：`haptic.clock.timer`/`effect.soft`/`effect.hard`/`effect.sharp`
- `backgroundColor` 可动画，用 `.animation()` 修饰器
- ArkTS 禁止 `{ ...obj }` 展开 — 逐字段赋值
- `@Prop` 不支持 interface 类型，只能 class 或基础类型
- `bindSheet` SheetOptions 不支持 `borderRadius`
- hdsEffect 沉浸视效仅真机渲染，模拟器不生效
