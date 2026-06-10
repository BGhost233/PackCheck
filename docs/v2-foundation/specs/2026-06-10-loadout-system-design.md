# 塔科夫式配装系统 · 设计 Spec

> 版本：v1 · 2026-06-10
> 状态：📝 草稿（待用户 review）
> 上位文档：`docs/vision/2026-06-04-product-vision-and-restructure.md`（纲领 §4）
> 技术底座：`docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md`（§6 / §3.5）
> 本文档是纲领 §4「产品第二灵魂」在工程+交互层的完整落地方案。

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
| 1 | 入口定位 | LoadoutPage **完全替代** ChecklistDetail | 配装是 packing 时态的核心交互，不是锦上添花 |
| 2 | 触发时机 | 新建行程时自动进入 + 行程详情直接打开 | 两者都要，不限制入口 |
| 3 | 布局形态 | **卡片式区域网格**（2 列，每个 BodyZone 一张卡片） | 纯卡片无人体拓扑，降低实现复杂度，适配不同屏幕 |
| 4 | 选装交互 | 底部按钮 → GearPickerSheet → 自动落槽 | 点击后按 CATEGORY_SLOT_MAP 自动匹配区域 |
| 5 | 打勾机制 | tap 装备项 = 打勾/取消勾选 | 保留 long-press → 展开详情/菜单 |
| 6 | 分层策略 | **系统预设层级**（Base/Mid/Shell/Insulation/Accessory） | 不允许用户自建层级，降低认知负担 |
| 7 | 品类策略 | **锁死 DEFAULT_CATEGORIES**（13 项），不支持用户自建品类 | 品类与槽位映射强绑定，松绑会破坏自动落槽 |
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
- **Misc 卡片 span 全宽**（占据 2 列），因为它收纳 7 个品类（证件/饮食/电力/摄影/急救/洗护/其他），内容最多
- 其余 6 个 Zone 各占 1 列，3 行 × 2 列 = 6 卡片 + 1 全宽 Misc = 完整布局
- Misc 作为兜底区域，收纳所有不具备强结构的品类

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
- 层级标签以 chip/badge 形式显示在装备项左侧
- **仅衣物类（UpperBody/LowerBody）明确展示层级关系**，其余区域层级为辅助排序用途
- 用户不可自建层级——系统预设 5 级已覆盖户外分层穿衣的全部场景

### 2.3 品类 → 槽位映射（CATEGORY_SLOT_MAP）

已在 `constants/GearLoadout.ets` 中实现，13 个品类一一映射到 BodyZone + LayerOrder：

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

**注**：`穿着·上身` 默认落到 Mid 层是因为大多数上衣属中层；用户配装时可在卡片内微调层级（tap 层级 chip 切换）。

---

## 3. 交互流程

### 3.1 入口路径

```
路径 A：新建行程
  TripFormSheet → 填写行程基本信息 → 确认 → 进入 LoadoutPage

路径 B：行程详情
  行程列表 tap 行程 → 直接进入 LoadoutPage（替代原 ChecklistDetail）
```

### 3.2 核心交互：选装填槽（阶段一）

```
┌─────────────────────────────────────┐
│          LoadoutPage 主视图           │
│                                      │
│  ┌──────────┐  ┌──────────┐         │
│  │  头部     │  │  上身     │         │
│  │ [墨镜 ✓] │  │ [速干T]  │         │
│  │ [头灯]   │  │ [抓绒 ✓] │         │
│  │          │  │ [硬壳]   │         │
│  └──────────┘  └──────────┘         │
│  ┌──────────┐  ┌──────────┐         │
│  │  下身     │  │  脚部     │         │
│  │ [内裤 ✓] │  │ [袜子 ✓] │         │
│  │ [登山裤] │  │ [登山鞋] │         │
│  └──────────┘  └──────────┘         │
│  ┌──────────┐  ┌──────────┐         │
│  │  背负     │  │  睡眠     │         │
│  │ [主包 ✓] │  │ [帐篷]   │         │
│  │ [腰包]   │  │ [睡袋 ✓] │         │
│  └──────────┘  └──────────┘         │
│  ┌─────────────────────────┐        │
│  │  杂项                    │        │
│  │ [证件✓][充电宝✓][头疼药] │        │
│  └─────────────────────────┘        │
│                                      │
│         [＋ 添加装备]                  │
└─────────────────────────────────────┘
```

**流程**：

1. 用户 tap 底部「＋ 添加装备」按钮
2. 弹出 **GearPickerSheet**（半模态 Sheet）
   - 展示装备库全量列表，按品类分组
   - 支持搜索过滤
   - 已选装备显示勾选标记
3. 用户 tap 选中一个装备
   - 系统通过 `slotHintForCategory(gear.category)` 获取目标 Zone + Layer
   - 装备自动落入对应 BodyZone 卡片的对应层级位置
   - 卡片出现入场动画（translateY + fadeIn）
4. 重复 2-3 直到选装完毕
5. 关闭 GearPickerSheet，回到 LoadoutPage 查看全局配装图

**退出 GearPickerSheet 的方式**：下拉手势关闭 / tap 遮罩层 / 完成按钮

### 3.3 勾选交互（打包确认）

在 LoadoutPage 中，装备已填入各槽位后：

- **tap** 装备项 → 切换 checked 状态（✓ / 未勾选），用于出发前打包确认
- **long-press** 装备项 → 展开操作菜单（移除、修改层级、查看装备详情）
- 勾选状态变化时：checkbox 出现 spring 弹性动画 + 行标底色微变（浅绿 tint）

### 3.4 空态设计

- 首次进入（行程无装备）：中央留白区展示引导图 + 一句话文案「tap 下方按钮，开始装备你的旅程」
- 特定 Zone 为空：卡片内显示虚线占位 + 灰色提示「还没有 {zoneName} 装备」
- 全部勾选完毕：顶部 banner 显示 "Ready to go! 🎒" + 完成进度 100%

### 3.5 进度指示

LoadoutPage 顶部固定一个轻量进度条/数字：
- 格式：`已装包 {checked}/{total}`
- 数字变化时使用 counter 滚动动画（~400ms ease-out）
- 100% 时进度条颜色从默认灰变为主题绿 + 微弹动画

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
- **新行程**：`group` 写入 BodyZone 枚举值
- **旧行程**：`group` 保持原值，LoadoutPage 按 `CATEGORY_SLOT_MAP` 重新推断 Zone 展示
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
│   ├── LoadoutPage.ets          # 主页面：替代 ChecklistDetail
│   ├── LoadoutZoneCard.ets      # Zone 卡片组件
│   ├── LoadoutGearItem.ets      # 单个装备项组件
│   └── LoadoutProgressBar.ets   # 顶部进度条组件
├── components/sheets/
│   └── GearPickerSheet.ets      # 装备选择半模态 Sheet
└── services/
    └── LoadoutService.ets       # 配装业务逻辑（分槽/排序/进度计算）
```

### 5.2 组件职责

#### LoadoutPage（主页面）
- 替代 ChecklistDetail 作为行程详情页
- 管理整体状态：当前行程、配装列表、勾选进度
- 顶部：行程标题 + 进度指示
- 中部：2 列 Zone 卡片网格（WaterFlow / GridRow）
- 底部：悬浮「＋ 添加装备」按钮
- 通过 SheetOverlay 路由呼出 GearPickerSheet

#### LoadoutZoneCard（区域卡片）
- 展示单个 BodyZone 的所有装备
- 卡片标题 = Zone 中文名（头部 / 上身 / 下身 / 脚部 / 背负 / 睡眠 / 杂项）
- 内部 ForEach 渲染 LoadoutGearItem，按 LayerOrder 排序
- 空态时显示虚线占位引导
- 卡片整体纯白 + 圆角 16vp + 无边框

#### LoadoutGearItem（装备项）
- 单行展示：[层级badge] + 装备名 + [重量] + [✓]
- tap → 切换 checked
- long-press → 展开操作 sheet
- checked 状态：文字降低透明度 + 行标底色变浅绿
- 出场动画：staggered translateY(12vp→0) + fadeIn

#### LoadoutProgressBar（进度条）
- 横条进度 + 数字 `已装包 N/M`
- 数字用 counter 滚动动画
- 100% 时色变 + 弹动

#### GearPickerSheet（选择 Sheet）
- 通过 SheetOverlay 统一路由
- 装备库列表，按品类 tab 筛选（复用 CategoryTagGroup）
- 搜索栏 + 列表
- 已在当前行程中的装备标记 ✓
- tap 装备 → 创建 ChecklistItem → 自动分配 group（Zone）→ 关闭或继续选
- 支持连续多选模式（不自动关闭，用户手动关闭）

#### LoadoutService（业务逻辑）
- `assignSlot(gear: GearItem): { zone: BodyZone, layer: LayerOrder }` — 封装 CATEGORY_SLOT_MAP 查询
- `sortItemsByLayer(items: ChecklistItem[], gears: GearItem[]): ChecklistItem[]` — 按层级排序
- `groupByZone(items: ChecklistItem[]): Map<BodyZone, ChecklistItem[]>` — 按 Zone 分组
- `calcProgress(items: ChecklistItem[]): { checked: number, total: number }` — 进度计算
- `inferZoneFromGroup(group: string): BodyZone` — 旧数据 group → Zone 推断

### 5.3 与现有系统的集成点

| 集成点 | 方式 |
|--------|------|
| 页面路由 | SheetOverlay 或 NavPathStack pushPath |
| 装备库数据 | 从 Index.ets @Provide gears 下发 |
| 行程数据 | 从 Index.ets @Provide checklists 下发 |
| 数据持久化 | 复用现有 DataService.saveChecklists() |
| Sheet 呼出 | 通过 SheetOverlay 路由（与 GearFormSheet 等同级） |
| 品类筛选 | 复用 CategoryTagGroup 组件 |
| 动画 | 使用 AnimationTokens + AnimationUtils |

---

## 6. 视觉设计语言

### 6.1 整体风格

- 背景：`PAGE_BG`（#F8F9FA 羽白）
- 卡片：纯白无边框 + 圆角 16vp + `SHADOW_SUBTLE` 微阴影
- Zone 卡片标题：字阶 `TITLE_SM`，颜色 `TEXT_SECONDARY`
- 装备名：字阶 `BODY_MD`，颜色 `TEXT_MAIN`
- 底部添加按钮：主题绿 `PRIMARY_COLOR` 胶囊形

### 6.2 层级 Badge 配色

| Layer | 中文 | Badge 颜色 |
|-------|------|-----------|
| Base | 贴身 | #E3F2FD 浅蓝 |
| Mid | 保暖 | #FFF3E0 浅橙 |
| Shell | 防护 | #E8F5E9 浅绿 |
| Insulation | 隔绝 | #F3E5F5 浅紫 |
| Accessory | 配件 | #F5F5F5 浅灰 |

Badge 仅在 UpperBody / LowerBody 卡片内显示（衣物分层有意义的区域），其余 Zone 隐藏层级 badge。

### 6.3 勾选态视觉

- 未勾选：正常显示
- 已勾选：文字透明度降至 0.5 + 行底色 `LIGHT_PRIMARY_COLOR` + 右侧 ✓ icon（`PRIMARY_COLOR`）
- 状态切换动画：opacity spring(0.25, 0.7) + 背景色 animateTo spring(0.35, 0.8)

### 6.4 Zone 卡片空态

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
| 底部按钮按压 | scale 三段式 | 1→0.96→1.02→1.0，Spring PRESS |
| GearPickerSheet 展开 | 半模态 Sheet 原生 + 背景 blur | 系统默认 |
| 进度数字变化 | counter 滚动 | ~400ms ease-out |
| 进度 100% 达成 | 色变 + scale bounce | Spring(0.3, 0.6) |
| 装备项长按 | scale(1→0.96) hold | Spring PRESS |

---

## 8. 边界情况处理

### 8.1 同一装备出现在多个 Zone？

**不允许**。一件装备只能落入一个 Zone（由 category 决定）。即使「穿着·配件」可能包含手套（理论上属 UpperBody），但为简化，统一按 CATEGORY_SLOT_MAP 预设分配。

### 8.2 用户对自动落槽不满意？

一期提供 long-press → 菜单中的「移动到其他区域」选项，修改 `ChecklistItem.group` 即可。此操作低频，不需要拖拽。

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

---

## 9. ChecklistDetail 替代策略

### 9.1 方案

LoadoutPage **完全替代** ChecklistDetail 作为行程详情页面：

- 原 ChecklistDetail.ets（868 行）保留代码文件但不再被路由引用
- Index.ets / SheetOverlay 中所有指向 ChecklistDetail 的调用改为指向 LoadoutPage
- 开发期间保留 ChecklistDetail 作为 fallback（通过 feature flag 控制），稳定后再物理删除

### 9.2 功能对齐清单

| ChecklistDetail 功能 | LoadoutPage 是否覆盖 | 备注 |
|---------------------|---------------------|------|
| 按分组展示装备 | ✅ 升级为 Zone 卡片 | 更结构化 |
| 勾选打包 | ✅ tap 勾选 | 相同功能 |
| 分组折叠/展开 | ❌ 移除 | Zone 卡片始终展开，信息密度不需要折叠 |
| 行程头部信息 | ✅ 顶部区域 | 标题 + 进度 + 目的地/时间 |
| 编辑装备 | ✅ long-press 菜单 | 路径稍变 |
| 添加装备 | ✅ GearPickerSheet | 升级为结构化选择 |
| 重量统计 | ✅ 保留 | Zone 卡片可显示分区重量小计 |
| 删除行程 | ✅ 保留 | 顶部更多菜单 |

---

## 10. 一期范围 & 不做清单

### 10.1 一期做（MVP）

- [x] LoadoutPage 主页面（2 列 Zone 卡片网格）
- [x] LoadoutZoneCard + LoadoutGearItem 组件
- [x] GearPickerSheet（从装备库选装 + 自动落槽）
- [x] tap 勾选 + long-press 菜单
- [x] 进度指示（已装包 N/M）
- [x] 自动落槽（CATEGORY_SLOT_MAP）
- [x] 替代 ChecklistDetail 作为行程详情
- [x] 空态设计
- [x] 所有动效接入 AnimationTokens
- [x] 旧数据兼容（inferZoneFromGroup）

### 10.2 一期不做（后续迭代）

- ❌ 阶段二「装包视图」（容器即实例 / 拖拽装入背包）
- ❌ Zone 间拖拽排序
- ❌ 用户自建 BodyZone
- ❌ 用户自建 Layer
- ❌ 智能推荐（按历史/天气/目的地）
- ❌ 配装模板（保存/套用）
- ❌ 分享配装卡片

---

## 11. 实现路径 & 文件依赖图

```
Phase 1: 基础组件
  ├── LoadoutService.ets（纯逻辑，无 UI）
  └── LoadoutGearItem.ets（最小渲染单元）

Phase 2: 容器组件
  ├── LoadoutZoneCard.ets（依赖 LoadoutGearItem）
  └── LoadoutProgressBar.ets

Phase 3: Sheet
  └── GearPickerSheet.ets（依赖 CategoryTagGroup + 装备库数据）

Phase 4: 主页面集成
  ├── LoadoutPage.ets（组装所有子组件）
  └── 接入路由（替换 ChecklistDetail 引用）

Phase 5: 动效 & 打磨
  ├── 入场动画
  ├── 勾选动画
  └── 进度动画
```

---

## 12. 验证标准（Done 的定义）

1. **构建通过**：`hvigorw assembleApp` 零 error
2. **功能完整**：从装备库选装 → 自动落槽 → 勾选确认全链路跑通
3. **旧数据不崩**：打开旧行程能正常渲染（Zone 推断 + 兜底到 Misc）
4. **动效到位**：所有交互均有 Spring 弹性响应，无硬切
5. **空态优雅**：无装备 / 特定 Zone 空 / 装备库空三种空态都有引导
6. **性能达标**：50+ 装备项的行程渲染无掉帧（保持 60fps）
7. **体验验证**：配装过程有「像玩游戏」的感觉，不是在「填表格」

---

## 13. 风险 & 缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Misc Zone 内容过多导致卡片过长 | 视觉失衡 | Misc 卡片内按品类再分组 or 限制单卡最大高度可滚动 |
| 自动落槽准确率不高（如防风手套属 Head 而非 UpperBody） | 用户困惑 | 提供 long-press 移动功能 + 后续迭代优化映射 |
| 2 列布局在小屏手机挤压 | 文字截断 | 响应式：宽度 < 360vp 时降为 1 列 |
| ChecklistDetail 替换影响面大 | 回归 bug | Feature flag 控制 + 保留旧组件作为 fallback |
| 层级 badge 对非户外用户无感 | 认知噪音 | 仅衣物 Zone 显示，其余 Zone 隐藏 |

---

## 14. 与纲领文档的对齐确认

| 纲领 §4 要求 | 本 spec 对齐情况 |
|-------------|-----------------|
| §4.1 解决什么 | ✅ §0.2 完整承载 |
| §4.3 横轴×纵轴 | ✅ §2 完整定义 |
| §4.4 容器即实例 | ⏸️ 一期不做，§10.2 明确留位 |
| §4.5 功能×位置正交 | ✅ Zone=位置，Layer=功能结构 |
| §4.6 结构强度光谱 | ✅ 衣物强结构（层级badge）→ 杂项弱结构（朴素列表） |
| §4.7 两阶段流水线 | ⏸️ 一期只做阶段一（选装），阶段二留位 |

---

## 附录 A：Zone 中文名映射

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
