# 塔科夫式配装系统 · 设计 Spec

> 版本：v2 · 2026-06-10
> 状态：📝 草稿（待用户 review）
> 上位文档：`docs/vision/2026-06-04-product-vision-and-restructure.md`（纲领 §4）
> 技术底座：`docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md`（§6 / §3.5）
> 本文档是纲领 §4「产品第二灵魂」在工程+交互层的完整落地方案。
>
> **v1→v2 修订记录**：基于 Everest 审查报告（11 项反馈）全面修正。主要变更：①「完全替代」改为「双视图并存」；② Misc Zone 新增品类子分区；③ 移除品类锁死策略；④ GearPickerSheet 新增目标 Zone 预览；⑤ 补全退出路径/层级微调交互定义；⑥ 修正技术细节（@Prop、PackStore、Sheet 动画曲线）。

---

## 0. 定位与目标

### 0.1 它是什么

塔科夫式配装系统是 PackCheck 的**第二灵魂**——将「出行前选装备」从枯燥的多选列表升维为「按身体部位 × 分层填槽」的配装游戏。用户像逃离塔科夫那样给角色（自己）按部位穿戴装备，科学打包、不漏带，同时获得游戏化的爽感。

### 0.2 它解决什么

- **科学打包不漏带**：结构化槽位 = 心智模型外显，一眼看到哪个部位/层级还空着
- **枯燥多选 → 配装游戏**：从 checkbox list 升级为视觉化填槽，留存 & 参与感质变
- **户外分层知识可视化**：新手用户自然理解「贴身→保暖→防风→羽绒」的分层逻辑
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
| 4 | 选装交互 | FAB → GearPickerSheet → 自动落槽 + 目标预览 | 点击后按 CATEGORY_SLOT_MAP 自动匹配，Sheet 内显示目标 Zone |
| 5 | 打勾机制 | tap 装备项 = 打勾/取消勾选 | 保留 long-press → 展开操作菜单 |
| 6 | 分层策略 | **系统预设层级**（Base/Mid/Shell/Insulation/Accessory） | 不允许用户自建层级，降低认知负担 |
| 7 | 品类策略 | **保留现有品类扩展能力**，预设 13 项 + 自定义品类 fallback 到 Misc | `slotHintForCategory()` 已有 fallback 机制，无需锁死 |
| 8 | 阶段二装包 | **一期不做**，留到后续迭代（group display 层面解决） | 控制一期范围，先把阶段一做透 |
| 9 | 拖拽排序 | **一期不做** | 自动落槽已满足核心需求，手动微调属锦上添花 |
| 10 | 数据迁移 | **零迁移** | 复用 ChecklistItem.fromGearId/group/checked，无新字段 |

---

## 2. 信息架构 · 横轴 × 纵轴

### 2.1 横轴：BodyZone（身体部位 / 容器区域）

```
enum BodyZone {
  Head       = 'head'     // 头部：帽子、头灯、墨镜
  UpperBody  = 'upper'    // 上身：内衣→中层→外壳
  LowerBody  = 'lower'    // 下身：内裤→裤子→雪裤
  Feet       = 'feet'     // 脚部：袜子→鞋→冰爪
  Carry      = 'carry'    // 背负：背包系统
  Sleep      = 'sleep'    // 睡眠：睡袋+垫子+帐篷
  Misc       = 'misc'     // 杂项：证件/电力/饮食/摄影/急救/洗护/其他
}
```

**布局规则**：
- 2 列网格，每个 BodyZone 占一个卡片格
- 顺序固定：Head → UpperBody → LowerBody → Feet → Carry → Sleep → Misc
- **Misc 卡片 span 全宽**（占据 2 列），因为它收纳 7+ 个品类，内容最多
- 其余 6 个 Zone 各占 1 列，3 行 × 2 列 = 6 卡片 + 1 全宽 Misc = 完整布局
- Misc 作为兜底区域，收纳所有不具备强结构的品类（含用户自定义品类）

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
- **仅衣物类（UpperBody/LowerBody）明确展示层级 badge**，其余区域层级为辅助排序用途（badge 隐藏）
- 层级 badge 是独立的 tap target：tap badge → 弹出层级选择 popup（5 个选项），允许用户微调层级归属
- 用户不可自建层级——系统预设 5 级已覆盖户外分层穿衣的全部场景

### 2.3 品类 → 槽位映射（CATEGORY_SLOT_MAP）

已在 `constants/GearLoadout.ets` 中实现，预设 13 个品类一一映射到 BodyZone + LayerOrder：

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

**自定义品类处理**：用户创建的不在上表中的品类，通过 `slotHintForCategory()` 的 fallback 机制自动落入 Misc/Accessory。用户现有的自定义品类功能（增/删/改/排序）完全保留不受影响。

### 2.4 Misc Zone 内部结构：品类子分区

Misc 收纳品类多，如果无差别平铺会退化为旧清单。解决方案：**Misc 卡片内部按品类做子分区**。

```
┌──────────────────────────────────────────┐
│  🔲 杂项                                  │
│                                            │
│  ▸ 证件                                   │
│    身份证 ✓  ·  钱包                       │
│                                            │
│  ▸ 饮食系统                                │
│    炉头 · 气罐 ✓ · 钛锅 · 餐具            │
│                                            │
│  ▸ 电力系统                                │
│    充电宝 20000mAh ✓ · Type-C 线           │
│                                            │
│  ▸ 摄影系统                                │
│    相机 · 三脚架                            │
│                                            │
│  ▸ 安全急救 · 清洁洗护 · 其他              │
│    头疼药 · 牙刷 · 防晒霜                   │
└──────────────────────────────────────────┘
```

**规则**：
- 子分区标题 = 品类名，右侧显示该品类下的装备计数
- 装备 ≤ 2 件的品类合并为最后一个「综合」行（减少碎片感）
- 子分区默认展开；品类 > 4 个时，低频品类（如安全急救/洗护）可折叠
- 如果后续实机测试 Misc 仍然过长，二期可考虑将「饮食系统」升格为独立 Zone（新增 BodyZone.Kitchen），不影响现有映射

---

## 3. 交互流程

### 3.1 入口路径

```
路径 A：新建行程
  TripFormSheet → 填写行程基本信息 → 确认 → 进入行程详情页（默认配装视图）

路径 B：行程详情
  行程列表 tap 行程 → 共享元素转场 → 进入行程详情页（默认配装视图）
```

### 3.2 行程详情页：双视图架构

行程详情页是一个 `NavDestination`，内部包含两个子视图，通过顶部分段控件切换：

```
┌──────────────────────────────────────┐
│  < 返回    武功山徒步          ···    │  ← 导航栏
│                                      │
│  [配装视图]  [清单视图]               │  ← 分段控件（Segmented Control）
│                                      │
│  ┌──────────────────────────────────┐│
│  │                                  ││  ← 当前激活视图内容
│  │   (LoadoutView 或 ChecklistView) ││
│  │                                  ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

**配装视图（默认）**：新增的 LoadoutView（Zone 卡片网格），用于出行前规划「带什么」。
**清单视图**：现有的 ChecklistDetail（保留全部功能），用于出行中/后确认「带了没」。

**为什么双视图并存**（第一性原理）：
- 出行前（packing 时态）：用户需要结构化思考、查漏补缺 → 配装视图是正确工具
- 出行中/后（checking 时态）：用户需要快速扫视、逐项打勾 → 清单视图是正确工具
- 两种意图对应两种心智模型，强行合并 = 体验退步

**数据共享**：两个视图读取同一份 `TripChecklist` 数据。在配装视图中修改装备（添加/删除/打勾），清单视图实时同步（共享 `checklists` @State 引用，Index.ets 的状态管理保证一致性）。

**共享元素转场**：`geometryTransition('trip-' + id)` 绑定在父 NavDestination 级别，HomePage 行程卡片到行程详情页的一镜到底展开不受影响。

### 3.3 核心交互：选装填槽（阶段一）

```
┌─────────────────────────────────────┐
│          配装视图                      │
│                                      │
│  已装包 5/18  ████░░░░░░░  28%      │  ← 进度条
│                                      │
│  ┌──────────┐  ┌──────────┐         │
│  │ 😊 头部   │  │ 👕 上身   │         │
│  │ [墨镜 ✓] │  │ [速干T]  │         │
│  │ [头灯]   │  │ [抓绒 ✓] │         │
│  │          │  │ [硬壳]   │         │
│  └──────────┘  └──────────┘         │
│  ┌──────────┐  ┌──────────┐         │
│  │ 🚶 下身   │  │ 👟 脚部   │         │
│  │ [内裤 ✓] │  │ [袜子 ✓] │         │
│  │ [登山裤] │  │ [登山鞋] │         │
│  └──────────┘  └──────────┘         │
│  ┌──────────┐  ┌──────────┐         │
│  │ 🎒 背负   │  │ ⛺ 睡眠   │         │
│  │ [主包 ✓] │  │ [帐篷]   │         │
│  │ [腰包]   │  │ [睡袋 ✓] │         │
│  └──────────┘  └──────────┘         │
│  ┌─────────────────────────┐        │
│  │ 🔲 杂项                  │        │
│  │ ▸ 证件: [身份证✓][钱包]  │        │
│  │ ▸ 饮食: [炉头][气罐✓]    │        │
│  │ ▸ 电力: [充电宝✓]        │        │
│  └─────────────────────────┘        │
│                                      │
│                          [＋]        │  ← FAB（右下角悬浮）
└─────────────────────────────────────┘
```

**流程**：

1. 用户 tap 右下角 FAB「＋」按钮
2. 弹出 **GearPickerSheet**（半模态 Sheet，通过 SheetOverlay 路由）
   - 展示装备库全量列表，按品类分组
   - 支持搜索过滤（复用 CategoryTagGroup 品类 tab 筛选）
   - **每行装备右侧显示目标 Zone 标签**（如 `→ 上身`），用户选之前就知道它会落到哪
   - 已选装备显示 ✓ 标记
3. 用户 tap 选中一个装备
   - 系统通过 `slotHintForCategory(gear.category)` 获取目标 Zone + Layer
   - 装备自动落入对应 BodyZone 卡片的对应层级位置
   - 背景 LoadoutView 中对应 Zone 卡片出现入场动画（scale + fadeIn）
   - **Sheet 不自动关闭**——支持连续多选
4. 用户继续选择更多装备，或关闭 Sheet
5. 关闭 GearPickerSheet（下拉手势 / tap 遮罩 / 完成按钮），回到配装视图查看全局配装图

### 3.4 GearPickerSheet 详细交互

```
┌──────────────────────────────────────┐
│  选择装备                    [完成]    │
│  ┌────────────────────────────────┐  │
│  │  🔍 搜索装备…                   │  │
│  └────────────────────────────────┘  │
│  全部  穿着·上身  饮食  电力  …      │  ← 品类 tab 筛选
│                                        │
│  ▸ 穿着·上身                           │
│  ┌──────────────────────────────────┐  │
│  │  速干T恤 (Patagonia)    → 上身   │  │  ← 目标 Zone chip
│  │  抓绒衣 (Arc'teryx)  ✓  → 上身   │  │  ← 已选标记
│  │  硬壳冲锋衣             → 上身   │  │
│  └──────────────────────────────────┘  │
│  ▸ 饮食系统                            │
│  ┌──────────────────────────────────┐  │
│  │  炉头 (Soto)           → 杂项   │  │
│  │  钛锅 (Snow Peak)      → 杂项   │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌────────────────────────────────┐    │
│  │  + 临时添加（不入装备库）         │    │
│  └────────────────────────────────┘    │
└──────────────────────────────────────┘
```

**关键规则**：
- tap 装备行 → 选中/取消选中（toggle），已选标记 ✓
- tap 已选装备 → 取消选中（从行程移除）
- 右侧 Zone chip 颜色与对应 Zone 卡片标题色一致，建立视觉关联
- 底部「临时添加」入口：创建不入装备库的临时 ChecklistItem
- 装备库为空时展示空态引导

### 3.5 勾选交互（打包确认）

在配装视图中，装备已填入各槽位后：

| 操作 | 触发方式 | 效果 |
|------|---------|------|
| 切换勾选 | tap 装备行 | checked 切换（最高频操作） |
| 修改层级 | tap 层级 badge（仅 UpperBody/LowerBody 可见） | 弹出层级选择 popup（5 选项） |
| 移动到其他 Zone | long-press → 菜单 →「移动到…」 | 修改 `ChecklistItem.group` |
| 查看装备详情 | long-press → 菜单 →「查看详情」 | 呼出装备详情面板 |
| 从行程移除 | long-press → 菜单 →「移除」 | 从 `items` 中删除 |

勾选状态变化时：checkbox 出现 spring 弹性动画 + 行底色微变（浅绿 tint）。

### 3.6 退出路径

```
导航栏：
┌──────────────────────────────────────┐
│  < 返回    武功山徒步          ···    │
└──────────────────────────────────────┘
```

- **返回箭头 `<`**：点击返回行程列表（HomePage）。返回时**自动保存**当前配装结果——无需显式「保存」按钮
- **自动保存策略**：如果从进入到退出之间无任何变更（未添加/删除/勾选），返回时不触发 `PackStore.saveChecklists()`，避免不必要 I/O
- **更多菜单 `···`**：右上角，包含「编辑行程信息」（呼出 ProfileEditSheet）、「核查复盘」（进入 ReviewPage）、「删除行程」

### 3.7 核查复盘入口

配装视图的更多菜单 `···` 中保留「核查复盘」入口，tap 后进入 ReviewPage（逐张卡片滑动确认）。退出 ReviewPage 后回到进入时的视图（配装/清单）。

### 3.8 空态设计

- 首次进入（行程无装备）：中央留白区展示引导图 + 一句话文案「tap 右下角按钮，开始装备你的旅程」
- 特定 Zone 为空：卡片内显示虚线占位 + 灰色提示「还没有 {zoneName} 装备」
- 全部勾选完毕：顶部进度条 100% + 色变弹动 + 文案 "准备出发 🎒"

### 3.9 进度指示

配装视图顶部（分段控件下方）固定一个轻量进度条 + 数字：
- 格式：`已装包 {checked}/{total}`
- 数字变化时使用 counter 滚动动画（~400ms ease-out）
- 100% 时进度条颜色从默认灰变为主题绿 `PRIMARY_COLOR` + 微弹动画 Spring(0.3, 0.6)

---

## 4. 数据模型 · 零迁移策略

### 4.1 核心洞察

配装系统**不需要新增任何持久化字段**。现有数据结构已完全够用：

```typescript
// 已有 — ChecklistItem
interface ChecklistItem {
  id: string;
  name: string;
  group: string;        // ← 复用为 BodyZone 标识
  checked: boolean;     // ← 打包勾选状态
  weight?: number;
  price?: number;
  fromGearId?: string;  // ← 关联装备库
}

// 已有 — TripChecklist
interface TripChecklist {
  id: string;
  title: string;
  items: ChecklistItem[];  // ← 配装结果即 items 列表
  // ... 其他字段
}
```

### 4.2 字段映射关系

| 配装概念 | 存储字段 | 映射逻辑 |
|----------|----------|----------|
| 装备落入哪个 Zone | `ChecklistItem.group` | 存 BodyZone 值（'head'/'upper'/...） |
| 装备层级 | 运行时计算 | 通过 `fromGearId` → GearItem.category → `CATEGORY_SLOT_MAP.layer` |
| 是否已打包 | `ChecklistItem.checked` | 直接复用 |
| 关联装备库 | `ChecklistItem.fromGearId` | 直接复用 |
| 装备名称 | `ChecklistItem.name` | 冗余存储（离线可用） |
| 装备重量 | `ChecklistItem.weight` | 冗余存储 |

### 4.3 group 字段语义升级

原 `ChecklistItem.group` 用于旧版清单的手动分组（自由文本）。配装系统中：
- **新行程**：`group` 写入 BodyZone 枚举值（'head'/'upper'/'lower'/'feet'/'carry'/'sleep'/'misc'）
- **旧行程**：`group` 保持原值，LoadoutView 按 `CATEGORY_SLOT_MAP` 重新推断 Zone 展示
- **向后兼容**：旧行程数据不受影响，只是在新 UI 中按推断位置渲染

### 4.4 层级的运行时推导

层级（LayerOrder）不持久化，运行时按以下路径推导：
```
ChecklistItem.fromGearId → 查找 GearItem.category → CATEGORY_SLOT_MAP[category].layer
```
若 `fromGearId` 为空（手动添加的临时装备），回退到 `Accessory` 层。

---

## 5. 组件架构

### 5.1 新增文件清单

```
entry/src/main/ets/
├── components/gear/
│   ├── TripDetailPage.ets         # 行程详情页（NavDestination 壳，含双视图切换）
│   ├── LoadoutView.ets            # 配装视图（Zone 卡片网格）
│   ├── LoadoutZoneCard.ets        # Zone 卡片组件
│   ├── LoadoutGearItem.ets        # 单个装备项组件
│   └── LoadoutProgressBar.ets     # 顶部进度条组件
├── components/sheets/
│   └── GearPickerSheet.ets        # 装备选择半模态 Sheet
└── services/
    └── LoadoutService.ets         # 配装业务逻辑（分槽/排序/进度计算）
```

### 5.2 组件职责

#### TripDetailPage（行程详情页壳）
- 作为 `NavDestination` 注册到 NavPathStack
- 承载 `geometryTransition('trip-' + id)`，保持从 HomePage 的共享元素转场
- 顶部导航栏：返回按钮 + 行程标题 + 更多菜单 `···`
- 分段控件切换：配装视图 / 清单视图
- 管理当前视图 @State（默认配装视图）
- 退出时触发自动保存

#### LoadoutView（配装视图）
- 接收 @Prop 的 TripChecklist + GearItem[] 数据
- 顶部：进度指示（LoadoutProgressBar）
- 中部：2 列 Zone 卡片网格（GridRow / WaterFlow）
- 底部：FAB「＋」按钮（右下角悬浮，absolute 定位）
- 通过回调触发 SheetOverlay 呼出 GearPickerSheet

#### LoadoutZoneCard（区域卡片）
- 展示单个 BodyZone 的所有装备
- 卡片标题 = Zone icon + 中文名
- 内部 ForEach 渲染 LoadoutGearItem，按 LayerOrder 排序
- **Misc 卡片特殊**：内部按品类分子区（两层 ForEach：外层品类、内层装备）
- 空态时显示虚线占位引导
- 卡片整体纯白 + 圆角 16vp + `SHADOW_SUBTLE` 微阴影

#### LoadoutGearItem（装备项）
- 单行展示：[层级badge?] + 装备名 + [重量] + [✓]
- tap 装备行 → 切换 checked
- tap 层级 badge（仅衣物 Zone）→ 弹出层级选择 popup
- long-press → 展开操作菜单（移动到其他 Zone / 查看详情 / 从行程移除）
- checked 状态：文字透明度降至 0.5 + 行底色 `LIGHT_PRIMARY_COLOR` + 右侧 ✓ icon
- 出场动画：staggered translateY(12vp→0) + fadeIn

#### LoadoutProgressBar（进度条）
- 横条进度 + 数字 `已装包 N/M`
- 数字用 counter 滚动动画
- 100% 时色变 + 弹动

#### GearPickerSheet（选择 Sheet）
- 通过 SheetOverlay 统一路由
- 装备库列表，按品类 tab 筛选（复用 CategoryTagGroup）
- 搜索栏 + 列表
- **每行装备右侧显示目标 Zone 标签**（如 `→ 上身`），提供自动落槽的可预测性
- 已在当前行程中的装备标记 ✓（tap 可取消）
- **连续多选模式**：选中装备后 Sheet 不自动关闭，背景 LoadoutPage 实时显示装备入场动画
- 用户手动关闭 Sheet（下滑手势 / tap 关闭按钮）
- 底部「临时添加」入口：添加不在装备库中的临时装备

#### LoadoutService（业务逻辑）
- `assignSlot(gear: GearItem): { zone: BodyZone, layer: LayerOrder }` — 封装 CATEGORY_SLOT_MAP 查询
- `sortItemsByLayer(items: ChecklistItem[], gears: GearItem[]): ChecklistItem[]` — 按层级排序
- `groupByZone(items: ChecklistItem[]): Map<BodyZone, ChecklistItem[]>` — 按 Zone 分组
- `groupMiscByCategory(items: ChecklistItem[], gears: GearItem[]): Map<string, ChecklistItem[]>` — Misc 内按品类分子组
- `calcProgress(items: ChecklistItem[]): { checked: number, total: number }` — 进度计算
- `inferZoneFromGroup(group: string): BodyZone` — 旧数据 group → Zone 推断

### 5.3 与现有系统的集成点

| 集成点 | 方式 |
|--------|------|
| 页面路由 | NavPathStack pushPathByName（与 ChecklistDetail/ReviewPage 同级） |
| 装备库数据 | 从 Index.ets `@Prop gears` 显式传递 |
| 行程数据 | 从 Index.ets `@Prop checklists` 显式传递 |
| 数据持久化 | 复用现有 `PackStore.saveChecklists()` |
| Sheet 呼出 | 通过 SheetOverlay 路由（与 GearFormSheet 等同级），动画使用 `SPRING_PANEL_ENTER/EXIT` + 背景 `scale(0.94)` + `blur(12)` |
| 品类筛选 | 复用 CategoryTagGroup 组件 |
| 动画 | 使用 AnimationTokens + AnimationUtils |
| 共享元素转场 | 继承 ChecklistDetail 的 `geometryTransition('trip-' + id)` |

---

## 6. 视觉设计语言

### 6.1 整体风格

- 背景：`PAGE_BG`（#F8F9FA 羽白）
- 卡片：纯白无边框 + 圆角 16vp + `SHADOW_SUBTLE` 微阴影
- Zone 卡片标题：icon + 字阶 `TITLE_SM`，颜色 `TEXT_SECONDARY`
- 装备名：字阶 `BODY_MD`，颜色 `TEXT_MAIN`
- 添加按钮：**FAB**（浮动操作按钮），右下角悬浮，主题绿 `PRIMARY_COLOR` 圆形，内容可穿透（与装备库 Tab FAB 保持一致）

### 6.2 Zone 卡片 Icon

每个 Zone 卡片标题旁加 `sys.symbol` 图标作为视觉线索，提升扫视辨识度：

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

### 6.3 层级 Badge 配色

在 `Colors.ets` 中定义为语义 token（禁止硬编码 hex）：

| Layer | 中文 | Token 名 | 色值 |
|-------|------|----------|------|
| Base | 贴身 | `LAYER_BASE_BG` | #E3F2FD 浅蓝 |
| Mid | 保暖 | `LAYER_MID_BG` | #FFF3E0 浅橙 |
| Shell | 防护 | `LAYER_SHELL_BG` | #E8F5E9 浅绿 |
| Insulation | 隔绝 | `LAYER_INSULATION_BG` | #F3E5F5 浅紫 |
| Accessory | 配件 | `LAYER_ACCESSORY_BG` | #F5F5F5 浅灰 |

Badge 仅在 UpperBody / LowerBody 卡片内显示（衣物分层有意义的区域），其余 Zone 隐藏层级 badge。

### 6.4 勾选态视觉

- 未勾选：正常显示
- 已勾选：文字透明度降至 0.5 + 行底色 `LIGHT_PRIMARY_COLOR` + 右侧 ✓ icon（`PRIMARY_COLOR`）
- 状态切换动画：opacity spring(0.25, 0.7) + 背景色 animateTo spring(0.35, 0.8)

### 6.5 Zone 卡片空态

- 虚线边框（dashArray）
- 中央灰色 icon + 一行文案
- 透明度 0.4

---

## 7. 动效规范

所有动画严格遵循 `docs/DEVELOPMENT_STANDARDS.md` 及 `constants/AnimationTokens.ets` 定义：

| 场景 | 动画类型 | 参数 |
|------|----------|------|
| Zone 卡片入场 | staggered fadeIn + translateY | 间隔 40ms，Y: 12vp→0，Spring(0.35, 0.8) |
| 装备项入场（选装后） | scale(0.9→1) + fadeIn | Spring(0.3, 0.75) |
| 勾选切换 | opacity + bgColor | Spring(0.25, 0.7) |
| FAB 按压 | scale 三段式 | 1→0.96→1.02→1.0，Spring PRESS |
| GearPickerSheet 展开 | SheetOverlay 路由 | `SPRING_PANEL_ENTER/EXIT` + 背景 `scale(0.94)` + `blur(12)` |
| 进度数字变化 | counter 滚动 | ~400ms ease-out |
| 进度 100% 达成 | 色变 + scale bounce | Spring(0.3, 0.6) |
| 装备项长按 | scale(1→0.96) hold | Spring PRESS |
| 视图切换（配装↔清单） | 交叉淡入淡出 | opacity + Spring(0.35, 0.8) |

---

## 8. 边界情况处理

### 8.1 同一装备出现在多个 Zone？

**不允许**。一件装备只能落入一个 Zone（由 category 决定）。即使「穿着·配件」可能包含手套（理论上属 UpperBody），但为简化，统一按 CATEGORY_SLOT_MAP 预设分配。

### 8.2 用户对自动落槽不满意？

**层级微调**：tap 装备行左侧的层级 badge → 弹出层级选择 popup（5 个选项），修改运行时排序。仅在 UpperBody / LowerBody 可操作。

**区域移动**：long-press → 菜单 →「移动到其他区域」→ 选择目标 Zone → 修改 `ChecklistItem.group`。

两个操作互不冲突：层级 badge 是独立 tap target，不占用装备行的 tap（勾选）和 long-press（菜单）。

### 8.3 手动添加临时装备（不在装备库中）

GearPickerSheet 底部提供「临时添加」入口，创建 ChecklistItem 时 `fromGearId` 为空。此时：
- Zone 推断：用户手动选择品类 → CATEGORY_SLOT_MAP
- Layer 推断：回退到 Accessory
- 该临时装备不进入装备库，仅存在于当前行程

### 8.4 旧行程数据如何展示？

旧行程的 `ChecklistItem.group` 为自由文本（如 "穿着"、"电子"）：
- LoadoutService.inferZoneFromGroup() 做模糊匹配
- 匹配失败 → 回退到 Misc Zone
- 旧数据不做写迁移，仅运行时视觉重排

### 8.5 装备库为空时的配装？

引导用户先去装备库添加装备，或使用「临时添加」功能。GearPickerSheet 空态展示引导。

### 8.6 自定义品类的装备如何落槽？

用户通过 CategoryTagGroup 创建的自定义品类（如「滑雪」「攀岩」），不在 CATEGORY_SLOT_MAP 中。此时 `slotHintForCategory()` 返回 fallback：`{ zone: Misc, layer: Accessory }`。装备自动落入 Misc 杂项区，用户可通过 long-press 移动到合适的 Zone。

---

## 9. 行程详情页架构：双视图并存

### 9.1 方案（修订）

~~LoadoutPage 完全替代 ChecklistDetail~~ → **配装视图与清单视图并存**，通过顶部分段控件切换。

```
行程详情 NavDestination
┌──────────────────────────────────────┐
│  < 返回    武功山徒步         ···    │  ← 导航栏
│                                      │
│  [配装视图]  [清单视图]               │  ← SegmentButton
│                                      │
│  ┌──────────────────────────────────┐│
│  │     当前激活视图的内容             ││  ← 配装 or 清单
│  │     ...                          ││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

**具体实现**：

1. 行程详情页为一个 NavDestination，内部有两个子视图通过 SegmentButton 切换：
   - **配装视图（默认）**：LoadoutView（Zone 卡片网格）——新增
   - **清单视图**：ChecklistView（现有 ChecklistDetail 逻辑的子组件化）——保留全部现有功能
2. `geometryTransition('trip-' + id)` 继续绑在父 NavDestination 上，共享元素转场不丢失
3. 两个视图读取同一份 `TripChecklist` 数据（共享 @State），任一视图中的修改实时同步
4. ChecklistDetail 的代码**不删除不重命名**，改为作为清单视图子组件嵌入

### 9.2 双视图的价值

| 场景 | 最优视图 | 原因 |
|------|---------|------|
| 出行前规划带什么 | 配装视图 | 结构化填槽，查漏补缺 |
| 出行当天逐项打勾 | 清单视图 | 线性扫描，快速确认 |
| 30+ 装备的行程快速定位 | 清单视图 | 分组折叠，搜索定位 |
| 回顾配装方案 | 配装视图 | 一眼看到全身穿搭 |

### 9.3 功能对齐清单

| ChecklistDetail 功能 | 处理方式 | 备注 |
|---------------------|---------|------|
| 按分组展示装备 | ✅ 清单视图保留 | 同时配装视图按 Zone 展示 |
| 勾选打包 | ✅ 两个视图均支持 | 共享 checked 状态 |
| 分组折叠/展开 | ✅ 清单视图保留 | 配装视图不需要（Zone 卡片天然分区） |
| 行程头部/渐进式 chip | ✅ 提升到父 NavDestination 顶部 | 两个视图共享 |
| 左滑编辑/删除 | ✅ 清单视图保留 | 配装视图用 long-press 菜单 |
| 打勾进度/庆祝动画 | ✅ 两个视图共享 | 进度条在父级，两个视图均可触发 100% 庆祝 |
| 折叠头部 | ✅ 清单视图保留 | 配装视图另做轻量 header |
| 核查复盘入口 | ✅ 两个视图均提供入口 | 导航栏更多菜单 `···` → 核查复盘 |
| 共享元素转场 | ✅ 绑在父 NavDestination | 不丢失 |

### 9.4 导航栏与退出路径

```
┌──────────────────────────────────────┐
│  < 返回    武功山徒步         ···    │
│                                      │
│  已装包 12/18  ████████░░░  67%     │
└──────────────────────────────────────┘
```

- **`<` 返回**：点击返回行程列表（HomePage）。返回时自动保存——无显式「保存」按钮
- **不触发无用 I/O**：若无变更（未添加/删除/勾选），不调用 `PackStore.saveChecklists()`
- **`···` 更多菜单**：编辑行程信息（→ TripFormSheet）、核查复盘（→ ReviewPage）、删除行程
- **核查复盘**：从配装视图或清单视图进入 ReviewPage 后，返回时回到进入前的视图

---

## 10. 一期范围 & 不做清单

### 10.1 一期做（MVP）

- [x] 行程详情双视图架构（配装 + 清单，SegmentButton 切换）
- [x] LoadoutView 主视图（2 列 Zone 卡片网格）
- [x] LoadoutZoneCard + LoadoutGearItem 组件
- [x] Misc 卡片内部按品类分子区
- [x] GearPickerSheet（从装备库选装 + 自动落槽 + 目标 Zone 标签 + 连续多选）
- [x] tap 勾选 + long-press 菜单（移动/详情/移除）
- [x] 进度指示（已装包 N/M）
- [x] 自动落槽（CATEGORY_SLOT_MAP）
- [x] FAB 添加按钮
- [x] Zone 卡片 icon 标识
- [x] 层级 badge（仅衣物 Zone）+ tap 切换层级
- [x] 空态设计（全局/Zone/Sheet）
- [x] 所有动效接入 AnimationTokens
- [x] 旧数据兼容（inferZoneFromGroup）
- [x] 共享元素转场继承
- [x] 核查复盘入口保留

### 10.2 一期不做（后续迭代）

- ❌ 阶段二「装包视图」（容器即实例 / 拖拽装入背包）
- ❌ Zone 间拖拽排序
- ❌ 用户自建 BodyZone
- ❌ 用户自建 Layer
- ❌ 智能推荐（按历史/天气/目的地）
- ❌ 配装模板（保存/套用）
- ❌ 分享配装卡片
- ❌ 装备编辑页手动覆盖配装区域字段（非一期增强）

---

## 11. 实现路径 & 文件依赖图

```
Phase 1: 基础组件
  ├── LoadoutService.ets（纯逻辑，无 UI）
  ├── LoadoutGearItem.ets（最小渲染单元）
  └── Colors.ets 新增 LAYER_*_BG token

Phase 2: 容器组件
  ├── LoadoutZoneCard.ets（依赖 LoadoutGearItem）
  └── LoadoutProgressBar.ets

Phase 3: Sheet
  └── GearPickerSheet.ets（依赖 CategoryTagGroup + 装备库数据 + Zone 标签）

Phase 4: 主页面集成
  ├── TripDetailPage.ets（父 NavDestination：双视图容器 + 导航栏）
  ├── LoadoutView.ets（配装视图，组装 ZoneCard 网格 + FAB）
  ├── ChecklistDetail 作为清单视图嵌入
  └── 接入路由（Index.ets NavPathStack 新增 'TripDetailPage'）

Phase 5: 转场 & 动效
  ├── geometryTransition 迁移到 TripDetailPage
  ├── 入场动画
  ├── 勾选动画
  ├── 视图切换动画
  └── 进度动画
```

---

## 12. 验证标准（Done 的定义）

1. **构建通过**：`hvigorw assembleApp` 零 error
2. **功能完整**：从装备库选装 → 自动落槽 → 勾选确认全链路跑通
3. **双视图可切换**：配装↔清单切换流畅，数据实时同步
4. **旧数据不崩**：打开旧行程在两个视图均能正常渲染
5. **共享元素转场正常**：HomePage 行程卡片 → 行程详情一镜到底展开
6. **动效到位**：所有交互均有 Spring 弹性响应，无硬切
7. **空态优雅**：无装备 / 特定 Zone 空 / 装备库空三种空态都有引导
8. **性能达标**：50+ 装备项的行程渲染无掉帧（保持 60fps）
9. **核查复盘可达**：两个视图均可进入 ReviewPage
10. **体验验证**：配装过程有「像玩游戏」的感觉，不是在「填表格」

---

## 13. 风险 & 缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Misc Zone 内容过多 | 视觉失衡 | Misc 内按品类分子区 + 可折叠 |
| 自动落槽准确率不高 | 用户困惑 | GearPickerSheet 显示目标 Zone + long-press 移动 |
| 2 列布局在小屏手机挤压 | 文字截断 | 响应式：宽度 < 360vp 时降为 1 列 |
| 双视图增加实现复杂度 | 工期 | 清单视图直接复用 ChecklistDetail，不重写 |
| 层级 badge 对非户外用户无感 | 认知噪音 | 仅衣物 Zone 显示，其余 Zone 隐藏 |
| 自定义品类全部落 Misc | 高级用户不满 | long-press 移动 + 后续迭代支持手动覆盖映射 |
| geometryTransition 迁移到新父组件 | 动画断裂 | Phase 5 专项处理，严格测试 |

---

## 14. 与纲领文档的对齐确认

| 纲领 §4 要求 | 本 spec 对齐情况 |
|-------------|------------------|
| §4.1 解决什么 | ✅ §0.2 完整承载 |
| §4.3 横轴×纵轴 | ✅ §2 完整定义 |
| §4.4 容器即实例 | ⏸️ 一期不做，§10.2 明确留位 |
| §4.5 功能×位置正交 | ✅ Zone=位置，Layer=功能结构 |
| §4.6 结构强度光谱 | ✅ 衣物强结构（层级badge）→ Misc 内品类分区 → 兜底朴素列表 |
| §4.7 两阶段流水线 | ⏸️ 一期只做阶段一（选装），阶段二留位 |

---

## 附录 A：Zone 中文名 + Icon 映射

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

## 附录 C：审查修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1 | 2026-06-10 | 初稿 |
| v2 | 2026-06-10 | 吸收 Everest 审查意见：P0×3 + P1×3 + P2×5，详见下 |

### v1 → v2 主要修订

1. **[P0] 替代策略改为并存**：不再完全替代 ChecklistDetail，改为双视图并存（配装 + 清单）通过 SegmentButton 切换。共享元素转场、渐进 chip、分组折叠、左滑操作、核查复盘全部保留。
2. **[P0] Misc Zone 内部分区**：Misc 卡片内按品类做子分区（两层 ForEach），避免 20+ 装备无差别平铺。
3. **[P0] 品类不锁死**：撤回「锁死 13 项」决策，保留现有品类扩展能力。自定义品类通过 `slotHintForCategory()` fallback 自动落入 Misc。
4. **[P1] GearPickerSheet 目标预览**：每行装备右侧显示目标 Zone 标签，连续多选不自动关闭。
5. **[P1] 退出路径定义**：导航栏 `<` 返回 + 自动保存 + `···` 更多菜单。
6. **[P1] 层级微调交互明确**：tap badge = 切换层级，long-press = 菜单（移动/详情/移除），互不冲突。
7. **[P2] 技术细节修正**：@Provide→@Prop、DataService→PackStore、Sheet 动画改用 SPRING_PANEL_ENTER/EXIT。
8. **[P2] ReviewPage 入口更新**：两个视图均可进入核查复盘。
9. **[P2] Badge 配色 token 化**：定义 `LAYER_*_BG` 语义 token。
10. **[P2] 添加按钮改为 FAB**：右下角悬浮，与装备库 Tab 一致。
11. **[P2] Zone 卡片加 icon**：提升视觉辨识度。