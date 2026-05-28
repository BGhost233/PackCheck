import { GearItem } from '../../models/PackModels';
import {
  CARD_BG,
  DANGER_COLOR,
  PRIMARY_COLOR,
  SHEET_EDIT_ITEM,
  SHEET_EDIT_TRIP,
  SHEET_GEAR,
  SHEET_GEAR_SORT,
  SHEET_GENERATE_TRIP,
  SHEET_IMPORT,
  SHEET_TEMP_ITEM,
  SHEET_TRIP,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import { GearSortSheet } from './GearSortSheet';
import { GenerateTripSheet } from './GenerateTripSheet';
import { GearFormSheet } from './GearFormSheet';
import { TripFormSheet } from './TripFormSheet';
import { TempItemSheet } from './TempItemSheet';
import { ImportSheet } from './ImportSheet';

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
  // Temp item
  @Prop tempItemName: string = '';
  @Prop tempItemGroup: string = '其他';
  @Prop showTempAddNotice: boolean = false;
  // Import
  @Prop gears: GearItem[] = [];
  @Prop importGearIds: string[] = [];
  @Prop importGearCategory: string = '全部';
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
  onCreateTrip: () => void = (): void => {};
  onSaveTrip: () => void = (): void => {};
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
              .backgroundColor('#00000000')
              .onClick(() => {
                this.onAddGearFromImport();
              })
          }
          Button(this.sheetMode === SHEET_TEMP_ITEM ? '完成' : '关闭')
            .fontSize(13)
            .fontColor(TEXT_SECONDARY)
            .backgroundColor('#00000000')
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
            onSave: this.onSaveGear
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
        } else if (this.sheetMode === SHEET_EDIT_TRIP) {
          TripFormSheet({
            tripTitle: this.tripTitle,
            tripDate: this.tripDate,
            isEditMode: true,
            onTitleChange: this.onTripTitleChange,
            onDateChange: this.onTripDateChange,
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
            onConfirm: this.onAddTempItem
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
        }
      }
      .width('100%')
      .height('72%')
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })
      .backgroundColor(CARD_BG)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .translate({ y: this.sheetTranslateY })
    }
    .width('100%')
    .height('100%')
    .opacity(this.sheetOverlayOpacity)
    .backgroundColor('#26000000')
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
      return '生成清单';
    }
    return '';
  }
}
