// 配装系统 - 配装视图主组件
// 职责：Stack 布局 = Scroll(进度条 + Zone 卡片网格) + FAB
// 空态引导 / 有装备态 / FAB 触发 GearPickerSheet

import {
  PRIMARY_COLOR,
  LIGHT_PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  CARD_BG,
  PAGE_BG,
  OVERLAY_DIM,
  ZONE_HEAD_COLOR,
  ZONE_UPPER_COLOR,
  ZONE_LOWER_COLOR,
  ZONE_FEET_COLOR,
  ZONE_CARRY_COLOR,
  ZONE_SLEEP_COLOR,
  ZONE_MISC_COLOR
} from '../../constants/Colors';
import { CARD_RADIUS, PAGE_PADDING } from '../../constants/Layout';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  STAGGER_OFFSET_Y,
  staggerDelay
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import {
  assignSlot,
  groupByZone,
  sortItemsByLayer,
  calcProgress,
  zoneDisplayName,
  zoneIconName,
  allZones,
  groupMiscByCategory,
  LoadoutProgress
} from '../../services/LoadoutService';
import { LoadoutZoneCard } from './LoadoutZoneCard';
import { LoadoutProgressBar } from './LoadoutProgressBar';

// Zone 展示顺序（人体从上到下）
const ZONE_ORDER: string[] = [
  BodyZone.Head,
  BodyZone.UpperBody,
  BodyZone.LowerBody,
  BodyZone.Feet,
  BodyZone.Carry,
  BodyZone.Sleep,
  BodyZone.Misc
];

@Component
export struct LoadoutView {
  @Prop @Watch('onTripChange') trip: TripChecklist = { id: '', title: '', items: [], createdAt: 0 };
  @Prop gears: GearItem[] = [];

  // callbacks
  onOpenPicker: () => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  onLongPressItem: (item: ChecklistItem) => void = () => {};
  onLayerChange: (itemId: string, layer: string) => void = () => {};

  // FAB 按压状态
  @State private fabScale: number = 1.0;
  // 入场动画控制
  @State private appeared: boolean = false;
  // 缓存计算结果（每次 build 刷新）
  private zoneMapCache: Map<string, ChecklistItem[]> = new Map();
  private progressCache: LoadoutProgress = { checked: 0, total: 0 };

  aboutToAppear() {
    this.refreshCache();
    // 无 setTimeout——直接触发，子元素各自的 .animation({ delay }) 天然形成 stagger
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.appeared = true;
    });
  }

  aboutToDisappear() {
    // 组件销毁时重置状态（无 timer 需清理，但保持防御性语义）
    this.appeared = false;
  }

  onTripChange(): void {
    this.refreshCache();
  }

  build() {
    Stack() {
      // 底层：Scroll 内容
      if (this.trip.items.length === 0) {
        this.buildEmptyState()
      } else {
        this.buildContentState()
      }

      // 上层：FAB（有装备时常驻，空态时隐藏——空态用引导按钮代替）
      if (this.trip.items.length > 0) {
        this.buildFAB()
      }
    }
    .width('100%')
    .height('100%')
  }

  private refreshCache(): void {
    this.zoneMapCache = groupByZone(this.trip.items);
    this.progressCache = calcProgress(this.trip.items);
  }

  private cachedProgress(): LoadoutProgress {
    return this.progressCache;
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
          .translate({ y: this.appeared ? 0 : 20 })
          .animation({ curve: SPRING_GENERAL() })

        Text('还没有装备')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .opacity(this.appeared ? 1 : 0)
          .animation({ curve: SPRING_GENERAL(), delay: 60 })

        Text('点击下方按钮，从装备库中选择出行装备')
          .fontSize(14)
          .fontColor(TEXT_SECONDARY)
          .opacity(this.appeared ? 1 : 0)
          .animation({ curve: SPRING_GENERAL(), delay: 120 })

        Button('选择装备')
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
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
  private buildContentState() {
    Scroll() {
      Column({ space: 16 }) {
        // 进度条（一次计算）
        LoadoutProgressBar({
          checked: this.cachedProgress().checked,
          total: this.cachedProgress().total
        })
          .margin({ left: PAGE_PADDING, right: PAGE_PADDING, top: 16 })

        // Zone 卡片网格
        this.buildZoneGrid()

        // 底部安全区留白
        Blank().height(100)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildZoneGrid() {
    Column({ space: 12 }) {
      ForEach(this.getVisibleZones(), (zone: string, index: number) => {
        LoadoutZoneCard({
          zone: zone,
          items: sortItemsByLayer(this.getItemsForZone(zone), this.gears),
          gears: this.gears,
          zoneColor: this.getZoneColor(zone),
          onToggleCheck: this.onToggleCheck,
          onLongPress: this.onLongPressItem,
          onTapLayerBadge: (item: ChecklistItem) => { this.onLongPressItem(item); }
        })
          .opacity(this.appeared ? 1 : 0)
          .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
          .animation({
            curve: SPRING_GENERAL(),
            delay: staggerDelay(index)
          })
      })
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
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
    .position({ right: PAGE_PADDING, bottom: 32 })
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

  // --- Helpers ---

  private getVisibleZones(): string[] {
    return ZONE_ORDER.filter(z => {
      const items = this.zoneMapCache.get(z);
      return items !== undefined && items.length > 0;
    });
  }

  private getItemsForZone(zone: string): ChecklistItem[] {
    return this.zoneMapCache.get(zone) ?? [];
  }

  private getZoneColor(zone: string): string {
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
