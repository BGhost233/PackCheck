import { ChecklistItem, GearItem, TripChecklist } from '../models/PackModels';
import { formatKg } from '../services/GearService';
import {
  checkedCount,
  progressText,
  progressTotal,
  isChecklistDone,
  startOfDay,
  checklistDateAt,
  findLatestChecklist,
  daysLeftCount,
  countdownLead,
  countdownSuffix,
  rowDateText,
  futureTrips,
  pastTrips,
  checklistItemWeight,
  checklistTotalWeight
} from '../services/ChecklistService';
import {
  AMBER_ACCENT,
  CARD_BG,
  CARD_BORDER_BOTTOM_COLOR,
  CARD_BORDER_BOTTOM_WIDTH,
  CARD_RADIUS,
  CELEBRATE_GOLD,
  DANGER_COLOR,
  DIVIDER_COLOR,
  FONT_FEATURE_TNUM,
  HOME_COLLAPSE_MAX,
  HOME_HEADER_COLLAPSED,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PAGE_PADDING,
  PRIMARY_COLOR,
  PRIMARY_TINT_COLOR,
  SHADOW_MICRO,
  SHADOW_SUBTLE,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  TRANSPARENT,
  WHITE
} from '../constants/DesignTokens';
import {
  SPRING_PRESS,
  SPRING_GENERAL,
  SPRING_SCROLL,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  STAGGER_OFFSET_Y,
  staggerDelay
} from '../constants/AnimationTokens';
import { heroGradientStart } from '../utils/ColorUtils';
import { HeadCollapseController } from '../utils/HeadCollapseController';
import { hdsEffect } from '@kit.UIDesignKit';
import {
  FONT_SIZE_CAPTION, FONT_SIZE_BODY_SMALL, FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_OVERLINE, FONT_SIZE_BODY_LARGE, FONT_SIZE_TITLE_LARGE,
  FONT_SIZE_STAT_LARGE, FONT_SIZE_EMOJI_LARGE
} from '../constants/Typography';
import { HomeQuickEntry } from './home/HomeQuickEntry';


@Component
export struct HomePage {
  @Prop @Watch('onChecklistsChange') checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop @Watch('onChecklistRenderNonceChange') checklistRenderNonce: number = 0;
  @Prop @Watch('onSwipeResetNonceChange') swipeResetNonce: number = 0;
  // tabVisibilityNonce：父层每次切至此 tab 时递增，驱动入场动画重播
  // 解决 ArkUI TabContent keep-alive 时 aboutToAppear 不触发的问题
  @Prop @Watch('onTabVisibilityNonceChange') tabVisibilityNonce: number = 0;

  onOpenTrip: () => void = (): void => {};
  onOpenChecklist: (id: string) => void = (id: string): void => {};
  onQuickReview: (checklistId: string) => void = (checklistId: string): void => {};
  onConfirmDeleteChecklist: (item: TripChecklist) => void = (item: TripChecklist): void => {};

  @State private heroDaysDisplay: number = 0;
  @State private heroNumberAnimated: boolean = false;
  @State private progressNumeratorDisplay: number = 0;
  @State private progressAnimated: boolean = false;
  // 全屏沉浸：状态栏高度由 EntryAbility/Index 通过 AppStorage 全局下发，折叠头顶部据此避让。
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // head 折叠进度镜像（0=全展开，1=全折叠）。
  //   ⚠️ 刷新陷阱：render 必须读此 @State（非控制器内部字段），controller.onChange 推动更新。
  @State private headProgress: number = 0;
  @State private historyPressedId: string = '';
  @State private heroPressed: boolean = false;
  @State private historyStaggerReady: boolean = false;
  @State private emptyBtnPressed: boolean = false;
  @State private heroRingCelebrateScale: number = 1.0;
  @State private ringCelebrateColor: string = PRIMARY_COLOR;
  // hdsEffect 按压视效：按下时 Hero 卡「陷入材质 + 点光晕染」，松手回弹（仅真机生效，模拟器降级为无）
  @State private heroPressShadow: hdsEffect.PressShadowType = hdsEffect.PressShadowType.NONE;
  private wasLatestChecklistDone: boolean = false;
  private cachedLatest: TripChecklist | undefined = undefined;
  private scroller: Scroller = new Scroller();
  private historyListScroller: ListScroller = new ListScroller();
  private isAlive: boolean = true;

  // 统一折叠控制器（overlay 范式：head 定高浮在滚动容器上，靠内部元素变形）。
  //   对齐 Large Title：跟手 1:1 + 松手就近吸附（补齐原本缺失的 onScrollStop）。
  //   collapseDistance = HOME_COLLAPSE_MAX。onChange 推动 headProgress 镜像驱动所有 head 变形 + 内容区 hero 联动。
  private headController: HeadCollapseController = new HeadCollapseController({
    collapseDistance: HOME_COLLAPSE_MAX,
    enableSnap: true,
    getUIContext: () => this.getUIContext(),
    onChange: (progress: number, snapping: boolean) => {
      this.headProgress = progress;
    }
  });
  // timer handles 用于 aboutToDisappear 清理
  private staggerTimerId: number = -1;
  private celebrateTimerId: number = -1;

  private onChecklistsChange(): void {
    this.cachedLatest = findLatestChecklist(this.checklists);
  }

  private onChecklistRenderNonceChange(): void {
    const checklist = this.latestChecklist();
    if (checklist !== undefined) {
      this.progressNumeratorDisplay = checkedCount(checklist);
      this.progressAnimated = true;
    }
  }

  private onSwipeResetNonceChange(): void {
    if (this.checklists.length > 0) {
      this.historyListScroller.closeAllSwipeActions({ onFinish: () => {} });
    }
  }

  // shared：入场动画状态重置（被 aboutToAppear 和 onTabVisibilityNonceChange 复用）
  private resetEntryStates(): void {
    this.heroDaysDisplay = 0;
    this.heroNumberAnimated = false;
    this.progressNumeratorDisplay = 0;
    this.progressAnimated = false;
    this.historyStaggerReady = false;
    this.wasLatestChecklistDone = false;
  }

  // shared：历史列表错落 stagger 调度（被 aboutToAppear 和 onTabVisibilityNonceChange 复用）
  private scheduleStaggerEntry(): void {
    if (this.staggerTimerId >= 0) {
      clearTimeout(this.staggerTimerId);
    }
    this.staggerTimerId = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.historyStaggerReady = true;
      this.checkCelebration();
    }, 100);
  }

  // tab 可见性变化时重置入场动画并重播
  onTabVisibilityNonceChange(): void {
    this.resetEntryStates();
    this.scheduleStaggerEntry();
    // 主动重启 hero 数字动画和进度动画
    // TabContent keep-alive 下 onAppear 不会再触发，必须在此处主动调用
    this.startHeroNumberAnimation();
    this.startProgressAnimation();
    // headProgress 不重置 — 由 HeadCollapseController 滚动驱动
  }

  aboutToAppear(): void {
    this.isAlive = true;
    this.resetEntryStates();
    this.headProgress = 0;
    this.scheduleStaggerEntry();
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    if (this.staggerTimerId >= 0) {
      clearTimeout(this.staggerTimerId);
      this.staggerTimerId = -1;
    }
    if (this.celebrateTimerId >= 0) {
      clearTimeout(this.celebrateTimerId);
      this.celebrateTimerId = -1;
    }
  }

  // head 折叠进度（0~1）。读 @State 镜像（非 controller.progress()）以触发 ArkUI 依赖收集。
  //   所有 head 变形（字号/透明度/背景/模糊）与内容区 hero 联动均读此值。
  private scrollProgress(): number {
    return this.headProgress;
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

  private heroScale(): number {
    return 1 - this.scrollProgress() * 0.4;
  }

  private getAnimatedHeroLead(checklist: TripChecklist): string {
    if (this.heroNumberAnimated) {
      return countdownLead(checklist);
    }
    const days = daysLeftCount(checklist);
    if (days === undefined) {
      return countdownLead(checklist);
    }
    if (days === 0) {
      return countdownLead(checklist);
    }
    return Math.round(this.heroDaysDisplay).toString();
  }

  private startHeroNumberAnimation(): void {
    const checklist = this.latestChecklist();
    if (checklist === undefined) {
      this.heroNumberAnimated = true;
      return;
    }
    const days = daysLeftCount(checklist);
    if (days === undefined || days === 0) {
      this.heroNumberAnimated = true;
      return;
    }
    const target: number = Math.abs(days);
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL(),
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
    const target = checkedCount(checklist);
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL(),
      onFinish: (): void => {
        this.progressAnimated = true;
      }
    }, (): void => {
      this.progressNumeratorDisplay = target;
    });
  }

  private latestChecklist(): TripChecklist | undefined {
    // 直接返回 @Watch('onChecklistsChange') 预缓存的结果，避免 build 内多次 O(N) 扫描
    if (this.cachedLatest === undefined) {
      this.cachedLatest = findLatestChecklist(this.checklists);
    }
    return this.cachedLatest;
  }

  private homeStatusText(): string {
    if (this.checklists.length === 0) {
      return '还没有行程，创建一个吧';
    }
    const futureCount = futureTrips(this.checklists).length;
    if (futureCount > 0) {
      return futureCount.toString() + ' 个行程待出发';
    }
    return '已完成 ' + pastTrips(this.checklists).length.toString() + ' 个行程';
  }

  private heroSubtitleText(): string {
    const checklist = this.latestChecklist();
    if (checklist === undefined) {
      return '';
    }
    const parts: string[] = [];
    // 目的地（优先展示）
    if (checklist.destination !== undefined && checklist.destination.trim().length > 0) {
      parts.push(checklist.destination.trim());
    }
    // 日期
    if (checklist.date !== undefined && checklist.date.length > 0) {
      parts.push(checklist.date);
    } else {
      parts.push('未设置日期');
    }
    // 总重
    parts.push(formatKg(checklistTotalWeight(checklist, this.gears)));
    return parts.join(' · ');
  }

  // ===== HeroCard 安全辅助方法（消灭所有 forced unwrap） =====

  private heroTitle(): string {
    const c = this.latestChecklist();
    return c !== undefined ? c.title : '';
  }

  private heroId(): string {
    const c = this.latestChecklist();
    return c !== undefined ? c.id : '';
  }

  private heroDaysLeftSafe(): number | undefined {
    const c = this.latestChecklist();
    if (c === undefined) {
      return undefined;
    }
    return daysLeftCount(c);
  }

  private heroStatusLabel(): string {
    const days = this.heroDaysLeftSafe();
    if (days !== undefined && days >= 0) {
      return '准备中';
    }
    return '已完成';
  }

  private heroStatusColor(): string {
    const days = this.heroDaysLeftSafe();
    if (days !== undefined && days >= 0) {
      return PRIMARY_COLOR;
    }
    return TEXT_TERTIARY;
  }

  private heroLeadText(): string {
    const c = this.latestChecklist();
    if (c === undefined) {
      return '';
    }
    return this.getAnimatedHeroLead(c);
  }

  private heroLeadFontSize(): number {
    const days = this.heroDaysLeftSafe();
    return days === 0 ? FONT_SIZE_STAT_LARGE : FONT_SIZE_EMOJI_LARGE;
  }

  private heroLeadColor(): string {
    const days = this.heroDaysLeftSafe();
    if (days === undefined) {
      return TEXT_TERTIARY;
    }
    if (days <= 3 && days > 0) {
      return AMBER_ACCENT;
    }
    return PRIMARY_COLOR;
  }

  private heroSuffixText(): string {
    const c = this.latestChecklist();
    if (c === undefined) {
      return '';
    }
    return countdownSuffix(c);
  }

  private heroProgressTotal(): number {
    const c = this.latestChecklist();
    if (c === undefined) {
      return 1;
    }
    return progressTotal(c);
  }

  private heroItemCountText(): string {
    const c = this.latestChecklist();
    if (c === undefined) {
      return '0';
    }
    return c.items.length.toString();
  }

  private rowDateColor(item: TripChecklist): string {
    const dateAt = checklistDateAt(item);
    if (dateAt === undefined) {
      return TEXT_TERTIARY;
    }
    const dayDiff = Math.floor((dateAt - startOfDay(new Date())) / 86400000);
    if (dayDiff === 0) {
      return PRIMARY_COLOR;
    }
    if (dayDiff >= 1 && dayDiff <= 3) {
      return AMBER_ACCENT;
    }
    if (dayDiff > 3) {
      return TEXT_SECONDARY;
    }
    // dayDiff < 0，历史行程
    return TEXT_TERTIARY;
  }

  private rowDateBold(item: TripChecklist): FontWeight {
    const dateAt = checklistDateAt(item);
    if (dateAt === undefined) {
      return FontWeight.Normal;
    }
    const dayDiff = Math.floor((dateAt - startOfDay(new Date())) / 86400000);
    return dayDiff === 0 ? FontWeight.Bold : FontWeight.Normal;
  }

  private checkCelebration(): void {
    if (this.wasLatestChecklistDone) {
      return;
    }
    const checklist = this.latestChecklist();
    if (checklist !== undefined && isChecklistDone(checklist) && checklist.items.length > 0) {
      this.wasLatestChecklistDone = true;
      this.heroRingCelebrateScale = 1.35;
      this.ringCelebrateColor = CELEBRATE_GOLD;
      this.getUIContext().animateTo({
        curve: SPRING_PRESS()
      }, () => {
        this.heroRingCelebrateScale = 1.35;
      });
      this.celebrateTimerId = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.getUIContext().animateTo({
          curve: SPRING_GENERAL()
        }, () => {
          this.heroRingCelebrateScale = 1.0;
          this.ringCelebrateColor = PRIMARY_COLOR;
        });
      }, 600);
    }
  }

  private compactHeaderText(): string {
    const latest = this.latestChecklist();
    if (latest === undefined) {
      return '';
    }
    const days = daysLeftCount(latest);
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
      Stack() {
        Scroll(this.scroller) {
          Column({ space: 20 }) {
            // Spacer: reserve height for the fixed CollapsingHeader（含状态栏避让）
            Column()
              .width('100%')
              .height(this.statusBarHeight + HOME_HEADER_COLLAPSED - 12)
            if (this.latestChecklist() !== undefined) {
              this.HeroCard();
            } else {
              this.EmptyHero();
            }
            this.QuickEntries();
            this.HistoryTimeline();
            // 弹性底部 spacer：保证内容少时也能上滑，消除顶部留白
            Column()
              .width('100%')
              .height(300)
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 32 })
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
        // 跟手：progress 严格 1:1 实时映射（零吸附、不抢手感）。
        .onDidScroll(() => {
          this.headController.handleScroll(this.scroller);
        })
        // 补齐 Large Title 就近吸附：松手惯性停在中间态时吸附到 0/1，绝不留半折叠残缺态。
        .onScrollStop(() => {
          this.headController.handleScrollStop(this.scroller);
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down && this.checklists.length > 0) {
            this.historyListScroller.closeAllSwipeActions({ onFinish: () => {} });
          }
        })

        this.HomeCollapsingHeader()
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
  }

  // 折叠态底部 hairline 分隔线：alpha 随 progress 0→1 浮现（对齐 iOS Large Title）
  private homeHeaderBorderColor(): string {
    const p = this.scrollProgress();
    const t = p < 0.5 ? 0 : Math.min(1, (p - 0.5) * 2);
    const alpha = Math.round(t * 0xFF);
    const hex = alpha < 16 ? '0' + alpha.toString(16).toUpperCase() : alpha.toString(16).toUpperCase();
    return '#' + hex + DIVIDER_COLOR.substring(1); // DIVIDER_COLOR with dynamic alpha
  }

  @Builder
  private HomeCollapsingHeader() {
    Row() {
      Text('PackCheck')
        .fontSize(this.titleFontSize())
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .animation({ curve: SPRING_SCROLL() })
      if (this.latestChecklist() !== undefined) {
        Text(this.compactHeaderText())
          .fontSize(FONT_SIZE_BODY_SMALL)
          .fontColor(TEXT_TERTIARY)
          .maxLines(1)
          .margin({ left: 8 })
          .opacity(this.scrollProgress() < 0.5 ? 0 : Math.min(1, (this.scrollProgress() - 0.5) * 2))
          .translate({ x: this.scrollProgress() < 0.5 ? -8 : 0 })
          .animation({ curve: SPRING_SCROLL() })
      }
      Blank()
      if (this.scrollProgress() < 0.6) {
        Text(this.homeStatusText())
          .fontSize(FONT_SIZE_BODY_SMALL)
          .fontColor(TEXT_TERTIARY)
          .opacity(1 - this.scrollProgress() * 2)
          .animation({ curve: SPRING_SCROLL() })
      }
    }
    .width('100%')
    .height(this.statusBarHeight + HOME_HEADER_COLLAPSED)
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING + 4, top: this.statusBarHeight })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(PAGE_BG)
    .border({ width: { bottom: 0.5 }, color: { bottom: this.homeHeaderBorderColor() } })
    .position({ x: 0, y: 0 })
  }

  @Builder
  private HeroCard() {
    if (this.latestChecklist() !== undefined) {
      Column({ space: 16 }) {
        Row() {
          Text(this.heroTitle())
            .fontSize(FONT_SIZE_TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          Text(this.heroStatusLabel())
            .fontSize(FONT_SIZE_BODY_SMALL)
            .fontColor(this.heroStatusColor())
        }
        .width('100%')

        Row() {
          Text(this.heroLeadText())
            .fontSize(this.heroLeadFontSize())
            .fontWeight(FontWeight.Bold)
            .fontColor(this.heroLeadColor())
            .fontFeature(FONT_FEATURE_TNUM)
          Text(this.heroSuffixText())
            .fontSize(FONT_SIZE_BODY_LARGE)
            .fontColor(TEXT_SECONDARY)
            .margin({ bottom: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .onAppear((): void => {
          this.startHeroNumberAnimation();
        })

        Row() {
          Text(this.heroSubtitleText())
            .fontSize(FONT_SIZE_BODY_SMALL)
            .fontColor(TEXT_TERTIARY)
            .layoutWeight(1)
          this.RingProgress();
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

      }
      .width('100%')
      .padding(20)
      .borderRadius(CARD_RADIUS)
      .linearGradient({
        angle: 135,
        colors: [[heroGradientStart(this.heroDaysLeftSafe()), 0], [CARD_BG, 1]]
      })
      .shadow({ radius: 12, color: SHADOW_SUBTLE, offsetX: 0, offsetY: 2 })
      .geometryTransition('trip-' + this.heroId())
      .transition(TransitionEffect.opacity(0.99))
      .opacity(this.heroOpacity())
      .scale({
        x: this.heroPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST * this.heroScale(),
        y: this.heroPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST * this.heroScale()
      })
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pressShadow(this.heroPressShadow)
        .buildEffect())
      .animation({ curve: SPRING_PRESS() })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.heroPressed = true;
          this.heroPressShadow = hdsEffect.PressShadowType.BLEND_GRADIENT;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.heroPressed = false;
          this.heroPressShadow = hdsEffect.PressShadowType.NONE;
        }
      })
      .onClick(() => {
        if (this.heroOpacity() > 0.3) {
          const latest = this.latestChecklist();
          if (latest !== undefined) {
            this.onOpenChecklist(latest.id);
          }
        }
      })
    }
  }

  @Builder
  private RingProgress() {
    Stack({ alignContent: Alignment.Center }) {
      Circle({ width: 52, height: 52 })
        .fill(TRANSPARENT)
        .stroke(DIVIDER_COLOR)
        .strokeWidth(5)
      Progress({
        value: this.progressNumeratorDisplay,
        total: this.heroProgressTotal(),
        type: ProgressType.Ring
      })
        .width(52)
        .height(52)
        .color(this.ringCelebrateColor)
        .style({ strokeWidth: 5, enableSmoothEffect: true })
        .animation({ curve: SPRING_GENERAL() })
      Text(this.progressNumeratorDisplay.toString() + '/' + this.heroItemCountText())
        .fontSize(FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.ringCelebrateColor)
        .fontFeature(FONT_FEATURE_TNUM)
        .animation({ curve: SPRING_GENERAL() })
    }
    .width(52)
    .height(52)
    .scale({ x: this.heroRingCelebrateScale, y: this.heroRingCelebrateScale })
    .onAppear((): void => {
      this.startProgressAnimation();
    })
  }

  @Builder
  private EmptyHero() {
    Column({ space: 8 }) {
      Text('点击下方开始你的第一次出发')
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_TERTIARY)
      Button('创建第一个行程')
        .height(44)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(WHITE)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(22)
        .margin({ top: 10 })
        .scale({ x: this.emptyBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
          y: this.emptyBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.emptyBtnPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.emptyBtnPressed = false;
          }
        })
        .onClick(() => {
          this.onOpenTrip();
        })
    }
    .width('100%')
    .padding({ top: 40, bottom: 40 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(CARD_BG)
    .borderRadius(CARD_RADIUS)
    .shadow({ radius: 12, color: SHADOW_MICRO, offsetX: 0, offsetY: 2 })
  }

  // 只取未来行程中最近的一个（dateAt >= 今天）
  private nearestFutureChecklist(): TripChecklist | undefined {
    const today = startOfDay(new Date());
    let nearest: TripChecklist | undefined = undefined;
    for (let i = 0; i < this.checklists.length; i++) {
      const dateAt = checklistDateAt(this.checklists[i]);
      if (dateAt !== undefined && dateAt >= today) {
        const nearestDateAt = nearest !== undefined ? checklistDateAt(nearest) : undefined;
        if (nearest === undefined || (nearestDateAt !== undefined && dateAt < nearestDateAt)) {
          nearest = this.checklists[i];
        }
      }
    }
    return nearest;
  }

  private quickReviewLabel(): string {
    const target = this.nearestFutureChecklist();
    if (target === undefined) {
      return '';
    }
    if (target.items.length > 0 && checkedCount(target) === target.items.length) {
      return '再检查一遍';
    }
    return '快速核查';
  }

  @Builder
  private QuickEntries() {
    Row({ space: 12 }) {
      HomeQuickEntry({
        icon: $r('sys.symbol.plus_circle'),
        title: '新建行程',
        bg: PRIMARY_TINT_COLOR,
        color: PRIMARY_COLOR,
        action: () => { this.onOpenTrip(); }
      });
      if (this.nearestFutureChecklist() !== undefined) {
        HomeQuickEntry({
          icon: $r('sys.symbol.checkmark_shield'),
          title: this.quickReviewLabel(),
          bg: CARD_BG,
          color: TEXT_MAIN,
          action: () => { this.handleQuickReview(); }
        });
      }
    }
    .width('100%')
  }

  private handleQuickReview(): void {
    const target = this.nearestFutureChecklist();
    if (target === undefined) {
      return;
    }
    // 统一交给父组件处理（父组件根据 items 数量判断进详情还是核查模式）
    this.onQuickReview(target.id);
  }

  private historyListHeight(): number {
    if (this.checklists.length === 0) {
      return 64;
    }
    const hasBoth = futureTrips(this.checklists).length > 0 && pastTrips(this.checklists).length > 0;
    // 即将启程 28vp + 走过的路 36vp + margin top 16vp = 80vp
    return this.checklists.length * 60 + (hasBoth ? 80 : 0);
  }

  @Builder
  private HistoryTimeline() {
    Column({ space: 12 }) {
      Text('我的行程')
        .fontSize(FONT_SIZE_BODY_LARGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .width('100%')
      if (this.checklists.length === 0) {
        Text('暂无行程，创建一个吧')
          .fontSize(FONT_SIZE_BODY_SMALL)
          .fontColor(TEXT_TERTIARY)
          .width('100%')
          .height(64)
          .textAlign(TextAlign.Center)
      } else {
        List({ scroller: this.historyListScroller }) {
          if (futureTrips(this.checklists).length > 0 && pastTrips(this.checklists).length > 0) {
            ListItem() {
              Text('即将启程')
                .fontSize(FONT_SIZE_BODY_SMALL)
                .fontWeight(FontWeight.Medium)
                .fontColor(TEXT_SECONDARY)
                .letterSpacing(1)
                .width('100%')
                .padding({ left: 16, top: 4, bottom: 4 })
            }
            .height(28)
            .selectable(false)
          }
          ForEach(futureTrips(this.checklists), (item: TripChecklist, index: number) => {
            ListItem() {
              this.HistoryRow(item);
            }
            .opacity(this.historyStaggerReady ? 1 : 0)
            .translate({ y: this.historyStaggerReady ? 0 : STAGGER_OFFSET_Y })
            .animation({ delay: staggerDelay(index), curve: SPRING_GENERAL() })
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
          }, (item: TripChecklist) => item.id + '_' + item.items.length.toString() + '_' + this.checklistRenderNonce.toString())
          if (futureTrips(this.checklists).length > 0 && pastTrips(this.checklists).length > 0) {
            ListItem() {
              Text('走过的路')
                .fontSize(FONT_SIZE_BODY_SMALL)
                .fontWeight(FontWeight.Medium)
                .fontColor(TEXT_SECONDARY)
                .letterSpacing(1)
                .width('100%')
                .padding({ left: 16, top: 4, bottom: 4 })
            }
            .height(36)
            .margin({ top: 16 })
            .selectable(false)
          }
          ForEach(pastTrips(this.checklists), (item: TripChecklist, index: number) => {
            ListItem() {
              this.HistoryRow(item);
            }
            .opacity(this.historyStaggerReady ? 1 : 0)
            .translate({ y: this.historyStaggerReady ? 0 : STAGGER_OFFSET_Y })
            .animation({ delay: staggerDelay(futureTrips(this.checklists).length + index), curve: SPRING_GENERAL() })
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
          }, (item: TripChecklist) => item.id + '_' + item.items.length.toString() + '_' + this.checklistRenderNonce.toString())
        }
        .width('100%')
        .height(this.historyListHeight())
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.PARENT_FIRST })
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
          .height(16)
          .backgroundColor(DIVIDER_COLOR)
        Circle({ width: 8, height: 8 })
          .fill(isChecklistDone(item) ? PRIMARY_COLOR : TRANSPARENT)
          .stroke(PRIMARY_COLOR)
          .strokeWidth(1.5)
        Row()
          .width(2)
          .height(20)
          .backgroundColor(DIVIDER_COLOR)
      }
      .width(16)
      .alignItems(HorizontalAlign.Center)
      Column({ space: 2 }) {
        Row({ space: 8 }) {
          Text(item.title)
            .fontSize(FONT_SIZE_OVERLINE)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          Text(progressText(item))
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_TERTIARY)
            .fontFeature(FONT_FEATURE_TNUM)
        }
        Text(rowDateText(item))
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(this.rowDateColor(item))
          .fontWeight(this.rowDateBold(item))
          .fontFeature(FONT_FEATURE_TNUM)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor(CARD_BG)
    .borderRadius(12)
    .border({ width: { bottom: CARD_BORDER_BOTTOM_WIDTH }, color: { bottom: CARD_BORDER_BOTTOM_COLOR } })
    .geometryTransition('trip-' + item.id)
    .transition(TransitionEffect.opacity(0.99))
    .scale({ x: this.historyPressedId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST, y: this.historyPressedId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.historyPressedId = item.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.historyPressedId = '';
      }
    })
  }

  @Builder
  private HistoryDeleteAction(item: TripChecklist) {
    Row() {
      Text('删除')
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(WHITE)
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
