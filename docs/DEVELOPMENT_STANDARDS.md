# PackCheck 开发规范

> 本文档是 PackCheck 项目的唯一开发标准，所有后续开发必须遵循。
> 融合华为 HarmonyOS 官方设计体系（引力体系 + 自然交互）与项目实战经验。

---

## 零、开发前置 — 文档优先

**接到需求 → 先搜文档 → 读懂再动手。** 不走网络，不凭经验猜。

本地 HarmonyOS 全量离线文档：`/Users/bghost233/Desktop/HarmonyOS-Docs/`（189MB，11,267 篇 .md）。

| 分类 | 路径 | 用途 |
|------|------|------|
| 开发指南 | `开发指南/` | ArkUI/ArkTS/Ability Kit 等开发指导 |
| API 参考 | `API参考/` | 组件参数、接口签名、状态管理 API |
| 最佳实践 | `最佳实践/` | 场景化案例、架构设计、性能优化 |
| FAQ | `FAQ/` | 高频问题与排错 |
| 版本说明 | `版本说明/` | 各 API 版本 changelog |
| 变更预告 | `变更预告/` | Roadmap / 即将废弃 API |

检索方法：

```bash
# 按文件名搜
find "/Users/bghost233/Desktop/HarmonyOS-Docs" -name "*关键词*"
# 按内容搜
grep -rl "关键词" "/Users/bghost233/Desktop/HarmonyOS-Docs/开发指南" | head -20
grep -rl "关键词" "/Users/bghost233/Desktop/HarmonyOS-Docs/API参考" | head -20
grep -rl "关键词" "/Users/bghost233/Desktop/HarmonyOS-Docs/最佳实践" | head -20
grep -rl "关键词" "/Users/bghost233/Desktop/HarmonyOS-Docs/FAQ" | head -20
```

典型流程：需求 → 判断知识域 → grep 检索 → Read 2-5 篇 → 基于文档出方案 → 写代码。性能优化优先查 `最佳实践/性能优化/`，状态管理优先查 `开发指南/...状态管理...` + `最佳实践/状态管理最佳实践`。

详见 `memory/harmonyos-docs-first.md`。

---

## 一、架构规范

### 1.1 目录职责

```
entry/src/main/ets/
├── pages/Index.ets          — 唯一 Page，仅负责：Navigation 容器 + NavPathStack 路由 + 全局 State 声明
├── components/              — UI 组件（每个文件一个 @Component）
│   └── sheets/              — Sheet 面板组件（统一通过 SheetOverlay 容器包装）
├── constants/               — 纯常量导出（零逻辑）
│   ├── Colors.ets           — 色彩 token
│   ├── Typography.ets       — 字阶 token
│   ├── Layout.ets           — 间距/尺寸 token
│   ├── AnimationTokens.ets  — Spring 预设 + 时长常量
│   ├── SheetMode.ets        — Sheet 状态枚举
│   ├── GearSort.ets         — 排序枚举
│   └── DesignTokens.ets     — Barrel re-export（保持旧 import 路径兼容）
├── utils/                   — 工具函数（纯函数为主，含个别通用 UI 基础设施 class）
│   ├── ColorUtils.ets       — 颜色计算
│   ├── AnimationUtils.ets   — 通用动画封装（Builder/函数）
│   └── HeadCollapseController.ets — 顶部折叠滚动数学内核（有状态 class，与业务无关）
├── services/                — 业务逻辑层（纯函数，无 class 包装）
│   ├── GearService.ets      — 装备计算（筛选/排序/统计）
│   ├── ChecklistService.ets — 行程清单操作（增删改查，immutable 更新）
│   ├── ItineraryService.ets — 行程日程操作（DayItinerary/RouteSegment clone + CRUD）
│   ├── CategoryService.ets  — 分组操作（增删改、rename 迁移、保护判定）
│   └── PackStore.ets        — 持久化存储（singleton + 防抖 flush + 运行时验证）
└── models/                  — 数据类型定义
    └── PackModels.ets       — 所有 interface/class/enum
```

**Token 导入路径**：直接从具体 token 文件（如 `Colors.ets`、`AnimationTokens.ets`）或通过 `DesignTokens` barrel 导入均可，推荐前者以获得更精确的语义。

### 1.2 代码放置决策树

```
新增代码 → 问自己：

Q1: 这段逻辑是否操作 UI 渲染？
  YES → components/ 下新建或扩展组件
  NO  → Q2

Q2: 是否是纯数据计算/转换/筛选？
  YES → services/ 下对应 Service 文件，导出纯函数
  NO  → Q3

Q3: 是否是可复用的工具/辅助？
  YES → utils/ 下对应工具文件
  NO  → Q4

Q4: 是否是常量/配置/token？
  YES → constants/ 下对应文件
  NO  → 它可能属于 models/（类型定义）或 pages/Index.ets（全局状态协调）
```

### 1.3 铁律

- **Index.ets 不写业务逻辑**：所有计算委托给 services，所有 UI 委托给 components。Index.ets 只做状态声明、路由注册、组件组装。
- **一个文件一个职责**：超过 300 行的组件必须考虑拆分。
- **Service 只导出纯函数**：禁止 class 包装，禁止依赖 this，入参出参明确。
- **新增常量必须归入对应 token 文件**：禁止在组件中硬编码色值/尺寸/时长。
- **Barrel re-export 保兼容**：拆分常量模块后，DesignTokens.ets 统一 re-export，旧 import 路径不断。

### 1.4 组件拆分标准

满足以下任一条件，必须提取为独立组件：

- 被 2 处以上引用
- 自身逻辑超过 150 行
- 具备独立的交互状态（如展开/折叠、选中/取消）
- 是一个完整的 Sheet 面板

---

## 二、设计语言系统

### 2.1 色彩体系

遵循 HarmonyOS 三层 token 架构：基础色 → 语义色 → 组件色。

| 层级 | 说明 | 项目对应 |
|------|------|----------|
| 基础色 (Primitive) | 色板原始值 | `#2D7D46` 山野绿色板 |
| 语义色 (Semantic) | 场景含义 | `PRIMARY_COLOR`、`DANGER_COLOR`、`TEXT_MAIN` |
| 组件色 (Component) | 组件内部直接使用 | 由语义色组合得出，如按钮背景=PRIMARY、按钮文字=CARD_BG |

**色彩使用规则：**

- 主色 `#2D7D46`（山野绿）— 品牌色、操作按钮、选中态、进度
- 页面背景 `#F8F9FA`（羽白）— 全局底色
- 卡片背景 `#FFFFFF` — 纯白无边框，仅以圆角 + 微阴影区分层级
- 文字三级：主 `#1A1A1A` / 次 `#666666` / 辅 `#999999`
- 危险操作 `#E53935` — 删除、不可逆操作
- 强调辅助 `#E8890C`（琥珀）— 数值亮点、趋势标注
- 禁止在组件中直接写 hex 色值，必须引用 Colors.ets 常量

### 2.2 字体排版

基于 HarmonyOS Sans 官方字阶（手机端）：

| 级别 | 字号 (fp) | 字重 | 使用场景 |
|------|-----------|------|----------|
| Display | 40 | Bold (700) | 仅启动/空状态大标题 |
| Title Large | 24 | Bold (700) | 页面主标题 |
| Title Medium | 20 | Medium (500) | 区块标题 |
| Subtitle Large | 18 | Medium (500) | 卡片标题 |
| Subtitle Medium | 16 | Medium (500) | 列表项主文本 |
| Body Large | 16 | Regular (400) | 正文段落 |
| Body Medium | 14 | Regular (400) | 正文默认 |
| Caption | 12 | Regular (400) | 辅助说明、时间戳 |

**项目扩展字阶（对应 Typography.ets）：**

| 级别 | 字号 (fp) | 使用场景 |
|------|-----------|----------|
| Panel Title | 17 | 弹窗/面板/对话框标题 |
| Page Title | 22 | 页面标题（Index/Profile/TripDetail） |
| Body Small | 13 | 次级正文/列表描述/进度文字 |
| Overline | 15 | 加强正文/按钮文字/DayCard 标题 |
| Mini | 11 | 最小辅助文字/hint/tab 标签 |

**排版规则：**

- 字体单位统一 fp（随系统缩放）
- 数字展示启用 `fontFeature: "'tnum'"` 等宽数字
- 行高默认 1.4 倍字号
- 标题与正文间距 ≥ 8vp
- 所有字号/字重从 Typography.ets 常量引用，禁止硬编码

### 2.3 布局系统

遵循 HarmonyOS 8vp 栅格体系：

- **基础单位**：vp（视觉像素），保证跨设备一致
- **栅格基数**：8vp，所有间距取 8 的倍数（8/12/16/20/24/32/40）
- **页面边距**：20vp（手机竖屏）
- **卡片内边距**：20vp
- **区块间距**：24vp
- **元素间距**：12vp（紧凑）/ 16vp（常规）
- **圆角规范**：卡片 20vp / 小卡片 12vp / Chip 18vp / 按钮 12vp

**布局铁律：**

- 禁止使用 px 单位（display 物理像素除外）
- 间距不满足 8 倍数时须注释说明原因
- 所有尺寸常量定义在 Layout.ets

### 2.4 阴影与毛玻璃

| 层级 | 用途 | 参数 |
|------|------|------|
| 无阴影 | 卡片静态态 | 纯白卡片靠圆角区分 |
| 浮起 | 拖拽浮层/弹窗 | `shadow({ radius: 24, color: '#1A000000', offsetY: 8 })` |
| 毛玻璃 | Tab 栏/覆盖层 | `backdropBlur(20)` + 半透明背景 |

### 2.5 交互入口原则

**好设计不需要说明书——功能应该长在用户已有的肌肉记忆里，而非 UI 上。**

如果一个功能需要被用户"找到"才能使用，它已经失败了。三项准则：

| 准则 | 含义 |
|------|------|
| **功能隐形** | 功能存在但不露面，在用户需要的那一刻恰好出现。用户不需要教育、不需要教程、不需要入口 |
| **借力已有行为** | 不是"请用户学新动作"，而是"用户的旧动作顺便触发新功能"。新功能是已有手势/行为的自然延伸 |
| **入口为零** | 不重新设计入口，不额外添加按钮。每想加一个入口/按钮前，先问：能不能不加也能实现？ |

**经典案例：**

| 案例 | 做了什么 | 没做什么 |
|------|---------|----------|
| AirPods 设备自动切换 | 感知用户意图（哪个设备在播放），自动切换音源 | 没有切换按钮、没有设置入口，连"入口"概念都被消灭 |
| iPhone 抬起唤醒 + Face ID | 把"认证"藏进"拿起手机"这个自然动作 | 没有按电源键、没有滑动解锁、没有叫"解锁"的按钮 |
| iOS 边缘滑动返回 | 从屏幕边缘右滑 → 把当前页"推开"，物理直觉直接映射 | 不需要去左上角找返回按钮 |

**共同 DNA：用户不需要知道功能的存在，功能在用户做出直觉行为时恰好发生。**

在 PackCheck 中贯彻此原则——新功能优先考虑：能否通过已有手势触发？能否融入现有导航流程？能否让用户"碰巧发现"而非"被迫学习"？

---

## 三、动效统一规范

### 3.1 核心理念

融合 HarmonyOS「引力体系」六大原则：

1. **自然流畅** — 动画模拟物理世界惯性，Spring 弹性曲线为默认
2. **简洁高效** — 动效服务于信息传达，不为酷炫而动
3. **快速响应** — 用户操作后 100ms 内必须有视觉反馈
4. **连续一致** — 相同操作的动效全局统一
5. **和谐有序** — 多元素同时运动时有主次、有先后（错落）
6. **恰到好处** — 动效持续时间克制，不打断用户心流

### 3.2 时长分级

| 级别 | 时长 | 适用场景 |
|------|------|----------|
| Instant | 0ms | 拖拽跟手、即时状态切换 |
| Short | 100-150ms | 按压反馈、色彩过渡、微交互 |
| Medium | 200-250ms | 面板展开、列表折叠、Tab 切换 |
| Long | 300-400ms | 页面转场、共享元素过渡、数字滚动 |
| Ceremony | 500-1000ms | 仪式动画（新建行程翻转、确认出发弹射） |

### 3.3 曲线选择矩阵

**Spring 曲线（默认选择，覆盖 90% 场景）：**

| 预设 | response | damping | 场景 |
|------|----------|---------|------|
| `SPRING_GENERAL` | 0.35 | 0.80 | 通用状态变化、折叠展开 |
| `SPRING_PRESS` | 0.25 | 0.70 | 按压反馈（快速有弹性） |
| `SPRING_TAB` | 0.40 | 0.75 | Tab 滑动指示器 |
| `SPRING_COUNTER` | 0.30 | 0.75 | 数字变化滚动 |
| `SPRING_SCROLL` | 0.45 | 0.85 | 滚动惯性回弹 |
| `SPRING_HERO_EXPAND` | 0.42 | 0.73 | 共享元素展开 |
| `SPRING_HERO_COLLAPSE` | 0.36 | 0.78 | 共享元素收回 |
| `SPRING_PANEL_ENTER` | 0.38 | 0.72 | 面板弹出（有过冲） |
| `SPRING_PANEL_EXIT` | 0.30 | 0.88 | 面板收回（干脆） |

**Bezier 曲线（仅在 Spring 不适用时降级）：**

| 曲线 | 参数 | 场景 |
|------|------|------|
| Standard | `cubic-bezier(0.40, 0.00, 0.20, 1.00)` | 元素尺寸变化 |
| Decelerate | `cubic-bezier(0.00, 0.00, 0.20, 1.00)` | 元素入场（从外进入视口） |
| Accelerate | `cubic-bezier(0.40, 0.00, 1.00, 1.00)` | 元素退场（离开视口） |

**禁止：**

- `Curve.Linear` — 机械感强，视觉不自然（例外：帧级匀速滚动/拖拽跟手场景允许使用 `CURVE_LINEAR` token）
- `Curve.EaseInOut` — 对称曲线，不符合物理直觉
- 未定义在 AnimationTokens.ets 中的自定义曲线

### 3.4 转场体系

**共享元素转场（一镜到底，首选）：**

```typescript
// 源页面：为元素标记 geometryTransition id
.geometryTransition('gear_card_' + item.id)

// 目标 NavDestination：相同 id 的元素自动匹配
.geometryTransition('gear_card_' + item.id)

// 跳转：必须在 animateTo 内 + animated=false
animateTo({ curve: SPRING_HERO_EXPAND() }, () => {
  this.navStack.pushPath({ name: 'DetailPage' }, false)
})
```

**淡入淡出转场（无共享元素时）：**

```typescript
// NavDestination 添加
.transition(TransitionEffect.OPACITY)
```

**同页就地放大（geometryTransition 第二种语境）：**

同一页面内元素从小卡放大铺满（如核查清单网格态格子 ↔ 全屏聚焦态），与跨页转场参数相反——必须用 `{ follow: true }` 让节点从原几何中心连续插值长大，而非淡入淡出。

```typescript
// 两端为同一 id，且外壳结构 100% 一致（抽公共 Shell 组件复用）
.geometryTransition('zone_' + zone, { follow: true })
```

铁律：(1) 两端共用同一外壳组件（如 `ZoneShell`），结构/样式 100% 对齐，否则 follow 期间会跳变；(2) 隐藏未参与端用 `opacity(0) + hitTest(None)`，禁止 `visibility(Hidden)`（脱离渲染树会丢失配对）；(3) 跨页 Navigation 转场反而禁止 follow:true（破坏文档流），二者不可混用。

**级联入场（列表/菜单）：**

```typescript
// 使用 AnimationUtils.staggeredEntrance
ForEach(items, (item, index) => {
  ItemComponent({ item })
    .translate({ y: this.entered ? 0 : STAGGER_OFFSET_Y })
    .opacity(this.entered ? 1 : 0)
    .animation({
      delay: staggerDelay(index),
      duration: DURATION_NORMAL,
      curve: SPRING_GENERAL()
    })
})
```

### 3.5 手势动效

**按压反馈（所有可点击元素必须有）：**

```typescript
// 使用 AnimationUtils 封装的 pressEffect
.scale({ x: this.pressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
         y: this.pressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
.animation({ curve: SPRING_PRESS() })
.onTouch((e) => {
  if (e.type === TouchType.Down) this.pressed = true
  if (e.type === TouchType.Up || e.type === TouchType.Cancel) this.pressed = false
})
```

**滑动跟手：**

- 拖拽中 `animation({ duration: 0 })` 消除插值延迟
- 松手回弹用 `SPRING_GENERAL`
- 边缘阻尼：超出边界后位移 = 实际位移 × 0.3

**弹性回弹：**

- 超出有效范围时自动回弹到边界
- 使用 `SPRING_SCROLL` 预设

### 3.6 动效禁止事项

1. **禁止 `duration` + Spring 曲线同时使用** — Spring 系列（`springMotion`/`responsiveSpringMotion`/`springCurve`）完全忽略 `duration` 字段，时间由 `response` 参数唯一决定。错落延迟必须用 `delay` 字段：`animateTo({ delay: index * 40, curve: SPRING_GENERAL() }, ...)`
2. **禁止同一属性同时有 `.animation()` 和 `animateTo()`** — 两者竞争会产生卡顿/抖动。选一种：要么 `.animation()` 修饰器驱动（适合滚动联动），要么 `animateTo` 命令式驱动（适合离散事件）
3. **禁止滚动驱动场景使用 `animateTo`**（用 `.animation()` 修饰器）
4. **禁止 `setTimeout` 延迟切换状态实现「动画」**
5. **禁止动画静止态残留非中性值** — rest state 必须是中性值：scale=1.0、opacity=0 或 1。绝不能停在弹性中间值（如 `PRESS_SCALE_BOUNCE`=1.02）
6. **禁止 `Curve.EaseInOut` 冒充 Standard 曲线** — `Curve.EaseInOut` 实际是 `cubic-bezier(0.42, 0, 0.58, 1.0)`（对称曲线），HarmonyOS Standard 是 `cubic-bezier(0.4, 0, 0.2, 1.0)`（非对称减速）。使用 `curves.cubicBezierCurve(0.4, 0.0, 0.2, 1.0)` 生成正确的 `ICurve`

---

## 四、组件封装规范

### 4.1 通用动画工具（AnimationUtils.ets）

所有通用动画模式统一封装在 `utils/AnimationUtils.ets`，组件直接调用：

| 工具 | 说明 |
|------|------|
| `pressEffect()` | 按压三段式 scale 动画状态管理 |
| `staggeredEntrance()` | 列表错落入场参数生成 |
| `counterAnimation()` | 数字滚动动画驱动 |
| `panelTransition()` | 面板展开/收回统一动画 |
| `sharedElementPush()` | 共享元素 push 转场封装 |
| `sharedElementPop()` | 共享元素 pop 转场封装 |

### 4.2 Sheet 面板统一模式

所有 Sheet 面板必须：

1. 使用 `SheetOverlay` 作为容器（自带遮罩 + Spring 弹出/收回 + 手势下滑关闭）
2. 通过 `SheetMode` 枚举切换
3. 面板高度由内容决定，maxHeight 不超过 85%
4. 进入时背景施加 `scale(0.94)` + `blur(12)` 消散效果

### 4.3 顶部折叠统一控制器（HeadCollapseController.ets）

项目内所有「顶部区域随内容滚动而折叠」的场景（首页 hero、装备库 header、行程详情日期行）统一走 `utils/HeadCollapseController.ets`，**禁止**各页面再手写一套 scrollOffset→progress 的滚动数学。

**抽象边界（关键）**：控制器只统一「滚动数学内核」——progress 计算、跟手 1:1 映射、松手就近吸附、曲线分流、强制折叠旁路；**不统一 head 渲染**。项目存在两种互不兼容的折叠布局范式，对控制器完全透明：

- **inline 塌缩范式**（TripDetailPage）：head 是滚动内容的真实兄弟节点，折叠时高度归零让位。**navbar 标题同帧参与呼吸**：不只日期行塌缩，navbar 标题也随同一 progress 插值字号（20→17）+ 下沉（4→0），走同一折叠曲线，避免「下半身塌缩、上半身 navbar 死板不动」的割裂感；返回箭头作为导航功能锚点保持稳定，不参与呼吸。
- **overlay 定高变形范式**（HomePage / GearPage）：head 用 `.position` 浮在滚动容器上，靠内部元素字号/透明度变形。

两种布局各自从 `onChange` 回调拿 `progress(0~1)` 去插值自己的 head，避开「两种布局强行统一」的坑。

**体验范式：对齐 iOS Large Title。** 跟手期 progress 严格 1:1 实时映射（零吸附、不抢手感）；松手惯性停在 (0,1) 中间态时就近吸附到 0 或 1，绝不留半折叠残缺态。

**⚠️ 刷新陷阱（铁律）**：控制器是普通 class，改内部字段**不触发** ArkUI re-render。故消费页面**必须**持有自己的 `@State progress` 镜像，由 `onChange` 回调推动更新，渲染一律读 `@State` 镜像、**绝不**直接读 `controller.progress()`。`animateTo` 需 `UIContext`，控制器无 `getUIContext()`，必须由页面经 config 注入。

**接入三件套**：① 页面持 `headController` 实例 + `@State` 进度镜像；② 滚动容器挂 `handleScroll`（Grid 用 `.onScroll`、List/Scroll 用 `.onDidScroll`）+ `handleScrollStop`（挂 `.onScrollStop` 补吸附）；③ 旁路强折叠（聚焦/搜索展开）调 `setForcedCollapsed(true)`——但若锁定态的视觉（背景/模糊）与 `progress=1` 语义不等价（如 GearPage 搜索态是纯背景零模糊 ≠ progress=1 的半透明毛玻璃），则**保留各自视觉特判**、不强行收口到控制器。

### 4.4 组件接口设计原则

| 装饰器 | 使用场景 |
|--------|----------|
| `@Prop` | 父→子单向数据流，子组件只读（深拷贝，注意性能） |
| `@Link` | 父↔子双向绑定（简单值类型、开关状态） |
| `@StorageLink` | 全局持久化状态（极少使用，仅 PackStore 层面） |
| `@BuilderParam` | 插槽模式，父注入 UI 片段 |
| `@State` | 组件内部私有状态 |

**接口设计铁律：**

- 组件 props 不超过 8 个（超过说明职责太重，需要拆分）
- 回调用 `() => void` 或明确参数类型，禁止 `Function`
- 可选参数必须有合理默认值

### 4.6 @Prop→@State 内化模式

当子组件拥有表单编辑状态时，使用「内化模式」解耦父子：

- **禁止** 父组件为子组件的每个表单字段持有 `@State` + `onChange` 回调（N 字段 = 2N 个 props = God Component）
- **推荐** 子组件通过 `initialXxx` 普通 prop 接收初始值，`aboutToAppear()` 中赋给内部 `@State`，编辑过程完全自治
- **提交** 通过一个参数化回调 `onSave: (field1, field2, ...) => void` 一次性传回所有编辑结果
- **验证** 由子组件自行完成（如 `@State errorText`），父组件只关心最终合法数据

```typescript
// 子组件
initialName: string = '';     // 普通 prop，非 @Prop
@State name: string = '';     // 内部自治
onSave: (name: string, weight: string) => void = () => {};

aboutToAppear() {
  this.name = this.initialName;
}
```

适用场景：EditItemPanel、EditGearPanel、DayFormSheet、SegmentFormSheet、TripCeremonyCard。

### 4.5 组件命名规范

| 类别 | 命名 | 示例 |
|------|------|------|
| 页面级组件 | `XxxPage` | `HomePage`、`GearPage` |
| 功能组件 | 名词性描述 | `WeightGauge`、`AssetTrendCard` |
| Sheet 面板 | `XxxSheet` | `GearFormSheet`、`TripFormSheet` |
| 工具/覆盖 | `XxxOverlay` / `XxxPanel` | `SheetOverlay`、`EditGearPanel` |

---

## 五、代码质量守则

### 5.1 ArkTS 类型安全

- 箭头函数参数必须标注类型：`(item: GearItem) => item.id`，禁止 `(item) => item.id`
- 禁止 `any` 类型
- 禁止无类型对象字面量导出（用 const + 明确类型）
- `ForEach` 的 key generator 必须包含所有影响渲染的维度

### 5.2 状态管理

- 最小化 @State 数量 — 能计算得出的值用 getter，不声明 State
- 深层对象变更必须创建新引用（immutable update），不直接修改属性
- 状态变更集中在 animateTo 回调内（保证动画正确触发）

### 5.2.1 clone helper 铁律

对于含 3 个以上字段的 interface（DayItinerary、RouteSegment、TicketInfo、ChecklistItem、TripChecklist），**禁止手写对象字面量**，必须通过 clone helper 创建：

- `cloneDayItinerary(source, overrides?)` / `cloneRouteSegment(source, overrides?)` / `cloneTicketInfo(source, overrides?)` — 在 ItineraryService.ets
- `cloneChecklistItem(source, overrides?)` — 在 ChecklistService.ets
- `createChecklist(title, date, dateAt, destination)` — 在 ChecklistService.ets

**原因**：N 处手写字面量 + 新增字段 → 遗漏概率随 N 指数增长。clone helper 保证字段一处定义、全局一致。

### 5.2.2 事务化更新模式

涉及多个关联数据源的操作（如 category 删除需同步更新 categories + gears + checklists），必须使用「先构建完整新状态 → 批量持久化 → 全部成功后一次性赋值 @State」模式，中间任一 save 失败则 return 不更新 UI：

```typescript
// ✅ 正确：事务化
const nextCategories = deleteCategory(categories, target);
const nextGears = migrateGearsOnDelete(gears, target, fallback);
try {
  await store.saveCategories(nextCategories);
  await store.saveGears(nextGears);
} catch { return; } // 失败不更新 UI
this.categories = nextCategories;
this.gears = nextGears;
```

### 5.3 命名规范

| 类别 | 风格 | 示例 |
|------|------|------|
| 组件 | PascalCase | `TripCeremonyCard` |
| 函数/方法 | camelCase | `toggleItemInChecklists()` |
| 常量 | UPPER_SNAKE_CASE | `PRIMARY_COLOR` |
| 变量/参数 | camelCase | `selectedGearId` |
| 布尔值 | is/has/should 前缀 | `isExpanded`、`hasItems` |
| 文件 | PascalCase.ets | `GearService.ets` |

### 5.4 注释规范

- 文件头部一行说明职责
- 公开函数必须 JSDoc 注释（说明入参/出参/用途）
- 复杂算法注释思路，不注释「做了什么」（代码本身表达）
- 禁止注释掉的代码残留（直接删除，git 有历史）

---

## 六、提交与验证流程

### 6.1 改动流程

```
1. 理解需求 → 2. 输出方案 → 3. 等待确认 → 4. 最小改动实现
→ 5. 构建验证 → 6. 立即 commit → 7. 继续下一步
```

### 6.2 构建命令

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon
```

### 6.3 Commit 规范

```
<type>: <简明描述>

type = feat | fix | refactor | style | docs | chore
```

示例：
- `feat: 新增 Typography.ets 字阶常量`
- `refactor: 提取按压动画到 AnimationUtils`
- `fix: 修复共享元素转场闪烁`

### 6.4 不可触碰的底线

- 不注释报错代码绕过编译
- 不造假数据跑通逻辑
- 不在修 bug 时顺手重构
- 不 hardcode 色值/尺寸/时长
- 不在 Index.ets 里写超过 10 行的业务逻辑函数
- 不手写 DayItinerary/RouteSegment/TicketInfo/ChecklistItem 对象字面量（走 clone helper）

---

## 七、HarmonyOS 平台适配

### 7.1 响应式布局

当前 PackCheck 以手机竖屏为主，但预留平板/折叠屏扩展能力：

- 使用 vp 单位保证物理尺寸一致
- 关键布局参数定义在 Layout.ets（未来按 breakpoint 分档）
- `position()` 定位的组件必须监听 `onAreaChange` 适配屏幕变化

### 7.2 备份恢复

PackCheck 使用 `EntryBackupAbility`（BackupExtensionAbility）接入系统备份恢复。数据全部存储在 Preferences（`packcheck_store`），位于 `el2/base/preferences/` 默认备份范围内，框架自动完成文件级备份恢复。`onBackupEx`/`onRestoreEx` 仅用于记录结构化日志和版本信息，不需要手动序列化数据。

如未来迁移到 RDB 或其他存储，需在 `backup_config.json` 的 `includes` 中显式添加路径，并在 `onRestoreEx` 中实现数据迁移逻辑。

### 7.3 深色模式预留

- 色彩全部走 Colors.ets 常量（未来切换只改一处）
- 已有 `resources/dark/element/color.json` 深色资源目录
- 禁止在组件中直接写色值，确保未来一键切换

### 7.4 无障碍

- 可操作元素最小触控区域 48×48 vp
- 图标按钮添加 `.accessibilityText()` 描述
- 对比度：文字与背景对比度 ≥ 4.5:1

---

## 八、结构防腐铁律（每次开发必读）

> 本章是 PackCheck 抵抗"代码结构腐化"的硬边界，治理对象：**上帝组件、跨文件重复、封装与落地脱节、死代码与结构性碍眼债、文件位置混乱**。
> 这五类债不会让构建失败，所以最容易被一次次"先跑通"累积。**每次新增/修改代码，都必须对照本章自查；违反即返工，不接受"能跑就行"。**

### 8.1 防上帝组件

判定一个组件是否正在变成"上帝组件"，任一命中即触发治理动作：

| 信号 | 阈值 | 动作 |
|------|------|------|
| 文件行数 | > 300 行 | 必须评估拆分（先拆纯展示子视图 + 下沉计算到 service） |
| `@State` 数量 | > 10 个 | 检查是否有可计算派生值（用 getter/纯函数替代 State） |
| props 数量 | > 8 个 | 用 interface 聚合 + 统一 action 回调收口 |
| 一个方法行数 | > 60 行 | 抽纯函数到 services/，组件内只留 UI 编排 |
| 同一组件同时管理 ≥ 3 类不相关交互状态 | — | 按交互域拆分子组件 |

**拆分优先级（从低风险到高风险）**：① 纯展示片段（空状态、行、chip）→ 独立无状态 @Component；② 纯计算（筛选/排序/统计/格式化）→ 下沉 services/ 纯函数；③ 自带交互状态的完整区块 → 独立有状态组件。**先做 ①②（零风险），③ 谨慎。**

### 8.2 ⚠️ 何时"不该拆"（反直觉，最高优先级，违反会破坏功能）

拆分不是越多越好。以下场景**强制保留在原组件内**，强拆会破坏动画时序 / 依赖收集 / 共享元素配对，或踩 ArkUI `@Builder` 跨组件 `this` 丢失坑（见 MEMORY 避坑 #8）：

| 不该拆的场景 | 原因 |
|------|------|
| **多 @State + setTimeout/Timer 编排的动画状态机**（如 TripCeremonyCard 仪式动画） | 跨组件后状态机时序错乱、`aboutToDisappear` 清 timer 链断裂（避坑 #39） |
| **geometryTransition 共享元素的两端**（如 ZoneShell 网格态↔聚焦态） | 拆开后两端外壳结构无法保证 100% 一致，follow 期间跳变（§3.4 铁律） |
| **拖拽 / 长按浮层**（FloatingGroupCard、行程托盘、聚焦拖拽层） | 手势坐标系、`duration:0` 跟手、命中检测依赖同一坐标空间 |
| **页面级状态协调容器**（Index.ets） | 它就是协调层，"瘦"的方式是下沉计算而非拆容器 |
| **依赖父级 @State 闭包的内联 @Builder** | 跨组件 `@Builder` 回调丢 `this`（避坑 #8/#14） |

**判定流程（第一性原理）**：拆之前先问——拆出去后，这段逻辑还能拿到它依赖的状态/坐标系/转场配对吗？答案存疑就**不拆**，改为"下沉纯计算 + 原地保留 UI 编排"。

### 8.3 防跨文件重复（grep-before-add 铁律）

**新增任何函数 / 常量 / @Builder / 子视图前，必须先 `grep` 同名或同义关键字，确认现有实现不能复用。**

- 计算逻辑：先查 services/ 是否已有同义纯函数（如 `groupByZone`/`totalGearWeight`），有则复用，禁止在组件里重写一份。
- 常量：先查 constants/ 对应 token 文件，禁止换个名字重新定义（如又写一个 `0.96` 而不用 `PRESS_SCALE_DOWN`）。
- UI 片段：视觉/结构相同的片段抽公共组件；**但视觉不同不要强行合并**（曾误判 CompanionChip≈FootprintChip，逐字核对后视觉不同，保持独立才对）。合并前必须逐字对比样式，不凭"看起来像"。

### 8.4 防封装与落地脱节

项目已有的封装（`AnimationUtils`、`HeadCollapseController`、`SheetOverlay`、各 token 文件）是**唯一事实源**，禁止"绕过封装手写一份"：

- 顶部随滚动折叠 → 必须走 `HeadCollapseController`，禁止各页面重写 scrollOffset→progress 数学（§4.3 + 避坑 #46）。
- 按压 / 错落入场 / 数字滚动 / 面板转场 → 走 `AnimationUtils`，禁止各处手抄一遍 onTouch+scale 三段式。
- Sheet 面板 → 走 `SheetOverlay` 容器，禁止裸写遮罩 + translateY。
- 色值 / 字号 / 间距 / 时长 / 曲线 → 走 constants/ token，禁止硬编码（§2、§3）。

**反向约束**：封装层新增能力后，必须真的在落地点用上；只导出不消费的封装 = 死代码（见 8.5）。

### 8.5 防死代码与结构性碍眼债

- **不可达代码即时清理**：入口方法无任何调用点 / 条件永不为真 / State 永不被置位 → 整条链路（含其专用 @State、方法、Builder、store 方法、持久化 key、常量）一并删除，跨文件追到底。清理后全仓 `grep` 关键字确认零残留 + 构建通过 + commit（实战参考：targetWeightGram/WeightTargetEditor 链路清理）。
- **只导出不消费的常量/函数**：删除时同步检查 barrel re-export（`DesignTokens.ets`）（避坑 #31）。
- **禁止注释掉的代码残留**：直接删，git 有历史（§5.4）。
- **提交前自查**：本次改动有没有留下孤儿 import、空方法、不再触发的分支？有则清。

### 8.6 防文件位置混乱

新增文件**先对照 §1.1 职责表 + §1.2 决策树定位**，放错位置即返工：

- 纯计算 → `services/`（纯函数，无 class 包装、无 this 依赖）。
- UI 组件 → `components/`，按页面域分子目录（`components/home/`、`components/gear/`、`components/sheets/`）。
- 常量 → `constants/` 对应 token 文件 + `DesignTokens.ets` barrel re-export。
- 工具 → `utils/`。类型 → `models/`。全局协调 → `pages/Index.ets`。
- 子组件从 `components/<域>/` 引用常量需多一层相对路径（`../../constants/`）。
- 新建子目录前先 `ls` 确认父目录存在（曾因 home/ 不存在写入 ENOENT）。

### 8.7 结构防腐自查清单（提交前必过）

- [ ] 改动的组件没有突破 8.1 任一阈值？突破了有没有拆/下沉？
- [ ] 该不该拆，对照 8.2 确认没有强拆动画状态机 / 转场两端 / 手势浮层？
- [ ] 新增的函数/常量/UI 片段，grep 过没有重复实现？
- [ ] 用的是现有封装（AnimationUtils/HeadCollapseController/SheetOverlay/token），没有绕过手写？
- [ ] 本次改动没留死代码（孤儿 import、空方法、不可达分支、只导出不消费的封装）？
- [ ] 新增文件放对目录了（对照 §1.1/§1.2），barrel re-export 补了？

---

## 附录：快速查阅

### A. 文件新增检查清单

新增任何文件前确认：

- [ ] 放对目录了吗？（对照 1.1 职责表）
- [ ] 有对应的 barrel re-export 吗？
- [ ] 文件头有一行职责注释吗？
- [ ] 命名符合规范吗？

### B. 动效实现检查清单

实现任何动画前确认：

- [ ] 用的是 AnimationTokens 里的预设曲线吗？
- [ ] 时长符合 3.2 分级吗？
- [ ] 有按压反馈吗？（可点击元素）
- [ ] 没有 Spring + duration 混用吗？（Spring 忽略 duration，错落用 delay）
- [ ] 静止态是中性值吗？（scale=1.0，opacity=0 或 1）
- [ ] 同一属性没有同时 `.animation()` + `animateTo()` 吧？
- [ ] Bezier 曲线用的 `curves.cubicBezierCurve()` 而非 `Curve.EaseInOut` 吧？
- [ ] 颜色都从 Colors.ets token 引用了吗？（包括 `TRANSPARENT`）

### C. 组件提交检查清单

提交组件代码前确认：

- [ ] `build()` 有显式根容器吗？（禁止裸 `if/else`、裸 `@Builder` 调用、裸 `ForEach` 作为 build 根节点——隐式 Column 会导致内容居中，避坑 #51）
- [ ] 箭头函数参数有类型标注吗？
- [ ] 色值/尺寸从常量引用了吗？
- [ ] @State 数量合理吗？（不超过 10 个）
- [ ] props 不超过 8 个吗？
- [ ] TabContent 内的子组件入场动画是否依赖 `onAppear`？（TabContent keep-alive 下 onAppear 不重触发，需用 nonce 驱动，避坑 #52）
- [ ] 构建通过了吗？
