import { common } from '@kit.AbilityKit';
import { curves, LengthMetrics } from '@kit.ArkUI';
import { sensor, vibrator } from '@kit.SensorServiceKit';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { ChecklistDetail } from '../components/ChecklistDetail';
import { GearPage } from '../components/GearPage';
import { HomePage } from '../components/HomePage';
import { ReviewPage } from '../components/ReviewPage';
import { TripCeremonyCard } from '../components/TripCeremonyCard';
import { EditItemPanel } from '../components/EditItemPanel';
import { EditGearPanel } from '../components/EditGearPanel';
import { GearFilterPanel } from '../components/GearFilterPanel';
import {
  ARROW_COLOR,
  BORDER_COLOR,
  CARD_BG,
  DANGER_COLOR,
  DIVIDER_COLOR,
  GEAR_SORT_GROUP,
  GEAR_SORT_PRICE,
  GEAR_SORT_TIME,
  GEAR_SORT_TRIP_COUNT,
  GEAR_SORT_VALUE,
  GEAR_SORT_WEIGHT,
  GROUP_HEADER_BG,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PRIMARY_COLOR,
  PROGRESS_END_COLOR,
  SHEET_EDIT_ITEM,
  SHEET_EDIT_TRIP,
  SHEET_GEAR,
  SHEET_GEAR_SORT,
  SHEET_GENERATE_TRIP,
  SHEET_IMPORT,
  SHEET_NONE,
  SHEET_TEMP_ITEM,
  SHEET_TRIP,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../constants/DesignTokens';
import {
  SPRING_GENERAL,
  SPRING_TAB,
  DURATION_NORMAL,
  PRESS_SCALE_BOUNCE,
  PRESS_SCALE_REST,
  PANEL_SCALE_START
} from '../constants/AnimationTokens';
import { ChecklistItem, DEFAULT_CATEGORIES, GearItem, makeId, normalizeNumber, TripChecklist } from '../models/PackModels';
import { PackStore } from '../services/PackStore';
import {
  numberOrZero as gsNumberOrZero,
  gearTripCount as gsGearTripCount,
  gearValueRatio as gsGearValueRatio,
  sortedGears as gsSortedGears,
  filterGears as gsFilterGears,
  normalizeGearCategories as gsNormalizeGearCategories,
  gearSortLabel as gsGearSortLabel,
  filteredGearGroups as gsFilteredGearGroups,
  filteredGearsByGroup as gsFilteredGearsByGroup,
  totalGearWeight as gsTotalGearWeight,
  totalGearPrice as gsTotalGearPrice,
  averageGearValueRatio as gsAverageGearValueRatio,
  heaviestGearText as gsHeaviestGearText,
  mostExpensiveGearText as gsMostExpensiveGearText,
  mostFrequentGearText as gsMostFrequentGearText,
  formatKg as gsFormatKg,
  gearStatsText as gsGearStatsText,
  gearById as gsGearById,
  presetCategories as gsPresetCategories,
  categoryTabs as gsCategoryTabs,
  uniqueGearIds as gsUniqueGearIds,
  importGearMetaText as gsImportGearMetaText,
  filteredImportGears as gsFilteredImportGears,
} from '../services/GearService';
import {
  checkedCount as csCheckedCount,
  progressPercent as csProgressPercent,
  progressValue as csProgressValue,
  progressTotal as csProgressTotal,
  progressText as csProgressText,
  checklistMetaText as csChecklistMetaText,
  isChecklistDone as csIsChecklistDone,
  activeChecklistCount as csActiveChecklistCount,
  homeStatusText as csHomeStatusText,
  parseTripDateAt as csParseTripDateAt,
  startOfDay as csStartOfDay,
  checklistDateAt as csChecklistDateAt,
  countdownText as csCountdownText,
  checklistItemWeight as csChecklistItemWeight,
  checklistItemPrice as csChecklistItemPrice,
  checklistTotalWeight as csChecklistTotalWeight,
  checklistCheckedWeight as csChecklistCheckedWeight,
  progressStartColor as csProgressStartColor,
  progressEndColor as csProgressEndColor,
  checklistGroups as csChecklistGroups,
  checklistItemsByGroup as csChecklistItemsByGroup,
  isGroupDone as csIsGroupDone,
  formatTripDate as csFormatTripDate,
  formatDateText as csFormatDateText,
  numberInputText as csNumberInputText,
  isChecklistItemInGear as csIsChecklistItemInGear,
  hasGearMarker as csHasGearMarker,
  checklistHasGear as csChecklistHasGear,
  countableGearIds as csCountableGearIds,
  addItemsToChecklist as csAddItemsToChecklist,
  latestChecklistHomeSubtitle as csLatestChecklistHomeSubtitle,
  matchingGearForChecklistItem as csMatchingGearForChecklistItem
} from '../services/ChecklistService';

@Entry
@Component
struct Index {
  private store: PackStore = new PackStore();

  @State private gears: GearItem[] = [];
  @State private checklists: TripChecklist[] = [];
  @State private categories: string[] = [];
  @State private selectedGearCategories: string[] = ['全部'];
  @State private gearFilterPanelExpanded: boolean = false;
  @State private currentTabIndex: number = 0;
  @State private contentBlur: number = 0;
  @State private contentScale: number = 1.0;
  private isClickSwitching: boolean = false;
  private tabsController: HdsTabsController = new HdsTabsController();
  private navPathStack: NavPathStack = new NavPathStack();
  private lastBackPressTime: number = 0;
  @State private gearSearchKeyword: string = '';
  @State private gearSortMode: string = GEAR_SORT_GROUP;
  @State private expandedGearId: string = '';
  @State private targetWeightGram: number = 10000;
  @State private multiSelectMode: boolean = false;
  @State private selectedMultiGearIds: string[] = [];
  @State private generateTripTitle: string = '';
  @State private selectedChecklistId: string = '';
  @State private sheetMode: string = SHEET_NONE;
  @State private editingGearId: string = '';
  @State private gearName: string = '';
  @State private gearCategory: string = '其他';
  @State private gearWeight: string = '';
  @State private gearPrice: string = '';
  @State private gearNote: string = '';
  @State private tripTitle: string = '';
  @State private tripDate: string = '';
  @State private tempItemName: string = '';
  @State private tempItemGroup: string = '其他';
  @State private importGearIds: string[] = [];
  @State private importGearCategory: string = '全部';
  @State private collapsedGroups: string[] = [];
  @State private returnToImportAfterGear: boolean = false;
  @State private errorText: string = '';
  @State private editingItemId: string = '';
  @State private editingItemName: string = '';
  @State private editingItemGroup: string = '其他';
  @State private editingItemWeight: string = '';
  @State private editingItemPrice: string = '';
  @State private showEditItemPanel: boolean = false;
  @State private showEditGearPanel: boolean = false;
  @State private showCompletionToast: boolean = false;
  @State private showTempAddNotice: boolean = false;
  @State private progressPulse: boolean = false;
  @State private reviewIndex: number = 0;
  @State private reviewFinished: boolean = false;
  @State private reviewDragX: number = 0;
  @State private highlightedItemId: string = '';
  @State private checklistRenderNonce: number = 0;
  // ===== 新建行程仪式感 =====
  @State private showTripCeremony: boolean = false;
  @State private ceremonyTripTitle: string = '';
  @State private ceremonyTripDate: string = '';

  private shakeListening: boolean = false;
  private lastShakeAt: number = 0;
  private shakeCallback = (data: sensor.AccelerometerResponse): void => {
    const strength = Math.abs(data.x) + Math.abs(data.y) + Math.abs(data.z);
    const now = Date.now();
    if (strength > 28 && now - this.lastShakeAt > 1200) {
      this.lastShakeAt = now;
      this.highlightRandomUncheckedItem();
    }
  };

  aboutToAppear(): void {
    this.loadAppData();
  }

  aboutToDisappear(): void {
    this.stopShakeListening();
  }

  private async loadAppData(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      this.gears = await this.store.getGears();
      this.checklists = await this.store.getChecklists();
      this.checklists.sort((a, b) => b.createdAt - a.createdAt);
      this.categories = await this.store.getCategories();
      this.targetWeightGram = await this.store.getGearTargetWeight();
      if (this.selectedChecklistId.length === 0 && this.checklists.length > 0) {
        this.selectedChecklistId = this.checklists[0].id;
      }
      if (this.categories.length > 0) {
        this.gearCategory = this.categories[0];
      }
      this.tempItemGroup = '其他';
    } catch (error) {
      this.errorText = '数据加载失败';
    }
  }

  private applyChecklistState(nextChecklists: TripChecklist[], animated: boolean = false): void {
    const updateState = (): void => {
      this.checklists = nextChecklists;
      this.checklistRenderNonce = this.checklistRenderNonce + 1;
    };
    if (animated) {
      this.getUIContext().animateTo({ duration: 260, curve: curves.springMotion(0.22, 0.82) }, updateState);
      return;
    }
    updateState();
  }

  private checklistItemRenderKey(item: ChecklistItem): string {
    return item.id + '|' + item.name + '|' + item.group + '|' +
      (item.checked ? '1' : '0') + '|' + this.numberKey(item.weight) + '|' +
      this.numberKey(item.price) + '|' + this.checklistRenderNonce.toString();
  }

  private numberKey(value: number | undefined): string {
    return value === undefined ? '' : value.toString();
  }

  private latestChecklist(): TripChecklist | undefined {
    if (this.checklists.length === 0) {
      return undefined;
    }
    return this.checklists[0];
  }

  private hasLatestChecklist(): boolean {
    return this.latestChecklist() !== undefined;
  }

  private latestChecklistTitle(): string {
    const latest = this.latestChecklist();
    if (latest === undefined) {
      return '';
    }
    return latest.title;
  }

  private latestChecklistSubtitle(): string {
    const latest = this.latestChecklist();
    if (latest === undefined) {
      return '';
    }
    return this.checklistMetaText(latest);
  }

  private latestChecklistProgress(): number {
    const latest = this.latestChecklist();
    if (latest === undefined) {
      return 0;
    }
    return this.progressPercent(latest);
  }

  private openLatestChecklist(): void {
    const latest = this.latestChecklist();
    if (latest !== undefined) {
      this.openChecklist(latest.id);
    }
  }

  private currentChecklist(): TripChecklist | undefined {
    for (let index = 0; index < this.checklists.length; index++) {
      if (this.checklists[index].id === this.selectedChecklistId) {
        return this.checklists[index];
      }
    }
    return undefined;
  }

  private hasCurrentChecklist(): boolean {
    return this.currentChecklist() !== undefined;
  }

  private currentChecklistTitle(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '';
    }
    return checklist.title;
  }

  private currentChecklistSubtitle(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '';
    }
    if (checklist.date === undefined || checklist.date.length === 0) {
      return '点击设置出发日期';
    }
    return checklist.date;
  }

  private currentChecklistProgress(): number {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return 0;
    }
    return this.progressPercent(checklist);
  }

  private currentChecklistProgressValue(): number {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return 0;
    }
    return this.progressValue(checklist);
  }

  private currentChecklistProgressTotal(): number {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return 1;
    }
    return this.progressTotal(checklist);
  }

  private currentChecklistProgressText(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '0/0';
    }
    return this.progressText(checklist);
  }

  private currentChecklistCountdownText(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '';
    }
    return this.countdownText(checklist);
  }

  private currentChecklistCheckedWeight(): number {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return 0;
    }
    return this.checklistCheckedWeight(checklist);
  }

  private currentChecklistItemCount(): number {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return 0;
    }
    return checklist.items.length;
  }

  private filteredGears(): GearItem[] {
    return gsFilterGears(this.gears, this.gearSearchKeyword, gsNormalizeGearCategories(this.selectedGearCategories), this.gearSortMode);
  }

  private normalizeGearCategories(categories: string[]): string[] {
    return gsNormalizeGearCategories(categories);
  }

  private openGearFilterPanel(): void {
    this.gearFilterPanelExpanded = true;
  }

  private closeGearFilterPanel(categories: string[]): void {
    this.selectedGearCategories = this.normalizeGearCategories(categories);
    this.gearFilterPanelExpanded = false;
  }

  private sortedGears(items: GearItem[]): GearItem[] {
    return gsSortedGears(items, this.gearSortMode);
  }

  private numberOrZero(value: number | undefined): number {
    return gsNumberOrZero(value);
  }

  private gearValueRatio(item: GearItem): number {
    return gsGearValueRatio(item);
  }

  private filteredGearGroups(): string[] {
    return gsFilteredGearGroups(this.gears, this.gearSearchKeyword, gsNormalizeGearCategories(this.selectedGearCategories), this.gearSortMode);
  }

  private filteredGearsByGroup(group: string): GearItem[] {
    return gsFilteredGearsByGroup(this.gears, this.gearSearchKeyword, gsNormalizeGearCategories(this.selectedGearCategories), this.gearSortMode, group);
  }

  private gearSortLabel(): string {
    return gsGearSortLabel(this.gearSortMode);
  }

  private gearTripCount(item: GearItem): number {
    return gsGearTripCount(item);
  }

  private gearGroupCount(group: string): number {
    return this.filteredGearsByGroup(group).length;
  }

  private gearStatsText(): string {
    return gsGearStatsText(this.gears);
  }

  private totalGearWeight(): number {
    return gsTotalGearWeight(this.gears);
  }

  private totalGearPrice(): number {
    return gsTotalGearPrice(this.gears);
  }

  private averageGearValueRatio(): number {
    return gsAverageGearValueRatio(this.gears);
  }

  private heaviestGearText(): string {
    return gsHeaviestGearText(this.gears);
  }

  private mostExpensiveGearText(): string {
    return gsMostExpensiveGearText(this.gears);
  }

  private mostFrequentGearText(): string {
    return gsMostFrequentGearText(this.gears);
  }

  private formatKg(weightGram: number): string {
    return gsFormatKg(weightGram);
  }

  private categoryTabs(): string[] {
    return gsCategoryTabs(this.categories);
  }

  private presetCategories(): string[] {
    return gsPresetCategories(this.categories);
  }

  private checklistGroups(): string[] {
    return csChecklistGroups(this.currentChecklist());
  }

  private checklistItemsByGroup(group: string): ChecklistItem[] {
    return csChecklistItemsByGroup(this.currentChecklist(), group);
  }

  private groupItemCount(group: string): number {
    return this.checklistItemsByGroup(group).length;
  }

  private isGroupDone(group: string): boolean {
    return csIsGroupDone(this.currentChecklist(), group);
  }

  private isGroupCollapsed(group: string): boolean {
    return this.collapsedGroups.indexOf(group) >= 0;
  }

  private toggleGroup(group: string): void {
    const nextGroups: string[] = [];
    let exists = false;
    for (let index = 0; index < this.collapsedGroups.length; index++) {
      if (this.collapsedGroups[index] === group) {
        exists = true;
      } else {
        nextGroups.push(this.collapsedGroups[index]);
      }
    }
    if (!exists) {
      nextGroups.push(group);
    }
    this.collapsedGroups = nextGroups;
  }

  private checkedCount(checklist: TripChecklist): number {
    return csCheckedCount(checklist);
  }

  private progressPercent(checklist: TripChecklist): number {
    return csProgressPercent(checklist);
  }

  private progressValue(checklist: TripChecklist): number {
    return csProgressValue(checklist);
  }

  private progressTotal(checklist: TripChecklist): number {
    return csProgressTotal(checklist);
  }

  private progressText(checklist: TripChecklist): string {
    return csProgressText(checklist);
  }

  private checklistMetaText(checklist: TripChecklist): string {
    return csChecklistMetaText(checklist);
  }

  private homeStatusText(): string {
    return csHomeStatusText(this.checklists);
  }

  private isChecklistDone(checklist: TripChecklist): boolean {
    return csIsChecklistDone(checklist);
  }

  private isCurrentChecklistDone(): boolean {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return false;
    }
    return csIsChecklistDone(checklist);
  }

  private activeChecklistCount(): number {
    return csActiveChecklistCount(this.checklists);
  }

  private parseTripDateAt(text: string): number | undefined {
    return csParseTripDateAt(text);
  }

  private startOfDay(date: Date): number {
    return csStartOfDay(date);
  }

  private checklistDateAt(checklist: TripChecklist): number | undefined {
    return csChecklistDateAt(checklist);
  }

  private countdownText(checklist: TripChecklist): string {
    return csCountdownText(checklist);
  }

  private checklistTotalWeight(checklist: TripChecklist): number {
    return csChecklistTotalWeight(checklist, this.gears);
  }

  private checklistCheckedWeight(checklist: TripChecklist): number {
    return csChecklistCheckedWeight(checklist, this.gears);
  }

  private progressStartColor(percent: number): string {
    return csProgressStartColor(percent);
  }

  private progressEndColor(percent: number): string {
    return csProgressEndColor(percent);
  }

  private gearById(id: string): GearItem | undefined {
    return gsGearById(this.gears, id);
  }

  private checklistItemWeight(item: ChecklistItem): number | undefined {
    return csChecklistItemWeight(item, this.gears);
  }

  private checklistItemPrice(item: ChecklistItem): number | undefined {
    return csChecklistItemPrice(item, this.gears);
  }

  private numberInputText(value: number | undefined): string {
    return csNumberInputText(value);
  }

  private latestChecklistHomeSubtitle(): string {
    return csLatestChecklistHomeSubtitle(this.latestChecklist(), this.gears);
  }

  private resetGearForm(): void {
    this.editingGearId = '';
    this.gearName = '';
    this.gearWeight = '';
    this.gearPrice = '';
    this.gearNote = '';
    this.gearCategory = '其他';
  }

  private openAddGear(): void {
    this.resetGearForm();
    this.returnToImportAfterGear = false;
    this.sheetMode = SHEET_GEAR;
  }

  private openAddGearFromImport(): void {
    this.resetGearForm();
    this.returnToImportAfterGear = true;
    this.sheetMode = SHEET_GEAR;
  }

  private openEditGear(item: GearItem): void {
    this.editingGearId = item.id;
    this.gearName = item.name;
    this.gearCategory = item.category;
    this.gearWeight = item.weight === undefined ? '' : item.weight.toString();
    this.gearPrice = item.price === undefined ? '' : item.price.toString();
    this.gearNote = item.note === undefined ? '' : item.note;
    this.errorText = '';
    this.showEditGearPanel = true;
  }

  private closeEditGearPanel(): void {
    this.showEditGearPanel = false;
    this.resetGearForm();
    this.errorText = '';
  }

  private async saveGear(): Promise<void> {
    const name = this.gearName.trim();
    const category = this.gearCategory.trim().length === 0 ? '其他' : this.gearCategory.trim();
    if (name.length === 0) {
      this.errorText = '装备名称不能为空';
      return;
    }

    const nextGears: GearItem[] = [];
    let updated = false;
    for (let index = 0; index < this.gears.length; index++) {
      const item = this.gears[index];
      if (item.id === this.editingGearId) {
        const edited: GearItem = {
          id: item.id,
          name: name,
          category: category,
          weight: normalizeNumber(this.gearWeight),
          price: normalizeNumber(this.gearPrice),
          note: this.gearNote.trim(),
          tripCount: item.tripCount,
          createdAt: item.createdAt
        };
        nextGears.push(edited);
        updated = true;
      } else {
        nextGears.push(item);
      }
    }

    if (!updated) {
      const created: GearItem = {
        id: makeId('gear'),
        name: name,
        category: category,
        weight: normalizeNumber(this.gearWeight),
        price: normalizeNumber(this.gearPrice),
        note: this.gearNote.trim(),
        tripCount: 0,
        createdAt: Date.now()
      };
      nextGears.unshift(created);
    }

    await this.store.saveGears(nextGears);
    this.gears = nextGears;
    await this.ensureCategory(category);
    if (this.returnToImportAfterGear) {
      this.returnToImportAfterGear = false;
      this.errorText = '';
      this.sheetMode = SHEET_IMPORT;
    } else if (this.showEditGearPanel) {
      this.closeEditGearPanel();
    } else {
      this.closeSheet();
    }
  }

  private async ensureCategory(category: string): Promise<void> {
    if (this.categories.indexOf(category) >= 0) {
      return;
    }
    const nextCategories: string[] = [];
    for (let index = 0; index < this.categories.length; index++) {
      nextCategories.push(this.categories[index]);
    }
    nextCategories.push(category);
    await this.store.saveCategories(nextCategories);
    this.categories = nextCategories;
  }

  private async deleteGear(id: string): Promise<void> {
    const nextGears = this.gears.filter((item: GearItem) => item.id !== id);
    await this.store.saveGears(nextGears);
    this.gears = nextGears;
    if (this.expandedGearId === id) {
      this.expandedGearId = '';
    }
  }

  private confirmDeleteGear(item: GearItem): void {
    AlertDialog.show({
      message: '确定删除"' + item.name + '"？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定',
        fontColor: DANGER_COLOR,
        action: () => {
          this.deleteGear(item.id);
        }
      }
    });
  }

  private toggleGearExpanded(id: string): void {
    this.expandedGearId = this.expandedGearId === id ? '' : id;
  }

  private enterGearMultiSelect(id: string): void {
    this.multiSelectMode = true;
    this.expandedGearId = '';
    if (this.selectedMultiGearIds.indexOf(id) < 0) {
      this.selectedMultiGearIds = [id];
    }
  }

  private cancelGearMultiSelect(): void {
    this.multiSelectMode = false;
    this.selectedMultiGearIds = [];
    this.generateTripTitle = '';
  }

  private hasMultiGearSelection(id: string): boolean {
    return this.selectedMultiGearIds.indexOf(id) >= 0;
  }

  private toggleMultiGearSelection(id: string): void {
    const nextIds: string[] = [];
    let exists = false;
    for (let index = 0; index < this.selectedMultiGearIds.length; index++) {
      if (this.selectedMultiGearIds[index] === id) {
        exists = true;
      } else {
        nextIds.push(this.selectedMultiGearIds[index]);
      }
    }
    if (!exists) {
      nextIds.push(id);
    }
    this.selectedMultiGearIds = nextIds;
  }

  private openGenerateTripSheet(): void {
    if (this.selectedMultiGearIds.length === 0) {
      this.showToastMessage('请选择装备');
      return;
    }
    this.generateTripTitle = '';
    this.sheetMode = SHEET_GENERATE_TRIP;
  }

  private uniqueGearIds(ids: string[]): string[] {
    return gsUniqueGearIds(ids);
  }

  private checklistHasGear(checklist: TripChecklist, gearId: string): boolean {
    return csChecklistHasGear(checklist, gearId);
  }

  private countableGearIds(checklist: TripChecklist, gearIds: string[]): string[] {
    return csCountableGearIds(checklist, gearIds);
  }

  private async incrementGearTripCounts(gearIds: string[]): Promise<void> {
    const dedupedIds = this.uniqueGearIds(gearIds);
    if (dedupedIds.length === 0) {
      return;
    }
    const nextGears: GearItem[] = [];
    for (let index = 0; index < this.gears.length; index++) {
      const gear = this.gears[index];
      if (dedupedIds.indexOf(gear.id) >= 0) {
        const updated: GearItem = {
          id: gear.id,
          name: gear.name,
          category: gear.category,
          weight: gear.weight,
          price: gear.price,
          note: gear.note,
          tripCount: this.gearTripCount(gear) + 1,
          createdAt: gear.createdAt
        };
        nextGears.push(updated);
      } else {
        nextGears.push(gear);
      }
    }
    await this.store.saveGears(nextGears);
    this.gears = nextGears;
  }

  private isChecklistItemInGear(item: ChecklistItem): boolean {
    return csIsChecklistItemInGear(item);
  }

  private hasGearMarker(item: ChecklistItem): boolean {
    return csHasGearMarker(item);
  }

  private matchingGearForChecklistItem(item: ChecklistItem): GearItem | undefined {
    return csMatchingGearForChecklistItem(item, this.gears);
  }

  private openTripSheet(): void {
    this.tripTitle = '';
    this.tripDate = '';
    this.sheetMode = SHEET_TRIP;
  }

  // ===== 新建行程仪式感方法 =====
  private startTripCeremony(): void {
    this.ceremonyTripTitle = '';
    this.ceremonyTripDate = '';
    this.errorText = '';
    this.showTripCeremony = true;
  }

  private async finishTripCeremony(): Promise<void> {
    this.tripTitle = this.ceremonyTripTitle;
    this.tripDate = this.ceremonyTripDate;
    await this.createChecklist();
    this.showTripCeremony = false;
  }

  private dismissTripCeremony(): void {
    this.showTripCeremony = false;
  }

  private async createChecklist(): Promise<void> {
    const title = this.tripTitle.trim();
    if (title.length === 0) {
      this.errorText = '行程名称不能为空';
      return;
    }
    const created: TripChecklist = {
      id: makeId('trip'),
      title: title,
      date: this.tripDate.trim(),
      dateAt: this.parseTripDateAt(this.tripDate),
      items: [],
      createdAt: Date.now()
    };
    const nextChecklists: TripChecklist[] = [created];
    for (let index = 0; index < this.checklists.length; index++) {
      nextChecklists.push(this.checklists[index]);
    }
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    this.selectedChecklistId = created.id;
    this.closeSheet();
    this.startShakeListening();
    this.navPathStack.pushPathByName('ChecklistDetail', undefined, true);
  }

  private openChecklist(checklistId: string): void {
    this.selectedChecklistId = checklistId;
    this.collapsedGroups = [];
    this.startShakeListening();
    this.navPathStack.pushPathByName('ChecklistDetail', undefined, true);
  }

  private returnToHome(): void {
    this.stopShakeListening();
    this.tabsController.changeIndex(0);
    if (this.navPathStack.size() > 0) {
      this.navPathStack.pop(true);
    }
  }

  private openReviewMode(): void {
    if (this.currentChecklistItemCount() === 0) {
      this.showToastMessage('暂无可核查物品');
      return;
    }
    this.stopShakeListening();
    this.reviewIndex = 0;
    this.reviewFinished = false;
    this.reviewDragX = 0;
    this.navPathStack.pushPathByName('ReviewPage', undefined, true);
  }

  private exitReviewMode(): void {
    this.reviewDragX = 0;
    this.startShakeListening();
    if (this.navPathStack.size() > 0) {
      this.navPathStack.pop(true);
    }
  }

  private startShakeListening(): void {
    if (this.shakeListening) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, this.shakeCallback);
      this.shakeListening = true;
    } catch (error) {
      this.shakeListening = false;
    }
  }

  private stopShakeListening(): void {
    if (!this.shakeListening) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER, this.shakeCallback);
    } catch (error) {
    }
    this.shakeListening = false;
  }

  private highlightRandomUncheckedItem(): void {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const candidates: ChecklistItem[] = [];
    for (let index = 0; index < checklist.items.length; index++) {
      if (!checklist.items[index].checked) {
        candidates.push(checklist.items[index]);
      }
    }
    if (candidates.length === 0) {
      return;
    }
    const pick = candidates[Math.floor(Math.random() * candidates.length)];
    this.highlightedItemId = pick.id;
    this.showToastMessage('检查一下：' + pick.name);
    setTimeout(() => {
      if (this.highlightedItemId === pick.id) {
        this.highlightedItemId = '';
      }
    }, 1200);
  }

  private async deleteChecklist(checklistId: string): Promise<void> {
    const nextChecklists = this.checklists.filter((item: TripChecklist) => item.id !== checklistId);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    if (this.selectedChecklistId === checklistId) {
      this.selectedChecklistId = nextChecklists.length === 0 ? '' : nextChecklists[0].id;
    }
  }

  private confirmDeleteChecklist(item: TripChecklist): void {
    AlertDialog.show({
      message: '确定删除行程"' + item.title + '"？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定',
        fontColor: DANGER_COLOR,
        action: () => {
          this.deleteChecklist(item.id);
        }
      }
    });
  }

  private openTempItemSheet(): void {
    this.tempItemName = '';
    this.tempItemGroup = '其他';
    this.showTempAddNotice = false;
    this.sheetMode = SHEET_TEMP_ITEM;
  }

  private openEditItemSheet(item: ChecklistItem): void {
    this.editingItemId = item.id;
    this.editingItemName = item.name;
    this.editingItemGroup = item.group;
    this.editingItemWeight = this.numberInputText(this.checklistItemWeight(item));
    this.editingItemPrice = this.numberInputText(this.checklistItemPrice(item));
    this.errorText = '';
    this.showEditItemPanel = true;
  }

  private closeEditItemPanel(): void {
    this.showEditItemPanel = false;
    this.editingItemId = '';
    this.editingItemName = '';
    this.editingItemGroup = '其他';
    this.editingItemWeight = '';
    this.editingItemPrice = '';
    this.errorText = '';
  }

  private async saveChecklistItemToGear(item: ChecklistItem): Promise<void> {
    if (this.hasGearMarker(item)) {
      this.showToastMessage('已在装备库中');
      return;
    }

    const name = item.name.trim();
    const group = item.group.trim().length === 0 ? '其他' : item.group.trim();
    if (name.length === 0) {
      this.showToastMessage('物品名称为空');
      return;
    }

    const matchedGear = this.matchingGearForChecklistItem(item);
    if (matchedGear !== undefined) {
      await this.updateChecklistItem(item.id, name, group, matchedGear.id, true);
      this.showToastMessage('已在装备库中');
      return;
    }

    const created: GearItem = {
      id: makeId('gear'),
      name: name,
      category: group,
      weight: item.weight,
      price: item.price,
      tripCount: 0,
      createdAt: Date.now()
    };
    const nextGears: GearItem[] = [created];
    for (let index = 0; index < this.gears.length; index++) {
      nextGears.push(this.gears[index]);
    }
    await this.store.saveGears(nextGears);
    this.gears = nextGears;
    await this.ensureCategory(group);
    await this.updateChecklistItem(item.id, name, group, created.id, true);
    this.showToastMessage('已存入装备库');
    await this.triggerLightVibration();
  }

  private openEditTripSheet(): void {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    this.tripTitle = checklist.title;
    this.tripDate = checklist.date === undefined ? '' : checklist.date;
    this.sheetMode = SHEET_EDIT_TRIP;
  }

  private async saveTripInfo(): Promise<void> {
    const checklist = this.currentChecklist();
    const title = this.tripTitle.trim();
    if (checklist === undefined || title.length === 0) {
      this.errorText = '行程名称不能为空';
      return;
    }
    await this.updateChecklistInfo(checklist.id, title, this.tripDate.trim(), this.parseTripDateAt(this.tripDate));
    this.closeSheet();
  }

  private async updateChecklistInfo(checklistId: string, title: string, date: string, dateAt: number | undefined): Promise<void> {
    const nextChecklists: TripChecklist[] = [];
    for (let index = 0; index < this.checklists.length; index++) {
      const source = this.checklists[index];
      if (source.id === checklistId) {
        const updated: TripChecklist = {
          id: source.id,
          title: title,
          date: date,
          dateAt: dateAt,
          items: source.items,
          createdAt: source.createdAt
        };
        nextChecklists.push(updated);
      } else {
        nextChecklists.push(source);
      }
    }
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  private openDatePicker(): void {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    DatePickerDialog.show({
      selected: new Date(),
      lunar: false,
      showTime: false,
      onDateAccept: (date: Date) => {
        this.updateChecklistInfo(checklist.id, checklist.title, this.formatTripDate(date), this.startOfDay(date));
      }
    });
  }

  private formatTripDate(date: Date): string {
    return csFormatTripDate(date);
  }

  private formatDateText(timestamp: number): string {
    return csFormatDateText(timestamp);
  }

  private async addTempItem(): Promise<void> {
    const checklist = this.currentChecklist();
    const name = this.tempItemName.trim();
    const group = this.tempItemGroup.trim().length === 0 ? '其他' : this.tempItemGroup.trim();
    if (checklist === undefined || name.length === 0) {
      this.errorText = '物品名称不能为空';
      return;
    }
    const item: ChecklistItem = {
      id: makeId('item'),
      name: name,
      group: group,
      checked: false
    };
    const nextChecklists = this.addItemsToChecklist(checklist.id, [item]);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    await this.ensureCategory(group);
    this.tempItemName = '';
    this.showTempAddNotice = true;
    this.errorText = '';
    setTimeout(() => {
      if (this.sheetMode === SHEET_TEMP_ITEM) {
        this.showTempAddNotice = false;
      }
    }, 500);
  }

  private currentChecklistItemById(itemId: string): ChecklistItem | undefined {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return undefined;
    }
    for (let index = 0; index < checklist.items.length; index++) {
      if (checklist.items[index].id === itemId) {
        return checklist.items[index];
      }
    }
    return undefined;
  }

  private isChecklistItemChecked(itemId: string): boolean {
    const item = this.currentChecklistItemById(itemId);
    if (item === undefined) {
      return false;
    }
    return item.checked;
  }

  private async saveEditedItem(): Promise<void> {
    const name = this.editingItemName.trim();
    const group = this.editingItemGroup.trim().length === 0 ? '其他' : this.editingItemGroup.trim();
    const weight = normalizeNumber(this.editingItemWeight);
    const price = normalizeNumber(this.editingItemPrice);
    if (this.editingItemId.length === 0 || name.length === 0) {
      this.errorText = '物品名称不能为空';
      return;
    }
    await this.updateChecklistItem(this.editingItemId, name, group, undefined, false, weight, price, true);
    await this.ensureCategory(group);
    this.closeEditItemPanel();
  }

  private async updateChecklistItem(itemId: string, name: string, group: string, fromGearId: string | undefined,
    updateGearId: boolean, weight: number | undefined = undefined, price: number | undefined = undefined,
    updateMetrics: boolean = false): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists: TripChecklist[] = [];
    for (let index = 0; index < this.checklists.length; index++) {
      const source = this.checklists[index];
      if (source.id === checklist.id) {
        const nextItems: ChecklistItem[] = [];
        for (let itemIndex = 0; itemIndex < source.items.length; itemIndex++) {
          const item = source.items[itemIndex];
          if (item.id === itemId) {
            const updatedItem: ChecklistItem = {
              id: item.id,
              name: name,
              group: group,
              checked: item.checked,
              weight: updateMetrics ? weight : item.weight,
              price: updateMetrics ? price : item.price,
              fromGearId: updateGearId ? fromGearId : item.fromGearId
            };
            nextItems.push(updatedItem);
          } else {
            nextItems.push(item);
          }
        }
        const updatedChecklist: TripChecklist = {
          id: source.id,
          title: source.title,
          date: source.date,
          dateAt: source.dateAt,
          items: nextItems,
          createdAt: source.createdAt
        };
        nextChecklists.push(updatedChecklist);
      } else {
        nextChecklists.push(source);
      }
    }
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  private openImportSheet(): void {
    this.importGearIds = [];
    this.importGearCategory = '全部';
    this.sheetMode = SHEET_IMPORT;
  }

  private filteredImportGears(): GearItem[] {
    return gsFilteredImportGears(this.gears, this.importGearCategory);
  }

  private importGearMetaText(item: GearItem): string {
    return gsImportGearMetaText(item);
  }

  private hasImportSelection(id: string): boolean {
    return this.importGearIds.indexOf(id) >= 0;
  }

  private toggleImportSelection(id: string, checked: boolean): void {
    const nextIds: string[] = [];
    for (let index = 0; index < this.importGearIds.length; index++) {
      if (this.importGearIds[index] !== id) {
        nextIds.push(this.importGearIds[index]);
      }
    }
    if (checked) {
      nextIds.push(id);
    }
    this.importGearIds = nextIds;
  }

  private async importSelectedGear(): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined || this.importGearIds.length === 0) {
      this.errorText = '请选择装备';
      return;
    }
    const items: ChecklistItem[] = [];
    const selectedGearIds: string[] = [];
    for (let gearIndex = 0; gearIndex < this.gears.length; gearIndex++) {
      const gear = this.gears[gearIndex];
      if (this.importGearIds.indexOf(gear.id) >= 0) {
        selectedGearIds.push(gear.id);
        const item: ChecklistItem = {
          id: makeId('item'),
          name: gear.name,
          group: gear.category,
          checked: false,
          weight: gear.weight,
          price: gear.price,
          fromGearId: gear.id
        };
        items.push(item);
      }
    }
    const countGearIds = this.countableGearIds(checklist, selectedGearIds);
    const nextChecklists = this.addItemsToChecklist(checklist.id, items);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    await this.incrementGearTripCounts(countGearIds);
    this.closeSheet();
  }

  private async generateChecklistFromSelectedGears(): Promise<void> {
    const title = this.generateTripTitle.trim();
    if (title.length === 0) {
      this.errorText = '行程名称不能为空';
      return;
    }
    const uniqueIds = this.uniqueGearIds(this.selectedMultiGearIds);
    const items: ChecklistItem[] = [];
    for (let gearIndex = 0; gearIndex < this.gears.length; gearIndex++) {
      const gear = this.gears[gearIndex];
      if (uniqueIds.indexOf(gear.id) >= 0) {
        const item: ChecklistItem = {
          id: makeId('item'),
          name: gear.name,
          group: gear.category,
          checked: false,
          weight: gear.weight,
          price: gear.price,
          fromGearId: gear.id
        };
        items.push(item);
      }
    }
    const created: TripChecklist = {
      id: makeId('trip'),
      title: title,
      items: items,
      createdAt: Date.now()
    };
    const nextChecklists: TripChecklist[] = [created];
    for (let index = 0; index < this.checklists.length; index++) {
      nextChecklists.push(this.checklists[index]);
    }
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    await this.incrementGearTripCounts(uniqueIds);
    this.selectedChecklistId = created.id;
    this.cancelGearMultiSelect();
    this.closeSheet();
    this.startShakeListening();
    this.navPathStack.pushPathByName('ChecklistDetail', undefined, true);
  }

  private addItemsToChecklist(checklistId: string, items: ChecklistItem[]): TripChecklist[] {
    return csAddItemsToChecklist(this.checklists, checklistId, items);
  }

  private currentReviewItem(): ChecklistItem | undefined {
    const checklist = this.currentChecklist();
    if (checklist === undefined || this.reviewIndex < 0 || this.reviewIndex >= checklist.items.length) {
      return undefined;
    }
    return checklist.items[this.reviewIndex];
  }

  private currentReviewItemName(): string {
    const item = this.currentReviewItem();
    return item === undefined ? '' : item.name;
  }

  private currentReviewItemGroup(): string {
    const item = this.currentReviewItem();
    return item === undefined ? '' : item.group;
  }

  private reviewSummaryText(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '';
    }
    return '已带 ' + this.checkedCount(checklist).toString() + ' 件，未带 ' +
      (checklist.items.length - this.checkedCount(checklist)).toString() + ' 件';
  }

  private async markReviewItem(checked: boolean): Promise<void> {
    const item = this.currentReviewItem();
    const checklist = this.currentChecklist();
    if (item === undefined || checklist === undefined) {
      this.reviewFinished = true;
      return;
    }
    await this.setChecklistItemChecked(item.id, checked);
    const nextIndex = this.reviewIndex + 1;
    if (nextIndex >= checklist.items.length) {
      this.reviewFinished = true;
    } else {
      this.reviewIndex = nextIndex;
    }
    this.reviewDragX = 0;
  }

  private async setChecklistItemChecked(itemId: string, checked: boolean): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const beforeCheckedCount = this.checkedCount(checklist);
    const beforeTotal = checklist.items.length;
    const nextChecklists: TripChecklist[] = [];
    let updatedCurrent: TripChecklist | undefined = undefined;
    for (let index = 0; index < this.checklists.length; index++) {
      const source = this.checklists[index];
      if (source.id === checklist.id) {
        const nextItems: ChecklistItem[] = [];
        for (let itemIndex = 0; itemIndex < source.items.length; itemIndex++) {
          const item = source.items[itemIndex];
          if (item.id === itemId) {
            const updatedItem: ChecklistItem = {
              id: item.id,
              name: item.name,
              group: item.group,
              checked: checked,
              weight: item.weight,
              price: item.price,
              fromGearId: item.fromGearId
            };
            nextItems.push(updatedItem);
          } else {
            nextItems.push(item);
          }
        }
        const updatedChecklist: TripChecklist = {
          id: source.id,
          title: source.title,
          date: source.date,
          dateAt: source.dateAt,
          items: nextItems,
          createdAt: source.createdAt
        };
        updatedCurrent = updatedChecklist;
        nextChecklists.push(updatedChecklist);
      } else {
        nextChecklists.push(source);
      }
    }
    this.applyChecklistState(nextChecklists, true);
    await this.store.saveChecklists(nextChecklists);
    if (updatedCurrent !== undefined && beforeTotal > 0 &&
      beforeCheckedCount === beforeTotal - 1 && this.checkedCount(updatedCurrent) === beforeTotal) {
      this.showAchievement();
    }
  }

  private async toggleChecklistItem(itemId: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const beforeCheckedCount = this.checkedCount(checklist);
    const beforeTotal = checklist.items.length;
    const nextChecklists: TripChecklist[] = [];
    let updatedCurrent: TripChecklist | undefined = undefined;
    for (let index = 0; index < this.checklists.length; index++) {
      const source = this.checklists[index];
      if (source.id === checklist.id) {
        const nextItems: ChecklistItem[] = [];
        for (let itemIndex = 0; itemIndex < source.items.length; itemIndex++) {
          const item = source.items[itemIndex];
          if (item.id === itemId) {
            const updatedItem: ChecklistItem = {
              id: item.id,
              name: item.name,
              group: item.group,
              checked: !item.checked,
              weight: item.weight,
              price: item.price,
              fromGearId: item.fromGearId
            };
            nextItems.push(updatedItem);
          } else {
            nextItems.push(item);
          }
        }
        const updatedChecklist: TripChecklist = {
          id: source.id,
          title: source.title,
          date: source.date,
          dateAt: source.dateAt,
          items: nextItems,
          createdAt: source.createdAt
        };
        updatedCurrent = updatedChecklist;
        nextChecklists.push(updatedChecklist);
      } else {
        nextChecklists.push(source);
      }
    }
    this.highlightedItemId = itemId;
    this.applyChecklistState(nextChecklists, true);
    await this.store.saveChecklists(nextChecklists);
    setTimeout(() => {
      if (this.highlightedItemId === itemId) {
        this.highlightedItemId = '';
      }
    }, 600);
    if (updatedCurrent !== undefined && beforeTotal > 0 &&
      beforeCheckedCount === beforeTotal - 1 && this.checkedCount(updatedCurrent) === beforeTotal) {
      this.showAchievement();
    }
  }

  private showAchievement(): void {
    this.showCompletionToast = true;
    this.progressPulse = true;
    this.showToastMessage('全部就绪，出发吧！', 2000);
    this.triggerLightVibration();
    setTimeout(() => {
      this.showCompletionToast = false;
    }, 2000);
    setTimeout(() => {
      this.progressPulse = false;
    }, 900);
  }

  private showToastMessage(message: string, duration: number = 1500): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
    } catch (error) {
    }
  }

  private async triggerLightVibration(): Promise<void> {
    try {
      await vibrator.startVibration({ type: 'time', duration: 50 }, { usage: 'touch' });
    } catch (error) {
    }
  }

  private async deleteChecklistItem(itemId: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists: TripChecklist[] = [];
    for (let index = 0; index < this.checklists.length; index++) {
      const source = this.checklists[index];
      if (source.id === checklist.id) {
        const nextItems = source.items.filter((item: ChecklistItem) => item.id !== itemId);
        const updatedChecklist: TripChecklist = {
          id: source.id,
          title: source.title,
          date: source.date,
          dateAt: source.dateAt,
          items: nextItems,
          createdAt: source.createdAt
        };
        nextChecklists.push(updatedChecklist);
      } else {
        nextChecklists.push(source);
      }
    }
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  private closeSheet(): void {
    this.errorText = '';
    this.returnToImportAfterGear = false;
    this.editingItemId = '';
    this.showTempAddNotice = false;
    this.getUIContext().animateTo({
      duration: 250, curve: Curve.EaseOut
    }, () => {
      this.sheetMode = SHEET_NONE;
    });
  }

  @Builder
  NavDestinationMap(name: string, param: Object) {
    if (name === 'ChecklistDetail') {
      NavDestination() {
        ChecklistDetail({
          checklists: this.checklists,
          gears: this.gears,
          selectedChecklistId: this.selectedChecklistId,
          collapsedGroups: this.collapsedGroups,
          highlightedItemId: this.highlightedItemId,
          progressPulse: this.progressPulse,
          checklistRenderNonce: this.checklistRenderNonce,
          onReturnHome: () => {
            this.returnToHome();
          },
          onOpenEditTrip: () => {
            this.openEditTripSheet();
          },
          onOpenDatePicker: () => {
            this.openDatePicker();
          },
          onOpenTempItem: () => {
            this.openTempItemSheet();
          },
          onOpenImport: () => {
            this.openImportSheet();
          },
          onOpenReview: () => {
            this.openReviewMode();
          },
          onToggleGroup: (group: string) => {
            this.toggleGroup(group);
          },
          onOpenEditItem: (item: ChecklistItem) => {
            this.openEditItemSheet(item);
          },
          onToggleChecklistItem: (itemId: string) => {
            this.toggleChecklistItem(itemId);
          },
          onSaveChecklistItemToGear: (item: ChecklistItem) => {
            this.saveChecklistItemToGear(item);
          },
          onDeleteChecklistItem: (itemId: string) => {
            this.deleteChecklistItem(itemId);
          }
        })
      }
      .hideTitleBar(true)
      .width('100%')
      .height('100%')
      .transition(TransitionEffect.OPACITY)
    } else if (name === 'ReviewPage') {
      NavDestination() {
        ReviewPage({
          checklists: this.checklists,
          selectedChecklistId: this.selectedChecklistId,
          reviewIndex: this.reviewIndex,
          reviewFinished: this.reviewFinished,
          reviewDragX: this.reviewDragX,
          onUpdateDragX: (value: number) => {
            this.reviewDragX = value;
          },
          onMarkReviewItem: (checked: boolean) => {
            this.markReviewItem(checked);
          },
          onExitReviewMode: () => {
            this.exitReviewMode();
          }
        })
      }
      .hideTitleBar(true)
      .width('100%')
      .height('100%')
    }
  }

  onBackPress(): boolean | void {
    // 仪式卡片展开时，返回键关闭卡片
    if (this.showTripCeremony) {
      this.dismissTripCeremony();
      return true;
    }
    if (this.navPathStack.size() > 0) {
      if (this.navPathStack.size() === 1) {
        this.stopShakeListening();
      }
      return false;
    }
    const now = Date.now();
    if (now - this.lastBackPressTime < 2000) {
      return false;
    }
    this.lastBackPressTime = now;
    this.showToastMessage('再滑一次退出应用');
    return true;
  }

  private triggerBlurPulse(targetIndex: number): void {
    this.isClickSwitching = true;
    // 立即更新 tabIndex 让 TabBar 指示器同步响应
    this.currentTabIndex = targetIndex;
    // 散焦 + 按压 + 切换一气呵成（50ms 下沉）
    this.getUIContext().animateTo({
      duration: 50, curve: Curve.EaseOut
    }, () => {
      this.contentBlur = 6;
      this.contentScale = 0.96;
    });
    // 极短延迟后切换内容 + 弹回
    setTimeout(() => {
      this.tabsController.changeIndex(targetIndex);
      this.getUIContext().animateTo({
        duration: 120, curve: Curve.EaseOut
      }, () => {
        this.contentBlur = 0;
      });
      this.getUIContext().animateTo({
        curve: curves.springMotion(0.3, 0.82)
      }, () => {
        this.contentScale = 1.0;
      });
      setTimeout(() => { this.isClickSwitching = false; }, 200);
    }, 50);
  }

  @Builder
  customTabBar(index: number, icon: Resource, label: string) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentTabIndex === index ? PRIMARY_COLOR : TEXT_TERTIARY])
      Text(label)
        .fontSize(11)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? PRIMARY_COLOR : TEXT_TERTIARY)
        .margin({ top: 2 })
      // 液态指示器小横条
      Row()
        .width(this.currentTabIndex === index ? 18 : 0)
        .height(3)
        .borderRadius(1.5)
        .backgroundColor(PRIMARY_COLOR)
        .margin({ top: 3 })
        .opacity(this.currentTabIndex === index ? 1.0 : 0)
    }
    .justifyContent(FlexAlign.Center)
    .width(64)
    .height(48)
    .scale({
      x: this.currentTabIndex === index ? 1.0 : 0.92,
      y: this.currentTabIndex === index ? 1.0 : 0.92
    })
    .opacity(this.currentTabIndex === index ? 1.0 : 0.6)
    .animation({ duration: 0, curve: SPRING_TAB() })
    .onClick(() => {
      if (this.currentTabIndex !== index) {
        this.triggerBlurPulse(index);
      }
    })
  }

  build() {
    Navigation(this.navPathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            HomePage({
              checklists: this.checklists,
              gears: this.gears,
              onOpenTrip: () => {
                this.startTripCeremony();
              },
              onOpenGear: () => {
                this.triggerBlurPulse(1);
              },
              onOpenChecklist: (id: string) => {
                this.openChecklist(id);
              },
              onConfirmDeleteChecklist: (item: TripChecklist) => {
                this.confirmDeleteChecklist(item);
              }
            });
          }
          .tabBar(this.customTabBar(0, $r('sys.symbol.list_checkmark'), '清单'))

          TabContent() {
            GearPage({
              gears: this.gears,
              selectedGearCategories: this.selectedGearCategories,
              gearSearchKeyword: this.gearSearchKeyword,
              gearSortMode: this.gearSortMode,
              expandedGearId: this.expandedGearId,
              targetWeightGram: $targetWeightGram,
              multiSelectMode: this.multiSelectMode,
              selectedMultiGearIds: this.selectedMultiGearIds,
              onSearchChange: (keyword: string) => {
                this.gearSearchKeyword = keyword;
              },
              onOpenFilterPanel: () => {
                this.openGearFilterPanel();
              },
              onOpenSort: () => {
                this.sheetMode = SHEET_GEAR_SORT;
              },
              onStartMultiSelect: () => {
                this.multiSelectMode = true;
                this.selectedMultiGearIds = [];
              },
              onOpenAddGear: () => {
                this.openAddGear();
              },
              onOpenEditGear: (item: GearItem) => {
                this.openEditGear(item);
              },
              onConfirmDeleteGear: (item: GearItem) => {
                this.confirmDeleteGear(item);
              },
              onToggleGearExpanded: (id: string) => {
                this.toggleGearExpanded(id);
              },
              onEnterGearMultiSelect: (id: string) => {
                this.enterGearMultiSelect(id);
              },
              onToggleMultiGearSelection: (id: string) => {
                this.toggleMultiGearSelection(id);
              },
              onCancelGearMultiSelect: () => {
                this.cancelGearMultiSelect();
              },
              onOpenGenerateTripSheet: () => {
                this.openGenerateTripSheet();
              }
            });
          }
          .tabBar(this.customTabBar(1, $r('sys.symbol.bag'), '装备库'))
        }
        .animationDuration(200)
        .barOverlap(true)
        .vertical(false)
        .barPosition(BarPosition.End)
        .barFloatingStyle({
          barBottomMargin: 28,
          gradientMask: {
            maskColor: '#66F8F9FA',
            maskHeight: 72
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .blur(this.contentBlur)
        .scale({ x: this.contentScale, y: this.contentScale })
        .onAnimationStart((_from: number, _to: number) => {
          // 仅滑动触发时执行按压脉冲，点击切换已由 triggerBlurPulse 处理
          if (this.isClickSwitching) {
            return;
          }
          // 滑动松手 — 轻按压 + blur 脉冲
          this.getUIContext().animateTo({ duration: 80, curve: Curve.EaseOut }, () => {
            this.contentScale = 0.97;
            this.contentBlur = 4;
          });
          setTimeout(() => {
            this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
              this.contentBlur = 0;
            });
            this.getUIContext().animateTo({
              curve: curves.springMotion(0.35, 0.8)
            }, () => {
              this.contentScale = 1.0;
            });
          }, 80);
        })
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })

        if (this.gearFilterPanelExpanded) {
          GearFilterPanel({
            categories: this.categories,
            gears: this.gears,
            selectedCategories: this.selectedGearCategories,
            onApply: (categories: string[]) => {
              this.closeGearFilterPanel(categories);
            },
            onDismiss: () => {
              this.gearFilterPanelExpanded = false;
            }
          })
        }
        if (this.sheetMode !== SHEET_NONE) {
          this.SheetOverlay();
        }
        if (this.showEditItemPanel) {
          EditItemPanel({
            editingItemName: this.editingItemName,
            editingItemGroup: this.editingItemGroup,
            editingItemWeight: this.editingItemWeight,
            editingItemPrice: this.editingItemPrice,
            errorText: this.errorText,
            categories: this.categories,
            onNameChange: (value: string) => { this.editingItemName = value; },
            onGroupChange: (value: string) => { this.editingItemGroup = value; },
            onWeightChange: (value: string) => { this.editingItemWeight = value; },
            onPriceChange: (value: string) => { this.editingItemPrice = value; },
            onSave: () => { this.saveEditedItem(); },
            onClose: () => {
              this.showEditItemPanel = false;
              this.editingItemId = '';
              this.editingItemName = '';
              this.editingItemGroup = '其他';
              this.editingItemWeight = '';
              this.editingItemPrice = '';
              this.errorText = '';
            }
          })
        }
        if (this.showEditGearPanel) {
          EditGearPanel({
            gearName: this.gearName,
            gearCategory: this.gearCategory,
            gearWeight: this.gearWeight,
            gearPrice: this.gearPrice,
            gearNote: this.gearNote,
            errorText: this.errorText,
            categories: this.categories,
            onNameChange: (value: string) => {
              this.gearName = value;
            },
            onCategoryChange: (value: string) => {
              this.gearCategory = value;
            },
            onWeightChange: (value: string) => {
              this.gearWeight = value;
            },
            onPriceChange: (value: string) => {
              this.gearPrice = value;
            },
            onNoteChange: (value: string) => {
              this.gearNote = value;
            },
            onSave: () => {
              this.saveGear();
            },
            onClose: () => {
              this.closeEditGearPanel();
            }
          })
        }
        if (this.showTripCeremony) {
          TripCeremonyCard({
            tripTitle: this.ceremonyTripTitle,
            tripDate: this.ceremonyTripDate,
            onTitleChange: (value: string) => {
              this.ceremonyTripTitle = value;
            },
            onDateChange: (value: string) => {
              this.ceremonyTripDate = value;
            },
            onFinish: () => {
              this.finishTripCeremony();
            },
            onDismiss: () => {
              this.dismissTripCeremony();
            }
          })
        }
        if (this.showCompletionToast) {
          this.CompletionToast();
        }
      }
      .width('100%')
      .height('100%')
    }
    .navDestination(this.NavDestinationMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .backgroundColor('#F8F9FA')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }



  @Builder
  private CompletionToast() {
    Column() {
      Row() {
        Text('🎉 全部打包完成！出发吧！')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY_COLOR)
      }
      .width('90%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(LIGHT_PRIMARY_COLOR)
      .borderRadius(24)
      .shadow({ radius: 8, color: '#262D7D46', offsetX: 0, offsetY: 2 })
      .transition({ type: TransitionType.Insert, translate: { y: -20 }, scale: { x: PANEL_SCALE_START, y: PANEL_SCALE_START }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 78 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private SheetOverlay() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.closeSheet();
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
                this.openAddGearFromImport();
              })
          }
          Button(this.sheetMode === SHEET_TEMP_ITEM ? '完成' : '关闭')
            .fontSize(13)
            .fontColor(TEXT_SECONDARY)
            .backgroundColor('#00000000')
            .onClick(() => {
              this.closeSheet();
            })
        }
        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }
        if (this.sheetMode === SHEET_GEAR) {
          this.GearSheet();
        } else if (this.sheetMode === SHEET_TRIP) {
          this.TripSheet();
        } else if (this.sheetMode === SHEET_EDIT_TRIP) {
          this.EditTripSheet();
        } else if (this.sheetMode === SHEET_TEMP_ITEM) {
          this.TempItemSheet();
        } else if (this.sheetMode === SHEET_IMPORT) {
          this.ImportSheet();
        } else if (this.sheetMode === SHEET_GEAR_SORT) {
          this.GearSortSheet();
        } else if (this.sheetMode === SHEET_GENERATE_TRIP) {
          this.GenerateTripSheet();
        }
      }
      .width('100%')
      .height('72%')
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })
      .backgroundColor(CARD_BG)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.translate({ y: 320 }).combine(TransitionEffect.scale({ x: PANEL_SCALE_START, y: PANEL_SCALE_START })).combine(TransitionEffect.opacity(0)),
        TransitionEffect.translate({ y: 320 }).combine(TransitionEffect.opacity(0))
      ))
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.opacity(0),
      TransitionEffect.opacity(0)
    ))
    .backgroundColor('#66000000')
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

  @Builder
  private GearSortSheet() {
    Column({ space: 10 }) {
      this.SortOption('按分组（默认）', GEAR_SORT_GROUP);
      this.SortOption('按价格（高→低）', GEAR_SORT_PRICE);
      this.SortOption('按重量（重→轻）', GEAR_SORT_WEIGHT);
      this.SortOption('按添加时间（新→旧）', GEAR_SORT_TIME);
      this.SortOption('按克单价（高→低）', GEAR_SORT_VALUE);
      this.SortOption('按出行次数（高→低）', GEAR_SORT_TRIP_COUNT);
    }
    .width('100%')
  }

  @Builder
  private SortOption(title: string, mode: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor(this.gearSortMode === mode ? PRIMARY_COLOR : TEXT_MAIN)
        .fontWeight(this.gearSortMode === mode ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)
      if (this.gearSortMode === mode) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(14)
          .fontColor([PRIMARY_COLOR])
      }
    }
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.gearSortMode === mode ? LIGHT_PRIMARY_COLOR : PAGE_BG)
    .borderRadius(12)
    .scale({ x: this.gearSortMode === mode ? PRESS_SCALE_BOUNCE : PRESS_SCALE_REST, y: this.gearSortMode === mode ? PRESS_SCALE_BOUNCE : PRESS_SCALE_REST })
    .animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() })
    .onClick(() => {
      this.gearSortMode = mode;
      this.closeSheet();
    })
  }

  @Builder
  private GenerateTripSheet() {
    Column({ space: 12 }) {
      Text('已选择 ' + this.selectedMultiGearIds.length.toString() + ' 件装备')
        .fontSize(12)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      this.FormInput('行程名称', this.generateTripTitle, (value: string) => {
        this.generateTripTitle = value;
      });
      Button('确认生成')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.generateTripTitle.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.generateTripTitle.trim().length > 0)
        .onClick(() => {
          this.generateChecklistFromSelectedGears();
        })
    }
    .width('100%')
  }

  @Builder
  private GearSheet() {
    Scroll() {
      Column({ space: 12 }) {
        this.FormInput('装备名称（必填）', this.gearName, (value: string) => {
          this.gearName = value;
        });
        Text('选择分组')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        this.GearCategoryTags()
        Row({ space: 12 }) {
          this.FormInput('重量(g)', this.gearWeight, (value: string) => {
            this.gearWeight = value;
          }, InputType.Number);
          this.FormInput('价格(¥)', this.gearPrice, (value: string) => {
            this.gearPrice = value;
          }, InputType.Number);
        }
        this.FormInput('备注（一行，可选）', this.gearNote, (value: string) => {
          this.gearNote = value;
        });
        Button(this.editingGearId.length === 0 ? '确认添加' : '确认保存')
          .height(48)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.gearName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.gearName.trim().length > 0)
          .onClick(() => {
            this.saveGear();
          })
      }
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }

  @Builder
  private EditTripSheet() {
    Column({ space: 12 }) {
      this.FormInput('行程名称', this.tripTitle, (value: string) => {
        this.tripTitle = value;
      });
      this.DatePickerField('出发日期（可选）', this.tripDate);
      Button('确认保存')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY_COLOR)
        .width('100%')
        .onClick(() => {
          this.saveTripInfo();
        })
    }
  }

  @Builder
  private TripSheet() {
    Column({ space: 12 }) {
      this.FormInput('行程名称', this.tripTitle, (value: string) => {
        this.tripTitle = value;
      });
      this.DatePickerField('出发日期（可选）', this.tripDate);
      Button('创建')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY_COLOR)
        .width('100%')
        .onClick(() => {
          this.createChecklist();
        })
    }
  }

  @Builder
  private TempItemSheet() {
    Column({ space: 12 }) {
      this.FormInput('输入物品名称', this.tempItemName, (value: string) => {
        this.tempItemName = value;
      });
      Text('选择分组')
        .fontSize(12)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      this.TempItemCategoryTags()
      if (this.showTempAddNotice) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(12)
            .fontColor([PRIMARY_COLOR])
          Text('已添加')
            .fontSize(12)
            .fontColor(PRIMARY_COLOR)
        }
        .width('100%')
      }
      Button('确认添加')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.tempItemName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.tempItemName.trim().length > 0)
        .onClick(() => {
          this.addTempItem();
        })
    }
  }



  @Builder
  private GearCategoryTags() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      ForEach(this.presetCategories(), (category: string) => {
        Text(category)
          .fontSize(13)
          .fontColor(this.gearCategory === category ? '#FFFFFF' : '#666666')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.gearCategory === category ? PRIMARY_COLOR : CARD_BG)
          .border({ width: 1, color: this.gearCategory === category ? PRIMARY_COLOR : '#E0E0E0' })
          .borderRadius(12)
          .onClick(() => {
            this.gearCategory = category;
          })
      }, (category: string) => category)
    }
    .width('100%')
  }

  @Builder
  private TempItemCategoryTags() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      ForEach(this.presetCategories(), (category: string) => {
        Text(category)
          .fontSize(13)
          .fontColor(this.tempItemGroup === category ? '#FFFFFF' : '#666666')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.tempItemGroup === category ? PRIMARY_COLOR : CARD_BG)
          .border({ width: 1, color: this.tempItemGroup === category ? PRIMARY_COLOR : '#E0E0E0' })
          .borderRadius(12)
          .onClick(() => {
            this.tempItemGroup = category;
          })
      }, (category: string) => category)
    }
    .width('100%')
  }


  @Builder
  private ImportSheet() {
    Column({ space: 12 }) {
      if (this.gears.length === 0) {
        Column({ space: 10 }) {
          Text('装备库还是空的')
            .fontSize(14)
            .fontColor(TEXT_MAIN)
          Text('添加你的第一件装备吧')
            .fontSize(12)
            .fontColor(TEXT_SECONDARY)
          Button('添加装备')
            .width(160)
            .height(44)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(12)
            .onClick(() => {
              this.openAddGearFromImport();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.categoryTabs(), (category: string) => {
            Text(category)
              .fontSize(13)
              .fontColor(this.importGearCategory === category ? '#FFFFFF' : '#666666')
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor(this.importGearCategory === category ? PRIMARY_COLOR : CARD_BG)
              .border({ width: 1, color: this.importGearCategory === category ? PRIMARY_COLOR : '#E0E0E0' })
              .borderRadius(12)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.importGearCategory = category;
              })
          }, (category: string) => category)
        }
        .width('100%')

        List({ space: 8 }) {
          ForEach(this.filteredImportGears(), (item: GearItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Checkbox()
                  .select(this.hasImportSelection(item.id))
                  .onChange((checked: boolean) => {
                    this.toggleImportSelection(item.id, checked);
                  })
                Column({ space: 4 }) {
                  Text(item.name)
                    .fontSize(14)
                    .fontColor(TEXT_MAIN)
                  if (this.importGearMetaText(item).length > 0) {
                    Text(this.importGearMetaText(item))
                      .fontSize(12)
                      .fontColor(TEXT_SECONDARY)
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(PAGE_BG)
              .borderRadius(12)
            }
          }, (item: GearItem) => item.id)
        }
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
      }
      Button('导入选中 (' + this.importGearIds.length.toString() + ')')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.importGearIds.length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.importGearIds.length > 0)
        .onClick(() => {
          this.importSelectedGear();
        })
    }
    .height('100%')
  }

  @Builder
  private DatePickerField(placeholder: string, dateText: string) {
    Row() {
      Text(dateText.length > 0 ? dateText : placeholder)
        .fontSize(14)
        .fontColor(dateText.length > 0 ? TEXT_MAIN : TEXT_SECONDARY)
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(18)
        .fontColor([TEXT_TERTIARY])
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .backgroundColor(PAGE_BG)
    .borderRadius(12)
    .onClick(() => {
      DatePickerDialog.show({
        start: new Date('2020-1-1'),
        end: new Date('2030-12-31'),
        selected: new Date(),
        lunar: false,
        onDateAccept: (value: Date) => {
          const month = value.getMonth() + 1;
          const day = value.getDate();
          this.tripDate = month.toString() + '\u6708' + day.toString() + '\u65e5';
        }
      });
    })
  }

  @Builder
  private FormInput(placeholder: string, textValue: string, onValueChange: (value: string) => void,
    inputType: InputType = InputType.Normal) {
    TextInput({ placeholder: placeholder, text: textValue })
      .type(inputType)
      .height(48)
      .fontSize(14)
      .fontColor(TEXT_MAIN)
      .placeholderColor(TEXT_SECONDARY)
      .backgroundColor(PAGE_BG)
      .borderRadius(12)
      .padding({ left: 12, right: 12 })
      .onChange((value: string) => {
        onValueChange(value);
      })
  }
}
