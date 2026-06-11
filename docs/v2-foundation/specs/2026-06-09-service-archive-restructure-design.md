# PackCheck 服役档案重构 · 技术方案 Spec

> 版本：v2 · 2026-06-09
> 状态：✅ 已定稿（2026-06-09 用户 review 通过）
> 纲领文档：`docs/design/2026-06-04-product-vision-and-restructure.md`（v2）
> 落地计划：`docs/superpowers/plans/2026-06-09-service-archive-foundation.md`（地基层第一步）
> 本 spec 是纲领文档在工程层的落地，定义数据模型 diff、各页面交互逻辑、文案词典、三步走执行路径。

---

## 0. 产品双核（最高定位，先于一切交互）

PackCheck 是一个**双时态**产品，不是单时态的回忆录。同一份装备数据有两副面孔：

| 时态 | 角色 | 触发场景 | 频率 | 信息诉求 |
|------|------|----------|------|----------|
| **出行前 · Packing** | 整理行囊的依据 / 装备核对工具 | 每次出门前打包 | 高频刚需 | 硬属性：重量、分组、价格、是否已装包 |
| **出行后 · Archive** | 装备的服役档案 / 陪伴叙事 | 回顾、留存、被触动 | 低频高价值 | 软记录：陪伴天数、出行次数、走过的路 |

**铁律：两核并重，任何一核都不能把另一核挤到二级。**
产品名叫 PackCheck——「Pack（打包）+ Check（核对）」是字面承诺，出行前的实用价值是用户每次打开 app 的理由；服役档案是情感留存，是让用户舍不得卸载的理由。前者拉日活，后者拉留存，缺一不可。

之前一度有把装备展开区做成纯情感卡片的风险——**已否决**。实用属性必须在前，为打包服务；陪伴记录在后，为情感服务。

### 0.1 两个灵魂，不是一个（对齐纲领文档）

纲领文档把产品结构定义为**两个灵魂并立**，本 spec 必须如实承载，不可偏废：

- **灵魂一 · 服役档案 / 经历连接**（纲领 §3）→ archive 时态。装备陪我走过哪里，回看时被自己的足迹打动。
- **灵魂二 · 带格子的核查清单**（纲领 §4 v3 修订）→ packing 时态。出行前在预设好的身体部位格子里填装备，收拾行李时逐项打勾不漏带。格子是清单的骨架，清单是格子的核查能力，二者一体不分家。

> **修正记录**：本 spec v1-v2 曾把配装描述为独立的「塔科夫式两阶段流水线系统」。经 v3 产品反思（2026-06-22），确认配装不是独立系统——它是清单的分组骨架。两阶段流水线（选装→装包）和配装/清单双 Tab 切换已被推翻。详见纲领 §4 v3 修订。

---

## 1. 六个已拍板的产品形态决策

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | Tab 架构 | **3 Tab**：行程 + 装备库 + 我 |
| 2 | 「我」Tab 顶部黄金区 | **人生足迹 = 年报叙事**（沉浸绿幕 + 拟人化一句话 + "故事都在你心里"留白） |
| 3 | 装备详情履历形态 | **陪伴卡片**（大数字陪伴天数 + 三 chip，二步可下钻时间轴） |
| 4 | 行程录入形态 | **渐进式 chip**（默认只露名称 + 选装备，结构化字段藏成可点亮标签，规避记账困境） |
| 5 | 全局文案语气 | **温柔陪伴**（服役→陪伴、任务→同行、老兵→相伴最久的伙伴、战绩→这一路走来） |
| 6 | 第一步落地范围 | **地基层**（不含行程自动反哺闭环；packing 做 L0 + 数据层为 L1 预留） |

### 双核补充决策（2026-06-09）

| # | 决策点 | 结论 |
|---|--------|------|
| 7 | 装备展开区信息分层 | **A：属性区 + 陪伴区上下分段**，双段常驻可见，各司其职 |
| 8 | packing 时态地基层深度 | **L0 + 数据层为 L1 预留**：保证装备属性查阅完整，勾选状态字段预埋 optional，L1 交互留到紧接小迭代 |

---

## 2. Tab 架构（决策 1）

### 现状
2 个 TabContent：行程（HomePage，index 0）+ 装备库（GearPage，index 1），由 `HdsTabs` + `customTabBar` @Builder 承载。

### 目标
3 个 TabContent：

```
┌─────────────┬─────────────┬─────────────┐
│   行程       │   装备库     │     我       │
│  HomePage    │  GearPage   │  ProfilePage │
│  (index 0)   │ (index 1)   │  (index 2)  │
└─────────────┴─────────────┴─────────────┘
```

- 「行程」「装备库」沿用现有页面，仅做文案/交互增量。
- 「我」= 新增 `ProfilePage.ets`，承载人生足迹年报叙事（决策 2）。
- 底部胶囊毛玻璃 Tab 从 2 格扩为 3 格，保持悬浮 absolute + 内容穿透。

---

## 3. 数据模型 diff（向后兼容，新增字段全 optional）

### 3.1 GearItem —— 补 packing 硬属性 + archive 软记录字段

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
  // ↓ 新增（全 optional，旧数据有默认行为）
  brand?: string;           // 品牌（packing 时态：辨识/复购参考）
  acquiredAt?: number;      // 入手时间戳（archive 时态：陪伴天数 = now - acquiredAt）
}
```

- 陪伴天数 = `acquiredAt` 存在时 `Math.floor((now - acquiredAt) / 天)`；不存在则 fallback 用 `createdAt`，或显示「还没记录入手日期」。
- `brand`、`acquiredAt` 缺省时 UI 优雅降级，不强制填写。

### 3.2 TripChecklist —— 补结构化经历字段（决策 3 字段挂行程）

```ts
export interface TripChecklist {
  id: string;
  title: string;
  date?: string;
  dateAt?: number;
  items: ChecklistItem[];
  createdAt: number;
  // ↓ 新增（全 optional，渐进式 chip 点亮才填）
  destination?: string;     // 目的地
  distanceKm?: number;      // 里程
  maxAltitude?: number;     // 最高海拔
  ascentM?: number;         // 累计爬升
  durationHours?: number;   // 时长
}
```

### 3.3 ChecklistItem —— L1 数据底座已现成，无需改

```ts
export interface ChecklistItem {
  id: string;
  name: string;
  group: string;
  checked: boolean;     // ✅ 已存在 → L1「已装包」勾选直接复用
  weight?: number;
  price?: number;
  fromGearId?: string;  // ✅ 已存在 → 装备↔行程关联现成
}
```

> 关键发现：L1 勾选清单的数据底座（`checked` + `fromGearId`）已在现有模型中，地基层「数据层为 L1 预留」几乎零成本，无需新增字段。

### 3.4 待删除 —— 趋势图整条数据链路（自检后核实，涉及 5 文件）

人生足迹年报叙事取代资产趋势图。全量盘点结果如下，落地时需逐项清理，删后 grep 确认零残留再构建：

- **`models/PackModels.ets`**：删 `AssetEvent`、`AssetTotals` 接口。
- **`services/PackStore.ets`**：删 `KEY_ASSET_EVENTS` 常量、`getAssetEvents`、`saveAssetEvents`、`appendAssetEvent` 三方法。
- **`components/AssetTrendCard.ets`**：整个文件删除。
- **`components/GearPage.ets`**：
  - 删 import 中的 `AssetEvent`、`import { AssetTrendCard }`
  - 删 `@Prop assetEvents: AssetEvent[]`
  - 删 `AssetTrendCard({...})` 渲染块（约 1083 行）
- **`pages/Index.ets`**（调用点最多，重点）：
  - 删 import 中的 `AssetEvent, AssetTotals`
  - 删 `@State private assetEvents`（约 184 行）
  - 删 `backfillAssetEvents()` 方法 + 其在加载流程中的调用（约 233/241 行）
  - 删 `this.assetEvents = await this.store.getAssetEvents()`（约 235 行）
  - 删 `computeAssetTotals()` 方法（约 606 行）
  - 删增/改/单删/批删装备 4 处的 `appendAssetEvent` + 后续 `getAssetEvents` 回填（约 668-694、853-865、909-920 行）
  - 删向 GearPage 传 `assetEvents` 的 @Prop 绑定

> 注意：`computeAssetTotals` 若被「装备库总价/总数」展示复用，需确认后保留总价计算逻辑、仅剥离事件记录部分，不可整删。落地时先确认引用范围。

### 3.5 新增 —— 格子分组数据种子（地基层预埋，纯常量无 UI）

> 决策 A：统一清单界面的格子分组交互留到第二步，但**地基层零成本铺好数据地基**，让格子界面开箱即知分区，不返工。

格子分组的唯一前置数据依赖 = 纲领 §4.3「品类 → 格子 + 层级」映射。`category` 字段与 `DEFAULT_CATEGORIES` 已存在，地基层只需新增一张内置映射常量表（不做任何 UI）：

```ts
// constants/GearLoadout.ets（新增常量文件，地基层只建表不用）

// 横轴：身体部位 / 容器槽位（纲领 §4.3 横轴）
export enum BodyZone {
  Head = 'head',          // 头部：帽子/眼镜/面巾
  UpperBody = 'upper',    // 上半身：速干/抓绒/冲锋衣/羽绒
  LowerBody = 'lower',    // 下半身：保暖裤/冲锋裤
  Feet = 'feet',          // 脚部：袜/鞋
  Carry = 'carry',        // 背负容器：背包（容器升格，纲领 §4.4）
  Sleep = 'sleep',        // 睡眠堆栈（纲领 §4.6 强结构）
  Misc = 'misc',          // 零散品：饮食/电力/摄影/急救等列表区
}

// 纵轴：分层顺序（从贴身到最外，纲领 §4.3 纵轴）
export enum LayerOrder {
  Base = 1,      // 贴身层
  Mid = 2,       // 保暖层
  Shell = 3,     // 防风防水层
  Insulation = 4,// 重保暖（羽绒）
  Accessory = 9, // 配件/无明确分层
}

// 品类 → 默认槽位 + 默认层级（弱映射，第二步配装时可手动微调）
export interface SlotHint { zone: BodyZone; layer: LayerOrder; }
export const CATEGORY_SLOT_MAP: Record<string, SlotHint> = {
  '证件':      { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '穿着·上身': { zone: BodyZone.UpperBody, layer: LayerOrder.Mid },
  '穿着·下身': { zone: BodyZone.LowerBody, layer: LayerOrder.Base },
  '穿着·配件': { zone: BodyZone.Head,      layer: LayerOrder.Accessory },
  '背负系统':  { zone: BodyZone.Carry,     layer: LayerOrder.Accessory },
  '行走系统':  { zone: BodyZone.Feet,      layer: LayerOrder.Base },
  '睡眠系统':  { zone: BodyZone.Sleep,     layer: LayerOrder.Accessory },
  '饮食系统':  { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '电力系统':  { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '摄影系统':  { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '安全急救':  { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '清洁洗护':  { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '其他':      { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
};
```

- **地基层只建这张表 + 枚举，不写任何格子 UI**。映射是「弱映射」——统一清单界面用此映射自动把装备归入对应格子，用户仅在有歧义时手动微调（纲领 §4.3：录入只加品类，不强加分层负担）。
- 「穿着·上身」默认落 Mid 层只是预填值；冲锋衣/羽绒等具体分层靠用户微调或更细的品类细化解决，地基层不纠结。
- 这样第二步做统一清单界面时，装备已经知道自己该落哪个格子，纯交互工作，零数据返工。

---

## 4. 各页面交互逻辑

### 4.1 「我」Tab · 人生足迹（决策 2）

顶部沉浸式绿幕黄金区，纯数据叙事 + 拟人化一句话 + 留白：

```
┌──────────────────────────────┐
│   [沉浸绿幕，山野绿渐变]        │
│                              │
│   这一路，你走了 1,280 km     │  ← counter 滚动数字
│   翻过 8 座山，去过 12 个地方   │
│   最久的伙伴陪了你 1,095 天    │  ← 拟人化
│                              │
│   故事都在你心里。            │  ← 留白，不强行展开
└──────────────────────────────┘
```

- 数字来自 TripChecklist 结构化字段聚合（distanceKm 求和、destination 去重计数等）。
- counter 滚动动画 ~400ms ease-out，不闪变。
- 无数据时显示温柔的空态引导，不显示 0。

### 4.2 装备库 · 展开区双段结构（决策 3 + 决策 7「A 方案」）

装备在列表里就地展开（沿用现状，非独立详情页）。展开后**上下两段常驻**：

```
┌──────────────────────────────┐
│ 【属性区 · for Packing】       │  ← 在前，打包刚需
│  重量 580g   分组 背负系统     │
│  价格 ¥1,299  品牌 Osprey     │
│  入手 2023-06-04              │
├──────────────────────────────┤  ← 分割线
│ 【陪伴区 · for Archive】       │  ← 在后，情感留存
│      已经陪你 1,095 天         │  ← 大数字陪伴
│  [出行 12 次] [走过 1280km]   │  ← 三 chip
│  [去过 12 地]                 │
│                              │
│  → 点 chip 可下钻陪伴时间轴    │  ← 二步下钻（地基层可后置）
└──────────────────────────────┘
```

- 陪伴天数大数字 = `acquiredAt` 计算。
- 三 chip 数据来自该装备关联的行程聚合（通过 `fromGearId` 反查）。
- 时间轴下钻属第二步，地基层可先只展示陪伴卡片不做下钻。

### 4.3 行程 · 渐进式 chip 录入（决策 4）

新建/编辑行程默认极简，规避记账困境：

```
默认态：
┌──────────────────────────────┐
│  行程名称  [____________]      │
│  选装备    [+ 添加装备]        │
│                              │
│  · 目的地  · 里程  · 海拔      │  ← 灰色可点亮 chip
│  · 爬升    · 时长             │     点一个亮一个，才显示输入
└──────────────────────────────┘
```

- 5 个结构化字段（destination/distanceKm/maxAltitude/ascentM/durationHours）默认收成可点亮 chip，不填不占视觉。
- 点亮才展开对应输入，填完即「这次的足迹」，喂给人生足迹与装备陪伴卡片。

### 4.4 packing L0（决策 6/8）

地基层 packing = L0 纯查阅：用户打包时打开装备库逐个看属性自己核对，装备库即清单。`ChecklistItem.checked` 字段已就绪，L1 行程内勾选清单交互留到地基层之后的小迭代。

---

## 5. 文案词典（决策 5 · 温柔陪伴，全局替换）

| 军事感（旧/否决） | 温柔陪伴（新/采用） |
|------------------|---------------------|
| 服役 / 服役档案 | 陪伴 / 陪伴档案 |
| 任务 | 同行 / 这一程 |
| 老兵 | 相伴最久的伙伴 |
| 战绩 / 战功 | 这一路走来 |
| 装备出勤 | 装备陪你出门 |
| 退役 | 退休 / 收进回忆 |
| 服役天数 | 陪伴天数 / 已经陪你 N 天 |

> 原则：内核是「装备与人经历的情感连接」，措辞一律软化为温柔的陪伴叙事，去掉一切军事/任务/考核感。具体页面文案以此词典为基准展开。

---

## 6. 带格子的核查清单 · 第二灵魂（纲领 §4 v3 修订，第二步实现）

> ⚠️ **v3 修订（2026-06-22）**：本章重写。原「塔科夫式配装系统」描述已被推翻。配装不是独立系统，是清单的分组骨架。两阶段流水线和配装/清单双 Tab 已废弃。
>
> 本章不在第一步落地范围内，但必须在 spec 里完整承载。地基层只为它铺数据种子（见 §3.5），交互整体属**第二步·引擎**。

### 6.1 它解决什么（纲领 §4.1）

**Pack + Check = 收拾行李 + 逐项核查。** 户外出行装备量大品类杂，用户需要一个工具帮他提前列好要带的东西，收拾行李时对照打勾不漏带。预设好的身体部位格子（头部/上身/下身/鞋/背负/睡眠/杂项）提供认知辅助——空格子提醒用户「这个维度还没准备」，降低混乱感，防止遗漏。

### 6.2 核心范式（纲领 §4.2–4.5 v3 修订，第二步实现）

- **格子 = 清单的分组骨架**：预设身体部位分区始终可见（包括空格子），用户在格子里添加装备 = 在清单里添加物品，出发前逐项打勾 = 核查。一个界面，不分 Tab。
- **身体部位横轴分区**：头部 → 上身 → 下身 → 鞋 → 背负 → 睡眠 → 杂项（人体从上到下 + 非穿着系统）。
- **衣物格子内保留纵轴分层**（贴身→保暖→防风，从里到外排序）：保住专业感，内行一眼看出分层是否合理。
- **杂项格子内按品类子分组**（摄影系统/证件/电子设备等）：杂项内容多，需要二级组织。
- **容器即实例**：背包升格为容器，多包场景自然成立（远期能力，当前简化为「背负」格子）。
- **空态**：空格子收缩为紧凑标题 + 虚线框占位区（虚线边框 + 中心「+」图标），点击添加。有内容的格子展开为完整卡片。

### 6.3 与地基层的衔接

地基层已埋 §3.5 的 `CATEGORY_SLOT_MAP` + `BodyZone`/`LayerOrder` 枚举。第二步开发统一清单界面时：装备按 `category` 查表自动归入对应格子 → 用户微调歧义项 → 格子内按层级自动排序。装备↔行程关联复用已有的 `ChecklistItem.fromGearId`。**第二步是纯交互+视图工作，无新增数据迁移负担。**

---

## 7. 三步走执行路径

### 🟢 第一步 · 地基层（本次落地范围）

数据层：
- GearItem 加 `brand?`、`acquiredAt?`（optional）
- TripChecklist 加 5 个结构化字段（optional）
- **新增 `constants/GearLoadout.ets`：`BodyZone`/`LayerOrder` 枚举 + `CATEGORY_SLOT_MAP` 映射表（配装数据种子，纯常量无 UI，见 §3.5）**
- 删除趋势图整条链路（AssetEvent/AssetTotals/KEY_ASSET_EVENTS/相关方法/AssetTrendCard.ets/调用点）

页面层：
- 新增「我」Tab + ProfilePage 人生足迹年报叙事
- 装备展开区改为属性区 + 陪伴区双段结构（A 方案）
- 行程录入改为渐进式 chip
- 全局文案按词典软化为温柔陪伴
- packing = L0；`ChecklistItem.checked`/`fromGearId` 作为 L1 预留（不做交互）

### 🔵 第二步 · 引擎

- **带格子的核查清单（第二灵魂的核心，纲领 §4 v3 修订 / 本 spec §6）**：合并配装/清单为统一视图，砍掉 Tab 切换。身体部位格子始终可见（含空态虚线框）、衣物格子内纵轴分层、装备自动归入格子。地基层已铺 `CATEGORY_SLOT_MAP` 种子，此步开箱即知分区。
- 行程 → 装备自动反哺闭环（填完行程足迹自动喂给装备陪伴卡片）
- 装备陪伴履历时间轴下钻

### 🟣 第三步 · 智能

- L2 智能 PackCheck（按行程类型/目的地/历史主动提示带什么、还没打勾什么）

---

## 8. 地基层验证标准（done 的定义）

1. **构建通过**：`hvigorw assembleApp` 成功。
2. **向后兼容**：旧数据（无 brand/acquiredAt/结构化字段）打开不崩，UI 优雅降级。
3. **双核可见**：装备展开区同时清晰呈现硬属性（packing）+ 陪伴记录（archive），属性在前。
4. **情感验证（核心）**：用户录完真实装备、填几条行程足迹后打开「我」Tab，会不会被触动、想截图。这是地基层成败的终极判据。
5. **文案一致**：全局无残留军事措辞，统一温柔陪伴语气。

---

## 9. 风险与边界

- 趋势图删除涉及多处调用点，需 grep 全量确认无残留引用再删，避免编译断裂。
- 「我」Tab 是全新页面，Index.ets 中心状态管理器需新增对应 @State 与分发，注意不破坏现有 50+ 状态。
- 人生足迹聚合计算在无数据/少数据时的空态，必须温柔，绝不显示一排 0。
- 新增字段全 optional 是铁律，任何 required 都会炸旧数据。
- `CATEGORY_SLOT_MAP` 地基层只建表不用，需确保不被第一步任何代码误引用产生死代码告警；作为第二步的纯数据预埋存在。
