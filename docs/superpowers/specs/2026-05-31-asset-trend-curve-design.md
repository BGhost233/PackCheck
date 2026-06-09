# 装备资产趋势曲线设计规格

> ⚠️ **已废弃（2026-06-09）** —— 本设计已被 v2「服役档案」产品转型推翻。
> 资产趋势图把装备库导向「投资组合/家底成长」的物质叙事，与新方向「装备的服役档案 · 温柔陪伴叙事」相悖（纲领文档 §0.1：里子＞面子、情感连接＞资产炫耀）。
> AssetTrendCard 组件及其整条数据链路将在地基层第一步删除。
> 现行方向见：纲领 `docs/design/2026-06-04-product-vision-and-restructure.md`、spec `docs/superpowers/specs/2026-06-09-service-archive-restructure-design.md`、计划 `docs/superpowers/plans/2026-06-09-service-archive-foundation.md`。
> 以下内容仅作历史存档，不再作为开发依据。

---

> 替换装备库页面顶部的 WeightGauge 圆盘组件，改为类似 Apple Stocks 迷你曲线风格的资产价值趋势图，为用户提供装备资产的成长叙事和情绪价值。

---

## 1. 设计目标

用户打开装备库时的核心心理模型是"看看我的装备家底"。圆盘提供的是一个静态快照（当前总价），缺乏时间维度和成长感。趋势曲线将"我有多少钱的装备"升级为"我的装备帝国是怎么一步步建起来的"——一个有叙事感的成长故事。

核心体验目标：让每一次打开装备库都像检查自己投资组合一样有成就感。

---

## 2. 数据层

### 2.1 数据模型

```typescript
// /entry/src/main/ets/models/PackModels.ets 新增

export interface AssetEvent {
  timestamp: number;          // 毫秒时间戳（事件发生时间）
  totalValue: number;         // 事件后的累计总价（元）
  totalCount: number;         // 事件后的装备总件数
  event: 'add' | 'remove' | 'edit';  // 事件类型
  gearName?: string;          // 触发事件的装备名称
  gearPrice?: number;         // 该装备的价格（元）
}
```

### 2.2 事件触发时机

| 用户操作 | 事件类型 | 记录内容 |
|----------|----------|----------|
| 新增装备（有 price） | `add` | gearName + gearPrice + 新总价 + 新件数 |
| 删除装备（有 price） | `remove` | gearName + gearPrice + 新总价 + 新件数 |
| 修改装备价格 | `edit` | gearName + 新 price + 新总价 + 件数不变 |
| 新增装备（无 price） | 不记录 | 无价格信息，不影响资产曲线 |

### 2.3 存储

在 PackStore 中新增：

```typescript
private readonly KEY_ASSET_EVENTS = 'packcheck_asset_events';

async getAssetEvents(): Promise<AssetEvent[]>
async saveAssetEvents(events: AssetEvent[]): Promise<void>
async appendAssetEvent(event: AssetEvent): Promise<void>  // 追加单条 + 保存
```

### 2.4 历史数据回填

首次升级时（检测到 `assetEvents` 为空且 `gears` 非空），基于现有数据自动生成历史事件序列：

```
1. gears.filter(g => g.price && g.price > 0)
2. .sort((a, b) => a.createdAt - b.createdAt)
3. 遍历，逐步累加 totalValue / totalCount
4. 为每件装备生成一条 { timestamp: gear.createdAt, ... } 的 add 事件
5. 保存到 assetEvents
```

### 2.5 数据清洗规则

显示时（非存储时）：同一天内有多条事件的，曲线上只显示最后一条的 totalValue 作为当天终值。滑动时可以逐条展示每个事件的详情。

---

## 3. 视觉设计

### 3.1 整体布局

```
┌─────────────────────────────────────────────────┐
│  ¥12,480                                        │  ← 当前总价，左对齐
│  装备资产                                        │  ← 辅助标签，TEXT_TERTIARY
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │      ●                                    │   │  ← 里程碑圆点
│  │     ╱╲          ╱──                       │   │
│  │   ╱    ╲      ╱╱                          │   │  ← 曲线 + 渐变填充
│  │  ╱      ╲  ╱╱                             │   │
│  │╱          ╲╱                              │   │
│  └──────────────────────────────────────────┘   │
│  2024.03            2024.09            2025.01   │  ← 时间标签（最多 3 个）
│                                                  │
│  ┌─────────┐  ┌───────────────┐  ┌──────────┐  │
│  │  件数    │  │   本月新增     │  │   重量    │  │  ← 统计卡片行
│  │   28    │  │ +3件 / ¥820   │  │  4.2kg   │  │
│  └─────────┘  └───────────────┘  └──────────┘  │
└─────────────────────────────────────────────────┘
```

### 3.2 设计参数

| 属性 | 值 |
|------|-----|
| 卡片背景 | `CARD_BG`（纯白）|
| 卡片圆角 | 16vp |
| 曲线区域高度 | 120vp |
| 曲线线宽 | 2vp |
| 曲线颜色 | `PRIMARY_COLOR`（#2D7D46 山野绿）|
| 渐变填充 | 从 `#1A2D7D46`（10% 透明度）到 `#002D7D46`（完全透明），垂直方向 |
| 里程碑圆点 | 直径 6vp，实心 `PRIMARY_COLOR` |
| 当前总价字号 | 24fp，FontWeight.Bold，`TEXT_MAIN` |
| 辅助标签 | 12fp，`TEXT_TERTIARY` |
| 时间标签 | 10fp，`TEXT_TERTIARY`，最多显示 3 个（首/中/末） |
| 统计卡片行 | 复用现有 StatPill 样式 |

### 3.3 里程碑阈值

在曲线上标记小圆点的资产总值阈值：

```typescript
const MILESTONES = [1000, 5000, 10000, 30000, 50000, 100000];
```

只标记已经达到过的里程碑。圆点位于曲线上对应 y 值的位置。

### 3.4 滑动交互态

手指按住曲线区域并水平滑动时：

```
┌─────────────────────────────────────────────────┐
│  ¥3,200                           2024年6月15日  │  ← 数值变为历史值 + 日期
│  装备资产                                        │
│                                                  │
│  ┌───────────────────────|──────────────────┐   │
│  │                       │                   │   │  ← 竖直参考线（1vp，#33000000）
│  │      ●                │                   │   │
│  │     ╱╲               ●│                   │   │  ← 触摸点高亮圆（8vp，PRIMARY）
│  │   ╱    ╲           ╱  │                   │   │
│  │  ╱      ╲  ╱╱╱        │                   │   │
│  │╱          ╲╱          │                   │   │
│  └───────────────────────|──────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  +1  始祖鸟 Beta LT               ¥3,200 │   │  ← 事件浮层
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

**交互细节：**

- 触发方式：在曲线 Canvas 区域内直接水平滑动（通过 `onTouch` 的 TouchType.Down + Move 判断）。由于曲线区域独立于列表 Scroll，手势不会冲突——列表滚动方向为垂直，曲线交互方向为水平
- 参考线：1vp 竖直虚线，颜色 `#33000000`
- 高亮圆点：8vp 直径，`PRIMARY_COLOR`，跟随曲线 y 坐标
- 顶部数字：实时变化为该节点对应的 `totalValue`，带 counter 过渡（100ms）
- 右上日期：显示 "YYYY年M月D日" 格式
- 事件浮层：在曲线下方展示，仅在触摸点对应有 AssetEvent 时显示
  - 格式：`+1 装备名称  ¥价格`（add 事件）/ `-1 装备名称  -¥价格`（remove 事件）/ `✏️ 装备名称  ¥新价格`（edit 事件）
  - 样式：白色背景 + 阴影 + 圆角 10vp + fontSize 13 + padding 10vp
- 松手后：数字回归当前总价，参考线和浮层消失（opacity 0 + translateY 4 的 spring 退出）
- 触觉反馈：滑过里程碑点或有事件的节点时，轻振动（`vibrator.startVibration({ type: 'time', duration: 10 })`）

### 3.5 空状态

当有效数据点 < 3 个（有 price 的装备 < 3 件）时，不显示曲线，改为引导：

```
┌─────────────────────────────────────────────────┐
│                                                  │
│       ╭───╮                                     │
│       │ 📈│                                     │
│       ╰───╯                                     │
│                                                  │
│    继续添加装备，解锁你的资产曲线                 │
│    至少 3 件有价格的装备即可查看趋势              │
│                                                  │
│  ┌─────────┐  ┌───────────────┐  ┌──────────┐  │
│  │  件数    │  │   本月新增     │  │   重量    │  │
│  │   2     │  │   暂无新增     │  │  0.3kg   │  │
│  └─────────┘  └───────────────┘  └──────────┘  │
└─────────────────────────────────────────────────┘
```

- 背景：浅灰虚线伪曲线作为装饰（静态 Canvas 绘制，一条固定的 sin 曲线虚线）
- 图标：SymbolGlyph chart_line 或自定义小图标
- 文字：fontSize 14 + TEXT_SECONDARY，居中
- 副文字：fontSize 12 + TEXT_TERTIARY

---

## 4. 动效设计

### 4.1 入场动画

曲线从左到右"绘制"出现：

```typescript
@State drawProgress: number = 0;  // 0~1

aboutToAppear() {
  setTimeout(() => {
    this.getUIContext().animateTo({
      duration: 1200,
      curve: curves.springMotion(0.4, 0.8)
    }, () => {
      this.drawProgress = 1;
    });
  }, 300);  // 延迟 300ms，让页面先稳定
}
```

Canvas `onReady` 中根据 `drawProgress` 只绘制前 N% 的路径点（通过控制 `lineTo` 的终点索引）。

### 4.2 里程碑点弹出

曲线绘制到里程碑点时，该点 scale 从 0 弹到 1.2 再回 1.0：

```typescript
// 里程碑点用独立的 Circle 组件覆盖在 Canvas 上，position 定位
.scale({ x: milestoneReached ? 1 : 0, y: milestoneReached ? 1 : 0 })
.animation({ duration: 300, curve: curves.springMotion(0.25, 0.7) })
```

### 4.3 滑动交互动效

| 元素 | 效果 |
|------|------|
| 高亮圆点 | 即时跟随手指 x，y 由曲线值决定 |
| 参考线 | 即时跟随手指 x |
| 顶部数字 | counter 过渡，100ms |
| 事件浮层出现 | opacity 0→1 + translateY(6→0)，springMotion(0.3, 0.75) |
| 事件浮层消失 | opacity 1→0 + translateY(0→4)，150ms EaseOut |
| 松手恢复 | 所有交互元素 opacity→0，数字回归当前值，200ms spring |

### 4.4 滚动折叠

复用现有 WeightGauge 的折叠逻辑：

```typescript
.opacity(this.gearTrendOpacity())      // scrollProgress 到 40% 时降为 0
.scale({ x: this.gearTrendScale(), y: this.gearTrendScale() })  // 到 100% 时缩到 0.6
```

函数逻辑保持不变，只是 rename。

---

## 5. 统计卡片行调整

### 5.1 中间卡片：总价 → 本月新增

**计算逻辑**：

```typescript
private monthlyAddedInfo(): { count: number, value: number } {
  const now = Date.now();
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const startTs = monthStart.getTime();

  const monthEvents = this.assetEvents
    .filter(e => e.timestamp >= startTs && e.event === 'add');

  return {
    count: monthEvents.length,
    value: monthEvents.reduce((sum, e) => sum + (e.gearPrice || 0), 0)
  };
}
```

**显示规则**：
- 有新增时：`+3件 / ¥820`
- 无新增时：`暂无新增`（fontSize 12，TEXT_TERTIARY）
- 如果本月无新增但近 3 个月有，降级显示"近3月新增"

### 5.2 其他两个卡片

保持不变：件数 / 重量。

---

## 6. 组件架构

### 6.1 新组件

```
/entry/src/main/ets/components/AssetTrendCard.ets
```

```typescript
@Component
export struct AssetTrendCard {
  // --- Props（从 GearPage 传入）---
  @Prop assetEvents: AssetEvent[] = [];
  @Prop currentTotal: number = 0;
  @Prop gearCount: number = 0;
  @Prop totalWeight: number = 0;

  // --- State ---
  @State drawProgress: number = 0;        // 入场绘制进度
  @State isTouching: boolean = false;     // 是否在滑动查看
  @State touchX: number = 0;             // 触摸 x 坐标
  @State touchValue: number = 0;         // 触摸位置对应的总价
  @State touchDate: string = '';         // 触摸位置对应的日期
  @State touchEvent: AssetEvent | null = null;  // 触摸位置对应的事件

  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;

  // --- 核心方法 ---
  private drawCurve(): void { ... }                   // Canvas 绘制曲线 + 渐变
  private getDataPoints(): Point[] { ... }            // 将 assetEvents 映射为 canvas 坐标点
  private getMilestonePoints(): Point[] { ... }       // 里程碑点坐标
  private interpolateValue(x: number): { value: number, date: number, event?: AssetEvent } { ... }  // 根据 x 插值
  private monthlyAddedInfo(): { count: number, value: number } { ... }

  build() {
    Column({ space: 12 }) {
      // 标题行：当前总价 / 触摸时历史值 + 日期
      this.TitleRow()

      // Canvas 曲线区域
      Stack() {
        Canvas(this.canvasContext) { ... }
        // 里程碑点（独立组件，覆盖在 canvas 上）
        ForEach(milestones, ...)
        // 滑动交互层：参考线 + 高亮点
        if (this.isTouching) { ... }
      }

      // 时间标签行
      this.TimeLabels()

      // 事件浮层（滑动到有事件的节点时显示）
      if (this.isTouching && this.touchEvent) {
        this.EventTooltip()
      }

      // 统计卡片行
      this.StatRow()
    }
  }
}
```

### 6.2 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `models/PackModels.ets` | 修改 | 新增 `AssetEvent` interface |
| `services/PackStore.ets` | 修改 | 新增 assetEvents 的读写方法 |
| `components/AssetTrendCard.ets` | 新建 | 趋势曲线组件 |
| `components/GearPage.ets` | 修改 | 替换 WeightGauge 为 AssetTrendCard，事件触发点植入 |
| `components/WeightGauge.ets` | 保留 | 暂不删除，待新组件稳定后移除 |

### 6.3 GearPage 集成点

```typescript
// 替换 WeightGauge({...})
AssetTrendCard({
  assetEvents: this.assetEvents,
  currentTotal: this.totalGearPrice(),
  gearCount: this.gears.length,
  totalWeight: this.totalGearWeight()
})
  .opacity(this.gearTrendOpacity())
  .scale({ x: this.gearTrendScale(), y: this.gearTrendScale() })
```

**事件植入位置**（在 GearPage 中）：

- 新增装备成功后 → `this.appendAssetEvent({ event: 'add', ... })`
- 删除装备确认后 → `this.appendAssetEvent({ event: 'remove', ... })`
- 修改装备价格保存后 → `this.appendAssetEvent({ event: 'edit', ... })`

---

## 7. Header 高度调整

| 组件 | 高度 |
|------|------|
| 标题行（当前总价 + 辅助标签）| 50vp |
| Canvas 曲线区 + 时间标签 | 140vp（120 + 20）|
| 统计卡片行 | 50vp |
| 间距（space 12 × 2 + padding） | 40vp |
| **合计** | **~280vp** |

现有 `GEAR_HEADER_EXPANDED = 340vp`，新组件 280vp 比现有更矮，不需要增加 header 高度。富余的 60vp 作为顶部和底部呼吸空间（padding）。

---

## 8. 边界情况处理

| 场景 | 处理 |
|------|------|
| 有价格的装备 < 3 件 | 显示空状态引导 |
| 所有装备在同一天添加 | 只有一个数据点，曲线退化为水平线 + 该点的值 |
| 总价值为 0（所有装备无价格） | 显示空状态引导 |
| 数据点 > 200 | 按月聚合（取月末值），避免曲线过密 |
| 删除装备导致总价下降 | 曲线正常下降，不做特殊颜色处理 |
| App 长时间未打开后重新打开 | 无特殊处理，曲线按事件时间绘制，自动有"平台期" |

---

## 9. 性能考量

- Canvas 绑定 `onAreaChange` 获取尺寸，仅在尺寸变化或数据变更时重绘
- 滑动交互时不重绘整条曲线，只更新参考线 + 高亮点（通过 Stack 叠加独立组件实现，不重绘 Canvas）
- `assetEvents` 数组预计长期 < 500 条（普通用户装备百件级别），内存和 JSON 序列化无压力
- 曲线的 bezier 控制点预计算，缓存在 `aboutToAppear` 中

---

## 10. 未来扩展（不在 V1 范围）

- 时间段切换（1月 / 3月 / 全部）
- 重量趋势曲线（切换 tab）
- 月度/年度总结卡片
- 装备折旧曲线（如果后续支持二手转售价）
