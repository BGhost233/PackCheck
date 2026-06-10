import { CATEGORY_ALL, GearItem } from '../../models/PackModels';
import {
  CARD_BG,
  DANGER_COLOR,
  PRIMARY_COLOR,
  SHEET_EDIT_ITEM,
  SHEET_EDIT_PROFILE,
  SHEET_EDIT_TRIP,
  SHEET_GEAR,
  SHEET_GEAR_SORT,
  SHEET_GENERATE_TRIP,
  SHEET_IMPORT,
  SHEET_MOVE_GROUP,
  SHEET_TEMP_ITEM,
  SHEET_TRIP,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  TRANSPARENT,
  OVERLAY_SUBTLE
} from '../../constants/Colors';
import { SPRING_GENERAL } from '../../constants/AnimationTokens';
import { GearSortSheet } from './GearSortSheet';
import { GenerateTripSheet } from './GenerateTripSheet';
import { GearFormSheet } from './GearFormSheet';
import { TripFormSheet } from './TripFormSheet';
import { TempItemSheet } from './TempItemSheet';
import { ImportSheet } from './ImportSheet';
import { ProfileEditSheet } from './ProfileEditSheet';
import { MoveGroupSheet } from './MoveGroupSheet';

@Component
export struct SheetOverlay {
  @Prop sheetMode: string = '';
  @Prop sheetTranslateY: number = 800;
  @Prop sheetOverlayOpacity: number = 0;
  @Prop errorText: string = '';
  // Gear form
  @Prop gearSortMode: string = '';
  @Prop gearName: string = '';
  @Prop gearCategory: string = '其他';
  @Prop gearWeight: string = '';
  @Prop gearPrice: string = '';
  @Prop gearNote: string = '';
  @Prop editingGearId: string = '';
  @Prop categories: string[] = [];
  // Trip form
  @Prop tripTitle: string = '';
  @Prop tripDate: string = '';
  @Prop tripDestination: string = '';
  @Prop tripDistanceKm: string = '';
  @Prop tripMaxAltitude: string = '';
  @Prop tripAscentM: string = '';
  @Prop tripDurationHours: string = '';
  // Temp item
  @Prop tempItemName: string = '';
  @Prop tempItemGroup: string = '其他';
  @Prop showTempAddNotice: boolean = false;
  // Import
  @Prop gears: GearItem[] = [];
  @Prop importGearIds: string[] = [];
  @Prop importGearCategory: string = CATEGORY_ALL;
  // Generate trip
  @Prop generateTripTitle: string = '';
  @Prop selectedMultiGearCount: number = 0;

  // Callbacks
  onClose: () => void = (): void => {};
  onSelectSort: (mode: string) => void = (mode: string): void => {};
  // Gear form callbacks
  onGearNameChange: (value: string) => void = (value: string): void => {};
  onGearCategoryChange: (value: string) => void = (value: string): void => {};
  onGearWeightChange: (value: string) => void = (value: string): void => {};
  onGearPriceChange: (value: string) => void = (value: string): void => {};
  onGearNoteChange: (value: string) => void = (value: string): void => {};
  onSaveGear: () => void = (): void => {};
  // Trip form callbacks
  onTripTitleChange: (value: string) => void = (value: string): void => {};
  onTripDateChange: (value: string) => void = (value: string): void => {};
  onTripDestinationChange: (value: string) => void = (value: string): void => {};
  onTripDistanceKmChange: (value: string) => void = (value: string): void => {};
  onTripMaxAltitudeChange: (value: string) => void = (value: string): void => {};
  onTripAscentMChange: (value: string) => void = (value: string): void => {};
  onTripDurationHoursChange: (value: string) => void = (value: string): void => {};
  onCreateTrip: () => void = (): void => {};
  onSaveTrip: () => void = (): void => {};
  onSaveProfile: () => void = (): void => {};
  // Temp item callbacks
  onTempItemNameChange: (value: string) => void = (value: string): void => {};
  onTempItemGroupChange: (value: string) => void = (value: string): void => {};
  onAddTempItem: () => void = (): void => {};
  // Import callbacks
  onImportCategoryChange: (value: string) => void = (value: string): void => {};
  onToggleImportSelection: (id: string, checked: boolean) => void = (id: string, checked: boolean): void => {};
  onImportSelectedGear: () => void = (): void => {};
  onAddGearFromImport: () => void = (): void => {};
  // Generate trip callbacks
  onGenerateTripTitleChange: (value: string) => void = (value: string): void => {};
  onGenerateTrip: () => void = (): void => {};
  // Move group callback
  onSelectMoveGroup: (group: string) => void = (group: string): void => {};
  // Swipe-to-dismiss gesture
  @State private sheetDragOffset: number = 0;
  @State private cardHeight: number = 600; // 默认值，onAreaChange 实时更新

  // Category editing callbacks
  onCategoryRename: (oldName: string, newName: string) => void = () => {};
  onCategoryDelete: (category: string) => void = () => {};
  onCategoryReorder: (categories: string[]) => void = () => {};
  onCategoryAdd: (name: string) => void = () => {};

  build() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.onClose();
        })
      Column({ space: 14 }) {
        Row() {
          Text(this.sheetTitle())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          if (this.sheetMode === SHEET_IMPORT && this.gears.length > 0) {
            Button('+ 添加装备')
              .fontSize(14)
              .fontColor(PRIMARY_COLOR)
              .backgroundColor(TRANSPARENT)
              .onClick(() => {
                this.onAddGearFromImport();
              })
          }
          Button(this.sheetMode === SHEET_TEMP_ITEM ? '完成' : '关闭')
            .fontSize(13)
            .fontColor(TEXT_SECONDARY)
            .backgroundColor(TRANSPARENT)
            .onClick(() => {
              this.onClose();
            })
        }
        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }
        if (this.sheetMode === SHEET_GEAR) {
          GearFormSheet({
            gearName: this.gearName,
            gearCategory: this.gearCategory,
            gearWeight: this.gearWeight,
            gearPrice: this.gearPrice,
            gearNote: this.gearNote,
            editingGearId: this.editingGearId,
            categories: this.categories,
            onNameChange: this.onGearNameChange,
            onCategoryChange: this.onGearCategoryChange,
            onWeightChange: this.onGearWeightChange,
            onPriceChange: this.onGearPriceChange,
            onNoteChange: this.onGearNoteChange,
            onSave: this.onSaveGear,
            onRename: this.onCategoryRename,
            onDelete: this.onCategoryDelete,
            onReorder: this.onCategoryReorder,
            onAddCategory: this.onCategoryAdd
          })
        } else if (this.sheetMode === SHEET_TRIP) {
          TripFormSheet({
            tripTitle: this.tripTitle,
            tripDate: this.tripDate,
            isEditMode: false,
            onTitleChange: this.onTripTitleChange,
            onDateChange: this.onTripDateChange,
            onConfirm: this.onCreateTrip
          })
        } else if (this.sheetMode === SHEET_EDIT_PROFILE) {
          ProfileEditSheet({
            tripDate: this.tripDate,
            tripDestination: this.tripDestination,
            tripDistanceKm: this.tripDistanceKm,
            tripMaxAltitude: this.tripMaxAltitude,
            tripAscentM: this.tripAscentM,
            tripDurationHours: this.tripDurationHours,
            onDateChange: this.onTripDateChange,
            onDestinationChange: this.onTripDestinationChange,
            onDistanceKmChange: this.onTripDistanceKmChange,
            onMaxAltitudeChange: this.onTripMaxAltitudeChange,
            onAscentMChange: this.onTripAscentMChange,
            onDurationHoursChange: this.onTripDurationHoursChange,
            onConfirm: this.onSaveProfile
          })
        } else if (this.sheetMode === SHEET_EDIT_TRIP) {
          TripFormSheet({
            tripTitle: this.tripTitle,
            tripDate: this.tripDate,
            isEditMode: true,
            tripDestination: this.tripDestination,
            tripDistanceKm: this.tripDistanceKm,
            tripMaxAltitude: this.tripMaxAltitude,
            tripAscentM: this.tripAscentM,
            tripDurationHours: this.tripDurationHours,
            onTitleChange: this.onTripTitleChange,
            onDateChange: this.onTripDateChange,
            onDestinationChange: this.onTripDestinationChange,
            onDistanceKmChange: this.onTripDistanceKmChange,
            onMaxAltitudeChange: this.onTripMaxAltitudeChange,
            onAscentMChange: this.onTripAscentMChange,
            onDurationHoursChange: this.onTripDurationHoursChange,
            onConfirm: this.onSaveTrip
          })
        } else if (this.sheetMode === SHEET_TEMP_ITEM) {
          TempItemSheet({
            tempItemName: this.tempItemName,
            tempItemGroup: this.tempItemGroup,
            showTempAddNotice: this.showTempAddNotice,
            categories: this.categories,
            onNameChange: this.onTempItemNameChange,
            onGroupChange: this.onTempItemGroupChange,
            onConfirm: this.onAddTempItem,
            onRename: this.onCategoryRename,
            onDelete: this.onCategoryDelete,
            onReorder: this.onCategoryReorder,
            onAddCategory: this.onCategoryAdd
          })
        } else if (this.sheetMode === SHEET_IMPORT) {
          ImportSheet({
            gears: this.gears,
            importGearIds: this.importGearIds,
            importGearCategory: this.importGearCategory,
            categories: this.categories,
            onCategoryChange: this.onImportCategoryChange,
            onToggleSelection: this.onToggleImportSelection,
            onImport: this.onImportSelectedGear,
            onAddGearFromImport: this.onAddGearFromImport
          })
        } else if (this.sheetMode === SHEET_GEAR_SORT) {
          GearSortSheet({
            gearSortMode: this.gearSortMode,
            onSelectSort: this.onSelectSort
          })
        } else if (this.sheetMode === SHEET_GENERATE_TRIP) {
          GenerateTripSheet({
            selectedCount: this.selectedMultiGearCount,
            generateTripTitle: this.generateTripTitle,
            onTitleChange: this.onGenerateTripTitleChange,
            onConfirm: this.onGenerateTrip
          })
        } else if (this.sheetMode === SHEET_MOVE_GROUP) {
          MoveGroupSheet({
            categories: this.categories,
            selectedCount: this.selectedMultiGearCount,
            onSelectGroup: (group: string) => {
              this.onSelectMoveGroup(group);
            }
          })
        }
      }
      .width('100%')
      .height('72%')
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })
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
              // 边缘阻尼：位移 × 0.3，卡片"变重"
              this.sheetDragOffset = event.offsetY * 0.3;
            }
          })
          .onActionEnd((_event: GestureEvent) => {
            if (this.sheetDragOffset > this.cardHeight * 0.25) {
              // 超过 25% 阈值 → 关闭
              this.sheetDragOffset = 0;
              this.onClose();
            } else {
              // 未达阈值 → Spring 回弹
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
    if (this.sheetMode === SHEET_GENERATE_TRIP) {
      return '生成行程';
    }
    if (this.sheetMode === SHEET_MOVE_GROUP) {
      return '移动到分组';
    }
    return '';
  }
}
