import { CATEGORY_ALL, ChecklistItem, GearItem, TransportMode, DayItinerary, RouteSegment } from '../../models/PackModels';
import {
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_BODY_SMALL,
  FONT_SIZE_CAPTION
} from '../../constants/Typography';
import { resolveItemName } from '../../services/ChecklistService';
import {
  CARD_BG,
  DANGER_COLOR,
  PRIMARY_COLOR,
  SHEET_EDIT_ITEM,
  SHEET_EDIT_PROFILE,
  SHEET_EDIT_TRIP,
  SHEET_GEAR,
  SHEET_GEAR_SORT,
  SHEET_IMPORT,
  SHEET_TEMP_ITEM,
  SHEET_TRIP,
  SHEET_GEAR_PICKER,
  SHEET_GEAR_ITEM_ACTION,
  SHEET_DAY_FORM,
  SHEET_SEGMENT_FORM,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  TRANSPARENT,
  OVERLAY_SUBTLE
} from '../../constants/Colors';
import { SPRING_GENERAL } from '../../constants/AnimationTokens';
import { GearSortSheet } from './GearSortSheet';
import { GearFormSheet } from './GearFormSheet';
import { TripFormSheet } from './TripFormSheet';
import { TempItemSheet } from './TempItemSheet';
import { ImportSheet } from './ImportSheet';
import { ProfileEditSheet } from './ProfileEditSheet';
import { GearPickerSheet } from './GearPickerSheet';
import { GearItemActionSheet } from './GearItemActionSheet';
import { DayFormSheet } from './DayFormSheet';
import { SegmentFormSheet } from './SegmentFormSheet';

@Component
export struct SheetOverlay {
  // ===== 通用控制 =====
  @Prop sheetMode: string = '';
  @Prop sheetTranslateY: number = 800;
  @Prop sheetOverlayOpacity: number = 0;
  @Prop errorText: string = '';
  onClose: () => void = (): void => {};

  // ===== GearFormSheet（§4.6 内化后只传初始值） =====
  @Prop editingGearId: string = '';
  @Prop categories: string[] = [];
  @Prop gearInitialName: string = '';
  @Prop gearInitialCategory: string = '其他';
  @Prop gearInitialWeight: string = '';
  @Prop gearInitialPrice: string = '';
  @Prop gearInitialNote: string = '';
  onSaveGear: (name: string, category: string, weight: string, price: string, note: string) => void = () => {};
  // Category editing callbacks (shared by GearForm / TempItem)
  onCategoryRename: (oldName: string, newName: string) => void = () => {};
  onCategoryDelete: (category: string) => void = () => {};
  onCategoryReorder: (categories: string[]) => void = () => {};
  onCategoryAdd: (name: string) => void = () => {};

  // ===== TripFormSheet（§4.6 内化后只传初始值） =====
  @Prop tripInitialTitle: string = '';
  @Prop tripInitialDate: string = '';
  @Prop tripInitialDestination: string = '';
  @Prop tripInitialDistanceKm: string = '';
  @Prop tripInitialMaxAltitude: string = '';
  @Prop tripInitialAscentM: string = '';
  @Prop tripInitialDurationHours: string = '';
  onCreateTrip: (title: string, date: string, destination: string,
    distanceKm: string, maxAltitude: string, ascentM: string, durationHours: string) => void = () => {};
  onSaveTrip: (title: string, date: string, destination: string,
    distanceKm: string, maxAltitude: string, ascentM: string, durationHours: string) => void = () => {};

  // ===== ProfileEditSheet（§4.6 内化后只传初始值） =====
  @Prop profileInitialDate: string = '';
  @Prop profileInitialDestination: string = '';
  @Prop profileInitialDistanceKm: string = '';
  @Prop profileInitialMaxAltitude: string = '';
  @Prop profileInitialAscentM: string = '';
  @Prop profileInitialDurationHours: string = '';
  onSaveProfile: (date: string, destination: string,
    distanceKm: string, maxAltitude: string, ascentM: string, durationHours: string) => void = () => {};

  // ===== TempItemSheet（§4.6 内化后只传初始值） =====
  @Prop tempInitialName: string = '';
  @Prop tempInitialGroup: string = '其他';
  onAddTempItem: (name: string, group: string) => void = () => {};

  // ===== ImportSheet（§4.6 内化后不需传选中/筛选状态） =====
  @Prop gears: GearItem[] = [];
  onImportGears: (ids: string[]) => void = () => {};
  onAddGearFromImport: () => void = (): void => {};

  // ===== GearSortSheet =====
  @Prop gearSortMode: string = '';
  onSelectSort: (mode: string) => void = (mode: string): void => {};

  // ===== GearPickerSheet =====
  @Prop pickerSelectedIds: string[] = [];
  @Prop pickerPreselectZone: string = '';
  onPickerToggleGear: (gear: GearItem) => void = () => {};
  onPickerAddGear: (name: string, zone: string, weight: number | undefined, category: string, saveToLibrary: boolean) => void = () => {};

  // ===== GearItemActionSheet =====
  @Prop actionItem: ChecklistItem = { id: '', name: '', group: '', checked: false };
  onActionMoveToZone: (itemId: string, zone: string) => void = () => {};
  onActionViewDetail: (item: ChecklistItem) => void = () => {};
  onActionRemove: (itemId: string) => void = () => {};

  // ===== DayFormSheet（已内化，只传初始值） =====
  @Prop editingDayId: string = '';
  @Prop dayFrom: string = '';
  @Prop dayTo: string = '';
  @Prop dayDate: string = '';
  @Prop dayNote: string = '';
  onSubmitDay: (day: DayItinerary) => void = () => {};
  onSubmitEditDay: (dayId: string, from: string, to: string, date: string, note: string) => void = () => {};
  onDeleteDayFromSheet: () => void = () => {};

  // ===== SegmentFormSheet（已内化，只传初始值） =====
  @Prop editingSegmentId: string = '';
  @Prop segFrom: string = '';
  @Prop segTo: string = '';
  @Prop segTransport: TransportMode = 'other';
  @Prop segDepartTime: string = '';
  @Prop segArriveTime: string = '';
  @Prop segNote: string = '';
  @Prop segAccommodation: string = '';
  @Prop ticketCode: string = '';
  @Prop ticketSeat: string = '';
  @Prop ticketPrice: string = '';
  onSubmitSegment: (segment: RouteSegment) => void = () => {};
  onDeleteSegmentFromSheet: () => void = () => {};

  // ===== Swipe-to-dismiss gesture =====
  @State private sheetDragOffset: number = 0;
  @State private cardHeight: number = 600;

  build() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.onClose();
        })
      Column({ space: 14 }) {
        // GearPickerSheet 自建 head（标题随态切换），跳过统一 head
        if (this.sheetMode !== SHEET_GEAR_PICKER) {
          Row() {
            Text(this.sheetTitle())
              .fontSize(FONT_SIZE_BODY_LARGE)
              .fontWeight(FontWeight.Medium)
              .fontColor(TEXT_MAIN)
              .layoutWeight(1)
            if (this.sheetMode === SHEET_IMPORT && this.gears.length > 0) {
              Button('+ 添加装备')
                .fontSize(FONT_SIZE_BODY_MEDIUM)
                .fontColor(PRIMARY_COLOR)
                .backgroundColor(TRANSPARENT)
                .onClick(() => {
                  this.onAddGearFromImport();
                })
            }
            Button(this.sheetMode === SHEET_TEMP_ITEM ? '完成' : '关闭')
              .fontSize(FONT_SIZE_BODY_SMALL)
              .fontColor(TEXT_SECONDARY)
              .backgroundColor(TRANSPARENT)
              .onClick(() => {
                this.onClose();
              })
          }
        }
        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }
        if (this.sheetMode === SHEET_GEAR) {
          GearFormSheet({
            editingGearId: this.editingGearId,
            categories: this.categories,
            initialName: this.gearInitialName,
            initialCategory: this.gearInitialCategory,
            initialWeight: this.gearInitialWeight,
            initialPrice: this.gearInitialPrice,
            initialNote: this.gearInitialNote,
            onSave: this.onSaveGear,
            onRename: this.onCategoryRename,
            onDelete: this.onCategoryDelete,
            onReorder: this.onCategoryReorder,
            onAddCategory: this.onCategoryAdd
          })
        } else if (this.sheetMode === SHEET_TRIP) {
          TripFormSheet({
            isEditMode: false,
            initialTitle: this.tripInitialTitle,
            initialDate: this.tripInitialDate,
            onConfirm: this.onCreateTrip
          })
        } else if (this.sheetMode === SHEET_EDIT_PROFILE) {
          ProfileEditSheet({
            initialDate: this.profileInitialDate,
            initialDestination: this.profileInitialDestination,
            initialDistanceKm: this.profileInitialDistanceKm,
            initialMaxAltitude: this.profileInitialMaxAltitude,
            initialAscentM: this.profileInitialAscentM,
            initialDurationHours: this.profileInitialDurationHours,
            onConfirm: this.onSaveProfile
          })
        } else if (this.sheetMode === SHEET_EDIT_TRIP) {
          TripFormSheet({
            isEditMode: true,
            initialTitle: this.tripInitialTitle,
            initialDate: this.tripInitialDate,
            initialDestination: this.tripInitialDestination,
            initialDistanceKm: this.tripInitialDistanceKm,
            initialMaxAltitude: this.tripInitialMaxAltitude,
            initialAscentM: this.tripInitialAscentM,
            initialDurationHours: this.tripInitialDurationHours,
            onConfirm: this.onSaveTrip
          })
        } else if (this.sheetMode === SHEET_TEMP_ITEM) {
          TempItemSheet({
            initialName: this.tempInitialName,
            initialGroup: this.tempInitialGroup,
            categories: this.categories,
            onConfirm: this.onAddTempItem,
            onRename: this.onCategoryRename,
            onDelete: this.onCategoryDelete,
            onReorder: this.onCategoryReorder,
            onAddCategory: this.onCategoryAdd
          })
        } else if (this.sheetMode === SHEET_IMPORT) {
          ImportSheet({
            gears: this.gears,
            categories: this.categories,
            onImport: this.onImportGears,
            onAddGearFromImport: this.onAddGearFromImport
          })
        } else if (this.sheetMode === SHEET_GEAR_SORT) {
          GearSortSheet({
            gearSortMode: this.gearSortMode,
            onSelectSort: this.onSelectSort
          })
        } else if (this.sheetMode === SHEET_GEAR_PICKER) {
          GearPickerSheet({
            gears: this.gears,
            categories: this.categories,
            selectedItemIds: this.pickerSelectedIds,
            preselectZone: this.pickerPreselectZone,
            onToggleGear: this.onPickerToggleGear,
            onAddGear: this.onPickerAddGear,
            onClose: this.onClose
          })
            .layoutWeight(1)
        } else if (this.sheetMode === SHEET_GEAR_ITEM_ACTION) {
          GearItemActionSheet({
            item: this.actionItem,
            displayName: resolveItemName(this.actionItem, this.gears),
            onMoveToZone: this.onActionMoveToZone,
            onViewDetail: this.onActionViewDetail,
            onRemove: this.onActionRemove,
            onClose: this.onClose
          })
        } else if (this.sheetMode === SHEET_DAY_FORM) {
          DayFormSheet({
            editingDayId: this.editingDayId,
            initialFrom: this.dayFrom,
            initialTo: this.dayTo,
            initialDate: this.dayDate,
            initialNote: this.dayNote,
            onSubmitDay: this.onSubmitDay,
            onSubmitEdit: this.onSubmitEditDay,
            onDeleteDay: this.onDeleteDayFromSheet
          })
        } else if (this.sheetMode === SHEET_SEGMENT_FORM) {
          SegmentFormSheet({
            editingSegmentId: this.editingSegmentId,
            initialFrom: this.segFrom,
            initialTo: this.segTo,
            initialTransport: this.segTransport,
            initialDepartTime: this.segDepartTime,
            initialArriveTime: this.segArriveTime,
            initialNote: this.segNote,
            initialAccommodation: this.segAccommodation,
            initialTicketCode: this.ticketCode,
            initialTicketSeat: this.ticketSeat,
            initialTicketPrice: this.ticketPrice,
            onSubmit: this.onSubmitSegment,
            onDeleteSegment: this.onDeleteSegmentFromSheet
          })
        }
      }
      .width('100%')
      .height('72%')
      .padding({ left: 16, right: 16, top: this.sheetMode === SHEET_GEAR_PICKER ? 10 : 16, bottom: 20 })
      .backgroundColor(CARD_BG)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .translate({ y: this.sheetTranslateY + this.sheetDragOffset })
      .onAreaChange((_old: Area, newArea: Area) => {
        this.cardHeight = newArea.height as number;
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
          .onActionUpdate((event: GestureEvent) => {
            if (event.offsetY > 0) {
              this.sheetDragOffset = event.offsetY * 0.3;
            }
          })
          .onActionEnd((_event: GestureEvent) => {
            if (this.sheetDragOffset > this.cardHeight * 0.25) {
              this.sheetDragOffset = 0;
              this.onClose();
            } else {
              this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
                this.sheetDragOffset = 0;
              });
            }
          })
          .onActionCancel(() => {
            this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
              this.sheetDragOffset = 0;
            });
          })
      )
    }
    .width('100%')
    .height('100%')
    .opacity(this.sheetOverlayOpacity)
    .backgroundColor(OVERLAY_SUBTLE)
    .backdropBlur(16)
  }

  private sheetTitle(): string {
    if (this.sheetMode === SHEET_GEAR) {
      return this.editingGearId.length === 0 ? '添加装备' : '编辑装备';
    }
    if (this.sheetMode === SHEET_TRIP) {
      return '新建行程';
    }
    if (this.sheetMode === SHEET_EDIT_TRIP) {
      return '编辑行程';
    }
    if (this.sheetMode === SHEET_EDIT_PROFILE) {
      return '编辑行程信息';
    }
    if (this.sheetMode === SHEET_TEMP_ITEM) {
      return '添加物品';
    }
    if (this.sheetMode === SHEET_EDIT_ITEM) {
      return '编辑物品';
    }
    if (this.sheetMode === SHEET_IMPORT) {
      return '从装备库导入';
    }
    if (this.sheetMode === SHEET_GEAR_SORT) {
      return '排序方式';
    }
    if (this.sheetMode === SHEET_GEAR_PICKER) {
      return '选择装备';
    }
    if (this.sheetMode === SHEET_GEAR_ITEM_ACTION) {
      return '';
    }
    if (this.sheetMode === SHEET_DAY_FORM) {
      return this.editingDayId.length === 0 ? '添加一天' : '编辑行程日';
    }
    if (this.sheetMode === SHEET_SEGMENT_FORM) {
      return this.editingSegmentId.length === 0 ? '添加路段' : '编辑路段';
    }
    return '';
  }
}
