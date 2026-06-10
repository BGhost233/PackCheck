// 行程详情页 - 双视图容器
// 职责：顶部共享信息区 + SegmentButton 切换配装/清单视图
// 在 Index.ets NavDestinationMap 中注册为 'TripDetailPage'

import {
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  CARD_BG,
  PAGE_BG,
  DIVIDER_COLOR,
  SHADOW_MICRO,
  TRANSPARENT,
  DANGER_COLOR
} from '../../constants/Colors';
import { PAGE_PADDING, CARD_RADIUS } from '../../constants/Layout';
import { SPRING_GENERAL, SPRING_PRESS, PRESS_SCALE_DOWN } from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { LoadoutView } from './LoadoutView';
import { ChecklistDetail } from '../ChecklistDetail';

@Component
export struct TripDetailPage {
  // 数据 (从 Index.ets 透传)
  @Prop checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedChecklistId: string = '';
  @Prop collapsedGroups: string[] = [];
  @Prop highlightedItemId: string = '';
  @Prop checklistRenderNonce: number = 0;

  // 视图切换
  @State private activeView: string = 'loadout'; // 'loadout' | 'checklist'

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

  // LoadoutView callbacks
  onOpenGearPicker: () => void = () => {};
  onLongPressItem: (item: ChecklistItem) => void = () => {};
  onLayerChange: (itemId: string, layer: string) => void = () => {};

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

      // SegmentButton 视图切换
      this.buildSegment()

      // 视图内容
      if (this.activeView === 'loadout') {
        LoadoutView({
          trip: this.currentChecklist() ?? { id: '', title: '', items: [], createdAt: 0 },
          gears: this.gears,
          onOpenPicker: this.onOpenGearPicker,
          onToggleCheck: this.onToggleChecklistItem,
          onLongPressItem: this.onLongPressItem,
          onLayerChange: this.onLayerChange
        })
          .layoutWeight(1)
          .transition(TransitionEffect.OPACITY.animation({ curve: SPRING_GENERAL() }))
      } else {
        ChecklistDetail({
          checklists: this.checklists,
          gears: this.gears,
          selectedChecklistId: this.selectedChecklistId,
          collapsedGroups: this.collapsedGroups,
          highlightedItemId: this.highlightedItemId,
          checklistRenderNonce: this.checklistRenderNonce,
          onReturnHome: this.onReturnHome,
          onOpenEditTrip: this.onOpenEditTrip,
          onOpenEditProfile: this.onOpenEditProfile,
          onOpenDatePicker: this.onOpenDatePicker,
          onOpenTempItem: this.onOpenTempItem,
          onOpenImport: this.onOpenImport,
          onOpenReview: this.onOpenReview,
          onToggleGroup: this.onToggleGroup,
          onOpenEditItem: this.onOpenEditItem,
          onToggleChecklistItem: this.onToggleChecklistItem,
          onSaveChecklistItemToGear: this.onSaveChecklistItemToGear,
          onDeleteChecklistItem: this.onDeleteChecklistItem
        })
          .layoutWeight(1)
          .transition(TransitionEffect.OPACITY.animation({ curve: SPRING_GENERAL() }))
      }
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

  @Builder
  private buildSegment() {
    Row({ space: 4 }) {
      this.buildSegmentTab('配装', 'loadout')
      this.buildSegmentTab('清单', 'checklist')
    }
    .width(200)
    .height(36)
    .borderRadius(18)
    .backgroundColor(DIVIDER_COLOR)
    .padding(3)
    .margin({ bottom: 8 })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  private buildSegmentTab(label: string, view: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.activeView === view ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.activeView === view ? TEXT_MAIN : TEXT_SECONDARY)
      .backgroundColor(this.activeView === view ? CARD_BG : TRANSPARENT)
      .borderRadius(15)
      .height('100%')
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .shadow(this.activeView === view ? {
        radius: 4,
        color: SHADOW_MICRO,
        offsetX: 0,
        offsetY: 1
      } : undefined)
      .animation({ curve: SPRING_GENERAL() })
      .onClick(() => {
        if (this.activeView !== view) {
          this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
            this.activeView = view;
          });
        }
      })
  }
}
