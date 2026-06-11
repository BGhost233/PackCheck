// 统一清单视图 - 主视图（网格态）
// 职责：2 列网格展示全部 7 个 Zone 格子（有内容态 / 空态），首屏精确 2×2.5 密度
// 替代旧的 LoadoutView + ChecklistDetail 双 Tab。spec §2.1 / §4
// Phase 1：网格骨架 + stagger 入场 + FAB + 空态引导；进度条/核查 留 Phase 2；全屏聚焦 留 Phase 3

import { display } from '@kit.ArkUI';
import {
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  CARD_BG,
  OVERLAY_DIM,
  ZONE_HEAD_COLOR,
  ZONE_UPPER_COLOR,
  ZONE_LOWER_COLOR,
  ZONE_FEET_COLOR,
  ZONE_CARRY_COLOR,
  ZONE_SLEEP_COLOR,
  ZONE_MISC_COLOR
} from '../../constants/Colors';
import {
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_MEDIUM
} from '../../constants/Typography';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  SPRING_HERO_EXPAND,
  SPRING_HERO_COLLAPSE,
  STAGGER_OFFSET_Y,
  staggerDelay
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { groupByZoneAll, calcProgress, LoadoutProgress } from '../../services/LoadoutService';
import { ZoneGridCell } from './ZoneGridCell';
import { FocusedZoneView } from './FocusedZoneView';
import { LoadoutProgressBar } from './LoadoutProgressBar';

// 双列网格中走常规单列的 zone（杂项单独跨列渲染在末尾）。spec §2.1.2 F-5
const GRID_SINGLE_ZONES: string[] = [
  BodyZone.Head,
  BodyZone.UpperBody,
  BodyZone.LowerBody,
  BodyZone.Feet,
  BodyZone.Carry,
  BodyZone.Sleep
];

// 网格布局常量
const GRID_PADDING: number = 16;   // 左右页边距
const GRID_GUTTER: number = 12;    // 行/列间距
const FIRST_SCREEN_ROWS: number = 2.5; // 首屏暗示密度：2 行完整 + 半行
// 反算兜底（无法取得屏高时）
const CELL_HEIGHT_FALLBACK: number = 160;

@Component
export struct UnifiedChecklistView {
  @Prop @Watch('onTripChange') trip: TripChecklist = { id: '', title: '', items: [], createdAt: 0 };
  @Prop gears: GearItem[] = [];
// 顶部已占高度（NavBar + SharedInfo + ProgressBar），用于首屏 cell 高度反算
// @Watch：aboutToAppear 时父层 build 可能尚未传入实算值，prop 后续更新需重算 cell 高度（review B3）
@Prop @Watch('onReservedTopChange') reservedTopHeight: number = 180;

  // callbacks
  // zone 可选：从空格子进入时透传对应 Zone，picker 据此排序高亮并预选临时新建分区（review I4）
  onOpenPicker: (zone?: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};

  // FAB 按压状态
  @State private fabScale: number = 1.0;
  // 入场动画控制
  @State private appeared: boolean = false;
  // 反算得到的单格高度
  @State private cellHeight: number = CELL_HEIGHT_FALLBACK;
  // 全屏聚焦的 Zone（null = 网格态）。spec §2.2 / §4.5.6
  @State private focusedZone: string | null = null;
  // 当前/上次聚焦渲染的 Zone（F-3：FocusedZoneView 常驻树用 visibility 切换，退场时仍需有 zone 可渲染）
  @State private focusedZoneRender: string = BodyZone.Misc;

  // 分组缓存：仅在 @Watch('trip') 时刷新。
  // 隐含前提（review C2）：Zone 分组只依赖 trip.items 自身字段，不依赖 gears。
  // 因此「gears 数据变化但 trip 引用不变」（如装备库重命名 gear）不会、也无需刷新本缓存。
  private zoneMapCache: Map<string, ChecklistItem[]> = new Map();

  aboutToAppear() {
    this.refreshCache();
    this.computeCellHeight();
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.appeared = true;
    });
  }

  aboutToDisappear() {
    this.appeared = false;
  }

onTripChange(): void {
this.refreshCache();
}

onReservedTopChange(): void {
this.computeCellHeight();
}

  build() {
    Column() {
      // 顶部全局进度条（sticky 吸顶，仅有内容时显示）。spec §2.1 / §3.3
      if (this.trip.items.length > 0) {
        LoadoutProgressBar({
          checked: this.progress().checked,
          total: this.progress().total
        })
      }

      Stack() {
        if (this.trip.items.length === 0) {
          this.buildEmptyState()
        } else {
          this.buildGridState()
        }

        if (this.trip.items.length > 0) {
          this.buildFAB()
        }

        // 全屏聚焦态（F-3：常驻树，用 visibility 切换，position 叠加在网格之上）
        this.buildFocusedLayer()
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

  // ---- 全屏聚焦层（常驻树，geometryTransition 共享元素配对端）----
  @Builder
  private buildFocusedLayer() {
    FocusedZoneView({
      zone: this.focusedZoneRender,
      items: this.itemsForZone(this.focusedZoneRender),
      zoneColor: this.zoneColor(this.focusedZoneRender),
      active: this.focusedZone != null,
      onClose: () => { this.closeFocus(); },
      onTapEmpty: (z: string) => { this.onOpenPicker(z); },
      onToggleCheck: this.onToggleCheck,
      // D-2「逐项核查本区」携带 Zone 进入 Review，后续 Phase 接入；此处先占位不误触
      onReviewZone: (z: string) => {}
    })
      .geometryTransition('zone_' + this.focusedZoneRender)
      .width('100%')
      .height('100%')
      .visibility(this.focusedZone != null ? Visibility.Visible : Visibility.Hidden)
      .hitTestBehavior(this.focusedZone != null ? HitTestMode.Default : HitTestMode.None)
  }

  // 进入聚焦：先设定渲染 zone，再 Spring 放大
  private openFocus(zone: string): void {
    this.focusedZoneRender = zone;
    this.getUIContext().animateTo({ curve: SPRING_HERO_EXPAND() }, () => {
      this.focusedZone = zone;
    });
  }

  // 退出聚焦：Spring 缩回原格
  private closeFocus(): void {
    this.getUIContext().animateTo({ curve: SPRING_HERO_COLLAPSE() }, () => {
      this.focusedZone = null;
    });
  }

  private progress(): LoadoutProgress {
    return calcProgress(this.trip.items);
  }

  private refreshCache(): void {
    this.zoneMapCache = groupByZoneAll(this.trip.items);
  }

  // 首屏 2×2.5 密度反算单格高度：(可视高 - 半行gutter冗余) / 2.5 行，扣去行间距
  // spec §2.1.2：用 2.5 行 ≈ 可视高度 反算，保证各机型一致暗示效果
  private computeCellHeight(): void {
    try {
      const di = display.getDefaultDisplaySync();
      const screenHeightVp = this.getUIContext().px2vp(di.height);
      const visibleHeight = screenHeightVp - this.reservedTopHeight;
      // 2.5 行 + 2 个完整 gutter（首屏可见 2 整行需 2 段间距）
      const usable = visibleHeight - GRID_GUTTER * FIRST_SCREEN_ROWS;
      const h = usable / FIRST_SCREEN_ROWS;
      if (h > 80 && h < 400) {
        this.cellHeight = h;
      }
    } catch (e) {
      // 取屏失败 → 用兜底高度
      this.cellHeight = CELL_HEIGHT_FALLBACK;
    }
  }

  @Builder
  private buildEmptyState() {
    Column() {
      Blank().layoutWeight(1)
      Column({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.bag'))
          .fontSize(64)
          .fontColor([TEXT_TERTIARY])
          .opacity(this.appeared ? 1 : 0)
          .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
          .animation({ curve: SPRING_GENERAL() })

        Text('还没有装备')
          .fontSize(FONT_SIZE_TITLE_MEDIUM)
          .fontWeight(FONT_WEIGHT_MEDIUM)
          .fontColor(TEXT_MAIN)
          .opacity(this.appeared ? 1 : 0)
          .animation({ curve: SPRING_GENERAL(), delay: 60 })

        Text('点击下方按钮，从装备库中选择出行装备')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_SECONDARY)
          .opacity(this.appeared ? 1 : 0)
          .animation({ curve: SPRING_GENERAL(), delay: 120 })

        Button('选择装备')
          .type(ButtonType.Capsule)
          .fontSize(FONT_SIZE_BODY_LARGE)
          .fontWeight(FONT_WEIGHT_MEDIUM)
          .fontColor(CARD_BG)
          .backgroundColor(PRIMARY_COLOR)
          .height(48)
          .padding({ left: 32, right: 32 })
          .margin({ top: 8 })
          .opacity(this.appeared ? 1 : 0)
          .scale({ x: this.appeared ? 1 : 0.9, y: this.appeared ? 1 : 0.9 })
          .animation({ curve: SPRING_GENERAL(), delay: 180 })
          .onClick(() => {
            this.onOpenPicker();
          })
      }
      .alignItems(HorizontalAlign.Center)

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildGridState() {
    Grid() {
      // 前 6 个 zone 走双列自动布局
      ForEach(GRID_SINGLE_ZONES, (zone: string, index: number) => {
        GridItem() {
          ZoneGridCell({
            zone: zone,
            items: this.itemsForZone(zone),
            zoneColor: this.zoneColor(zone),
            cellHeight: this.cellHeight,
            onTapTitle: (z: string) => { this.openFocus(z); },
            onTapEmpty: (z: string) => { this.onOpenPicker(z); },
            onToggleCheck: this.onToggleCheck
          })
        }
        .geometryTransition('zone_' + zone)
        .visibility(this.focusedZone == zone ? Visibility.Hidden : Visibility.Visible)
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
        .animation({
          curve: SPRING_GENERAL(),
          delay: staggerDelay(index)
        })
      }, (zone: string) => zone + '_' + this.itemsForZone(zone).length.toString())

      // 杂项格跨 2 列（spec §2.1.2 F-5），单独渲染在末尾
      GridItem() {
        ZoneGridCell({
          zone: BodyZone.Misc,
          items: this.itemsForZone(BodyZone.Misc),
          zoneColor: this.zoneColor(BodyZone.Misc),
          cellHeight: this.cellHeight,
          onTapTitle: (z: string) => { this.openFocus(z); },
          onTapEmpty: (z: string) => { this.onOpenPicker(z); },
          onToggleCheck: this.onToggleCheck
        })
      }
      .columnStart(0)
      .columnEnd(1)
      .geometryTransition('zone_' + BodyZone.Misc)
      .visibility(this.focusedZone == BodyZone.Misc ? Visibility.Hidden : Visibility.Visible)
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
      .animation({
        curve: SPRING_GENERAL(),
        delay: staggerDelay(GRID_SINGLE_ZONES.length)
      })
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(GRID_GUTTER)
    .rowsGap(GRID_GUTTER)
    .width('100%')
    .height('100%')
    .padding({ left: GRID_PADDING, right: GRID_PADDING, top: 8, bottom: 100 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildFAB() {
    Row() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(24)
        .fontColor([CARD_BG])
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor(PRIMARY_COLOR)
    .justifyContent(FlexAlign.Center)
    .shadow({
      radius: 12,
      color: OVERLAY_DIM,
      offsetX: 0,
      offsetY: 4
    })
    .position({ right: GRID_PADDING, bottom: 32 })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
          this.fabScale = 0.9;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
          this.fabScale = 1.0;
        });
      }
    })
    .onClick(() => {
      this.onOpenPicker();
    })
    .opacity(this.appeared ? 1 : 0)
    .scale({
      x: (this.appeared ? 1 : 0.8) * this.fabScale,
      y: (this.appeared ? 1 : 0.8) * this.fabScale
    })
    .animation({ curve: SPRING_GENERAL(), delay: 200 })
  }

  // ---- Helpers ----

  private itemsForZone(zone: string): ChecklistItem[] {
    return this.zoneMapCache.get(zone) ?? [];
  }

  private zoneColor(zone: string): string {
    switch (zone) {
      case BodyZone.Head: return ZONE_HEAD_COLOR;
      case BodyZone.UpperBody: return ZONE_UPPER_COLOR;
      case BodyZone.LowerBody: return ZONE_LOWER_COLOR;
      case BodyZone.Feet: return ZONE_FEET_COLOR;
      case BodyZone.Carry: return ZONE_CARRY_COLOR;
      case BodyZone.Sleep: return ZONE_SLEEP_COLOR;
      case BodyZone.Misc: return ZONE_MISC_COLOR;
      default: return TEXT_SECONDARY;
    }
  }
}
