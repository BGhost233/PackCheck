import {
  SPRING_TAB, SPRING_COUNTER,
  DURATION_CHART_DRAW, DURATION_NORMAL
} from '../constants/AnimationTokens';
import { vibrator } from '@kit.SensorServiceKit';
import { AssetEvent } from '../models/PackModels';
import {
  CARD_BG,
  FONT_FEATURE_TNUM,
  OVERLAY_DIM,
  PAGE_BG,
  PAGE_PADDING,
  PRIMARY_COLOR,
  PRIMARY_SHADOW,
  PRIMARY_TRANSPARENT,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../constants/DesignTokens';

interface CurvePoint {
  x: number;
  y: number;
  event: AssetEvent;
}

const MILESTONES: number[] = [1000, 5000, 10000, 30000, 50000, 100000];
const CANVAS_HEIGHT = 88;
const CANVAS_PADDING_X = 4;
const CANVAS_PADDING_TOP = 12;
const CANVAS_PADDING_BOTTOM = 4;

@Component
export struct AssetTrendCard {
  @Prop assetEvents: AssetEvent[] = [];
  @Prop currentTotal: number = 0;
  @Prop gearCount: number = 0;
  @Prop totalWeight: number = 0;

  @State @Watch('onDrawProgressChange') private drawProgress: number = 0;
  @State private isTouching: boolean = false;
  @State private touchX: number = 0;
  @State private touchValue: number = 0;
  @State private touchDate: string = '';
  @State private touchEventInfo: AssetEvent | undefined = undefined;
  @State private touchPointY: number = 0;

  private canvasContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasWidth: number = 0;
  private canvasHeight: number = CANVAS_HEIGHT;
  private cachedPoints: CurvePoint[] = [];
  private hasEnteredView: boolean = false;
  private lastVibrateIdx: number = -1; // 震动去重：上一次震动的节点 index

  aboutToAppear(): void {
    this.rebuildCachedPoints();
  }

  private onDrawProgressChange(): void {
    this.drawCurve();
  }

  // ======= 数据处理 =======

  private getValidEvents(): AssetEvent[] {
    const result: AssetEvent[] = [];
    for (let i = 0; i < this.assetEvents.length; i++) {
      result.push(this.assetEvents[i]);
    }
    result.sort((a: AssetEvent, b: AssetEvent) => a.timestamp - b.timestamp);
    return result;
  }

  private hasEnoughData(): boolean {
    const events = this.getValidEvents();
    if (events.length < 3) {
      return false;
    }
    // 按天聚合后至少需要 2 个不同天的数据点才能画线
    const dailyEvents = this.aggregateByDay(events);
    return dailyEvents.length >= 2;
  }

  // 按天聚合事件：同一天内多次操作合并为一个数据点（取当天最终累计值）
  private aggregateByDay(events: AssetEvent[]): AssetEvent[] {
    if (events.length === 0) {
      return [];
    }
    const result: AssetEvent[] = [];
    let lastDayKey = '';
    for (let i = 0; i < events.length; i++) {
      const evt = events[i];
      const d = new Date(evt.timestamp);
      const dayKey = d.getFullYear().toString() + '-' +
        (d.getMonth() + 1).toString().padStart(2, '0') + '-' +
        d.getDate().toString().padStart(2, '0');
      if (dayKey === lastDayKey && result.length > 0) {
        // 同一天：用最新的事件覆盖（totalValue 是累计值，取最后一条即为当天最终状态）
        result[result.length - 1] = evt;
      } else {
        result.push(evt);
        lastDayKey = dayKey;
      }
    }
    return result;
  }

  private rebuildCachedPoints(): void {
    const events = this.getValidEvents();
    if (events.length === 0 || this.canvasWidth === 0) {
      this.cachedPoints = [];
      return;
    }
    // 按天聚合：同一天的多次操作合并为一个点
    const dailyEvents = this.aggregateByDay(events);
    const drawW = this.canvasWidth - CANVAS_PADDING_X * 2;
    const drawH = this.canvasHeight - CANVAS_PADDING_TOP - CANVAS_PADDING_BOTTOM;

    let maxVal = 0;
    for (let i = 0; i < dailyEvents.length; i++) {
      if (dailyEvents[i].totalValue > maxVal) {
        maxVal = dailyEvents[i].totalValue;
      }
    }
    if (maxVal === 0) {
      maxVal = 1;
    }

    const minT = dailyEvents[0].timestamp;
    const maxT = dailyEvents.length > 1 ? dailyEvents[dailyEvents.length - 1].timestamp : minT + 1;
    const timeSpan = maxT - minT;

    const points: CurvePoint[] = [];
    for (let i = 0; i < dailyEvents.length; i++) {
      const evt = dailyEvents[i];
      const xRatio = timeSpan > 0 ? (evt.timestamp - minT) / timeSpan : 0.5;
      const yRatio = evt.totalValue / maxVal;
      points.push({
        x: CANVAS_PADDING_X + xRatio * drawW,
        y: CANVAS_PADDING_TOP + (1 - yRatio) * drawH,
        event: evt
      });
    }
    this.cachedPoints = points;
  }

  // ======= Canvas 绘制 =======

  private drawCurve(): void {
    const ctx = this.canvasContext;
    const w = this.canvasWidth;
    const h = this.canvasHeight;
    if (w === 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);

    if (this.cachedPoints.length < 2) {
      // 只有 1 个点时画一个小圆点
      if (this.cachedPoints.length === 1) {
        const p = this.cachedPoints[0];
        ctx.beginPath();
        ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = PRIMARY_COLOR;
        ctx.fill();
      }
      return;
    }

    const endIndex = Math.floor((this.cachedPoints.length - 1) * this.drawProgress);
    if (endIndex < 1) {
      return;
    }

    const points = this.cachedPoints;

    // 渐变填充（折线段）
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i <= endIndex; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    const lastPoint = points[endIndex];
    ctx.lineTo(lastPoint.x, h);
    ctx.lineTo(points[0].x, h);
    ctx.closePath();

    const gradient = ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, PRIMARY_SHADOW);
    gradient.addColorStop(1, PRIMARY_TRANSPARENT);
    ctx.fillStyle = gradient;
    ctx.fill();

    // 折线
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i <= endIndex; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    ctx.strokeStyle = PRIMARY_COLOR;
    ctx.lineWidth = 2;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.stroke();

    // 里程碑点
    this.drawMilestones(ctx, endIndex);
  }

  private drawMilestones(ctx: CanvasRenderingContext2D, endIndex: number): void {
    const points = this.cachedPoints;
    for (let i = 0; i <= endIndex && i < points.length; i++) {
      const evt = points[i].event;
      for (let m = 0; m < MILESTONES.length; m++) {
        const milestone = MILESTONES[m];
        if (evt.totalValue >= milestone) {
          const prevValue = i > 0 ? points[i - 1].event.totalValue : 0;
          if (prevValue < milestone) {
            ctx.beginPath();
            ctx.arc(points[i].x, points[i].y, 3, 0, Math.PI * 2);
            ctx.fillStyle = PRIMARY_COLOR;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(points[i].x, points[i].y, 5, 0, Math.PI * 2);
            ctx.strokeStyle = PRIMARY_COLOR;
            ctx.lineWidth = 1.5;
            ctx.stroke();
          }
        }
      }
    }
  }

  // ======= 触摸交互 =======

  private interpolateAtX(touchX: number): void {
    if (this.cachedPoints.length === 0) {
      return;
    }
    const points = this.cachedPoints;

    let nearestIdx = 0;
    let nearestDist = Math.abs(points[0].x - touchX);
    for (let i = 1; i < points.length; i++) {
      const dist = Math.abs(points[i].x - touchX);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }

    const nearest = points[nearestIdx];
    this.touchValue = nearest.event.totalValue;
    this.touchPointY = nearest.y;
    this.touchDate = this.formatDate(nearest.event.timestamp);
    this.touchEventInfo = nearest.event;

    // 震动去重：只在切换到新节点时震动一次
    if (nearestIdx !== this.lastVibrateIdx) {
      this.lastVibrateIdx = nearestIdx;
      try {
        vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' });
      } catch (e) {
        // ignore
      }
    }
  }

  private formatDate(timestamp: number): string {
    const d = new Date(timestamp);
    return d.getFullYear().toString() + '年' +
      (d.getMonth() + 1).toString() + '月' +
      d.getDate().toString() + '日';
  }

  private formatPrice(value: number): string {
    if (value >= 10000) {
      const wan = Math.floor(value / 1000) / 10;
      return '¥' + wan.toString() + '万';
    }
    return '¥' + value.toString();
  }

  private formatKg(gram: number): string {
    if (gram >= 1000) {
      return (gram / 1000).toFixed(1) + 'kg';
    }
    return gram.toString() + 'g';
  }

  // ======= 统计：本月新增 =======

  private monthlyAddedCount(): number {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    const startTs = monthStart.getTime();
    let count = 0;
    for (let i = 0; i < this.assetEvents.length; i++) {
      if (this.assetEvents[i].timestamp >= startTs && this.assetEvents[i].event === 'add') {
        count++;
      }
    }
    return count;
  }

  private monthlyAddedValue(): number {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    const startTs = monthStart.getTime();
    let value = 0;
    for (let i = 0; i < this.assetEvents.length; i++) {
      const evt = this.assetEvents[i];
      if (evt.timestamp >= startTs && evt.event === 'add') {
        const p = evt.gearPrice !== undefined ? evt.gearPrice : 0;
        value += p;
      }
    }
    return value;
  }

  // ======= 时间标签 =======

  private getTimeLabels(): string[] {
    const events = this.getValidEvents();
    if (events.length === 0) {
      return [];
    }
    const first = events[0];
    const last = events[events.length - 1];
    const formatShort = (ts: number): string => {
      const d = new Date(ts);
      return d.getFullYear().toString() + '.' + (d.getMonth() + 1).toString().padStart(2, '0');
    };
    if (events.length <= 2) {
      return [formatShort(first.timestamp), formatShort(last.timestamp)];
    }
    const mid = events[Math.floor(events.length / 2)];
    return [formatShort(first.timestamp), formatShort(mid.timestamp), formatShort(last.timestamp)];
  }

  // ======= 事件浮层文字 =======

  private getEventLabel(evt: AssetEvent): string {
    const name = evt.gearName !== undefined ? evt.gearName : '未知';
    const price = evt.gearPrice !== undefined ? '¥' + evt.gearPrice.toString() : '';
    if (evt.event === 'add') {
      return '+1  ' + name + '  ' + price;
    } else if (evt.event === 'remove') {
      return '-1  ' + name + '  -' + price;
    } else {
      return '✏️  ' + name + '  ' + price;
    }
  }

  // ======= 入场动画触发 =======

  private triggerEntrance(): void {
    if (this.hasEnteredView) {
      return;
    }
    this.hasEnteredView = true;
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: DURATION_CHART_DRAW,
        curve: SPRING_TAB()
      }, () => {
        this.drawProgress = 1;
      });
    }, 300);
  }

  // ======= Build =======

  build() {
    Column({ space: 8 }) {
      // 标题行
      this.TitleRow()

      if (this.hasEnoughData()) {
        // 曲线区域
        Stack() {
          Canvas(this.canvasContext)
            .width('100%')
            .height(CANVAS_HEIGHT)
            .onReady(() => {
              this.drawCurve();
            })
            .onAreaChange((_oldArea: Area, newArea: Area) => {
              const newW = newArea.width as number;
              if (newW > 0 && newW !== this.canvasWidth) {
                this.canvasWidth = newW;
                this.rebuildCachedPoints();
                this.drawCurve();
                this.triggerEntrance();
              }
            })

          // 触摸交互层
          if (this.isTouching) {
            // 竖直参考线
            Line()
              .width(1)
              .height(CANVAS_HEIGHT)
              .position({ x: this.touchX, y: 0 })
              .backgroundColor(OVERLAY_DIM)

            // 高亮圆点
            Circle({ width: 8, height: 8 })
              .fill(PRIMARY_COLOR)
              .position({ x: this.touchX - 4, y: this.touchPointY - 4 })
          }
        }
        .width('100%')
        .height(CANVAS_HEIGHT)
        .onTouch((event: TouchEvent) => {
          this.handleTouch(event);
        })
        .priorityGesture(
          PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 5 })
            .onActionStart(() => {
              // 拦截水平滑动，阻止冒泡到 HdsTabs 触发 Tab 切换
            })
            .onActionUpdate(() => {})
            .onActionEnd(() => {})
        )

        // 时间标签行
        this.TimeLabels()

        // 事件浮层
        if (this.isTouching && this.touchEventInfo !== undefined) {
          this.EventTooltip()
        }
      } else {
        // 空状态
        this.EmptyState()
      }

      // 统计卡片行
      this.StatRow()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(CARD_BG)
    .borderRadius(16)
  }

  private handleTouch(event: TouchEvent): void {
    const touches = event.touches;
    if (touches.length === 0) {
      return;
    }
    const x = touches[0].x;

    if (event.type === TouchType.Down) {
      this.isTouching = true;
      this.lastVibrateIdx = -1; // 重置震动去重
      this.touchX = x;
      this.interpolateAtX(x);
    } else if (event.type === TouchType.Move) {
      this.touchX = x;
      this.interpolateAtX(x);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({
        duration: DURATION_NORMAL,
        curve: SPRING_COUNTER()
      }, () => {
        this.isTouching = false;
        this.touchEventInfo = undefined;
      });
    }
  }

  @Builder
  private TitleRow() {
    Row() {
      Column({ space: 2 }) {
        Text(this.isTouching ? this.formatPrice(this.touchValue) : this.formatPrice(this.currentTotal))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .fontFeature(FONT_FEATURE_TNUM)
        Text('装备资产')
          .fontSize(11)
          .fontColor(TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      if (this.isTouching) {
        Text(this.touchDate)
          .fontSize(11)
          .fontColor(TEXT_SECONDARY)
      }
    }
    .width('100%')
  }

  @Builder
  private TimeLabels() {
    Row() {
      ForEach(this.getTimeLabels(), (label: string) => {
        Text(label)
          .fontSize(10)
          .fontColor(TEXT_TERTIARY)
      }, (label: string) => label)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: CANVAS_PADDING_X, right: CANVAS_PADDING_X })
  }

  @Builder
  private EventTooltip() {
    if (this.touchEventInfo !== undefined) {
      Row() {
        Text(this.getEventLabel(this.touchEventInfo))
          .fontSize(13)
          .fontColor(TEXT_MAIN)
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(PAGE_BG)
      .borderRadius(8)
    }
  }

  @Builder
  private EmptyState() {
    Column({ space: 6 }) {
      Text('📈')
        .fontSize(24)
      Text('继续添加装备，解锁你的资产曲线')
        .fontSize(13)
        .fontColor(TEXT_SECONDARY)
      Text('至少 3 件有价格的装备即可查看趋势')
        .fontSize(11)
        .fontColor(TEXT_TERTIARY)
    }
    .width('100%')
    .height(72)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private StatRow() {
    Row({ space: 6 }) {
      this.StatPill('件数', this.gearCount.toString())
      this.MonthlyPill()
      this.StatPill('重量', this.formatKg(this.totalWeight))
    }
    .width('100%')
  }

  @Builder
  private StatPill(label: string, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
        .fontFeature(FONT_FEATURE_TNUM)
      Text(label)
        .fontSize(10)
        .fontColor(TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(PAGE_BG)
    .borderRadius(8)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private MonthlyPill() {
    Column({ space: 2 }) {
      if (this.monthlyAddedCount() > 0) {
        Text('+' + this.monthlyAddedCount().toString() + '件 / ¥' + this.monthlyAddedValue().toString())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .fontFeature(FONT_FEATURE_TNUM)
      } else {
        Text('暂无新增')
          .fontSize(11)
          .fontColor(TEXT_TERTIARY)
      }
      Text('本月新增')
        .fontSize(10)
        .fontColor(TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(PAGE_BG)
    .borderRadius(8)
    .alignItems(HorizontalAlign.Center)
  }
}
