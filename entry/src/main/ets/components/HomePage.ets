import { curves } from '@kit.ArkUI';
import { ChecklistItem, GearItem, TripChecklist } from '../models/PackModels';
import {
  CARD_BG,
  CARD_RADIUS,
  COUNTDOWN_ORANGE,
  DANGER_COLOR,
  DIVIDER_COLOR,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PAGE_PADDING,
  PRIMARY_COLOR,
  PRIMARY_TINT_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../constants/DesignTokens';
import { heroGradientStart } from '../utils/ColorUtils';

@Component
export struct HomePage {
  @Prop checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];

  onOpenTrip: () => void = (): void => {};
  onOpenGear: () => void = (): void => {};
  onOpenChecklist: (id: string) => void = (id: string): void => {};
  onConfirmDeleteChecklist: (item: TripChecklist) => void = (item: TripChecklist): void => {};

  @State private heroDaysDisplay: number = 0;
  @State private heroNumberAnimated: boolean = false;
  @State private progressNumeratorDisplay: number = 0;
  @State private progressAnimated: boolean = false;
  @State private scrollOffset: number = 0;
  private collapseMax: number = 200;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.heroDaysDisplay = 0;
    this.heroNumberAnimated = false;
    this.progressNumeratorDisplay = 0;
    this.progressAnimated = false;
    this.scrollOffset = 0;
  }

  private scrollProgress(): number {
    return Math.max(0, Math.min(1, this.scrollOffset / this.collapseMax));
  }

  private titleFontSize(): number {
    return 28 - this.scrollProgress() * 12;
  }

  private titlePaddingBottom(): number {
    return 18 - this.scrollProgress() * 10;
  }

  private heroOpacity(): number {
    return 1 - this.scrollProgress();
  }

  private getAnimatedHeroLead(checklist: TripChecklist): string {
    if (this.heroNumberAnimated) {
      return this.countdownLead(checklist);
    }
    const days = this.daysLeft(checklist);
    if (days === undefined) {
      return this.countdownLead(checklist);
    }
    if (days === 0) {
      return this.countdownLead(checklist);
    }
    return Math.round(this.heroDaysDisplay).toString();
  }

  private getAnimatedProgressText(checklist: TripChecklist): string {
    if (this.progressAnimated) {
      return this.progressText(checklist);
    }
    return Math.round(this.progressNumeratorDisplay).toString() + '/' + checklist.items.length.toString();
  }

  private startHeroNumberAnimation(): void {
    const checklist = this.latestChecklist();
    if (checklist === undefined) {
      this.heroNumberAnimated = true;
      return;
    }
    const days = this.daysLeft(checklist);
    if (days === undefined || days === 0) {
      this.heroNumberAnimated = true;
      return;
    }
    const target = Math.abs(days);
    this.getUIContext().animateTo({
      duration: 800,
      curve: Curve.EaseOut,
      onFinish: (): void => {
        this.heroNumberAnimated = true;
      }
    }, (): void => {
      this.heroDaysDisplay = target;
    });
  }

  private startProgressAnimation(): void {
    const checklist = this.latestChecklist();
    if (checklist === undefined) {
      this.progressAnimated = true;
      return;
    }
    const target = this.checkedCount(checklist);
    this.getUIContext().animateTo({
      duration: 800,
      curve: Curve.EaseOut,
      onFinish: (): void => {
        this.progressAnimated = true;
      }
    }, (): void => {
      this.progressNumeratorDisplay = target;
    });
  }

  private latestChecklist(): TripChecklist | undefined {
    if (this.checklists.length === 0) {
      return undefined;
    }
    return this.checklists[0];
  }

  private checkedCount(checklist: TripChecklist): number {
    let count = 0;
    for (let index = 0; index < checklist.items.length; index++) {
      if (checklist.items[index].checked) {
        count++;
      }
    }
    return count;
  }

  private progressValue(checklist: TripChecklist): number {
    return this.checkedCount(checklist);
  }

  private progressTotal(checklist: TripChecklist): number {
    return checklist.items.length === 0 ? 1 : checklist.items.length;
  }

  private progressText(checklist: TripChecklist): string {
    return this.checkedCount(checklist).toString() + '/' + checklist.items.length.toString();
  }

  private isChecklistDone(checklist: TripChecklist): boolean {
    return checklist.items.length > 0 && this.checkedCount(checklist) === checklist.items.length;
  }

  private activeChecklistCount(): number {
    let count = 0;
    for (let index = 0; index < this.checklists.length; index++) {
      if (!this.isChecklistDone(this.checklists[index])) {
        count++;
      }
    }
    return count;
  }

  private homeStatusText(): string {
    if (this.checklists.length === 0) {
      return '还没有行程，创建一个吧';
    }
    return this.activeChecklistCount().toString() + ' 个行程进行中';
  }

  private startOfDay(date: Date): number {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  }

  private parseTripDateAt(text: string): number | undefined {
    const monthIndex = text.indexOf('月');
    const dayIndex = text.indexOf('日');
    if (monthIndex > 0 && dayIndex > monthIndex) {
      const month = Number(text.substring(0, monthIndex));
      const day = Number(text.substring(monthIndex + 1, dayIndex));
      if (!Number.isNaN(month) && !Number.isNaN(day)) {
        return new Date(new Date().getFullYear(), month - 1, day).getTime();
      }
    }
    return undefined;
  }

  private checklistDateAt(checklist: TripChecklist): number | undefined {
    if (checklist.dateAt !== undefined) {
      return checklist.dateAt;
    }
    if (checklist.date !== undefined) {
      return this.parseTripDateAt(checklist.date);
    }
    return undefined;
  }

  private daysLeft(checklist: TripChecklist): number | undefined {
    const dateAt = this.checklistDateAt(checklist);
    if (dateAt === undefined) {
      return undefined;
    }
    return Math.floor((dateAt - this.startOfDay(new Date())) / 86400000);
  }

  private countdownLead(checklist: TripChecklist): string {
    const days = this.daysLeft(checklist);
    if (days === undefined) {
      return '待定';
    }
    if (days > 0) {
      return days.toString();
    }
    if (days === 0) {
      return '今天';
    }
    return Math.abs(days).toString();
  }

  private countdownSuffix(checklist: TripChecklist): string {
    const days = this.daysLeft(checklist);
    if (days === undefined) {
      return ' 设置出发日期';
    }
    if (days > 0) {
      return ' 天后出发';
    }
    if (days === 0) {
      return ' 出发！';
    }
    return ' 天前出发';
  }

  private checklistItemWeight(item: ChecklistItem): number | undefined {
    if (item.weight !== undefined) {
      return item.weight;
    }
    if (item.fromGearId !== undefined) {
      for (let index = 0; index < this.gears.length; index++) {
        if (this.gears[index].id === item.fromGearId) {
          return this.gears[index].weight;
        }
      }
    }
    return undefined;
  }

  private checklistTotalWeight(checklist: TripChecklist): number {
    let total = 0;
    for (let index = 0; index < checklist.items.length; index++) {
      const weight = this.checklistItemWeight(checklist.items[index]);
      if (weight !== undefined) {
        total += weight;
      }
    }
    return total;
  }

  private formatKg(weightGram: number): string {
    if (weightGram <= 0) {
      return '0kg';
    }
    return (Math.round(weightGram / 100) / 10).toString() + 'kg';
  }

  private formatDateText(timestamp: number): string {
    const date = new Date(timestamp);
    return date.getFullYear().toString() + '-' + (date.getMonth() + 1).toString() + '-' + date.getDate().toString();
  }

  private historyContentHeight(): number {
    if (this.checklists.length === 0) {
      return 64;
    }
    return this.checklists.length * 72;
  }

  private compactHeaderText(): string {
    const latest = this.latestChecklist();
    if (latest === undefined) {
      return '';
    }
    const days = this.daysLeft(latest);
    if (days === undefined) {
      return '· ' + latest.title;
    }
    if (days > 0) {
      return '· ' + latest.title + ' · ' + days.toString() + '天后';
    }
    if (days === 0) {
      return '· ' + latest.title + ' · 今天出发';
    }
    return '· ' + latest.title;
  }

  build() {
    Column() {
      Scroll(this.scroller) {
        Column({ space: 24 }) {
          this.DynamicHeader();
          if (this.latestChecklist() !== undefined) {
            this.HeroCard(this.latestChecklist());
          } else {
            this.EmptyHero();
          }
          this.QuickEntries();
          this.HistoryTimeline();
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 108 })
      }
      .edgeEffect(EdgeEffect.Spring)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .onScroll((xOffset: number, yOffset: number) => {
        this.scrollOffset = yOffset;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
  }

  @Builder
  private DynamicHeader() {
    Row() {
      Column({ space: 2 }) {
        Text('PackCheck')
          .fontSize(this.titleFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        if (this.scrollProgress() > 0.6) {
          Text(this.compactHeaderText())
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.scrollProgress() < 0.5) {
        Text(this.homeStatusText())
          .fontSize(13)
          .fontColor(TEXT_TERTIARY)
          .opacity(1 - this.scrollProgress() * 2)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 20, bottom: this.titlePaddingBottom() })
    .animation({ duration: 80, curve: Curve.Linear })
  }

  @Builder
  private HeroCard(checklist: TripChecklist | undefined) {
    if (checklist !== undefined) {
      Column({ space: 16 }) {
        Row() {
          Text(checklist.title)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          Text(this.isChecklistDone(checklist) ? '已完成' : '准备中')
            .fontSize(13)
            .fontColor(this.isChecklistDone(checklist) ? PRIMARY_COLOR : COUNTDOWN_ORANGE)
        }
        .width('100%')

        Row() {
          Text(this.getAnimatedHeroLead(checklist))
            .fontSize(this.daysLeft(checklist) === 0 ? 36 : 48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.daysLeft(checklist) !== undefined && this.daysLeft(checklist) !== undefined &&
              this.daysLeft(checklist)! <= 3 && this.daysLeft(checklist)! > 0 ? DANGER_COLOR : PRIMARY_COLOR)
          Text(this.countdownSuffix(checklist))
            .fontSize(16)
            .fontColor(TEXT_SECONDARY)
            .margin({ bottom: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .onAppear((): void => {
          this.startHeroNumberAnimation();
        })

        Row() {
          Text((checklist.date !== undefined && checklist.date.length > 0 ? checklist.date : '未设置日期') +
            ' · ' + this.formatKg(this.checklistTotalWeight(checklist)))
            .fontSize(13)
            .fontColor(TEXT_TERTIARY)
            .layoutWeight(1)
          this.RingProgress(checklist);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(20)
      .borderRadius(CARD_RADIUS)
      .linearGradient({
        angle: 135,
        colors: [[heroGradientStart(this.daysLeft(checklist)), 0], [CARD_BG, 1]]
      })
      .shadow({ radius: 12, color: '#0A000000', offsetX: 0, offsetY: 2 })
      .opacity(this.heroOpacity())
      .onClick(() => {
        if (this.heroOpacity() > 0.3) {
          this.onOpenChecklist(checklist.id);
        }
      })
    }
  }

  @Builder
  private RingProgress(checklist: TripChecklist) {
    Stack({ alignContent: Alignment.Center }) {
      Circle({ width: 52, height: 52 })
        .fill('#00000000')
        .stroke(DIVIDER_COLOR)
        .strokeWidth(5)
      Progress({
        value: this.progressValue(checklist),
        total: this.progressTotal(checklist),
        type: ProgressType.Ring
      })
        .width(52)
        .height(52)
        .color(PRIMARY_COLOR)
        .style({ strokeWidth: 5, enableSmoothEffect: true })
      Text(this.getAnimatedProgressText(checklist))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(PRIMARY_COLOR)
    }
    .width(52)
    .height(52)
    .onAppear((): void => {
      this.startProgressAnimation();
    })
  }

  @Builder
  private EmptyHero() {
    Column({ space: 8 }) {
      Text('🏔️')
        .fontSize(56)
      Text('还没有行程')
        .fontSize(18)
        .fontColor(TEXT_TERTIARY)
      Text('点击下方开始你的第一次出发')
        .fontSize(14)
        .fontColor('#CCCCCC')
      Button('创建第一个行程')
        .height(44)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(22)
        .margin({ top: 10 })
        .onClick(() => {
          this.onOpenTrip();
        })
    }
    .width('100%')
    .height(220)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(CARD_BG)
    .borderRadius(CARD_RADIUS)
    .shadow({ radius: 12, color: '#08000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  private QuickEntries() {
    Row({ space: 12 }) {
      this.QuickEntry('+', '新建行程', PRIMARY_TINT_COLOR, PRIMARY_COLOR, () => {
        this.onOpenTrip();
      });
      this.QuickEntry('🎒', '装备库', CARD_BG, TEXT_SECONDARY, () => {
        this.onOpenGear();
      });
    }
    .width('100%')
  }

  @Builder
  private QuickEntry(icon: string, title: string, bg: string, color: string, action: () => void) {
    Column({ space: 5 }) {
      Text(icon)
        .fontSize(24)
        .fontColor(color)
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
    }
    .height(80)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(bg)
    .borderRadius(16)
    .shadow({ radius: bg === CARD_BG ? 8 : 0, color: '#08000000', offsetX: 0, offsetY: 1 })
    .onClick(action)
  }

  @Builder
  private HistoryTimeline() {
    Column({ space: 12 }) {
      Text('历史行程')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .width('100%')
      if (this.checklists.length === 0) {
        Text('暂无历史行程')
          .fontSize(13)
          .fontColor(TEXT_TERTIARY)
          .width('100%')
          .height(64)
          .textAlign(TextAlign.Center)
      } else {
        List() {
          ForEach(this.checklists, (item: TripChecklist) => {
            ListItem() {
              this.HistoryRow(item);
            }
            .onClick(() => {
              this.onOpenChecklist(item.id);
            })
            .swipeAction({
              end: {
                builder: this.HistoryDeleteAction(item),
                actionAreaDistance: 80,
                onAction: () => {
                  this.onConfirmDeleteChecklist(item);
                }
              }
            })
          }, (item: TripChecklist) => item.id)
        }
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height(this.historyContentHeight())
        .scrollBar(BarState.Off)
        .backgroundColor(CARD_BG)
        .borderRadius(16)
      }
    }
    .width('100%')
  }

  @Builder
  private HistoryRow(item: TripChecklist) {
    Row({ space: 12 }) {
      Column() {
        Row()
          .width(2)
          .height(24)
          .backgroundColor(DIVIDER_COLOR)
        Circle({ width: 10, height: 10 })
          .fill(this.isChecklistDone(item) ? PRIMARY_COLOR : '#00000000')
          .stroke(PRIMARY_COLOR)
          .strokeWidth(2)
        Row()
          .width(2)
          .height(28)
          .backgroundColor(DIVIDER_COLOR)
      }
      .width(20)
      .alignItems(HorizontalAlign.Center)
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.title)
            .fontSize(16)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          Text(this.progressText(item))
            .fontSize(13)
            .fontColor(TEXT_TERTIARY)
        }
        Text(item.date !== undefined && item.date.length > 0 ? item.date : this.formatDateText(item.createdAt))
          .fontSize(13)
          .fontColor(TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16 })
    .backgroundColor(CARD_BG)
  }

  @Builder
  private HistoryDeleteAction(item: TripChecklist) {
    Row() {
      Text('删除')
        .fontSize(14)
        .fontColor('#FFFFFF')
    }
    .height(52)
    .padding({ left: 18, right: 18 })
    .margin({ left: 10 })
    .backgroundColor(DANGER_COLOR)
    .borderRadius(12)
    .onClick(() => {
      this.onConfirmDeleteChecklist(item);
    })
  }
}
