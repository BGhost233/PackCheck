# 塔科夫式配装系统 - 设计 Spec

> 版本：v4 - 2026-06-10
> 状态：📝 草稿（待用户 review）
> 上位文档：`docs/vision/2026-06-04-product-vision-and-restructure.md`（纲领 S4）
> 技术底座：`docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md`（S6 / S3.5）
> 本文档是纲领 S4「产品第二灵魂」在工程+交互层的完整落地方案。
>
> **修订历史**：
> - v1 -> v2：吸收第一轮审查（Everest），11 项修正。详见附录 C。
> - v2 -> v3：吸收第二轮审查（Everest），13 项修正。主要变更：NavDestinationMap 集成、GearPickerSheet 反馈重设计、空态渐进式引导、FAB 视图绑定、临时添加流程、共享信息区、Zone 颜色系统、勾选即时反馈、触控区规范。
> - v3 -> v4：吸收第三轮审查（Everest），14 项修正。主要变更：路径 A 转场定义、TempGearMiniSheet 改内联覆盖层、装备移除退场动画、Sheet 空态简化（去掉"去装备库"）、Zone 固定网格位置、品类 tab 单选+sticky、视图切换状态声明、long-press ActionSheet 设计、引导态过渡序列、清单视图 group 回译、FAB z-index 定义、底部安全区。

---

## 0. 定位与目标

### 0.1 它是什么

塔科夫式配装系统是 PackCheck 的**第二灵魂**——将「出行前选装备」从枯燥的多选列表升维为「按身体部位 x 分层填槽」的配装游戏。用户像逃离塔科夫那样给角色（自己）按部位穿戴装备，科学打包、不漏带，同时获得游戏化的爽感。

### 0.2 它解决什么

- **科学打包不漏带**：结构化槽位 = 心智模型外显，一眼看到哪个部位/层级还空着
- **枯燥多选 -> 配装游戏**：从 checkbox list 升级为视觉化填槽，留存 & 参与感质变
- **户外分层知识可视化**：新手用户自然理解「贴身->保暖->防风->羽绒」的分层逻辑
- **配完即行程记录**：配装结果直接成为 TripChecklist，无额外录入步骤

### 0.3 成功标准

- 用户配完装备后能感受到「像玩游戏一样打包」的爽感
- 配装完成到出发携带清单的路径为 0 步（配装结果 = 清单）
- 空槽位自然引导发现遗漏，比旧清单「检查是否忘带」的认知负担低一个量级

---

## 1. 产品决策汇总（已确认）

| # | 决策点 | 结论 | 依据 |
|---|--------|------|------|
| 1 | 入口定位 | **双视图并存**：配装视图（默认）+ 清单视图 | packing 和 checking 是两种心智模型，不强行合并 |
| 2 | 触发时机 | 新建行程时自动进入 + 行程详情直接打开 | 两者都要，不限制入口 |
| 3 | 布局形态 | **卡片式区域网格**（2 列，每个 BodyZone 一张卡片） | 纯卡片无人体拓扑，降低实现复杂度，适配不同屏幕 |
| 4 | 选装交互 | FAB -> GearPickerSheet -> 自动落槽 + Sheet 内实时反馈 | 反馈在用户焦点所在位置（Sheet 内），而非被遮罩的背景 |
| 5 | 打勾机制 | tap 装备项 = 打勾/取消勾选 | 保留 long-press -> 展开操作菜单（ActionSheet） |
| 6 | 分层策略 | **系统预设层级**（Base/Mid/Shell/Insulation/Accessory） | 不允许用户自建层级，降低认知负担 |
| 7 | 品类策略 | **保留现有品类扩展能力**，预设 13 项 + 自定义品类 fallback 到 Misc | `slotHintForCategory()` 已有 fallback 机制 |
| 8 | 阶段二装包 | **一期不做** | 控制一期范围，先把阶段一做透 |
| 9 | 拖拽排序 | **一期不做** | 自动落槽已满足核心需求 |
| 10 | 数据迁移 | **零迁移** | 复用 ChecklistItem.fromGearId/group/checked |
| 11 | 空态策略 | **渐进式**：Zone 卡片按需出现，不预渲染空 Zone | 新行程不显空旷 + 每添加一件装备「解锁」一个区域 |
| 12 | 默认视图 | **始终默认配装视图**，不记忆上次选择 | 新功能曝光 + 简化状态管理 |

---

## 2. 信息架构 - 横轴 x 纵轴

### 2.1 横轴：BodyZone（身体部位 / 容器区域）

```
enum BodyZone {
  Head       = 'head'     // 头部：帽子、头灯、墨镜
  UpperBody  = 'upper'    // 上身：内衣->中层->外壳
  LowerBody  = 'lower'    // 下身：内裤->裤子->雪裤
  Feet       = 'feet'     // 脚部：袜子->鞋->冰爪
  Carry      = 'carry'    // 背负：背包系统
  Sleep      = 'sleep'    // 睡眠：睡袋+垫子+帐篷
  Misc       = 'misc'     // 杂项：证件/电力/饮食/摄影/急救/洗护/其他
}
```

**布局规则**：
- 2 列网格，每个 BodyZone 占一个卡片格
- **Zone 卡片按人体固定网格位置排列**，顺序固定：Head -> UpperBody -> LowerBody -> Feet -> Carry -> Sleep -> Misc
- **Misc 卡片 span 全宽**（占据 2 列），因为它收纳 7+ 个品类
- 其余 6 个 Zone 各占 1 列
- **空 Zone 不渲染卡片内容，但保留 0 高度占位**——确保其他 Zone 不因空 Zone 出现而布局跳动。当某个 Zone 获得第一件装备时，卡片在其固定网格位置以动画展开（渐进式解锁）
- 无论装备添加顺序如何，Zone 的空间位置关系保持不变（头部左上、脚部中部、杂项底部全宽）。这符合用户的空间心理模型

**Zone 颜色系统**（定义在 `Colors.ets` 中）：

| Zone | Token 名 | 色值 | 用途 |
|------|----------|------|------|
| Head | `ZONE_HEAD_COLOR` | #42A5F5 蓝 | 卡片标题色 + GearPickerSheet Zone chip |
| UpperBody | `ZONE_UPPER_COLOR` | #EF5350 暖红 | 同上 |
| LowerBody | `ZONE_LOWER_COLOR` | #5C6BC0 靛蓝 | 同上 |
| Feet | `ZONE_FEET_COLOR` | #8D6E63 棕 | 同上 |
| Carry | `ZONE_CARRY_COLOR` | #FFA726 橙 | 同上 |
| Sleep | `ZONE_SLEEP_COLOR` | #7E57C2 紫 | 同上 |
| Misc | `ZONE_MISC_COLOR` | #78909C 灰蓝 | 同上 |

Zone 颜色贯穿配装视图（卡片标题）+ GearPickerSheet（目标 Zone chip），形成一致的视觉关联。

**Zone 图标**（每个卡片标题旁的辨识 icon）：

| Zone | 图标 |
|------|------|
| Head | `sys.symbol.face.smiling` |
| UpperBody | `sys.symbol.tshirt` |
| LowerBody | `sys.symbol.figure.walk` |
| Feet | `sys.symbol.shoeprints.fill` |
| Carry | `sys.symbol.backpack` |
| Sleep | `sys.symbol.tent` |
| Misc | `sys.symbol.square.grid.2x2` |

> 注：以上为建议 icon，实际开发时按 HarmonyOS 可用的 SymbolGlyph 资源确认。

### 2.2 纵轴：LayerOrder（分层）

```
enum LayerOrder {
  Base       = 1   // 贴身层（内衣/袜子）
  Mid        = 2   // 保暖层（抓绒/羽绒内胆）
  Shell      = 3   // 防护层（硬壳/雨衣/防风裤）
  Insulation = 4   // 隔绝层（羽绒外套/厚棉服）
  Accessory  = 9   // 配件层（帽子/手套/墨镜/头灯）
}
```

**分层展示规则**：
- 各 BodyZone 卡片内部，装备按 LayerOrder 升序排列
- **仅衣物类（UpperBody/LowerBody）明确展示层级 badge**，其余区域 badge 隐藏
- 层级 badge 是独立 tap target：tap badge -> 弹出层级选择 popup（5 个选项）
- **触控规范**：badge 可见区域至少 20x20vp，加 padding 达到 48x48vp 触控热区，使用 `hitTestBehavior(HitTestMode.Block)` 防止穿透到装备行的 tap 勾选
- 用户不可自建层级——系统预设 5 级已覆盖户外分层穿衣全部场景

### 2.3 品类 -> 槽位映射（CATEGORY_SLOT_MAP）

已在 `constants/GearLoadout.ets` 中实现，预设 13 个品类一一映射：

| 品类 | Zone | Layer |
|------|------|-------|
| 证件 | Misc | Accessory |
| 穿着·上身 | UpperBody | Mid |
| 穿着·下身 | LowerBody | Base |
| 穿着·配件 | Head | Accessory |
| 背负系统 | Carry | Accessory |
| 行走系统 | Feet | Base |
| 睡眠系统 | Sleep | Accessory |
| 饮食系统 | Misc | Accessory |
| 电力系统 | Misc | Accessory |
| 摄影系统 | Misc | Accessory |
| 安全急救 | Misc | Accessory |
| 清洁洗护 | Misc | Accessory |
| 其他 | Misc | Accessory |

**自定义品类处理**：用户创建的不在上表中的品类，通过 `slotHintForCategory()` 的 fallback 机制自动落入 Misc/Accessory。现有品类增删改排序功能完全保留。

### 2.4 Misc Zone 内部结构：品类子分区

Misc 收纳品类多，内部按品类做子分区避免无差别平铺：

```
+----------------------------------------------+
|  杂项                                         |
|                                              |
|  > 证件                                      |
|    身份证 [v]  -  钱包                        |
|                                              |
|  > 饮食系统                                   |
|    炉头 - 气罐 [v] - 钛锅 - 餐具             |
|                                              |
|  > 电力系统                                   |
|    充电宝 20000mAh [v] - Type-C 线            |
|                                              |
|  > 摄影 - 安全急救 - 洗护 - 其他             |
|    相机 - 头疼药 - 牙刷 - 防晒霜              |
+----------------------------------------------+
```

**规则**：
- 子分区标题 = 品类名，右侧显示该品类下装备计数
- 装备 <= 2 件的品类合并为最后一个综合行（减少碎片感）
- 子分区默认展开；品类 > 4 个时低频品类可折叠
- 后续迭代可考虑将「饮食系统」升格为独立 Zone

---

## 3. 用户操作时间线（进入 -> 操作 -> 退出）

本章按用户从打开行程到退出的完整时间线组织，确保每个触点的交互无断层。

### 3.1 进入行程详情

```
路径 A：新建行程
  TripFormSheet -> 填写基本信息 -> 确认 -> pushPathByName('TripDetailPage') -> 进入行程详情
  转场定义：
    - NavDestination 使用 .transition(TransitionEffect.OPACITY) 保持与现有一致
    - push 时 animateTo({ curve: SPRING_HERO_EXPAND() }, () => { pushPath(..., false) })
    - 主页内容同步施加 contentScale = 0.94 + contentBlur = 12 景深（复用现有动画逻辑）
    - 无共享元素源（TripFormSheet 不是行程卡片），因此仅靠 opacity + 景深过渡

路径 B：已有行程
  HomePage 行程列表 tap -> geometryTransition 一镜展开 -> 进入行程详情
  转场定义：
    - geometryTransition('trip-' + id) 驱动共享元素一镜到底展开
    - push 和 pop 时主内容同步施加 scale(0.94) + blur(12) 景深
    - 复用现有 pushChecklistDetail() / returnToHome() 的动画逻辑
```

两条路径都进入同一个 `TripDetailPage`（NavDestination），默认显示配装视图。

### 3.2 行程详情页布局

```
+--------------------------------------+
|  < 返回    武功山徒步          ...   |  <- 导航栏
|                                      |
|  2026年7月15日                        |  <- 共享信息区
|  武功山 - 22km - 海拔1918m - 12h     |  （tap -> ProfileEditSheet）
|                                      |
|  [配装视图]  [清单视图]               |  <- SegmentButton
|                                      |
|  +----------------------------------+|
|  |     当前激活视图的内容             ||
|  +----------------------------------+|
+--------------------------------------+
```

**共享信息区**（位于导航栏和分段控件之间）：
- 第一行：行程日期（tap -> DatePicker 编辑）
- 第二行：结构化字段摘要——目的地 / 里程 / 海拔 / 时长（渐进式 chip，tap -> ProfileEditSheet）
- 两个视图共享此区域，切换视图时不重绘
- 无数据时不显示此区域（仅行程标题在导航栏中）

**分段控件**：
- 默认选中「配装视图」
- 每次进入始终默认配装视图（不记忆上次选择）
- 切换时下方内容区交叉淡入淡出（opacity + Spring(0.35, 0.8)），上方信息区不动

**视图切换状态管理**：
- 使用 `if/else` 条件渲染（`activeView === 'loadout'` 分支）
- 非当前视图的组件被销毁，切换回时重建
- **设计选择**：清单视图的状态（折叠分组、滚动位置）不保持——每次进入清单视图都是一次「新的查看」。这不是 bug，是有意为之。理由：配装视图是主力视图，清单视图是辅助确认用途，无需记忆状态

### 3.3 配装视图：全局空态

首次进入全新行程（无装备）时：

```
+--------------------------------------+
|                                      |
|                                      |
|         [backpack icon]              |  <- 大图标
|                                      |
|    开始为这次行程配装吧               |  <- 引导文案
|    从装备库中选择带哪些装备            |
|                                      |
|       +--------------+               |
|       |  + 添加装备   |               |  <- 居中引导按钮（大号，非 FAB）
|       +--------------+               |
|                                      |
+--------------------------------------+
```

**核心规则**：
- 无装备时不显示任何 Zone 卡片、不显示进度条、不显示 FAB
- 居中引导按钮（非 FAB）：视觉焦点集中，用户不会困惑
- 用户添加第一件装备后，切换为正常布局（Zone 卡片 + FAB + 进度条）——过渡动画见 S3.11

### 3.4 配装视图：有装备状态

用户添加装备后的正常布局：

```
+--------------------------------------+
|  已装包 5/18  ====......  28%        |  <- 进度条
|                                      |
|  +----------+  +----------+         |
|  | [face] 头部 | [shirt] 上身 |      |  <- 只显示有装备的 Zone
|  | [墨镜 v] |  | [速干T]  |         |
|  | [头灯]   |  | [抓绒 v] |         |
|  |          |  | [硬壳]   |         |
|  +----------+  +----------+         |
|  +----------+                        |
|  | [tent] 睡眠 |                     |
|  | [帐篷]   |                        |
|  | [睡袋 v] |                        |
|  +----------+                        |
|  +-------------------------+         |
|  | [grid] 杂项              |         |
|  | > 饮食: [炉头][气罐v]    |         |
|  | > 电力: [充电宝v]        |         |
|  +-------------------------+         |
|                                      |
|              padding ~32vp           |  <- 底部安全区留白
|                          [+]         |  <- FAB（右下角悬浮）
+--------------------------------------+
```

**Zone 卡片固定网格位置**：
- Zone 卡片按 BodyZone 固定网格位置排列（Head 左上 -> Misc 全宽底部），无论装备添加顺序如何
- 空 Zone 不渲染卡片内容，但在网格中保留 0 高度占位（确保其他 Zone 不因空 Zone 出现而跳动）
- 当某个 Zone 获得第一件装备时，卡片在其固定位置以 staggered 动画出现（scale + fadeIn + height 展开）
- 游戏化正反馈：每添加一件装备有可能「解锁」一个新 Zone 区域

**进度指示**：
- 格式：`已装包 {checked}/{total}`
- 数字变化使用 counter 滚动动画（~400ms ease-out）
- 100% 时进度条从默认灰变为 `PRIMARY_COLOR` + scale bounce Spring(0.3, 0.6)

**FAB 可见性与定位**：
- **仅配装视图显示 FAB**
- 切换至清单视图时 FAB 淡出（opacity 0, Spring(0.25, 0.7)）
- 切回配装视图时 FAB 淡入
- 清单视图的添加装备入口保持在原有 ActionRow 中
- **z-index**：LoadoutView 使用 `Stack` 布局，Zone 卡片网格（ScrollView）在底层，FAB 在 Stack 的最上层（后渲染 = 高层级）。使用 `.position({ right: 16, bottom: safeBottom + 16 })` 绝对定位在右下角。FAB 天然不会被 Zone 卡片遮挡
- GearPickerSheet 通过全局 SheetOverlay 渲染（在根 Stack 层级），天然高于 LoadoutView 中的 FAB

**底部安全区**：
- Zone 卡片网格底部留 padding ~32vp，确保最底部卡片不被系统导航条遮挡
- FAB 距底部 ~80-100vp（TabBar 76vp + margin），不使用简单的 screenHeight 减法，而是基于 safeArea 计算

### 3.5 选装交互：GearPickerSheet

用户 tap FAB 或引导按钮后，弹出 GearPickerSheet：

```
+----------------------------------------------+
|  选择装备                        [完成]       |
|  +------------------------------------------+|
|  |  [search] 搜索装备...                     ||
|  +------------------------------------------+|
|  全部  穿着-上身  饮食  电力  ...            |  <- CategoryTagGroup 品类筛选（单选+sticky）
|                                              |
|  已选 3 件  > 上身 2 - 杂项 1               |  <- 实时计数栏（Zone 分布）
|                                              |
|  > 穿着-上身                                 |
|  +------------------------------------------+|
|  |  速干T恤 (Patagonia)    [-> 上身]         ||  <- 目标 Zone chip（ZONE_UPPER 色）
|  |  抓绒衣 (Arc'teryx)  v  [-> 上身]         ||  <- 已选：chip 变绿 + v
|  |  硬壳冲锋衣             [-> 上身]         ||
|  +------------------------------------------+|
|  > 饮食系统                                  |
|  +------------------------------------------+|
|  |  炉头 (Soto)           [-> 杂项]         ||  <- ZONE_MISC 色
|  |  钛锅 (Snow Peak)   v  [-> 杂项]         ||
|  +------------------------------------------+|
|                                              |
|  +------------------------------------------+|
|  |  + 临时添加（不入装备库）                  ||
|  +------------------------------------------+|
+----------------------------------------------+
```

**品类 tab 交互模式**：
- **单选模式**（`showAllOption = true`，`multiSelectMode = false`）
- tap 某个品类 -> 下方装备列表仅显示该品类装备
- 心智模型：用户在 Sheet 中想「我要找饮食系统的装备」，不是「我要同时看饮食和电力」
- **sticky 定位**：品类 tab 固定在搜索栏下方、装备列表上方。装备列表滚动时，品类 tab 保持可见（放在非滚动区域，即 Column 的 non-scrollable header 部分）

**反馈机制**（解决遮罩模糊导致用户看不到背景的问题）：

1. **Sheet 内即时反馈（主要）**：
   - 选中装备后：该行右侧 Zone chip 从对应 Zone 颜色变为 `PRIMARY_COLOR` 绿 + 出现 v + 微小 scale bounce
   - 取消选中：chip 回退到 Zone 颜色，v 消失
2. **实时计数栏**：品类 tab 下方增加一行 `已选 N 件 > 上身 2 - 杂项 1 - 头部 1`，实时更新
3. **关闭 Sheet 后的汇总动画**：Sheet 关闭后第一帧，所有新添加的装备一起播放 staggered 入场动画（此时背景清晰可见，动画最有效）

**连续多选规则**：
- Sheet 不自动关闭——用户可连续选择多件装备
- 用户通过下滑手势 / tap「完成」按钮关闭 Sheet
- 已在当前行程中的装备显示 v，tap 可取消（从行程移除）

### 3.6 临时添加流程

tap GearPickerSheet 底部「+ 临时添加」-> 弹出 TempGearMiniSheet（GearPickerSheet 内联覆盖层）：

```
+----------------------------------------------+
|  [GearPickerSheet 内容被遮罩变暗]             |
|                                              |
|          +-------------------------+         |
|          |  临时添加装备             |         |
|          |                         |         |
|          |  名称  [___________]    |         |
|          |                         |         |
|          |  归属区域                |         |
|          |  [头部] [上身] [下身]    |         |
|          |  [脚部] [背负] [睡眠]   |         |
|          |  [杂项*]                |         |
|          |                         |         |
|          |  重量（可选） [___] g    |         |
|          |                         |         |
|          |    [取消]    [添加]      |         |
|          +-------------------------+         |
|                                              |
+----------------------------------------------+
```

**TempGearMiniSheet 实现方式**：
- **内联覆盖层**，不经过全局 SheetOverlay 路由——因为 SheetOverlay 是单例（`sheetMode` 为字符串），GearPickerSheet 打开时不能再叠另一个 Sheet
- 在 GearPickerSheet 组件内部使用 `Stack` 实现：底层 = 正常 Sheet 内容，上层 = 半透明遮罩（`opacity(0.3)` 纯黑，无 blur）+ 居中白色圆角卡片
- 语义正确：mini sheet 是 GearPickerSheet 的子级，视觉上「属于选装流程的一部分」
- **入场动画**：遮罩 fadeIn + 卡片从 scale(0.92) + opacity(0) Spring(0.3, 0.75) 弹入
- **退场动画**：逆向 scale(1->0.92) + fadeOut，遮罩 fadeOut

**规则**：
- 名称必填，归属区域必选（默认 Misc），重量可选
- tap「添加」-> 创建 ChecklistItem（`fromGearId` 为空，`group` = 选中 Zone）-> 覆盖层关闭 -> 回到 GearPickerSheet
- 临时装备在配装视图中显示一个小标记（灰色 `临时` chip），表示非装备库正式装备
- 临时装备不进入装备库，仅存在于当前行程
- Zone chips 使用对应的 `ZONE_*_COLOR` 颜色

### 3.7 GearPickerSheet 空态（装备库为空）

如果装备库没有任何装备时打开 GearPickerSheet：

```
+----------------------------------------------+
|  选择装备                        [关闭]       |
|                                              |
|         [backpack+]                          |
|                                              |
|    装备库还是空的                             |
|    先临时添加一件试试吧                       |
|                                              |
|    +--------------------+                    |
|    |  + 临时添加一件     |                    |  <- tap -> 弹出临时添加覆盖层
|    +--------------------+                    |
|                                              |
+----------------------------------------------+
```

**设计决策（v4 变更）**：去掉「去装备库」按钮，仅保留「临时添加一件」入口。

**理由**：装备库为空的用户是第一次使用的新用户。他们此刻的心智是「我要为行程配装」，不需要「去装备库」这个概念分流注意力。让他们先通过临时添加完成第一次配装、体验核心价值。装备库是他们后续主动探索的功能。同时「去装备库」需要跨三层导航操作（关闭 Sheet -> pop NavDestination -> 切换 Tab），实现复杂且体验断裂——用户加完装备后还得重新找行程入口。纯「临时添加」路径无此问题。

### 3.8 勾选交互（打包确认）

在配装视图中，装备已填入各槽位后：

| 操作 | 触发方式 | 效果 |
|------|---------|------|
| 切换勾选 | tap 装备行 | checked 切换（最高频操作） |
| 修改层级 | tap 层级 badge（仅 UpperBody/LowerBody 可见） | 弹出层级选择 popup（5 选项） |
| 操作菜单 | long-press 装备行 | 呼出 ActionSheet（见 S3.12） |

**勾选反馈的即时性**：
- 第一帧（0ms）：checkbox v icon 瞬间出现/消失 + 行底色瞬间切换（0ms 硬切，不用动画）
- 后续（0-200ms）：v icon 用 Spring(0.25, 0.7) 弹入（从 scale 0 -> 1）；行底色用 Spring(0.35, 0.8) settle
- 效果：快速连续勾选 5 件装备时，每个 tap 的视觉反馈即时可感知，同时保留弹性质感

### 3.9 退出路径

```
导航栏：
+--------------------------------------+
|  < 返回    武功山徒步          ...   |
+--------------------------------------+
```

- **`<` 返回**：点击返回行程列表（HomePage）。返回时**自动保存**
- **自动保存的变更检测粒度**：
  - 添加/删除装备 = 有变更
  - 勾选/取消勾选 = 有变更
  - 修改层级 badge = 有变更（即使改回原值也算，简化实现）
  - 仅切换视图（配装<->清单）= 无变更
  - 打开 GearPickerSheet 又关闭未选任何装备 = 无变更
  - 若无变更，不调用 `PackStore.saveChecklists()`
- **`...` 更多菜单**：
  - 「编辑行程信息」-> 呼出 ProfileEditSheet
  - 「核查复盘」-> `navPathStack.pushPathByName('ReviewPage')`（ReviewPage 保持独立 NavDestination，pop 后自然回到 TripDetailPage）
  - 「删除行程」-> 确认弹窗 -> 删除 -> pop 回列表

### 3.10 核查复盘

- 从配装视图或清单视图的 `...` 菜单进入
- ReviewPage 作为独立 NavDestination 被 push 到 NavPathStack 上（保持现有路由方式）
- 退出 ReviewPage 后自然 pop 回 TripDetailPage，用户回到进入前的视图（配装/清单）
- ReviewPage 不需要做任何改动

### 3.11 引导态 -> 有装备态的过渡动画

用户在 GearPickerSheet 中选中第一件装备并关闭 Sheet 后，从全局空态（S3.3）过渡到有装备状态（S3.4）：

**动画序列**（staggered，形成「装备栏解锁」的仪式感）：
1. 引导按钮和大 icon 以 fadeOut 退场（~150ms，快速消失不留恋）
2. 首个 Zone 卡片在其固定网格位置以 scale(0.9->1) + translateY(8->0) + fadeIn 从下方弹入（Spring(0.38, 0.72)，与 PANEL_ENTER 一致）
3. 延迟 50ms 后，进度条以 translateY(-8->0) + fadeIn 从上方降下（Spring(0.35, 0.8)）
4. 再延迟 50ms 后，FAB 以 scale(0->1) + Spring(0.3, 0.75) 在右下角弹入
5. 三个元素（Zone 卡片 -> 进度条 -> FAB）的 staggering 间隔共 100ms，形成有节奏的「解锁」感

### 3.12 装备移除反馈

从 long-press ActionSheet 中选择「从行程移除」后的视觉反馈：

| 场景 | 视觉反馈 |
|------|---------|
| 移除后 Zone 内仍有其他装备 | 该装备行以 fadeOut + collapse（height -> 0）+ Spring(0.3, 0.88) 退场，同 Zone 其他装备平滑上移 |
| 移除后 Zone 变为空（最后一件） | 装备行退场后，Zone 卡片以 scale(1->0.92) + opacity(1->0) Spring(0.25, 0.8) 退场。相邻卡片平滑填补空位（0 高度占位恢复）。同时显示 toast：「XX 已移除」（1.5s 自动消失） |

注：不需要撤销功能（与现有 ChecklistDetail 一致），但退场动画必须流畅可感知，绝不硬切。

### 3.13 Long-press 操作菜单（ActionSheet）

long-press 装备行触发操作菜单，使用 **ActionSheet** 形式（底部弹出，通过 SheetOverlay 路由）：

```
+----------------------------------------------+
|  速干T恤 (Patagonia)                         |  <- 标题（装备名称）
|  ------------------------------------------- |
|  移动到其他区域  >                            |  <- tap -> 呼出 Zone 选择器
|  查看装备详情                                |  <- tap -> 呼出装备详情面板
|  从行程移除               (红色文字)          |  <- 危险操作
|  ------------------------------------------- |
|  取消                                        |
+----------------------------------------------+
```

**实现**：
- 新增 SheetOverlay 常量 `SHEET_GEAR_ITEM_ACTION`
- 通过全局 SheetOverlay 路由呼出（需要先关闭 GearPickerSheet——但 long-press 发生在配装视图中，此时无 Sheet 打开，不冲突）
- 复用项目统一的 Sheet 动画（`SPRING_PANEL_ENTER/EXIT`）
- 「从行程移除」使用红色字体，视觉标记危险操作
- 「移动到其他区域」tap 后进入 Zone 选择子面板（ActionSheet 内容切换为 7 个 Zone chip，tap 选中后修改 `group` 并关闭）

---

## 4. 数据模型 - 零迁移策略

### 4.1 核心洞察

配装系统**不需要新增任何持久化字段**。现有数据结构已完全够用：

```typescript
// 已有 -- ChecklistItem
interface ChecklistItem {
  id: string;
  name: string;
  group: string;        // <- 复用为 BodyZone 标识
  checked: boolean;     // <- 打包勾选状态
  weight?: number;
  price?: number;
  fromGearId?: string;  // <- 关联装备库
}

// 已有 -- TripChecklist
interface TripChecklist {
  id: string;
  title: string;
  items: ChecklistItem[];  // <- 配装结果即 items 列表
  // ... 其他字段
}
```

### 4.2 字段映射关系

| 配装概念 | 存储字段 | 映射逻辑 |
|----------|----------|----------|
| 装备落入哪个 Zone | `ChecklistItem.group` | 存 BodyZone 值（'head'/'upper'/...） |
| 装备层级 | 运行时计算 | 通过 `fromGearId` -> GearItem.category -> `CATEGORY_SLOT_MAP.layer` |
| 是否已打包 | `ChecklistItem.checked` | 直接复用 |
| 关联装备库 | `ChecklistItem.fromGearId` | 直接复用 |
| 装备名称 | `ChecklistItem.name` | 冗余存储（离线可用） |
| 装备重量 | `ChecklistItem.weight` | 冗余存储 |

### 4.3 group 字段语义升级

原 `ChecklistItem.group` 用于旧版清单的手动分组（自由文本）。配装系统中：
- **新行程**：`group` 写入 BodyZone 枚举值（'head'/'upper'/'lower'/'feet'/'carry'/'sleep'/'misc'）
- **旧行程**：`group` 保持原值，配装视图按 `CATEGORY_SLOT_MAP` 重新推断 Zone 展示
- **向后兼容**：旧行程数据不受影响，只是在新 UI 中按推断位置渲染

### 4.4 层级的运行时推导

层级（LayerOrder）不持久化，运行时按以下路径推导：
```
ChecklistItem.fromGearId -> 查找 GearItem.category -> CATEGORY_SLOT_MAP[category].layer
```
若 `fromGearId` 为空（手动添加的临时装备），回退到 `Accessory` 层。

### 4.5 变更检测（自动保存策略）

退出 TripDetailPage 时，按以下规则决定是否调用 `PackStore.saveChecklists()`：

| 操作 | 是否触发保存 |
|------|-------------|
| 添加/删除装备 | Yes |
| 勾选/取消勾选 | Yes |
| 修改层级 badge | Yes（即使改回原值也算，简化实现） |
| 移动装备到其他 Zone | Yes |
| 仅切换视图未做操作 | No |
| 打开 GearPickerSheet 又关闭未选 | No |
| 打开 long-press 菜单未执行操作 | No |

实现方式：`TripDetailPage` 维护一个 `isDirty: boolean` 标记，任何数据修改操作置 true。退出时检查 isDirty 决定是否保存。

---

## 5. 组件架构

### 5.1 新增文件清单

```
entry/src/main/ets/
+-- components/gear/
|   +-- TripDetailPage.ets         # 行程详情页（NavDestination 内容，双视图容器）
|   +-- LoadoutView.ets            # 配装视图（Zone 卡片网格 + FAB）
|   +-- LoadoutZoneCard.ets        # Zone 卡片组件
|   +-- LoadoutGearItem.ets        # 单个装备项组件
|   +-- LoadoutProgressBar.ets     # 顶部进度条组件
|   +-- GearItemActionSheet.ets    # 装备操作 ActionSheet 内容
+-- components/sheets/
|   +-- GearPickerSheet.ets        # 装备选择半模态 Sheet（含 TempGearMiniSheet 内联覆盖层）
+-- services/
    +-- LoadoutService.ets         # 配装业务逻辑
```

### 5.2 组件职责

#### TripDetailPage（行程详情页内容）
- 作为 `NavDestination` 内的直接子内容（在 Index.ets `NavDestinationMap` 中注册 `'TripDetailPage'` 分支）
- 承载 `geometryTransition('trip-' + id)`
- 布局从上到下：共享信息区（日期+结构化字段）-> SegmentButton -> 当前视图
- 管理 @State：`activeView: 'loadout' | 'checklist'`（始终默认 'loadout'）
- 管理 isDirty 标记，退出时触发条件保存
- `...` 更多菜单：编辑行程 / 核查复盘 / 删除行程
- **视图切换使用 if/else 条件渲染**：非当前视图组件被销毁，切换回时重建

**与 Index.ets NavDestinationMap 的集成**：
```typescript
// Index.ets NavDestinationMap Builder 中新增分支：
if (name === 'TripDetailPage') {
  NavDestination() {
    TripDetailPage({
      checklists: this.checklists,
      gears: this.gears,
      selectedChecklistId: this.selectedChecklistId,
      // ... 其他必要 @Prop
    })
  }
  .hideTitleBar(true)
  // geometryTransition id 与 HomePage 的 trip card 保持一致：
  // HomePage: .geometryTransition('trip-' + item.id)
  // TripDetailPage NavDestination: .geometryTransition('trip-' + selectedChecklistId)
  .geometryTransition('trip-' + this.selectedChecklistId)
  .transition(TransitionEffect.opacity(0.99))
  .onBackPressed(() => {
    // 条件保存 + pop
  })
}
```

原 `'ChecklistDetail'` 分支保留但标记为 deprecated，待稳定后移除。

#### LoadoutView（配装视图）
- 接收 @Prop 的 TripChecklist + GearItem[] 数据
- **使用 Stack 布局**：底层 = ScrollView（Zone 卡片网格），上层 = FAB（后渲染 = 高 z-index）
- 空态（无装备）：全屏引导（大 icon + 引导文案 + 大号引导按钮）
- 有装备时：进度条 + Zone 卡片网格（固定位置，仅展示有装备的 Zone）+ FAB
- FAB 通过 `.position({ right: 16, bottom: safeBottom + 16 })` 绝对定位在右下角
- FAB 仅在配装视图可见；切换到清单视图时淡出
- 通过回调触发 SheetOverlay 呼出 GearPickerSheet
- Zone 卡片网格底部留 padding ~32vp（底部安全区）

#### LoadoutZoneCard（区域卡片）
- 展示单个 BodyZone 的所有装备
- 卡片标题 = Zone icon + 中文名（标题颜色使用对应的 ZONE_*_COLOR）
- 内部 ForEach 渲染 LoadoutGearItem，按 LayerOrder 排序
- **Misc 卡片特殊**：内部按品类分子区（两层 ForEach：外层品类、内层装备）
- 卡片整体纯白 + 圆角 16vp + `SHADOW_SUBTLE` 微阴影

#### LoadoutGearItem（装备项）
- 单行展示：[层级badge?] + 装备名 + [重量] + [check mark]
- tap 装备行 -> 切换 checked（即时反馈：第一帧硬切到目标态，Spring 弹性收尾）
- tap 层级 badge（仅衣物 Zone）-> 弹出层级选择 popup
- long-press -> 呼出 ActionSheet（S3.13）
- 层级 badge 可见区域 >= 20x20vp，padding 扩展到 44x44vp 触控区（`hitTestBehavior(HitTestMode.Block)` 防穿透）
- 临时装备标记：显示 `临时` 小灰 chip
- **移除退场动画**：fadeOut + height collapse + Spring(0.3, 0.88)

#### LoadoutProgressBar（进度条）
- 横条进度 + 数字 `已装包 N/M`
- 数字用 counter 滚动动画
- 100% 时色变 + 弹动 + 文案 "准备出发"

#### GearPickerSheet（选择 Sheet）
- 通过 SheetOverlay 统一路由（`SHEET_GEAR_PICKER`）
- 布局：搜索栏 -> 品类 tab（**单选 + sticky**）-> **已选汇总栏** -> 装备列表（Scroll）-> 临时添加入口
- 品类 tab：`showAllOption = true`，`multiSelectMode = false`，sticky 在搜索栏下方不随列表滚动
- 已选汇总栏：`已选 N 件 > 上身 2 - 杂项 1`（实时更新，显示 Zone 分布）
- 每行装备右侧：目标 Zone chip（使用 ZONE_*_COLOR 对应颜色）
- 选中反馈：Zone chip 变绿 + check mark + scale bounce
- **连续多选**：选中后 Sheet 不关闭
- 关闭 Sheet 后：新添加的装备在配装视图中以 staggered 入场动画一起出现
- **装备库为空态**：中央 icon + 文案 + 仅一个入口「临时添加一件」
- **TempGearMiniSheet 内联覆盖层**：在 GearPickerSheet 组件内部用 Stack 实现（半透明遮罩 + 居中卡片），不经过全局 SheetOverlay 路由，不占用全局 Sheet 槽位

#### GearItemActionSheet（装备操作）
- 通过 SheetOverlay 统一路由（`SHEET_GEAR_ITEM_ACTION`）
- 标题显示装备名称
- 三个操作：移动到其他区域 / 查看装备详情 / 从行程移除（红色）
- 底部取消按钮
- 「移动」tap 后展示 Zone 选择器（7 个 Zone chip）

#### LoadoutService（业务逻辑）
- `assignSlot(gear: GearItem): { zone: BodyZone, layer: LayerOrder }` -- 封装 CATEGORY_SLOT_MAP 查询
- `sortItemsByLayer(items: ChecklistItem[], gears: GearItem[]): ChecklistItem[]` -- 按层级排序
- `groupByZone(items: ChecklistItem[]): Map<BodyZone, ChecklistItem[]>` -- 按 Zone 分组（跳过空 Zone）
- `groupMiscByCategory(items: ChecklistItem[], gears: GearItem[]): Map<string, ChecklistItem[]>` -- Misc 内按品类分子组
- `calcProgress(items: ChecklistItem[]): { checked: number, total: number }` -- 进度计算
- `inferZoneFromGroup(group: string): BodyZone` -- 旧数据 group -> Zone 推断
- `inferDisplayGroup(item: ChecklistItem, gears: GearItem[]): string` -- **v4 新增**，清单视图显示名回译

### 5.3 与现有系统的集成点

| 集成点 | 方式 |
|--------|------|
| 页面路由 | Index.ets `NavDestinationMap` 新增 `'TripDetailPage'` 分支 |
| 装备库数据 | 从 Index.ets `@Prop gears` 显式传递 |
| 行程数据 | 从 Index.ets `@Prop checklists` 显式传递 |
| 数据持久化 | 复用现有 `PackStore.saveChecklists()` |
| Sheet 呼出 | 通过 SheetOverlay 路由（新增 `SHEET_GEAR_PICKER` / `SHEET_GEAR_ITEM_ACTION` 常量） |
| Sheet 动画 | `SPRING_PANEL_ENTER/EXIT` + 背景 `scale(0.94)` + `backdropBlur(16)` |
| 品类筛选 | 复用 CategoryTagGroup 组件（单选模式） |
| 动画 | 使用 AnimationTokens + AnimationUtils |
| 共享元素转场 | `geometryTransition('trip-' + id)` 绑在新 NavDestination 上 |
| 核查复盘 | `navPathStack.pushPathByName('ReviewPage')`（保持独立 NavDestination） |

---

## 6. 视觉设计语言

### 6.1 整体风格

- 背景：`PAGE_BG`（#F8F9FA 羽白）
- 卡片：纯白无边框 + 圆角 16vp + `SHADOW_SUBTLE` 微阴影
- Zone 卡片标题：icon + 字阶 `TITLE_SM`，颜色使用对应 `ZONE_*_COLOR`
- 装备名：字阶 `BODY_MD`，颜色 `TEXT_MAIN`
- FAB：右下角悬浮，主题绿 `PRIMARY_COLOR` 圆形，56x56vp，仅配装视图可见

### 6.2 Zone 颜色系统

在 `Colors.ets` 中定义每个 Zone 的主题色（用于卡片标题 + GearPickerSheet Zone chip）：

| Zone | Token 名 | 色值 | 用途 |
|------|----------|------|------|
| Head | `ZONE_HEAD_COLOR` | #42A5F5 蓝 | 卡片标题 + Sheet chip |
| UpperBody | `ZONE_UPPER_COLOR` | #EF5350 暖红 | 卡片标题 + Sheet chip |
| LowerBody | `ZONE_LOWER_COLOR` | #5C6BC0 靛蓝 | 卡片标题 + Sheet chip |
| Feet | `ZONE_FEET_COLOR` | #8D6E63 棕 | 卡片标题 + Sheet chip |
| Carry | `ZONE_CARRY_COLOR` | #FFA726 橙 | 卡片标题 + Sheet chip |
| Sleep | `ZONE_SLEEP_COLOR` | #7E57C2 紫 | 卡片标题 + Sheet chip |
| Misc | `ZONE_MISC_COLOR` | #78909C 灰蓝 | 卡片标题 + Sheet chip |

Zone 颜色贯穿配装视图（卡片标题）+ GearPickerSheet（目标 Zone chip），形成一致的视觉关联。

### 6.3 Zone 卡片 Icon

| Zone | Icon | 中文名 |
|------|------|--------|
| Head | `sys.symbol.face.smiling` | 头部 |
| UpperBody | `sys.symbol.tshirt` | 上身 |
| LowerBody | `sys.symbol.figure.walk` | 下身 |
| Feet | `sys.symbol.shoeprints.fill` | 脚部 |
| Carry | `sys.symbol.backpack` | 背负 |
| Sleep | `sys.symbol.tent` | 睡眠 |
| Misc | `sys.symbol.square.grid.2x2` | 杂项 |

> 注：以上为建议 icon，实际开发时按 HarmonyOS 可用的 SymbolGlyph 资源确认。

### 6.4 层级 Badge 配色

在 `Colors.ets` 中定义为语义 token（禁止硬编码 hex）：

| Layer | 中文 | Token 名 | 色值 |
|-------|------|----------|------|
| Base | 贴身 | `LAYER_BASE_BG` | #E3F2FD 浅蓝 |
| Mid | 保暖 | `LAYER_MID_BG` | #FFF3E0 浅橙 |
| Shell | 防护 | `LAYER_SHELL_BG` | #E8F5E9 浅绿 |
| Insulation | 隔绝 | `LAYER_INSULATION_BG` | #F3E5F5 浅紫 |
| Accessory | 配件 | `LAYER_ACCESSORY_BG` | #F5F5F5 浅灰 |

Badge 仅在 UpperBody / LowerBody 卡片内显示。触控区域：可见区域 >= 20x20vp + padding 扩展到 44x44vp。

### 6.5 勾选态视觉

- 未勾选：正常显示
- 已勾选：文字透明度降至 0.5 + 行底色 `LIGHT_PRIMARY_COLOR` + 右侧 check icon（`PRIMARY_COLOR`）
- **即时反馈策略**：第一帧（0-16ms）checkbox icon 瞬间出现 + 背景色 EaseOut 快速到 80% 目标值（~50ms），然后 Spring(0.25, 0.7) 弹性收尾至 100%。确保快速连续勾选时每个 tap 都有即时视觉反馈。

### 6.6 Zone 卡片空态

**空 Zone 不渲染卡片内容**（见 S3.3 渐进式策略），仅保留 0 高度占位确保网格稳定。因此不存在单个 Zone 的空态显示。

---

## 7. 动效规范

所有动画严格遵循 `docs/DEVELOPMENT_STANDARDS.md` 及 `constants/AnimationTokens.ets` 定义：

| 场景 | 动画类型 | 参数 |
|------|----------|------|
| 路径 A 进入（新建行程） | NavDestination opacity + 背景景深 | .transition(OPACITY) + scale(0.94) + blur(12) |
| 路径 B 进入（tap 行程卡片） | geometryTransition 一镜展开 + 背景景深 | Spring HERO_EXPAND + scale(0.94) + blur(12) |
| Zone 卡片首次出现 | staggered scale(0.9->1) + fadeIn + height 展开 | 间隔 40ms，Spring(0.35, 0.8) |
| 引导态 -> 有装备态过渡 | staggered 序列（卡片->进度条->FAB） | 间隔 50ms，见 S3.11 |
| 装备项入场（Sheet 关闭后） | staggered translateY(12->0) + fadeIn | 间隔 30ms，Spring(0.3, 0.75) |
| 装备项退场（移除） | fadeOut + height collapse | Spring(0.3, 0.88) |
| Zone 卡片退场（最后一件移除） | scale(1->0.92) + opacity(1->0) | Spring(0.25, 0.8) + toast |
| 勾选切换 | check icon 瞬间出现 + bgColor 快速过渡 | 50ms EaseOut -> Spring(0.25, 0.7) 收尾 |
| FAB 按压 | scale 三段式 | 1->0.96->1.02->1.0，Spring PRESS |
| FAB 显示/隐藏（视图切换） | opacity + translateY(8) | Spring(0.3, 0.75) |
| GearPickerSheet 展开 | SheetOverlay 路由 | `SPRING_PANEL_ENTER/EXIT` + 背景 `scale(0.94)` + `backdropBlur(16)` |
| GearPickerSheet 内选中 | Zone chip 色变 + check + scale bounce | Spring(0.25, 0.7) |
| TempGearMiniSheet 入场 | 遮罩 fadeIn + 卡片 scale(0.92->1) + fadeIn | Spring(0.3, 0.75)，无 blur |
| TempGearMiniSheet 退场 | 遮罩 fadeOut + 卡片 scale(1->0.92) + fadeOut | Spring(0.25, 0.7) |
| ActionSheet 展开 | SheetOverlay 路由 | `SPRING_PANEL_ENTER/EXIT` |
| 进度数字变化 | counter 滚动 | ~400ms ease-out |
| 进度 100% 达成 | 色变 + scale bounce | Spring(0.3, 0.6) |
| 装备项长按 | scale(1->0.96) hold | Spring PRESS |
| 视图切换（配装<->清单） | 交叉淡入淡出 | opacity + Spring(0.35, 0.8) |

---

## 8. 边界情况处理

### 8.1 同一装备出现在多个 Zone？

**不允许**。一件装备只能落入一个 Zone（由 category 决定）。统一按 CATEGORY_SLOT_MAP 预设分配。

### 8.2 用户对自动落槽不满意？

**层级微调**：tap 层级 badge（仅 UpperBody/LowerBody）-> 弹出层级选择 popup。
**区域移动**：long-press -> ActionSheet ->「移动到其他区域」-> 选择目标 Zone -> 修改 `ChecklistItem.group`。

### 8.3 手动添加临时装备

GearPickerSheet 底部「+ 临时添加」-> 弹出 TempGearMiniSheet（内联覆盖层）：
- 名称（必填 TextInput）
- 归属区域（Zone chips，默认 Misc）
- 重量（可选 TextInput，单位 g）
- 确认 -> 创建 ChecklistItem（fromGearId 空，group = 选中 Zone）-> 覆盖层关闭 -> 回到 GearPickerSheet
- 配装视图中临时装备显示 `临时` 灰色小 chip 标识

### 8.4 旧行程数据如何展示？

旧行程的 `ChecklistItem.group` 为自由文本（如 "穿着"、"电子"）：
- LoadoutService.inferZoneFromGroup() 做模糊匹配
- 匹配失败 -> 回退到 Misc Zone
- 旧数据不做写迁移，仅运行时视觉重排

### 8.5 装备库为空时的 GearPickerSheet

中央 icon + 文案「装备库还是空的，先临时添加一件试试吧」+ 单一入口：「临时添加一件」按钮 -> 弹出 TempGearMiniSheet 内联覆盖层。

不提供「去装备库」入口（v4 变更，理由见 S3.7）。

### 8.6 自定义品类的装备如何落槽？

用户通过 CategoryTagGroup 创建的自定义品类（如「滑雪」「攀岩」），不在 CATEGORY_SLOT_MAP 中。`slotHintForCategory()` 返回 fallback：`{ zone: Misc, layer: Accessory }`。用户可通过 long-press -> ActionSheet 移动到合适的 Zone。

### 8.7 清单视图中配装装备的分组显示

配装视图添加的装备 `group` 值为 BodyZone 枚举（如 'upper', 'misc'）。清单视图（ChecklistDetail）按 `group` 分组展示时，需要将枚举值回译为有意义的中文分组名。

**解决方案**：`LoadoutService.inferDisplayGroup(item, gears)` 函数：
- 如果 `item.group` 在 BodyZone 枚举范围内：
  - 有 `fromGearId` -> 通过装备查找 category（品类名）作为显示分组名
  - 无 `fromGearId`（临时装备）-> 显示对应 Zone 的中文名 + 「(临时)」
- 如果 `item.group` 是旧格式（自由文本）-> 直接显示（保持向后兼容）

这样清单视图能正确展示「穿着·上身」「饮食系统」等品类分组名，而非 'upper' / 'misc' 这类原始枚举。

---

## 9. 行程详情页架构：双视图并存

### 9.1 技术架构

**核心事实**：ChecklistDetail 是普通 `@Component`（不是 NavDestination）。当前的 NavDestination 壳在 `Index.ets:1701-1755` 的 `NavDestinationMap` Builder 中创建。因此嵌入 TripDetailPage 无技术障碍。

**实现路径**：
1. `Index.ets` 的 `NavDestinationMap` 新增 `'TripDetailPage'` 分支
2. 该分支创建 `NavDestination`，内部渲染 `TripDetailPage` @Component
3. `TripDetailPage` 内部通过 @State 控制显示 `LoadoutView` 或 `ChecklistDetail`（if/else 条件渲染）
4. `.geometryTransition('trip-' + id)` 绑在这个新 NavDestination 上
5. `.transition(TransitionEffect.opacity(0.99))` 配合路径 A（无共享元素源）的淡入
6. `.onBackPressed()` 在新 NavDestination 上处理条件保存 + pop
7. 原 `'ChecklistDetail'` 分支保留作为 fallback（feature flag 切换），稳定后移除

### 9.2 双视图切换行为

- 分段控件始终显示在共享信息区下方
- **始终默认配装视图**（不记忆用户上次选择）
- 切换时当前视图淡出 + 新视图淡入（交叉淡入淡出，~200ms）
- FAB 跟随视图切换显示/隐藏（配装视图可见，清单视图不可见）
- **组件生命周期**：if/else 条件渲染导致非当前视图组件销毁。切换回时重建。清单视图的折叠/滚动状态不保持（设计选择，见 S3.2）

### 9.3 功能对齐清单

| ChecklistDetail 功能 | 处理方式 | 备注 |
|---------------------|---------|------|
| 按分组展示装备 | 清单视图保留 | 配装视图按 Zone 展示；清单视图使用 `inferDisplayGroup()` 回译中文分组名 |
| 勾选打包 | 两个视图均支持 | 共享 checked 状态 |
| 分组折叠/展开 | 清单视图保留 | 配装视图不需要 |
| 行程头部/渐进式 chip | 提升到 TripDetailPage 共享信息区 | 两个视图共享 |
| 左滑编辑/删除 | 清单视图保留 | 配装视图用 long-press ActionSheet |
| 打勾进度/庆祝动画 | 两个视图共享 | 进度条在配装视图；清单视图保留自己的进度展示 |
| 折叠头部 | 清单视图保留 | 配装视图用轻量 header |
| 核查复盘入口 | `...` 菜单可达 | pushPathByName('ReviewPage') |
| 共享元素转场 | 绑在父 NavDestination | 不丢失 |
| ActionRow 添加装备 | 清单视图保留 | 配装视图用 FAB |

---

## 10. 一期范围 & 不做清单

### 10.1 一期做（MVP）

- [x] TripDetailPage 双视图架构（配装 + 清单，SegmentButton 切换）
- [x] LoadoutView 主视图（2 列 Zone 卡片网格，固定位置渐进式出现）
- [x] LoadoutZoneCard + LoadoutGearItem 组件
- [x] Misc 卡片内部按品类分子区
- [x] GearPickerSheet（选装 + 目标 Zone 标签 + 已选汇总栏 + 连续多选 + 品类单选 sticky tab）
- [x] TempGearMiniSheet（内联覆盖层，临时添加完整流程）
- [x] tap 勾选（即时反馈）+ long-press ActionSheet（移动/详情/移除）
- [x] 装备移除退场动画（fadeOut + collapse / Zone scaleOut + toast）
- [x] 进度指示（已装包 N/M + 100% 庆祝）
- [x] 自动落槽（CATEGORY_SLOT_MAP）
- [x] FAB 添加按钮（仅配装视图，Stack + position 定位）
- [x] Zone 颜色系统 + icon 标识
- [x] 层级 badge（仅衣物 Zone）+ tap 切换层级 + 44x44vp 触控区
- [x] 空态设计（全屏引导 -> 引导态到有装备态过渡序列 -> 渐进式 Zone 出现 / Sheet 空态纯临时添加）
- [x] 所有动效接入 AnimationTokens
- [x] 旧数据兼容（inferZoneFromGroup + inferDisplayGroup）
- [x] 共享元素转场继承 + 路径 A opacity 转场 + 背景景深
- [x] 核查复盘入口（`...` 菜单 -> ReviewPage）
- [x] 自动保存 + isDirty 变更检测
- [x] 共享信息区（日期 + 结构化字段 + tap 编辑）
- [x] 底部安全区适配（卡片 padding + FAB 位置）
- [x] 清单视图分组名回译（inferDisplayGroup）

### 10.2 一期不做（后续迭代）

- 阶段二「装包视图」（容器即实例 / 拖拽装入背包）
- Zone 间拖拽排序
- 用户自建 BodyZone
- 用户自建 Layer
- 智能推荐（按历史/天气/目的地）
- 配装模板（保存/套用）
- 分享配装卡片
- 装备编辑页手动覆盖配装区域字段
- 记忆用户上次视图选择
- 共享信息区迷你进度展示（两个视图各有独立进度展示已足够）

---

## 11. 实现路径 & 文件依赖图

```
Phase 1: 基础层
  +-- LoadoutService.ets（纯逻辑，无 UI，含 inferDisplayGroup）
  +-- Colors.ets 新增 ZONE_*_COLOR + LAYER_*_BG token
  +-- LoadoutGearItem.ets（最小渲染单元，含层级 badge + 勾选即时反馈 + 移除退场动画）

Phase 2: 容器组件
  +-- LoadoutZoneCard.ets（依赖 LoadoutGearItem，含 Misc 子分区 + Zone 退场动画）
  +-- LoadoutProgressBar.ets

Phase 3: Sheet
  +-- GearPickerSheet.ets（依赖 CategoryTagGroup（单选 sticky） + 已选汇总栏 + Zone chip + 内联 TempGearMiniSheet）
  +-- GearItemActionSheet.ets（装备操作 ActionSheet）

Phase 4: 主页面集成
  +-- LoadoutView.ets（配装视图，Stack 布局：Zone 卡片网格 + FAB + 空态引导 + 引导态过渡动画）
  +-- TripDetailPage.ets（双视图容器 + 共享信息区 + SegmentButton + if/else 视图切换）
  +-- Index.ets NavDestinationMap 新增 'TripDetailPage' 分支（含 geometryTransition + transition(OPACITY) + 背景景深）
  +-- HomePage 行程 tap 改为 pushPathByName('TripDetailPage')

Phase 5: 转场 & 动效打磨
  +-- 路径 A 转场（opacity + 景深，无共享元素）
  +-- 路径 B 转场（geometryTransition 迁移到新 NavDestination + 景深）
  +-- 引导态 -> 有装备态过渡序列（staggered）
  +-- Zone 卡片入场/退场动画
  +-- 装备移除退场 + Zone 消失 + toast
  +-- 勾选即时反馈
  +-- FAB 显示/隐藏动画
  +-- 视图切换交叉淡入淡出
  +-- GearPickerSheet 关闭后 staggered 入场
```

---

## 12. 验证标准（Done 的定义）

1. **构建通过**：`hvigorw assembleApp` 零 error
2. **功能完整**：从装备库选装 -> 自动落槽 -> 勾选确认全链路跑通
3. **双视图可切换**：配装<->清单切换流畅，数据实时同步，清单视图分组名为中文
4. **旧数据不崩**：打开旧行程在两个视图均能正常渲染
5. **共享元素转场正常**：HomePage 行程卡片 -> 行程详情一镜到底展开（路径 B）
6. **路径 A 转场正常**：新建行程 -> opacity 淡入 + 背景景深，视觉流畅
7. **动效到位**：所有交互均有 Spring 弹性响应，无硬切；勾选即时可感知
8. **空态优雅**：新行程全屏引导 -> 添加首件装备后 staggered 过渡到正常布局
9. **性能达标**：50+ 装备项的行程渲染无掉帧（保持 60fps）
10. **核查复盘可达**：两个视图均可通过 `...` 菜单进入 ReviewPage
11. **临时添加跑通**：GearPickerSheet -> 临时添加（内联覆盖层）-> Zone 卡片出现临时装备
12. **自动保存正确**：有变更退出 -> 数据持久化；无变更退出 -> 不触发 I/O
13. **移除退场流畅**：移除装备时 fadeOut + collapse；移除最后一件时 Zone 卡片 scaleOut + toast
14. **Zone 固定位置**：无论添加顺序，Zone 卡片始终在其固定网格位置出现，布局不跳动
15. **体验验证**：配装过程有「像玩游戏」的感觉，不是在「填表格」

---

## 13. 风险 & 缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Misc Zone 内容过多 | 视觉失衡 | Misc 内按品类分子区 + 可折叠 |
| 自动落槽准确率不高 | 用户困惑 | Sheet 内 Zone chip 预览 + long-press ActionSheet 移动 |
| 2 列布局在小屏手机挤压 | 文字截断 | 响应式：宽度 < 360vp 时降为 1 列 |
| 双视图增加实现复杂度 | 工期 | 清单视图直接复用 ChecklistDetail，不重写 |
| 层级 badge 对非户外用户无感 | 认知噪音 | 仅衣物 Zone 显示，其余 Zone 隐藏 |
| 自定义品类全部落 Misc | 高级用户不满 | long-press ActionSheet 移动 + 后续迭代手动覆盖 |
| geometryTransition 迁移 | 动画断裂 | Phase 5 专项处理，strict 测试 |
| Sheet 遮罩模糊导致背景不可见 | 入场反馈丢失 | Sheet 内做实时计数 + 关闭后 staggered 入场 |
| Zone 卡片按需出现可能导致布局跳动 | 视觉不稳定 | 固定网格位置 + 0 高度占位 + spring 弹性入场 |
| TempGearMiniSheet 在 GearPickerSheet 内叠加 | 性能/层级问题 | 使用纯色遮罩（无 blur）+ 简单 scale 动画，规避叠加 blur |
| 清单视图显示英文枚举分组名 | 用户困惑 | inferDisplayGroup() 回译为品类中文名 |

---

## 14. 与纲领文档的对齐确认

| 纲领 S4 要求 | 本 spec 对齐情况 |
|-------------|------------------|
| S4.1 解决什么 | S0.2 完整承载 |
| S4.3 横轴x纵轴 | S2 完整定义 |
| S4.4 容器即实例 | 一期不做，S10.2 明确留位 |
| S4.5 功能x位置正交 | Zone=位置，Layer=功能结构 |
| S4.6 结构强度光谱 | 衣物强结构（层级badge）-> Misc 内品类分区 -> 兜底朴素列表 |
| S4.7 两阶段流水线 | 一期只做阶段一（选装），阶段二留位 |

---

## 附录 A：Zone 中文名 + Icon + 颜色映射

```typescript
const ZONE_DISPLAY_NAME: Record<BodyZone, string> = {
  [BodyZone.Head]:      '头部',
  [BodyZone.UpperBody]: '上身',
  [BodyZone.LowerBody]: '下身',
  [BodyZone.Feet]:      '脚部',
  [BodyZone.Carry]:     '背负',
  [BodyZone.Sleep]:     '睡眠',
  [BodyZone.Misc]:      '杂项',
};

// Icon 资源名（实际以 HarmonyOS SymbolGlyph 可用资源为准）
const ZONE_ICON: Record<BodyZone, string> = {
  [BodyZone.Head]:      'sys.symbol.face.smiling',
  [BodyZone.UpperBody]: 'sys.symbol.tshirt',
  [BodyZone.LowerBody]: 'sys.symbol.figure.walk',
  [BodyZone.Feet]:      'sys.symbol.shoeprints.fill',
  [BodyZone.Carry]:     'sys.symbol.backpack',
  [BodyZone.Sleep]:     'sys.symbol.tent',
  [BodyZone.Misc]:      'sys.symbol.square.grid.2x2',
};

// Zone 主题色 token（Colors.ets）
const ZONE_COLOR: Record<BodyZone, string> = {
  [BodyZone.Head]:      '#42A5F5',  // 蓝
  [BodyZone.UpperBody]: '#EF5350',  // 暖红
  [BodyZone.LowerBody]: '#5C6BC0',  // 靛蓝
  [BodyZone.Feet]:      '#8D6E63',  // 棕
  [BodyZone.Carry]:     '#FFA726',  // 橙
  [BodyZone.Sleep]:     '#7E57C2',  // 紫
  [BodyZone.Misc]:      '#78909C',  // 灰蓝
};
```

## 附录 B：Layer 中文名映射

```typescript
const LAYER_DISPLAY_NAME: Record<LayerOrder, string> = {
  [LayerOrder.Base]:       '贴身',
  [LayerOrder.Mid]:        '保暖',
  [LayerOrder.Shell]:      '防护',
  [LayerOrder.Insulation]: '隔绝',
  [LayerOrder.Accessory]:  '配件',
};
```

## 附录 C：修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1 | 2026-06-10 | 初稿 |
| v2 | 2026-06-10 | 吸收第一轮审查：P0x3 + P1x3 + P2x5 |
| v3 | 2026-06-10 | 吸收第二轮审查：P0x1 + P1x5 + P2x7，全流程走查补全 |
| v4 | 2026-06-10 | 吸收第三轮审查：P1x5 + P2x6 + P3x3，页面衔接/转场/微交互完善 |

### v1 -> v2 主要修订

1. **[P0] 替代策略改为并存**：不再完全替代 ChecklistDetail，改为双视图并存（配装 + 清单）通过 SegmentButton 切换。
2. **[P0] Misc Zone 内部分区**：Misc 卡片内按品类做子分区。
3. **[P0] 品类不锁死**：保留现有品类扩展能力，自定义品类 fallback 到 Misc。
4. **[P1] GearPickerSheet 目标预览**：每行装备右侧显示目标 Zone 标签。
5. **[P1] 退出路径定义**：导航栏返回 + 自动保存 + 更多菜单。
6. **[P1] 层级微调交互明确**：tap badge = 切换层级，long-press = 菜单，互不冲突。
7. **[P2] 技术细节修正**：@Provide->@Prop、DataService->PackStore、Sheet 动画曲线。
8. **[P2] ReviewPage 入口更新**。
9. **[P2] Badge 配色 token 化**。
10. **[P2] 添加按钮改为 FAB**。
11. **[P2] Zone 卡片加 icon**。

### v2 -> v3 主要修订

1. **[P0] NavDestinationMap 集成说明**：确认 ChecklistDetail 是普通 @Component 无嵌套问题，补充 TripDetailPage 在 NavDestinationMap 中的注册代码示例和 geometryTransition 绑定方式。
2. **[P1] GearPickerSheet 反馈机制重设计**：放弃依赖背景可见性（被遮罩模糊），改为 Sheet 内实时计数汇总栏 + Zone chip 变色 + 关闭后 staggered 入场。
3. **[P1] 空态渐进式策略**：新行程不显示 7 张空卡片 -> 全屏引导 -> Zone 卡片按需逐个出现（"解锁"感）。
4. **[P1] FAB 视图绑定**：FAB 仅配装视图可见，清单视图切换时淡出，避免入口冲突。
5. **[P1] 临时添加完整流程**：新增 TempGearMiniSheet 组件，定义三字段表单 + Zone 选择 + 临时标记。
6. **[P1] 共享信息区布局**：定义日期+结构化字段在导航栏下方、分段控件上方的位置，tap 编辑入口。
7. **[P2] Zone 颜色系统**：7 色 token 体系，卡片标题与 Sheet chip 颜色一致。
8. **[P2] 勾选即时反馈**：第一帧 EaseOut 到 80% + Spring 收尾，解决快速连续勾选的感知延迟。
9. **[P2] Badge 触控区域**：明确 44x44vp 最小触控区 + hitTestBehavior 防穿透。
10. **[P2] 默认视图**：始终默认配装视图，不记忆上次选择。
11. **[P2] Sheet 空态细化**：双入口（去装备库 + 临时添加）。
12. **[P2] 变更检测粒度**：isDirty 标记 + 操作分类表。
13. **[P2] ReviewPage 路径确认**：保持独立 NavDestination，pushPathByName 方式不变。

### v3 -> v4 主要修订

1. **[P1] 路径 A 转场定义**：新建行程 push NavDestination 时使用 `.transition(TransitionEffect.OPACITY)` + `animateTo` 驱动 push + 主内容 scale(0.94) + blur(12) 景深。与路径 B 视觉一致性对齐。
2. **[P1] TempGearMiniSheet 改为内联覆盖层**：不再经过全局 SheetOverlay 路由（Sheet 为单例不可叠加），改为在 GearPickerSheet 内部 Stack 渲染（半透明遮罩 + 居中卡片 + scale Spring 入场）。
3. **[P1] 装备移除退场动画**：定义两种场景——Zone 内仍有装备时单项 fadeOut + collapse；Zone 最后一件移除时卡片 scaleOut + toast。
4. **[P1] Sheet 空态简化**：去掉「去装备库」按钮，仅保留「临时添加一件」。理由：装备库为空 = 新用户，不需要装备库概念分流；同时避免跨三层导航的断裂体验。
5. **[P1] geometryTransition id 一致性**：在代码示例中明确标注 HomePage 卡片和 TripDetailPage NavDestination 使用相同 id 格式 `'trip-' + id`。
6. **[P2] 引导态 -> 有装备态过渡序列**：定义 staggered 动画（引导 fadeOut -> Zone 卡片弹入 -> 进度条降下 -> FAB 弹入），间隔 50ms，形成「装备栏解锁」仪式感。
7. **[P2] 清单视图分组名回译**：新增 `inferDisplayGroup()` 函数，将 BodyZone 枚举回译为品类中文名，避免清单视图显示 'upper'/'misc' 等无意义文本。
8. **[P2] 视图切换状态声明**：明确 if/else 条件渲染 + 组件销毁重建 + 清单视图状态不保持（设计选择，非 bug）。
9. **[P2] long-press ActionSheet 设计**：定义 ActionSheet 视觉布局（标题 + 三操作 + 取消），通过 SheetOverlay 路由（`SHEET_GEAR_ITEM_ACTION`），移除操作红色标记。
10. **[P2] 品类 tab 单选 + sticky**：GearPickerSheet 品类 tab 改为单选模式（multiSelectMode = false），sticky 在搜索栏下方不随列表滚动。
11. **[P2] FAB z-index 定义**：LoadoutView 使用 Stack 布局，FAB 后渲染（高 z-index）+ position 绝对定位，确保不被 Zone 卡片遮挡。
12. **[P3] Zone 固定网格位置**：Zone 卡片按人体逻辑顺序固定网格位置，空 Zone 保留 0 高度占位，无论添加顺序布局不跳动。
13. **[P3] 迷你进度展示**：评估后决定一期不做（两个视图各有独立进度展示已足够），列入「一期不做」清单。
14. **[P3] 底部安全区适配**：Zone 卡片网格底部 padding ~32vp + FAB 距底 ~80-100vp（考虑 TabBar 76vp + margin）。
