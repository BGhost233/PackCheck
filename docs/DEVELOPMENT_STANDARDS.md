# PackCheck 开发规范

> 本文档是 PackCheck 项目的唯一开发标准，所有后续开发必须遵循。
> 融合华为 HarmonyOS 官方设计体系（引力体系 + 自然交互）与项目实战经验。

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
├── utils/                   — 工具函数（纯函数，无状态）
│   ├── ColorUtils.ets       — 颜色计算
│   └── AnimationUtils.ets   — 通用动画封装（Builder/函数）
├── services/                — 业务逻辑层（纯函数，无 class 包装）
│   ├── GearService.ets      — 装备计算（筛选/排序/统计）
│   ├── ChecklistService.ets — 行程清单操作（增删改查，immutable 更新）
│   └── PackStore.ets        — 持久化存储
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

### 4.3 组件接口设计原则

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

### 4.4 组件命名规范

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

---

## 七、HarmonyOS 平台适配

### 7.1 响应式布局

当前 PackCheck 以手机竖屏为主，但预留平板/折叠屏扩展能力：

- 使用 vp 单位保证物理尺寸一致
- 关键布局参数定义在 Layout.ets（未来按 breakpoint 分档）
- `position()` 定位的组件必须监听 `onAreaChange` 适配屏幕变化

### 7.2 深色模式预留

- 色彩全部走 Colors.ets 常量（未来切换只改一处）
- 已有 `resources/dark/element/color.json` 深色资源目录
- 禁止在组件中直接写色值，确保未来一键切换

### 7.3 无障碍

- 可操作元素最小触控区域 48×48 vp
- 图标按钮添加 `.accessibilityText()` 描述
- 对比度：文字与背景对比度 ≥ 4.5:1

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

- [ ] 箭头函数参数有类型标注吗？
- [ ] 色值/尺寸从常量引用了吗？
- [ ] @State 数量合理吗？（不超过 10 个）
- [ ] props 不超过 8 个吗？
- [ ] 构建通过了吗？
