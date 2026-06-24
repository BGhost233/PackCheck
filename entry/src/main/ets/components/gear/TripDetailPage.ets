// 行程详情页 - 统一清单视图容器
// 职责：顶部导航栏 + 共享信息区 + UnifiedChecklistView（带格子的核查清单）
// 在 Index.ets NavDestinationMap 中注册为 'TripDetailPage'
// v3：删除配装/清单双 Tab（SegmentButton），合并为单一网格视图。spec §4.8

import {
  TEXT_MAIN,
  TEXT_TERTIARY,
  PAGE_BG,
  AMBER_ACCENT,
  META_SEPARATOR
} from '../../constants/Colors';
import { PAGE_PADDING, FONT_FEATURE_TNUM } from '../../constants/Layout';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  SPRING_TAB,
  PRESS_SCALE_DOWN,
  SPRING_HERO_EXPAND,
  SPRING_SCROLL,
  SPRING_HEAD_FOLLOW
} from '../../constants/AnimationTokens';
import { ChecklistItem, DayItinerary, GearItem, TripChecklist } from '../../models/PackModels';
import { UnifiedChecklistView } from './UnifiedChecklistView';
import { ItineraryView } from './ItineraryView';

// E-3：顶部元信息区结构化段。kind 决定着色：
//   'plain' 日期/地点 → TEXT_TERTIARY 纯文字；'data' 里程/海拔/时长 → AMBER_ACCENT + tnum 等宽点睛。
//   showPeak 仅海拔段为 true，前缀三角 ▲ 点睛（呼应纲领「人生足迹/高度」）。
interface MetaSegment {
  text: string;
  kind: 'plain' | 'data';
  showPeak: boolean;
}

@Component
export struct TripDetailPage {
  // 数据 (从 Index.ets 透传)
  @Prop @Watch('onTripDataChange') checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop @Watch('onTripDataChange') selectedChecklistId: string = '';
  @Prop collapsedGroups: string[] = [];
  @Prop highlightedItemId: string = '';
  @Prop checklistRenderNonce: number = 0;
  // 问题4a：聚焦态由 Index 持有 @State 源，本层 @Link 透传给 UnifiedChecklistView，使 Index onBackPressed 能分层拦截
  @Link focusedZone: string | null;
  // 问题4a：Index 命中聚焦态时递增此信号，透传给 UnifiedChecklistView 走带动画收起
  @Prop closeFocusSignal: number;

  // ============ Tab 切换状态 ============
  // 0=装备准备, 1=每日行程
  @State private tripTabIndex: number = 0;
  // visibility nonce：每次 tab 切至此组件时递增，驱动子组件入场动画重播
  // 解决 ArkUI TabContent keep-alive 时 aboutToAppear 不触发的问题
  @State private tripTab0VisibilityNonce: number = 0;
  @State private tripTab1VisibilityNonce: number = 0;
  // 0~1 连续值：滑动跟手逐帧驱动 / 点击时 animateTo 驱动
  @State private tripTabProgress: number = 0;
  // Tabs 控制器
  private tabController: TabsController = new TabsController();
  // Tabs 宽度缓存（onAreaChange 获取，用于计算 swipe ratio）
  private tabsWidth: number = 360;

  // 返回按钮按压
  @State private backScale: number = 1.0;
  // 逐项核查按钮按压
  @State private menuScale: number = 1.0;
  // Tab 标题按压缩放
  @State private tab0Scale: number = 1.0;
  @State private tab1Scale: number = 1.0;
  // 共享信息区按压
  @State private infoScale: number = 1.0;
  // 问题4a：head 随网格滚动的折叠进度（0=全展开，1=全折叠），由 UnifiedChecklistView.onScroll 回调驱动。
  //   本层据此插值收起日期行（SharedInfo），与子组件进度条折叠同帧联动。
  @State private headCollapseProgress: number = 0;
  // 问题4a：是否处于吸附动画态（区分曲线：跟手用即时跟随，吸附用 SPRING_SCROLL）。
  @State private headSnapping: boolean = false;
  // 全屏沉浸：状态栏高度由 EntryAbility/Index 通过 AppStorage 全局下发，navbar 顶部据此避让。
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  // 性能缓存：currentChecklist 和 metaSegments 一帧内被多处读取，
  // 缓存避免重复线性扫描和数组构造。@Watch 触发刷新。
  private cachedTrip: TripChecklist | undefined = undefined;
  private cachedMetaSegments: MetaSegment[] = [];

  // ChecklistDetail callbacks (透传)
  onReturnHome: () => void = () => {};
  onOpenEditTrip: () => void = () => {};
  onOpenEditProfile: () => void = () => {};
  onOpenDatePicker: () => void = () => {};
  onOpenTempItem: () => void = () => {};
  onOpenImport: () => void = () => {};
  onOpenReview: () => void = () => {};
  // D-2：聚焦态「逐项核查本区」回调
  onOpenZoneReview: (zone: string) => void = () => {};
  onDeleteTrip: () => void = () => {};
  onToggleGroup: (group: string) => void = () => {};
  onOpenEditItem: (item: ChecklistItem) => void = () => {};
  onToggleChecklistItem: (itemId: string) => void = () => {};
  onSaveChecklistItemToGear: (item: ChecklistItem) => void = () => {};
  onDeleteChecklistItem: (itemId: string) => void = () => {};

  // UnifiedChecklistView callbacks
  // zone 可选：从空格子进入时透传 Zone，picker 据此排序高亮 + 预选临时新建分区（review I4）
  onOpenGearPicker: (zone?: string) => void = () => {};
  onLongPressItem: (item: ChecklistItem) => void = () => {};
  onLayerChange: (itemId: string, layer: string) => void = () => {};
  // 问题4：聚焦态长按转拖拽移动装备到目标 Zone（改 group），透传到 Index 持久化
  onMoveItemToZone: (itemId: string, zone: string) => void = () => {};
  // Phase 4：长按菜单「移动到…」→ 由 Index 弹出 zone 选择面板
  onRequestMoveSheet: (item: ChecklistItem) => void = () => {};
  // #10：格子内排序完成回调
  onReorderItems: (zone: string, orderedIds: string[]) => void = () => {};
  // #1：多选批量移动请求（弹出 Zone 选择面板）
  onRequestBatchMoveSheet: (itemIds: string[]) => void = () => {};

  // Itinerary CRUD 回调（由 Index 处理持久化）
  onAddDay: () => void = () => {};
  onEditDay: (dayId: string) => void = () => {};
  onDeleteDay: (dayId: string) => void = () => {};
  onAddSegment: (dayId: string) => void = () => {};
  onEditSegment: (dayId: string, segId: string) => void = () => {};
  onDeleteSegment: (dayId: string, segId: string) => void = () => {};

  aboutToAppear(): void {
    this.refreshTripCache();
  }

  // 性能优化：数据变化时刷新缓存
  private onTripDataChange(): void {
    this.refreshTripCache();
  }

  private refreshTripCache(): void {
    // 缓存 currentChecklist
    this.cachedTrip = undefined;
    for (let i = 0; i < this.checklists.length; i++) {
      if (this.checklists[i].id === this.selectedChecklistId) {
        this.cachedTrip = this.checklists[i];
        break;
      }
    }
    // 缓存 metaSegments
    const segs: MetaSegment[] = [];
    const trip = this.cachedTrip;
    if (trip !== undefined) {
      if (trip.date !== undefined && trip.date.length > 0) {
        segs.push({ text: trip.date, kind: 'plain', showPeak: false });
      }
      if (trip.destination !== undefined && trip.destination.length > 0) {
        segs.push({ text: trip.destination, kind: 'plain', showPeak: false });
      }
      if (trip.distanceKm !== undefined && trip.distanceKm > 0) {
        segs.push({ text: trip.distanceKm.toString() + 'km', kind: 'data', showPeak: false });
      }
      if (trip.maxAltitude !== undefined && trip.maxAltitude > 0) {
        segs.push({ text: trip.maxAltitude.toString() + 'm', kind: 'data', showPeak: true });
      }
      if (trip.durationHours !== undefined && trip.durationHours > 0) {
        segs.push({ text: trip.durationHours.toString() + 'h', kind: 'data', showPeak: false });
      }
    }
    this.cachedMetaSegments = segs;
  }

  // 问题4a：有效折叠程度 = 聚焦态与滚动态取「更折叠」者。聚焦时日期行必须全收（让位给聚焦卡片）。
  private effectiveHeadCollapse(): number {
    return this.focusedZone != null ? 1 : this.headCollapseProgress;
  }

  // 问题4a：日期行折叠曲线——聚焦态走 SPRING_HERO；滚动吸附走 SPRING_SCROLL；跟手走 SPRING_HEAD_FOLLOW（近 1:1 实时）。
  private headCollapseCurve(): ICurve {
    if (this.focusedZone != null) {
      return SPRING_HERO_EXPAND();
    }
    return this.headSnapping ? SPRING_SCROLL() : SPRING_HEAD_FOLLOW();
  }

  // ============ 双标题 Tab 插值逻辑 ============
  // 激活态基础字号 20，折叠呼吸收到 17；非激活态固定 14。
  // tabIndex=0 的激活权重 = 1 - tripTabProgress；tabIndex=1 的激活权重 = tripTabProgress。
  private tabTitleFontSize(tabIndex: number): number {
    const weight: number = tabIndex === 0 ? (1 - this.tripTabProgress) : this.tripTabProgress;
    // 激活态字号 = 20 - 3 * collapseProgress（呼吸）；非激活态 = 14（不参与呼吸）
    const activeSize: number = 20 - 3 * this.effectiveHeadCollapse();
    const inactiveSize: number = 14;
    return inactiveSize + (activeSize - inactiveSize) * weight;
  }

  // 字重在 weight > 0.5 时切换为 Medium，否则 Regular
  private tabTitleWeight(tabIndex: number): FontWeight {
    const weight: number = tabIndex === 0 ? (1 - this.tripTabProgress) : this.tripTabProgress;
    return weight > 0.5 ? FontWeight.Medium : FontWeight.Regular;
  }

  // 颜色：激活 TEXT_MAIN，非激活 TEXT_TERTIARY，通过透明度连续插值实现渐变
  // 返回 [color, opacity] 不现实（ArkUI fontColor 不支持 opacity 参数），
  // 改用 hex 插值：TEXT_MAIN #1A1A1A / TEXT_TERTIARY #999999
  private tabTitleColor(tabIndex: number): string {
    const weight: number = tabIndex === 0 ? (1 - this.tripTabProgress) : this.tripTabProgress;
    // 线性插值 #999999 → #1A1A1A（RGB 各通道 153→26）
    const from: number = 153; // 0x99
    const to: number = 26;   // 0x1A
    const channel: number = Math.round(from + (to - from) * weight);
    const hex: string = channel.toString(16).padStart(2, '0');
    return `#${hex}${hex}${hex}`;
  }

  // ============ Tab 滑动下压效果 ============
  // 双侧对称下压：progress 在 0.5（中间态）时最深 0.97，两端恢复 1.0。
  // sin(π * progress) 天然满足 f(0)=0, f(0.5)=1, f(1)=0 的抛物线分布。
  private tabContentScale(): number {
    const TAB_DEPRESS_DEPTH: number = 0.03;
    return 1 - TAB_DEPRESS_DEPTH * Math.sin(Math.PI * this.tripTabProgress);
  }

  // Tab 切换（点击标题触发）：通过 controller 驱动 Tabs 翻页
  private switchTab(targetIndex: number): void {
    if (this.tripTabIndex === targetIndex) {
      return;
    }
    // visibility nonce：驱动目标 tab 子组件入场动画重播
    if (targetIndex === 0) { this.tripTab0VisibilityNonce++; }
    else { this.tripTab1VisibilityNonce++; }
    // 行程 Tab 已接入 HeadCollapseController，切换时不再强制重置折叠进度
    this.tabController.changeIndex(targetIndex);
  }

  // 下沉位移：展开 +4vp（向 SharedInfo 方向靠，强化「档案大标题」感）→ 折叠 0（归位居中）。
  private titleOffsetY(): number {
    return 4 * (1 - this.effectiveHeadCollapse());
  }

  /** 返回缓存的当前行程（refreshTripCache 预算）。O(1)。 */
  private currentChecklist(): TripChecklist | undefined {
    return this.cachedTrip;
  }

  // 顶部已占高度（NavBar + SharedInfo + ProgressBar），用于 UnifiedChecklistView 首屏 cell 高度反算。
  // 各段与各自渲染条件一致：NavBar 恒在；SharedInfo 仅 currentChecklist 有摘要文案时渲染；
  // ProgressBar 仅 items>0 时渲染。避免用硬编码默认值导致反算偏差（review B3）。
  private reservedTop(): number {
    const NAV_BAR: number = 40;
    const SHARED_INFO: number = 28;   // 12 字号文案 + 8 bottom padding
    const PROGRESS_BAR: number = 48;  // 文案行 + 进度条 + 上下 padding
    const trip = this.currentChecklist();
    // 全屏沉浸：navbar 顶部额外预留状态栏高度，需计入首屏 cell 反算。
    let h: number = this.statusBarHeight + NAV_BAR;
    if (trip !== undefined && this.metaSegments().length > 0) {
      h += SHARED_INFO;
    }
    if (trip !== undefined && trip.items.length > 0) {
      h += PROGRESS_BAR;
    }
    return h;
  }

  build() {
    Column() {
      // 顶部导航栏
      this.buildNavBar()

      // 共享信息区：行程参数摘要
      this.buildSharedInfo()

      // 内容区：Tabs 组件原生支持左右滑动切换
      Tabs({ barPosition: BarPosition.Start, controller: this.tabController, index: this.tripTabIndex }) {
        TabContent() {
          // Tab 0：装备准备（统一清单视图）
          UnifiedChecklistView({
            trip: this.currentChecklist() ?? { id: '', title: '', items: [], createdAt: 0 },
            gears: this.gears,
            checklistRenderNonce: this.checklistRenderNonce,
            reservedTopHeight: this.reservedTop(),
            focusedZone: this.focusedZone,
            closeFocusSignal: this.closeFocusSignal,
            onOpenPicker: (zone?: string) => { this.onOpenGearPicker(zone); },
            onToggleCheck: this.onToggleChecklistItem,
            onMoveItemToZone: this.onMoveItemToZone,
            onEditItem: this.onOpenEditItem,
            onRemoveItem: this.onDeleteChecklistItem,
            onRequestMoveSheet: this.onRequestMoveSheet,
            onReorderItems: this.onReorderItems,
            onRequestBatchMoveSheet: this.onRequestBatchMoveSheet,
            onReviewZone: this.onOpenZoneReview,
            onHeadCollapseChange: (progress: number, snapping: boolean) => {
              this.headSnapping = snapping;
              this.headCollapseProgress = progress;
            }
          })
            .width('100%')
            .height('100%')
        }
        .scale({ x: this.tabContentScale(), y: this.tabContentScale() })
        .animation({ curve: SPRING_TAB() })

        TabContent() {
          // Tab 1：每日行程
          ItineraryView({
            itinerary: this.getItinerary(),
            onAddDay: () => { this.onAddDay(); },
            onEditDay: (dayId: string) => { this.onEditDay(dayId); },
            onDeleteDay: (dayId: string) => { this.onDeleteDay(dayId); },
            onAddSegment: (dayId: string) => { this.onAddSegment(dayId); },
            onEditSegment: (dayId: string, segId: string) => { this.onEditSegment(dayId, segId); },
            onDeleteSegment: (dayId: string, segId: string) => { this.onDeleteSegment(dayId, segId); },
            onHeadCollapseChange: (progress: number, snapping: boolean) => {
              this.headSnapping = snapping;
              this.headCollapseProgress = progress;
            }
          })
            .width('100%')
            .height('100%')
        }
        .scale({ x: this.tabContentScale(), y: this.tabContentScale() })
        .animation({ curve: SPRING_TAB() })
      }
      .layoutWeight(1)
      .width('100%')
      .barHeight(0)
      .scrollable(true)
      .animationDuration(200)
      .onAreaChange((_old: Area, newArea: Area) => {
        const w = newArea.width as number;
        if (w > 0) {
          this.tabsWidth = w;
        }
      })
      .onGestureSwipe((_index: number, event: TabsAnimationEvent) => {
        // 逐帧跟手：currentOffset 负值=内容向左偏=趋向 index+1
        // progress = currentIndex - offset/width（offset 负时 progress 增大）
        const raw: number = this.tripTabIndex - event.currentOffset / this.tabsWidth;
        // clamp [0, 1]
        this.tripTabProgress = Math.max(0, Math.min(1, raw));
      })
        .onAnimationStart((_index: number, targetIndex: number) => {
          // 手势释放后动画开始：驱动标题归位
          this.getUIContext().animateTo({ curve: SPRING_TAB() }, () => {
            this.tripTabProgress = targetIndex;
          });
          // visibility nonce：驱动目标 tab 子组件入场动画重播
          if (targetIndex === 0) { this.tripTab0VisibilityNonce++; }
          else { this.tripTab1VisibilityNonce++; }
        })
      .onChange((index: number) => {
        // 兜底同步 index（动画完成后）
        this.tripTabIndex = index;
        // visibility nonce：驱动目标 tab 子组件入场动画重播
        if (index === 0) { this.tripTab0VisibilityNonce++; }
        else { this.tripTab1VisibilityNonce++; }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
  }

  // 获取当前行程的 itinerary 数据（无数据时返回空数组，由 ItineraryView 展示空态）
  private getItinerary(): DayItinerary[] {
    const trip = this.currentChecklist();
    if (trip !== undefined && trip.itinerary !== undefined && trip.itinerary.length > 0) {
      return trip.itinerary;
    }
    return [];
  }

  @Builder
  private buildNavBar() {
    Row() {
      // 返回按钮：SymbolGlyph 字形居中，与标题同线
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([TEXT_MAIN])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.backScale, y: this.backScale })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
            this.backScale = PRESS_SCALE_DOWN;
          });
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
            this.backScale = 1.0;
          });
        }
      })
      .onClick(() => {
        this.onReturnHome();
      })

      // 双标题 Tab：装备准备 / 每日行程
      // 激活态 fontSize 20fp（折叠呼吸→17），非激活态 14fp 固定
      // tripTabProgress 0→1 驱动字号连续插值，fontWeight 在 0.5 阈值切换
      Row({ space: 16 }) {
        Text('装备准备')
          .fontSize(this.tabTitleFontSize(0))
          .fontWeight(this.tabTitleWeight(0))
          .fontColor(this.tabTitleColor(0))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '45%' })
          .scale({ x: this.tab0Scale, y: this.tab0Scale })
          .animation({ curve: SPRING_TAB() })
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Down) {
              this.tab0Scale = PRESS_SCALE_DOWN;
            } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.tab0Scale = 1.0;
            }
          })
          .onClick(() => { this.switchTab(0); })

        Text('每日行程')
          .fontSize(this.tabTitleFontSize(1))
          .fontWeight(this.tabTitleWeight(1))
          .fontColor(this.tabTitleColor(1))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '45%' })
          .scale({ x: this.tab1Scale, y: this.tab1Scale })
          .animation({ curve: SPRING_TAB() })
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Down) {
              this.tab1Scale = PRESS_SCALE_DOWN;
            } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.tab1Scale = 1.0;
            }
          })
          .onClick(() => { this.switchTab(1); })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .translate({ y: this.titleOffsetY() })
      .animation({ curve: this.headCollapseCurve() })

      // 逐项核查入口：与首页核查图标统一（checkmark_shield）
      Row() {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(22)
          .fontColor([TEXT_MAIN])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.menuScale, y: this.menuScale })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.menuScale = PRESS_SCALE_DOWN;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.menuScale = 1.0;
        }
      })
      .onClick(() => {
        this.onOpenReview();
      })
    }
    .width('100%')
    .height(this.statusBarHeight + 40)
    .padding({ left: 12, right: 12, top: this.statusBarHeight })
    // 工具条三元素同线居中——横平竖直的正解（Bottom 会因子元素字形下沉散乱）
    .alignItems(VerticalAlign.Center)
  }

  // E-3：顶部元信息区 = 行程档案标识。轻结构化单行——日期/地点纯文字弱化，
  //   数据（里程/海拔/时长）用 amber + tnum 等宽点睛，海拔前加 ▲ 三角呼应「高度/人生足迹」。
  //   整体克制：不喧宾夺主，但让「这是一份档案」的质感成立。
  @Builder
  private buildSharedInfo() {
    if (this.metaSegments().length > 0) {
      Row() {
        ForEach(this.metaSegments(), (seg: MetaSegment, index: number) => {
          // 段间分隔点（仅非首段前插入）：META_SEPARATOR 明确弱于 plain 文字、又清晰可见，给并列段轻量切分
          if (index > 0) {
            Text(' · ')
              .fontSize(12)
              .fontColor(META_SEPARATOR)
          }
          // 海拔段三角点睛
          if (seg.showPeak) {
            Text('▲ ')
              .fontSize(11)
              .fontColor(AMBER_ACCENT)
          }
          Text(seg.text)
            .fontSize(12)
            .fontColor(seg.kind === 'data' ? AMBER_ACCENT : TEXT_TERTIARY)
            .fontWeight(seg.kind === 'data' ? FontWeight.Medium : FontWeight.Normal)
            .fontFeature(FONT_FEATURE_TNUM)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }, (seg: MetaSegment, index: number) => seg.text + '_' + index.toString())
      }
      .width('100%')
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: this.focusedZone != null ? 0 : 8 })
      .justifyContent(FlexAlign.Center)
      // 诉求1：进入聚焦时 head 日期行向上收没（height→0 + 淡出 + clip 裁切），
      //   让出空间给聚焦卡片顶到 navbar 下沿。Spring 与聚焦转场同帧（focusedZone 驱动），
      //   形成「head 被压扁吸走」的连续空间让渡，而非硬切消失。
      //   日期为单行 12 字号，展开高度固定 28（与 reservedTop 的 SHARED_INFO 一致，可插值）。
      // 问题4a：日期行高度/透明度随有效折叠程度插值（展开 28→折叠 0），
      //   与子组件 ProgressBar 折叠同帧联动——整条 head 随滚动连续收没。
      .height(28 * (1 - this.effectiveHeadCollapse()))
      .clip(true)
      .opacity(1 - this.effectiveHeadCollapse())
      .animation({ curve: this.headCollapseCurve() })
      .scale({ x: this.infoScale, y: this.infoScale })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.infoScale = PRESS_SCALE_DOWN;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.infoScale = 1.0;
        }
      })
      .onClick(() => {
        this.onOpenEditProfile();
      })
    }
  }

  /** 返回缓存的元信息段（refreshTripCache 预算）。O(1) 引用不变。 */
  private metaSegments(): MetaSegment[] {
    return this.cachedMetaSegments;
  }
}
