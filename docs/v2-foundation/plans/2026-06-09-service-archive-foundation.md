# PackCheck 服役档案 · 地基层 实现计划

> **For agentic workers / 给落地实现者（务必先读）：**
> 本计划用于**新开会话从零接手落地**，执行者对本项目无任何上下文记忆。开始任何编码前，**必须按下方「0. 必读上下文」逐个用 Read 工具读完所有引用文档**，再动手。步骤用 checkbox（`- [ ]`）跟踪，逐任务执行、逐任务构建验证、逐任务 commit。
>
> **执行纪律（来自 CLAUDE.md 开发铁律，最高优先级）：**
> - 最小改动；改完即跑 `hvigorw assembleApp`，构建不过不提交、不进下一步。
> - 禁止注释报错绕过；禁止 hardcode mock 绕过逻辑。
> - 新增字段一律 optional，向后兼容旧数据。
> - 一次只做一件事；每个任务构建通过后立即 `git add -A && git commit`。
> - 禁止在组件中硬编码色值/字号/时长/曲线，必须从 constants 引用。

**Goal:** 落地 PackCheck v2「服役档案」第一步地基层——删除失效的资产趋势图，补齐 packing/archive 双核数据字段，新增「我」Tab 人生足迹年报叙事，装备展开区改双段结构，行程录入改渐进式 chip，全局文案温柔化，并为第二步塔科夫配装零成本预埋品类→槽位映射种子。

**Architecture:** 鸿蒙原生 App（ArkTS + ArkUI，API 23+，SDK 6.1.0）。中心状态管理器模式——`pages/Index.ets` 持有全部 @State，通过 @Prop + callback 向下分发给页面组件。Tab 用 `HdsTabs` + `customTabBar` @Builder 承载。持久化用 `preferences` KV（`services/PackStore.ets`）。所有动效统一 Spring 曲线，常量从 `constants/` 引用。

**Tech Stack:** ArkTS / ArkUI / @kit.UIDesignKit（HdsTabs）/ @kit.ArkData（preferences）/ hvigorw 构建。

---

## 0. 必读上下文（编码前必须全部读完）

**执行者第一步：用 Read 工具按顺序读完以下文件，建立完整上下文。漏读任何一项都会导致方向偏离。**

### 0.1 纲领与规范文档（定方向，不可违背）

| 文件 | 作用 | 重点章节 |
|------|------|---------|
| `docs/design/2026-06-04-product-vision-and-restructure.md`（v2） | **产品愿景纲领，最高方向依据** | §0.1 根本基调、§3 服役档案机制、§4 塔科夫配装（第二灵魂）、§6 三步走 |
| `docs/superpowers/specs/2026-06-09-service-archive-restructure-design.md` | **本计划的直接来源 spec**，含全部决策、数据模型 diff、各页面交互、文案词典 | 全文必读 |
| `CLAUDE.md` | 协作准则 + 开发铁律 + UI/UX/动效规范 | 开发铁律、UI/UX 规范、关键常量文件表 |
| `docs/DEVELOPMENT_STANDARDS.md` | 架构规范 + 设计语言 + 动效统一规范 + 组件封装规范 | 全文 |
| `memory/MEMORY.md`「ArkUI 避坑清单」 | 34 条 ArkUI 踩坑记录，遇动效/手势/布局问题先查 | 全文 |

### 0.2 核心代码文件现状（已摸底，落地前再 Read 确认行号未漂移）

| 文件 | 职责 | 本计划涉及的关键点 |
|------|------|---------|
| `entry/src/main/ets/models/PackModels.ets` | 数据模型 | `GearItem`、`TripChecklist`、`ChecklistItem`、`AssetEvent`/`AssetTotals`（待删）、`DEFAULT_CATEGORIES`（13 品类） |
| `entry/src/main/ets/services/PackStore.ets` | preferences 持久化 | `KEY_ASSET_EVENTS`/`getAssetEvents`/`saveAssetEvents`/`appendAssetEvent`（待删） |
| `entry/src/main/ets/pages/Index.ets`（约 2341 行） | 中心状态管理器 | 第 1876 行 `HdsTabs` 2 个 TabContent；第 1836 行 `customTabBar` @Builder；`currentTabIndex`/`tabSwipeProgress` tab 切换机制（第 129/132 行）；tab 边界判断 `=== 0/1`（约 2015/2017 行）；趋势图调用点（见 spec §3.4） |
| `entry/src/main/ets/components/GearPage.ets` | 装备库页 | 装备就地展开（`@Prop expandedGearId` 第 73 行）；`@Prop assetEvents`（待删）；`AssetTrendCard` 渲染块（约 1083 行）；展开区 DetailLine 结构 |
| `entry/src/main/ets/components/HomePage.ets` | 行程列表页 | 「新建行程」入口（约 757 行 QuickEntry）；`onOpenTrip` 触发仪式 |
| `entry/src/main/ets/components/AssetTrendCard.ets`（约 601 行） | 资产趋势图组件 | **整个文件待删** |
| `entry/src/main/ets/utils/AnimationUtils.ets` | 通用动画封装 | `counterAnimate(from, to, callback)`（第 98 行，人生足迹数字滚动直接复用）、`staggeredAnimationOptions`、`pressHandler` |
| `entry/src/main/ets/constants/Colors.ets` | 色彩 token | `PRIMARY_COLOR=#2D7D46`、`PAGE_BG=#F8F9FA`、`CARD_BG=#FFFFFF`、`TEXT_SECONDARY=#666`、`TEXT_TERTIARY=#999` |
| `entry/src/main/ets/constants/Layout.ets` | 布局 token | `CARD_RADIUS=20`、`SMALL_CARD_RADIUS=12`、`CHIP_RADIUS=18` |
| `entry/src/main/ets/constants/AnimationTokens.ets` | Spring 预设 | `SPRING_GENERAL`、`SPRING_TAB_ICON` 等 |

### 0.3 已拍板的 8 个决策（速查，详见 spec §1）

1. 3 Tab：行程 + 装备库 + 我
2. 「我」Tab 顶部 = 人生足迹年报叙事（沉浸绿幕 + 拟人化 + “故事都在你心里”留白）
3. 装备详情履历 = 陪伴卡片（大数字陪伴天数 + 三 chip）
4. 行程录入 = 渐进式 chip（默认只露名称+选装备，5 字段藏成可点亮标签）
5. 文案语气 = 温柔陪伴（服役→陪伴、任务→同行、老兵→相伴最久的伙伴、战绩→这一路走来）
6. 第一步范围 = 地基层（packing 做 L0 + 数据层为 L1 预留）
7. 装备展开区 = 属性区 + 陪伴区上下分段，双段常驻
8. packing 地基层 = L0 + 数据种子（品类→槽位映射）为第二步塔科夫配装预埋

### 0.4 构建/验证方式（本项目无 pytest 式单测，验证 = 构建 + UI 自检）

- 构建命令：`cd /Users/bghost233/Documents/PackCheck && hvigorw assembleApp`（构建通过 = 该任务的硬验证）
- UI 自检：构建通过后在模拟器/真机查验对应交互与视觉（每个 UI 任务都列了自检要点）
- 每任务 commit：`git add -A && git commit -m "<message>"`

---

## 1. 文件结构（本计划新建/修改/删除清单）

**新建：**
- `entry/src/main/ets/constants/GearLoadout.ets` —— 配装数据种子（BodyZone/LayerOrder 枚举 + CATEGORY_SLOT_MAP），第二步预埋
- `entry/src/main/ets/components/ProfilePage.ets` —— 「我」Tab 页面，承载人生足迹年报叙事
- `entry/src/main/ets/services/FootprintService.ets` —— 人生足迹聚合计算（纯函数，从 checklists 算累计里程/爬升/地点数/相伴最久伙伴）

**修改：**
- `models/PackModels.ets` —— GearItem 加 brand?/acquiredAt?；TripChecklist 加 5 结构化字段；删 AssetEvent/AssetTotals
- `services/PackStore.ets` —— 删趋势图数据链路
- `pages/Index.ets` —— 删趋势图调用点；扩 3 Tab；新增 ProfilePage @State 与分发；tab 边界判断从 2 改 3
- `components/GearPage.ets` —— 删趋势图引用；展开区改双段结构
- `components/HomePage.ets` —— 行程录入入口/表单改渐进式 chip（结构化字段）
- 全局多文件 —— 文案温柔化（按 spec §5 词典）

**删除：**
- `components/AssetTrendCard.ets` —— 整个文件

> **拆分原则（来自 writing-plans + DEVELOPMENT_STANDARDS）**：人生足迹聚合逻辑拆成独立 `FootprintService.ets` 纯函数文件，与 UI（ProfilePage）分离，便于复用与单点验证。配装种子拆成独立 `GearLoadout.ets` 常量文件，职责单一。

---

## 2. 任务总览与依赖顺序

```
Task 1  数据模型 diff（GearItem/TripChecklist 加字段 + 删 AssetEvent/AssetTotals）   ← 地基中的地基
Task 2  删除趋势图数据链路（PackStore）
Task 3  删除趋势图 UI（AssetTrendCard.ets + GearPage/Index 引用）
Task 4  新增配装数据种子 GearLoadout.ets（第二步预埋）
Task 5  新增 FootprintService.ets（人生足迹聚合纯函数）
Task 6  新增 ProfilePage.ets + 扩为 3 Tab（接入 Index 状态分发）
Task 7  装备展开区改双段结构（属性区 + 陪伴区）
Task 8  行程录入改渐进式 chip（结构化字段）
Task 9  全局文案温柔化（按词典）
Task 10 收尾：全量 grep 残留检查 + 整体构建 + UI 自检
```

依赖关系：Task 1 是所有后续的前提（字段先就位）。Task 2→3 是删除链（先删数据层再删 UI 层，避免悬空引用），三者构成一个原子单元、在 Task 3 末尾统一构建+commit。Task 5→6 有依赖（ProfilePage 用 FootprintService）。其余相对独立。**严格按编号顺序执行。**

---

## 3. 详细任务

### Task 1: 数据模型 diff —— 补双核字段 + 删趋势图接口

**Files:** Modify `entry/src/main/ets/models/PackModels.ets`

- [ ] **Step 1: 给 GearItem 补 packing/archive 字段（全 optional）**，在 `createdAt` 后追加：

```ts
export interface GearItem {
  id: string;
  name: string;
  category: string;
  weight?: number;
  price?: number;
  note?: string;
  tripCount?: number;
  createdAt: number;
  brand?: string;        // 品牌（packing：辨识/复购参考；纲领 §2.2 降级保留为可选属性）
  acquiredAt?: number;   // 入手时间戳（archive：陪伴天数 = now - acquiredAt；与 createdAt 录入时间区分，纲领 §3.5）
}
```

- [ ] **Step 2: 给 TripChecklist 补结构化经历字段（全 optional）**，在 `createdAt` 后追加：

```ts
export interface TripChecklist {
  id: string;
  title: string;
  date?: string;
  dateAt?: number;
  items: ChecklistItem[];
  createdAt: number;
  destination?: string;     // 目的地
  distanceKm?: number;      // 里程（km）
  maxAltitude?: number;     // 最高海拔（m）
  ascentM?: number;         // 累计爬升（m）
  durationHours?: number;   // 时长（h）
}
```

- [ ] **Step 3: 删除 AssetEvent 与 AssetTotals 接口整段**（落地前 grep `AssetEvent`/`AssetTotals` 定位精确行）。

- [ ] **Step 4: 暂不构建、暂不 commit。** 删接口会导致引用断裂，需 Task 2/3 一起清完。继续 Task 2。

> 注意：`DEFAULT_CATEGORIES`、`ChecklistItem`（其 `checked`/`fromGearId` 已存在，是 L1 勾选清单的现成底座，**不改**）、`makeId`、`normalizeNumber` 保持不动。

---

### Task 2: 删除趋势图数据链路（PackStore）

**Files:** Modify `entry/src/main/ets/services/PackStore.ets`

- [ ] **Step 1:** import 删 `AssetEvent`（第 3 行）：
```ts
import { DEFAULT_CATEGORIES, GearItem, TripChecklist } from '../models/PackModels';
```
- [ ] **Step 2:** 删常量 `const KEY_ASSET_EVENTS = 'packcheck_asset_events';`（约 12 行）。
- [ ] **Step 3:** 删 `getAssetEvents` / `saveAssetEvents` / `appendAssetEvent` 三个方法整段（约 91-104 行）。
- [ ] **Step 4:** 暂不构建，继续 Task 3。

---

### Task 3: 删除趋势图 UI（组件文件 + 所有引用）

**Files:** Delete `components/AssetTrendCard.ets`；Modify `components/GearPage.ets`、`pages/Index.ets`

- [ ] **Step 1: 删整个文件**
```bash
rm /Users/bghost233/Documents/PackCheck/entry/src/main/ets/components/AssetTrendCard.ets
```

- [ ] **Step 2: GearPage.ets 清理**
  - 第 14 行 import 去掉 `AssetEvent`：`import { GearItem, TripChecklist } from '../models/PackModels';`
  - 第 16 行删 `import { AssetTrendCard } from './AssetTrendCard';`
  - 第 116 行删 `@Prop assetEvents: AssetEvent[] = [];`
  - 约 1083 行删整个 `AssetTrendCard({ ... })` 渲染块（删到该组件调用闭合）。

- [ ] **Step 3: Index.ets 清理**（落地前先 grep 各点确认行号）
  - 第 47 行 import 删 `AssetEvent, AssetTotals` → `import { ChecklistItem, GearItem, makeId, normalizeNumber, TripChecklist } from '../models/PackModels';`
  - 第 184 行删 `@State private assetEvents: AssetEvent[] = [];`（含上方 `// ===== 资产趋势 =====` 注释）
  - 约 233 行删 `await this.backfillAssetEvents();`
  - 约 235 行删 `this.assetEvents = await this.store.getAssetEvents();`
  - 约 241-270 行删整个 `backfillAssetEvents()` 方法
  - 约 606-616 行删 `computeAssetTotals()` 方法 ⚠️ **先 grep 该方法是否被「装备库总价/总数」展示复用——若被复用则保留计算、仅删事件记录调用**
  - 约 668-694、853-865、909-920 行删 4 处增/改/单删/批删后的 `appendAssetEvent`+`getAssetEvents` 回填块（**只删事件记录相关行，装备增删改本身逻辑保留**）
  - 约 1918 行删传给 GearPage 的 `assetEvents: this.assetEvents,` 入参行

- [ ] **Step 4: 全量 grep 确认零残留**
```bash
cd /Users/bghost233/Documents/PackCheck
grep -rn "AssetEvent\|AssetTotals\|AssetTrendCard\|appendAssetEvent\|getAssetEvents\|saveAssetEvents\|KEY_ASSET_EVENTS\|assetEvents\|backfillAssetEvents" entry/src/main/ets
```
Expected: 无输出（若 `computeAssetTotals` 被复用而保留，则它不在此清单内，属正常）

- [ ] **Step 5: 构建验证（Task 1+2+3 原子单元）**
```bash
cd /Users/bghost233/Documents/PackCheck && hvigorw assembleApp
```
Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**
```bash
git add -A && git commit -m "refactor: 删除失效的资产趋势图链路，补双核数据字段 brand/acquiredAt/行程结构化字段"
```

---

### Task 4: 新增配装数据种子 GearLoadout.ets（第二步预埋）

**Files:** Create `entry/src/main/ets/constants/GearLoadout.ets`

> 地基层只建表不用，为第二步塔科夫配装零成本预埋（spec §3.5 / §6，纲领 §4）。

- [ ] **Step 1: 创建文件**（`CATEGORY_SLOT_MAP` 的 key 必须与 `PackModels.ets` 的 `DEFAULT_CATEGORIES` 13 项严格一致——落地前先 Read DEFAULT_CATEGORIES 核对中文名）

```ts
// entry/src/main/ets/constants/GearLoadout.ets
// 塔科夫式配装系统数据种子（第二步实现配装 UI 时使用，地基层只建表）。纲领 §4 / spec §3.5、§6

// 横轴：身体部位 / 容器槽位（纲领 §4.3）
export enum BodyZone {
  Head = 'head',
  UpperBody = 'upper',
  LowerBody = 'lower',
  Feet = 'feet',
  Carry = 'carry',
  Sleep = 'sleep',
  Misc = 'misc',
}

// 纵轴：分层顺序（贴身→最外，纲领 §4.3）
export enum LayerOrder {
  Base = 1,
  Mid = 2,
  Shell = 3,
  Insulation = 4,
  Accessory = 9,
}

export interface SlotHint {
  zone: BodyZone;
  layer: LayerOrder;
}

// 品类 → 默认槽位（弱映射，第二步可手动微调）。key 与 DEFAULT_CATEGORIES 严格一致
export const CATEGORY_SLOT_MAP: Record<string, SlotHint> = {
  '证件':       { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '穿着·上身':  { zone: BodyZone.UpperBody, layer: LayerOrder.Mid },
  '穿着·下身':  { zone: BodyZone.LowerBody, layer: LayerOrder.Base },
  '穿着·配件':  { zone: BodyZone.Head,      layer: LayerOrder.Accessory },
  '背负系统':   { zone: BodyZone.Carry,     layer: LayerOrder.Accessory },
  '行走系统':   { zone: BodyZone.Feet,      layer: LayerOrder.Base },
  '睡眠系统':   { zone: BodyZone.Sleep,     layer: LayerOrder.Accessory },
  '饮食系统':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '电力系统':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '摄影系统':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '安全急救':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '清洁洗护':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '其他':       { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
};

// 给定品类返回槽位提示，未命中回退到 Misc/Accessory
export function slotHintForCategory(category: string): SlotHint {
  return CATEGORY_SLOT_MAP[category] ?? { zone: BodyZone.Misc, layer: LayerOrder.Accessory };
}
```

- [ ] **Step 2: 构建验证**（纯常量文件，须构建确保无语法错误且 ArkTS 接受 Record 类型）
```bash
cd /Users/bghost233/Documents/PackCheck && hvigorw assembleApp
```
Expected: BUILD SUCCESSFUL
> ⚠️ ArkTS 对 `Record<string, T>` 和对象字面量有严格约束，若报错查 `memory/MEMORY.md` ArkUI 避坑清单；必要时改用显式 interface + `as` 断言。

- [ ] **Step 3: Commit**
```bash
git add -A && git commit -m "feat: 新增配装数据种子 GearLoadout（品类→槽位映射，为第二步塔科夫配装预埋）"
```

---

### Task 5: 新增 FootprintService.ets（人生足迹聚合纯函数）

**Files:** Create `entry/src/main/ets/services/FootprintService.ets`

> 「我」Tab 顶部年报叙事的数据来源。纯函数，从 `TripChecklist[]` + `GearItem[]` 聚合。spec §4.1。**遵循「数据是钥匙、故事在用户心里」——只算可结构化的事实，不编造情感文案的具体内容。**

- [ ] **Step 1: 创建文件**

```ts
// entry/src/main/ets/services/FootprintService.ets
// 人生足迹聚合（纯函数）。「我」Tab 年报叙事数据源。spec §4.1
import { GearItem, TripChecklist } from '../models/PackModels';

export interface Footprint {
  tripCount: number;         // 同行次数
  totalDistanceKm: number;   // 累计里程
  totalAscentM: number;      // 累计爬升
  maxAltitude: number;       // 到过的最高海拔
  placeCount: number;        // 去过的地方数（destination 去重计数）
  gearCount: number;         // 装备总数
  longestCompanion?: LongestCompanion;  // 相伴最久的伙伴
}

export interface LongestCompanion {
  name: string;
  days: number;   // 陪伴天数 = now - acquiredAt（无 acquiredAt 则用 createdAt 兜底）
}

const MS_PER_DAY = 86400000;

export function computeFootprint(trips: TripChecklist[], gears: GearItem[]): Footprint {
  let totalDistanceKm = 0;
  let totalAscentM = 0;
  let maxAltitude = 0;
  const places = new Set<string>();

  for (const t of trips) {
    if (typeof t.distanceKm === 'number') totalDistanceKm += t.distanceKm;
    if (typeof t.ascentM === 'number') totalAscentM += t.ascentM;
    if (typeof t.maxAltitude === 'number' && t.maxAltitude > maxAltitude) maxAltitude = t.maxAltitude;
    if (t.destination && t.destination.trim().length > 0) places.add(t.destination.trim());
  }

  return {
    tripCount: trips.length,
    totalDistanceKm: Math.round(totalDistanceKm),
    totalAscentM: Math.round(totalAscentM),
    maxAltitude,
    placeCount: places.size,
    gearCount: gears.length,
    longestCompanion: computeLongestCompanion(gears),
  };
}

function computeLongestCompanion(gears: GearItem[]): LongestCompanion | undefined {
  if (gears.length === 0) return undefined;
  const now = Date.now();
  let best: GearItem | undefined;
  let bestStart = Number.MAX_SAFE_INTEGER;
  for (const g of gears) {
    const start = typeof g.acquiredAt === 'number' ? g.acquiredAt : g.createdAt;
    if (start < bestStart) {
      bestStart = start;
      best = g;
    }
  }
  if (!best) return undefined;
  const days = Math.max(0, Math.floor((now - bestStart) / MS_PER_DAY));
  return { name: best.name, days };
}
```

- [ ] **Step 2: 构建验证** `cd /Users/bghost233/Documents/PackCheck && hvigorw assembleApp` → BUILD SUCCESSFUL
- [ ] **Step 3: Commit** `git add -A && git commit -m "feat: 新增 FootprintService 人生足迹聚合（里程/爬升/海拔/地点/相伴最久伙伴）"`

---

### Task 6: 新增 ProfilePage.ets + 扩为 3 Tab

**Files:** Create `components/ProfilePage.ets`；Modify `pages/Index.ets`

> 这是地基层的「灵魂可见性」核心任务——验收判据：用户打开「我」Tab 会不会想截图（spec §8）。设计须落实 CLAUDE.md UI/UX 规范：Spring 曲线、按压三段式、staggered 入场、数字 counter 滚动（复用 `AnimationUtils.counterAnimate`）。配色用沉浸绿幕（`PRIMARY_COLOR`）+ 留白文案，**不堆数据炫技，文案温柔拟人**（决策 2）。

- [ ] **Step 1: 创建 ProfilePage.ets**（骨架；落地时按 spec §4.1 细化年报叙事视觉，数字滚动复用 counterAnimate）

```ts
// entry/src/main/ets/components/ProfilePage.ets
// 「我」Tab：人生足迹年报叙事。spec §4.1 / 决策 2。文案温柔拟人，留白为情感让路。
import { GearItem, TripChecklist } from '../models/PackModels';
import { computeFootprint, Footprint } from '../services/FootprintService';
import * as Colors from '../constants/Colors';
import * as Layout from '../constants/Layout';
import { counterAnimate } from '../utils/AnimationUtils';

@Component
export struct ProfilePage {
  @Prop trips: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];

  @State private footprint: Footprint = {
    tripCount: 0, totalDistanceKm: 0, totalAscentM: 0,
    maxAltitude: 0, placeCount: 0, gearCount: 0,
  };
  // counter 滚动展示值（aboutToAppear 时从 0 滚到真实值）
  @State private animDistance: number = 0;
  @State private animAscent: number = 0;

  aboutToAppear(): void {
    this.footprint = computeFootprint(this.trips, this.gears);
    counterAnimate(0, this.footprint.totalDistanceKm, (v: number) => { this.animDistance = Math.round(v); });
    counterAnimate(0, this.footprint.totalAscentM, (v: number) => { this.animAscent = Math.round(v); });
  }

  build() {
    Column() {
      // —— 顶部沉浸绿幕「人生足迹」（spec §4.1 黄金区）——
      // 文案示例（温柔拟人、留白）：
      //   "这一路，你和它们一起走了 {animDistance} 公里"
      //   "去过 {placeCount} 个地方 · 一起爬升 {animAscent} 米"
      //   "相伴最久的是「{longestCompanion.name}」，{days} 天了"
      // 视觉：PRIMARY_COLOR 渐变背景、大数字、staggered 淡入。具体实现按 spec §4.1。
      Text(`这一路，你和它们一起走了 ${this.animDistance} 公里`)
        .fontColor(Colors.CARD_BG)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.PAGE_BG)
  }
}
```

> **落地者注意**：以上是可编译骨架。完整年报叙事的视觉/动效请严格按 spec §4.1 与 CLAUDE.md UI/UX 规范实现（绿幕渐变、三 chip、留白「故事都在你心里」、staggered 40ms 错落）。`counterAnimate` 的真实签名落地前 Read `AnimationUtils.ets` 第 98 行确认（参数/回调形态）。

- [ ] **Step 2: Index.ets 扩为 3 Tab**

  落地前先 Read `Index.ets` 第 1836（customTabBar）、1876（HdsTabs）、2015/2017（tab 边界）、129/132（currentTabIndex/tabSwipeProgress）确认结构。改动点：
  - import ProfilePage
  - HdsTabs 内新增第 3 个 `TabContent() { ProfilePage({ trips: this.checklists, gears: this.gears }) }`，`.tabBar(this.customTabBar(2, /* icon */, '我'))`
  - `customTabBar` @Builder 若有按 index 硬编码的图标/文案分支，补 index===2 分支
  - **tab 滑动边界判断**：原 `currentTabIndex === 0 / === 1` 的硬编码（约 2015/2017），改为支持 3 tab 的边界（左边界 `index === 0` 不能再右拖左、右边界 `index === 2` 不能再左拖右）。`tabVisualWeight()` 跟手指示器逻辑同步核对，确保 3 段位移正确。
  - 确认 `tabsController`（HdsTabsController）的 index 范围与 navPathStack 不冲突。

  > ⚠️ 这是本任务最易踩坑处：tab 数从 2→3，所有「按 index 二选一」的硬编码都要升级为三态。落地后务必逐一滑动验证指示器跟手不跳变。

- [ ] **Step 3: 构建验证** `cd /Users/bghost233/Documents/PackCheck && hvigorw assembleApp` → BUILD SUCCESSFUL

- [ ] **Step 4: UI 自检**
  - 三个 Tab 可切换，底部胶囊 Tab 指示器跟手平滑（Spring，无跳变）
  - 左右滑动到首/尾 tab 时边界正确（不越界、不卡死）
  - 「我」Tab 数字 counter 从 0 滚动到真实值（~400ms）
  - 空数据（无行程/无装备）时不崩、文案兜底合理

- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: 新增「我」Tab 人生足迹年报叙事 + Tab 架构扩为 3 段"`

---

### Task 7: 装备展开区改双段结构（属性区 + 陪伴区）

**Files:** Modify `components/GearPage.ets`

> 决策 7：装备就地展开后，**上段属性区（packing 实用：重量/分组/品牌/价格，在前）+ 下段陪伴区（archive 情感：陪伴天数大数字 + 三 chip，在后）**，两段常驻。spec §4.2。体现双时态产品本质——出行前看属性、出行后看陪伴。

- [ ] **Step 1:** 落地前 Read `GearPage.ets` 第 73 行（`@Prop expandedGearId`）及展开渲染区（原 DetailLine 列表），确认现有展开结构。
- [ ] **Step 2: 重构展开区为双段**
  - **属性区（上）**：重量、分组（category）、品牌（brand，新字段，空则不显示该行）、价格。沿用现有 DetailLine 行样式，仅补 brand 行。
  - **分隔**：两段间用细分隔线或留白（`Layout` token，不硬编码）。
  - **陪伴区（下）**：
    - 大数字「陪伴天数」= `(now - (acquiredAt ?? createdAt)) / 86400000` 取整，counter 滚动（复用 `counterAnimate`）。
    - 三 chip：`同行 {tripCount} 次` / `相伴 {days} 天` / 第三 chip 按 spec §4.2（如「最近一次同行」或留白文案）。
    - 文案温柔（陪伴/同行，非服役/任务/战绩）。
  - 颜色/圆角/字号全部从 `Colors`/`Layout` 引用；按压元素加三段式按压反馈。
- [ ] **Step 3: 构建验证** → BUILD SUCCESSFUL
- [ ] **Step 4: UI 自检**：展开装备 → 上属性下陪伴双段呈现；陪伴天数 counter 滚动；brand 为空时不留空行；展开/收起有 Spring 过渡。
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: 装备展开区改双段结构（属性区+陪伴区，承载 packing/archive 双核）"`

---

### Task 8: 行程录入改渐进式 chip（结构化字段）

**Files:** Modify `components/HomePage.ets`

> 决策 4：行程录入默认只露「名称 + 选装备」，5 个结构化字段（destination/distanceKm/maxAltitude/ascentM/durationHours）藏成可点亮 chip——点亮才展开输入，不强迫填写。spec §4.3。体现「数据是钥匙」——填了就解锁人生足迹，不填也不挡路。

- [ ] **Step 1:** 落地前 Read `HomePage.ets` 行程新建/编辑入口（约 757 行 QuickEntry 及表单 Sheet）确认现有录入结构。
- [ ] **Step 2: 表单改造**
  - 主区保留：行程名称（title）、选装备。
  - 5 个字段做成一排可点亮 chip（灰=未填，绿=已填）：目的地、里程、海拔、爬升、时长。点击 chip 展开对应输入（数字键盘 for 数值字段），Spring 展开 + 背景模糊（按 CLAUDE.md：二级展开必须有过渡+高斯模糊）。
  - 保存时将值写入 TripChecklist 对应 optional 字段；空值不写（保持向后兼容）。
  - chip 用 `CHIP_RADIUS`，配色用 token。
- [ ] **Step 3: 构建验证** → BUILD SUCCESSFUL
- [ ] **Step 4: UI 自检**：新建行程默认只见名称+选装备；点 chip 平滑展开输入；填写后 chip 点亮；保存后重开能回显；全空也能正常存。
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: 行程录入改渐进式 chip（5 结构化字段按需点亮，解锁人生足迹）"`

---

### Task 9: 全局文案温柔化

**Files:** 多文件（按 grep 结果）

> 决策 5 / spec §5 文案词典。把「服役感/任务感/战绩感」措辞替换为温柔陪伴叙事。

- [ ] **Step 1: grep 现存待替换文案**
```bash
cd /Users/bghost233/Documents/PackCheck
grep -rn "服役\|任务\|老兵\|战绩\|出勤\|资产\|履历" entry/src/main/ets
```
- [ ] **Step 2: 按 spec §5 词典逐处替换**（示例，最终以 spec §5 为准）：
  - 服役 → 陪伴 / 同行
  - 任务（次数）→ 同行（次数）
  - 老兵 → 相伴最久的伙伴
  - 战绩 → 这一路走来
  - 资产/履历 → 陪伴记录 / 故事
  - 逐处替换，注意保持句子通顺，不机械替换破坏语义。
- [ ] **Step 3: 构建验证** → BUILD SUCCESSFUL
- [ ] **Step 4: UI 自检**：抽查各页面文案语气统一为温柔陪伴，无残留生硬军事/资产措辞。
- [ ] **Step 5: Commit** `git add -A && git commit -m "polish: 全局文案温柔化（服役→陪伴，按 spec 文案词典）"`

---

### Task 10: 收尾 —— 残留检查 + 整体构建 + UI 自检

- [ ] **Step 1: 残留与一致性 grep**
```bash
cd /Users/bghost233/Documents/PackCheck
grep -rn "AssetEvent\|AssetTrendCard\|appendAssetEvent\|KEY_ASSET_EVENTS" entry/src/main/ets   # 期望空
grep -rn "currentTabIndex === 1\b" entry/src/main/ets                                          # 核对 3-tab 边界无遗漏二态硬编码
```
- [ ] **Step 2: 整体构建** `cd /Users/bghost233/Documents/PackCheck && hvigorw assembleApp` → BUILD SUCCESSFUL
- [ ] **Step 3: 端到端 UI 自检（地基层验收，对照 spec §8）**
  - 三 Tab 完整可用、指示器跟手平滑、滑动边界正确。
  - 「我」Tab 人生足迹年报呈现、数字 counter 滚动、文案温柔——**核心判据：会不会想截图？**
  - 装备展开双段（属性+陪伴）正常。
  - 行程渐进式 chip 录入正常、字段回显正确。
  - 旧数据（无新字段）打开 App 不崩、字段缺省合理（向后兼容）。
- [ ] **Step 4: 最终 commit（如有零散收尾改动）** `git add -A && git commit -m "chore: 地基层收尾，整体构建与 UI 自检通过"`

---

## 4. Self-Review（计划完成后由执行者勾选）

- [ ] **spec 覆盖检查**：本计划是否覆盖 spec §3 数据模型 diff 全部条目？§4.1/§4.2/§4.3/§4.4（packing L0）各页面交互是否都有对应任务？（注：§4.4 packing L0 纯查阅在地基层主要体现为装备展开区属性段 + GearLoadout 种子，无独立配装 UI——配装 UI 属第二步。若 spec §4.4 有独立 L0 查阅页需求，需补任务。）
- [ ] **决策一致性**：8 个决策是否都在计划中体现？（3Tab✓ 年报叙事✓ 陪伴卡✓ 渐进chip✓ 文案✓ 地基范围✓ 双段展开✓ 配装种子✓）
- [ ] **占位符扫描**：所有代码块是否零占位符、可直接落地？（ProfilePage/装备展开区/行程表单视觉细节标注为「按 spec §X 实现」是有意为之——它们依赖 spec 视觉规格，执行者须对照 spec 落地，但骨架代码可编译。）
- [ ] **向后兼容**：所有新增字段是否 optional？删除趋势图是否清理彻底无悬空引用？
- [ ] **行号准确性**：执行者每个任务落地前是否都先 Read/grep 确认行号未漂移？（行号为摸底时快照，可能随删除链变动。）
- [ ] **验证节奏**：每个改动任务是否都有 `hvigorw assembleApp` 构建验证 + commit？

---

## 5. 下一步 / Execution Handoff

**本计划是地基层（第一步）的完整实现蓝图。三步走全景见 spec §7 / 纲领 §6：**
- **第一步（本计划）地基层**：数据字段 + 3Tab + 人生足迹 + 双段展开 + 渐进 chip + 配装种子预埋。
- **第二步 引擎**：塔科夫式配装系统 UI（纲领 §4，第二个灵魂）—— 用本计划 Task 4 种下的 `GearLoadout` 槽位映射，落地横轴身体部位 × 纵轴分层的配装界面、容器即实例、两阶段流水线。
- **第三步 智能**：行程自动反哺、智能 PackCheck（L2）、年报智能生成等。

**给落地执行者两种推进方式（二选一）：**

**A. Inline 顺序执行（推荐用于本地基层）**
在新会话直接说「按 `docs/superpowers/plans/2026-06-09-service-archive-foundation.md` 执行，从 Task 1 开始」。逐任务做、逐任务构建+commit、勾选 checkbox。任务间有删除链依赖（Task 1-3 原子），适合单线顺序推进。

**B. Subagent-Driven（适合 Task 4/5 等独立任务并行）**
Task 4（GearLoadout）、Task 5（FootprintService）相互独立、与删除链无依赖，可派子代理并行起草。但 Task 6/7/8 都改大文件（Index.ets/GearPage.ets/HomePage.ets）且彼此可能触碰相邻区域，建议串行避免冲突。

> **无论哪种方式，新会话第一动作永远是：Read 本计划「0. 必读上下文」列出的全部文档，再动手。** 这是为了在新对话不丢失我们已对齐的产品方向与设计结论。
