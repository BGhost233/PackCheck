// 行程详情页 - 统一清单视图容器
// 职责：顶部导航栏 + 共享信息区 + UnifiedChecklistView（带格子的核查清单）
// 在 Index.ets NavDestinationMap 中注册为 'TripDetailPage'
// v3：删除配装/清单双 Tab（SegmentButton），合并为单一网格视图。spec §4.8

import {
  TEXT_MAIN,
  TEXT_TERTIARY,
  PAGE_BG
} from '../../constants/Colors';
import { PAGE_PADDING } from '../../constants/Layout';
import { SPRING_GENERAL, SPRING_PRESS, PRESS_SCALE_DOWN } from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { UnifiedChecklistView } from './UnifiedChecklistView';

@Component
export struct TripDetailPage {
  // 数据 (从 Index.ets 透传)
  @Prop checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedChecklistId: string = '';
  @Prop collapsedGroups: string[] = [];
  @Prop highlightedItemId: string = '';
  @Prop checklistRenderNonce: number = 0;

  // 返回按钮按压
  @State private backScale: number = 1.0;
  // 更多菜单按压
  @State private menuScale: number = 1.0;
  // 共享信息区按压
  @State private infoScale: number = 1.0;
  // 更多菜单展开
  @State private showMoreMenu: boolean = false;

  // ChecklistDetail callbacks (透传)
  onReturnHome: () => void = () => {};
  onOpenEditTrip: () => void = () => {};
  onOpenEditProfile: () => void = () => {};
  onOpenDatePicker: () => void = () => {};
  onOpenTempItem: () => void = () => {};
  onOpenImport: () => void = () => {};
  onOpenReview: () => void = () => {};
  onDeleteTrip: () => void = () => {};
  onToggleGroup: (group: string) => void = () => {};
  onOpenEditItem: (item: ChecklistItem) => void = () => {};
  onToggleChecklistItem: (itemId: string) => void = () => {};
  onSaveChecklistItemToGear: (item: ChecklistItem) => void = () => {};
  onDeleteChecklistItem: (itemId: string) => void = () => {};

  // UnifiedChecklistView callbacks
  onOpenGearPicker: () => void = () => {};
  onLongPressItem: (item: ChecklistItem) => void = () => {};
  onLayerChange: (itemId: string, layer: string) => void = () => {};
  // 点击格子标题进全屏聚焦（Phase 3 接入；Phase 1 暂打开 picker 占位）
  onTapZoneTitle: (zone: string) => void = () => {};

  private currentChecklist(): TripChecklist | undefined {
    for (let i = 0; i < this.checklists.length; i++) {
      if (this.checklists[i].id === this.selectedChecklistId) {
        return this.checklists[i];
      }
    }
    return undefined;
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
        onOpenPicker: this.onOpenGearPicker,
        onTapZoneTitle: this.onTapZoneTitle
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
    .height(56)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildSharedInfo() {
    if (this.currentChecklist() !== undefined) {
      Row() {
        Text(this.buildInfoText())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 8 })
      .justifyContent(FlexAlign.Center)
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

  private buildInfoText(): string {
    const trip = this.currentChecklist();
    if (trip === undefined) {
      return '';
    }
    const parts: string[] = [];
    if (trip.date !== undefined && trip.date.length > 0) {
      parts.push(trip.date);
    }
    if (trip.destination !== undefined && trip.destination.length > 0) {
      parts.push(trip.destination);
    }
    if (trip.distanceKm !== undefined && trip.distanceKm > 0) {
      parts.push(trip.distanceKm.toString() + 'km');
    }
    if (trip.maxAltitude !== undefined && trip.maxAltitude > 0) {
      parts.push('海拔' + trip.maxAltitude.toString() + 'm');
    }
    if (trip.durationHours !== undefined && trip.durationHours > 0) {
      parts.push(trip.durationHours.toString() + 'h');
    }
    return parts.join(' · ');
  }
}
