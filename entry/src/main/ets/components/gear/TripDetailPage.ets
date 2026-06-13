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
  PRESS_SCALE_DOWN,
  SPRING_HERO_EXPAND,
  SPRING_SCROLL,
  SPRING_HEAD_FOLLOW
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { UnifiedChecklistView } from './UnifiedChecklistView';

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
  @Prop checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedChecklistId: string = '';
  @Prop collapsedGroups: string[] = [];
  @Prop highlightedItemId: string = '';
  @Prop checklistRenderNonce: number = 0;
  // 问题4a：聚焦态由 Index 持有 @State 源，本层 @Link 透传给 UnifiedChecklistView，使 Index onBackPressed 能分层拦截
  @Link focusedZone: string | null;
  // 问题4a：Index 命中聚焦态时递增此信号，透传给 UnifiedChecklistView 走带动画收起
  @Prop closeFocusSignal: number;

  // 返回按钮按压
  @State private backScale: number = 1.0;
  // 更多菜单按压
  @State private menuScale: number = 1.0;
  // 共享信息区按压
  @State private infoScale: number = 1.0;
  // 更多菜单展开
  @State private showMoreMenu: boolean = false;
  // 问题4a：head 随网格滚动的折叠进度（0=全展开，1=全折叠），由 UnifiedChecklistView.onScroll 回调驱动。
  //   本层据此插值收起日期行（SharedInfo），与子组件进度条折叠同帧联动。
  @State private headCollapseProgress: number = 0;
  // 问题4a：是否处于吸附动画态（区分曲线：跟手用即时跟随，吸附用 SPRING_SCROLL）。
  @State private headSnapping: boolean = false;
  // 全屏沉浸：状态栏高度由 EntryAbility/Index 通过 AppStorage 全局下发，navbar 顶部据此避让。
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

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

  private currentChecklist(): TripChecklist | undefined {
    for (let i = 0; i < this.checklists.length; i++) {
      if (this.checklists[i].id === this.selectedChecklistId) {
        return this.checklists[i];
      }
    }
    return undefined;
  }

  // 顶部已占高度（NavBar + SharedInfo + ProgressBar），用于 UnifiedChecklistView 首屏 cell 高度反算。
  // 各段与各自渲染条件一致：NavBar 恒在；SharedInfo 仅 currentChecklist 有摘要文案时渲染；
  // ProgressBar 仅 items>0 时渲染。避免用硬编码默认值导致反算偏差（review B3）。
  private reservedTop(): number {
    const NAV_BAR: number = 56;
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

      // 统一清单视图（带格子的核查清单）
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
        // 问题4a：接收子组件 head 折叠进度，驱动本层 SharedInfo 日期行同帧收起。
        onHeadCollapseChange: (progress: number, snapping: boolean) => {
          this.headSnapping = snapping;
          this.headCollapseProgress = progress;
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
  }

  @Builder
  private buildNavBar() {
    Row() {
      // 返回按钮
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
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

      // 行程名称
      Text(this.currentChecklist()?.title ?? '')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 更多菜单
      Row() {
        Text('···')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
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
        this.showMoreMenu = true;
      })
      .bindMenu(this.showMoreMenu, [
        {
          value: '编辑行程信息',
          action: () => { this.onOpenEditTrip(); }
        },
        {
          value: '逐项核查',
          action: () => { this.onOpenReview(); }
        },
        {
          value: '删除行程',
          action: () => { this.onDeleteTrip(); }
        }
      ], {
        onDisappear: () => { this.showMoreMenu = false; }
      })
    }
    .width('100%')
    .height(this.statusBarHeight + 56)
    .padding({ left: 12, right: 12, top: this.statusBarHeight })
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

  // E-3：把行程参数拆成结构化段，供 buildSharedInfo 分段着色 + reservedTop 判断高度。
  private metaSegments(): MetaSegment[] {
    const trip = this.currentChecklist();
    const segs: MetaSegment[] = [];
    if (trip === undefined) {
      return segs;
    }
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
    return segs;
  }
}
