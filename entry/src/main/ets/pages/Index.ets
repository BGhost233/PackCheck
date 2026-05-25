import { common } from '@kit.AbilityKit';
import { curves, LengthMetrics } from '@kit.ArkUI';
import { sensor, vibrator } from '@kit.SensorServiceKit';
import { ChecklistDetail } from '../components/ChecklistDetail';
import { GearPage } from '../components/GearPage';
import { HomePage } from '../components/HomePage';
import { ReviewPage } from '../components/ReviewPage';
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
  TEXT_TERTIARY,
  VIEW_CHECKLIST,
  VIEW_GEAR,
  VIEW_HOME,
  VIEW_REVIEW
} from '../constants/DesignTokens';
import { ChecklistItem, DEFAULT_CATEGORIES, GearItem, makeId, normalizeNumber, TripChecklist } from '../models/PackModels';
import { PackStore } from '../services/PackStore';

@Entry
@Component
struct Index {
  private store: PackStore = new PackStore();

  @State private gears: GearItem[] = [];
  @State private checklists: TripChecklist[] = [];
  @State private categories: string[] = [];
  @State private currentView: string = VIEW_HOME;
  @State private selectedGearCategory: string = '全部';
  @State private showAllGearTags: boolean = false;
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
  @State private editItemPanelScale: number = 0.85;
  @State private editItemPanelOpacity: number = 0;
  @State private showEditGearPanel: boolean = false;
  @State private editGearPanelScale: number = 0.85;
  @State private editGearPanelOpacity: number = 0;
  @State private showCompletionToast: boolean = false;
  @State private showTempAddNotice: boolean = false;
  @State private progressPulse: boolean = false;
  @State private reviewIndex: number = 0;
  @State private reviewFinished: boolean = false;
  @State private reviewDragX: number = 0;
  @State private highlightedItemId: string = '';
  @State private checklistRenderNonce: number = 0;

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
    const filtered: GearItem[] = [];
    const keyword = this.gearSearchKeyword.trim().toLowerCase();
    for (let index = 0; index < this.gears.length; index++) {
      const item = this.gears[index];
      const categoryMatched = this.selectedGearCategory === '全部' || item.category === this.selectedGearCategory;
      const note = item.note === undefined ? '' : item.note;
      const keywordMatched = keyword.length === 0 ||
        item.name.toLowerCase().indexOf(keyword) >= 0 ||
        item.category.toLowerCase().indexOf(keyword) >= 0 ||
        note.toLowerCase().indexOf(keyword) >= 0;
      if (categoryMatched && keywordMatched) {
        filtered.push(item);
      }
    }
    return this.sortedGears(filtered);
  }

  private sortedGears(items: GearItem[]): GearItem[] {
    const sorted: GearItem[] = [];
    for (let index = 0; index < items.length; index++) {
      sorted.push(items[index]);
    }
    sorted.sort((left: GearItem, right: GearItem): number => {
      if (this.gearSortMode === GEAR_SORT_PRICE) {
        return this.numberOrZero(right.price) - this.numberOrZero(left.price);
      }
      if (this.gearSortMode === GEAR_SORT_WEIGHT) {
        return this.numberOrZero(right.weight) - this.numberOrZero(left.weight);
      }
      if (this.gearSortMode === GEAR_SORT_TIME) {
        return right.createdAt - left.createdAt;
      }
      if (this.gearSortMode === GEAR_SORT_VALUE) {
        return this.gearValueRatio(right) - this.gearValueRatio(left);
      }
      if (this.gearSortMode === GEAR_SORT_TRIP_COUNT) {
        return this.gearTripCount(right) - this.gearTripCount(left);
      }
      if (left.category === right.category) {
        return right.createdAt - left.createdAt;
      }
      return left.category.localeCompare(right.category);
    });
    return sorted;
  }

  private numberOrZero(value: number | undefined): number {
    return value === undefined ? 0 : value;
  }

  private gearValueRatio(item: GearItem): number {
    if (item.price === undefined || item.weight === undefined || item.weight <= 0) {
      return 0;
    }
    return item.price / item.weight;
  }

  private filteredGearGroups(): string[] {
    const items = this.filteredGears();
    const groups: string[] = [];
    for (let index = 0; index < items.length; index++) {
      const group = this.gearSortMode === GEAR_SORT_GROUP ? items[index].category : this.gearSortLabel();
      if (groups.indexOf(group) < 0) {
        groups.push(group);
      }
    }
    return groups;
  }

  private filteredGearsByGroup(group: string): GearItem[] {
    const items = this.filteredGears();
    if (this.gearSortMode !== GEAR_SORT_GROUP) {
      return items;
    }
    return items.filter((item: GearItem) => item.category === group);
  }

  private gearSortLabel(): string {
    if (this.gearSortMode === GEAR_SORT_PRICE) {
      return '按价格';
    }
    if (this.gearSortMode === GEAR_SORT_WEIGHT) {
      return '按重量';
    }
    if (this.gearSortMode === GEAR_SORT_TIME) {
      return '按添加时间';
    }
    if (this.gearSortMode === GEAR_SORT_VALUE) {
      return '按克单价';
    }
    if (this.gearSortMode === GEAR_SORT_TRIP_COUNT) {
      return '按出行次数';
    }
    return '按分组';
  }

  private gearTripCount(item: GearItem): number {
    return item.tripCount === undefined ? 0 : item.tripCount;
  }

  private gearGroupCount(group: string): number {
    return this.filteredGearsByGroup(group).length;
  }

  private gearStatsText(): string {
    return this.gears.length.toString() + ' 件 · ' + this.formatKg(this.totalGearWeight()) +
      ' · ¥' + this.totalGearPrice().toString();
  }

  private totalGearWeight(): number {
    let total = 0;
    for (let index = 0; index < this.gears.length; index++) {
      total += this.numberOrZero(this.gears[index].weight);
    }
    return total;
  }

  private totalGearPrice(): number {
    let total = 0;
    for (let index = 0; index < this.gears.length; index++) {
      total += this.numberOrZero(this.gears[index].price);
    }
    return total;
  }

  private averageGearValueRatio(): number {
    let totalPrice = 0;
    let totalWeight = 0;
    for (let index = 0; index < this.gears.length; index++) {
      if (this.gears[index].price !== undefined && this.gears[index].weight !== undefined) {
        totalPrice += this.numberOrZero(this.gears[index].price);
        totalWeight += this.numberOrZero(this.gears[index].weight);
      }
    }
    if (totalWeight <= 0) {
      return 0;
    }
    return Math.round(totalPrice * 100 / totalWeight) / 100;
  }

  private heaviestGearText(): string {
    let item: GearItem | undefined = undefined;
    for (let index = 0; index < this.gears.length; index++) {
      if (this.gears[index].weight !== undefined &&
        (item === undefined || this.numberOrZero(this.gears[index].weight) > this.numberOrZero(item.weight))) {
        item = this.gears[index];
      }
    }
    if (item === undefined || item.weight === undefined) {
      return '暂无';
    }
    return item.name + ' (' + item.weight.toString() + 'g)';
  }

  private mostExpensiveGearText(): string {
    let item: GearItem | undefined = undefined;
    for (let index = 0; index < this.gears.length; index++) {
      if (this.gears[index].price !== undefined &&
        (item === undefined || this.numberOrZero(this.gears[index].price) > this.numberOrZero(item.price))) {
        item = this.gears[index];
      }
    }
    if (item === undefined || item.price === undefined) {
      return '暂无';
    }
    return item.name + ' (¥' + item.price.toString() + ')';
  }

  private mostFrequentGearText(): string {
    let item: GearItem | undefined = undefined;
    for (let index = 0; index < this.gears.length; index++) {
      if (this.gearTripCount(this.gears[index]) > 0 &&
        (item === undefined || this.gearTripCount(this.gears[index]) > this.gearTripCount(item))) {
        item = this.gears[index];
      }
    }
    return item === undefined ? '暂无' : item.name + ' (×' + this.gearTripCount(item).toString() + '次)';
  }

  private formatKg(weightGram: number): string {
    if (weightGram <= 0) {
      return '0kg';
    }
    return (Math.round(weightGram / 100) / 10).toString() + 'kg';
  }

  private categoryTabs(): string[] {
    const tabs: string[] = ['全部'];
    const categories = this.presetCategories();
    for (let index = 0; index < categories.length; index++) {
      tabs.push(categories[index]);
    }
    return tabs;
  }

  private presetCategories(): string[] {
    const nextCategories: string[] = [];
    for (let index = 0; index < DEFAULT_CATEGORIES.length; index++) {
      nextCategories.push(DEFAULT_CATEGORIES[index]);
    }
    for (let index = 0; index < this.categories.length; index++) {
      if (nextCategories.indexOf(this.categories[index]) < 0) {
        nextCategories.push(this.categories[index]);
      }
    }
    return nextCategories;
  }

  private checklistGroups(): string[] {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return [];
    }
    const groups: string[] = [];
    for (let index = 0; index < checklist.items.length; index++) {
      const group = checklist.items[index].group;
      if (groups.indexOf(group) < 0) {
        groups.push(group);
      }
    }
    return groups;
  }

  private checklistItemsByGroup(group: string): ChecklistItem[] {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return [];
    }
    return checklist.items.filter((item: ChecklistItem) => item.group === group);
  }

  private groupItemCount(group: string): number {
    return this.checklistItemsByGroup(group).length;
  }

  private isGroupDone(group: string): boolean {
    const items = this.checklistItemsByGroup(group);
    if (items.length === 0) {
      return false;
    }
    for (let index = 0; index < items.length; index++) {
      if (!items[index].checked) {
        return false;
      }
    }
    return true;
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
    let count = 0;
    for (let index = 0; index < checklist.items.length; index++) {
      if (checklist.items[index].checked) {
        count++;
      }
    }
    return count;
  }

  private progressPercent(checklist: TripChecklist): number {
    if (checklist.items.length === 0) {
      return 0;
    }
    return Math.floor(this.checkedCount(checklist) * 100 / checklist.items.length);
  }

  private progressValue(checklist: TripChecklist): number {
    if (checklist.items.length === 0) {
      return 0;
    }
    return this.checkedCount(checklist);
  }

  private progressTotal(checklist: TripChecklist): number {
    if (checklist.items.length === 0) {
      return 1;
    }
    return checklist.items.length;
  }

  private progressText(checklist: TripChecklist): string {
    return this.checkedCount(checklist).toString() + '/' + checklist.items.length.toString();
  }

  private checklistMetaText(checklist: TripChecklist): string {
    const progress = this.progressText(checklist);
    if (checklist.date === undefined || checklist.date.length === 0) {
      return progress;
    }
    return checklist.date + ' · ' + progress;
  }

  private homeStatusText(): string {
    if (this.checklists.length === 0) {
      return '还没有行程，创建一个吧';
    }
    return this.activeChecklistCount().toString() + ' 个行程进行中';
  }

  private isChecklistDone(checklist: TripChecklist): boolean {
    return checklist.items.length > 0 && this.checkedCount(checklist) === checklist.items.length;
  }

  private isCurrentChecklistDone(): boolean {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return false;
    }
    return this.isChecklistDone(checklist);
  }

  private activeChecklistCount(): number {
    let count = 0;
    for (let index = 0; index < this.checklists.length; index++) {
      if (!this.isChecklistDone(this.checklists[index])) {
        count++;
      }
    }
    return count;
  }

  private parseTripDateAt(text: string): number | undefined {
    const value = text.trim();
    if (value.length === 0) {
      return undefined;
    }
    const monthIndex = value.indexOf('月');
    const dayIndex = value.indexOf('日');
    if (monthIndex > 0 && dayIndex > monthIndex) {
      const month = Number(value.substring(0, monthIndex));
      const day = Number(value.substring(monthIndex + 1, dayIndex));
      if (!Number.isNaN(month) && !Number.isNaN(day)) {
        return new Date(new Date().getFullYear(), month - 1, day).getTime();
      }
    }
    return undefined;
  }

  private startOfDay(date: Date): number {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  }

  private checklistDateAt(checklist: TripChecklist): number | undefined {
    if (checklist.dateAt !== undefined) {
      return checklist.dateAt;
    }
    if (checklist.date !== undefined) {
      return this.parseTripDateAt(checklist.date);
    }
    return undefined;
  }

  private countdownText(checklist: TripChecklist): string {
    const dateAt = this.checklistDateAt(checklist);
    if (dateAt === undefined) {
      return '';
    }
    const today = this.startOfDay(new Date());
    const dayDiff = Math.floor((dateAt - today) / 86400000);
    if (dayDiff > 0) {
      return '还有 ' + dayDiff.toString() + ' 天出发';
    }
    if (dayDiff === 0) {
      return '今天出发！';
    }
    return '已出发 ' + Math.abs(dayDiff).toString() + ' 天';
  }

  private checklistTotalWeight(checklist: TripChecklist): number {
    let total = 0;
    for (let index = 0; index < checklist.items.length; index++) {
      const item = checklist.items[index];
      const weight = this.checklistItemWeight(item);
      if (weight !== undefined) {
        total += weight;
      }
    }
    return total;
  }

  private checklistCheckedWeight(checklist: TripChecklist): number {
    let total = 0;
    for (let index = 0; index < checklist.items.length; index++) {
      const item = checklist.items[index];
      const weight = this.checklistItemWeight(item);
      if (item.checked && weight !== undefined) {
        total += weight;
      }
    }
    return total;
  }

  private progressStartColor(percent: number): string {
    if (percent < 30) {
      return '#90A4AE';
    }
    return PRIMARY_COLOR;
  }

  private progressEndColor(percent: number): string {
    if (percent < 30) {
      return '#90A4AE';
    }
    if (percent < 60) {
      return '#4CAF50';
    }
    return PROGRESS_END_COLOR;
  }

  private gearById(id: string): GearItem | undefined {
    for (let index = 0; index < this.gears.length; index++) {
      if (this.gears[index].id === id) {
        return this.gears[index];
      }
    }
    return undefined;
  }

  private checklistItemWeight(item: ChecklistItem): number | undefined {
    if (item.weight !== undefined) {
      return item.weight;
    }
    if (item.fromGearId !== undefined) {
      const gear = this.gearById(item.fromGearId);
      if (gear !== undefined) {
        return gear.weight;
      }
    }
    return undefined;
  }

  private checklistItemPrice(item: ChecklistItem): number | undefined {
    if (item.price !== undefined) {
      return item.price;
    }
    if (item.fromGearId !== undefined) {
      const gear = this.gearById(item.fromGearId);
      if (gear !== undefined) {
        return gear.price;
      }
    }
    return undefined;
  }

  private numberInputText(value: number | undefined): string {
    return value === undefined ? '' : value.toString();
  }

  private latestChecklistHomeSubtitle(): string {
    const latest = this.latestChecklist();
    if (latest === undefined) {
      return '';
    }
    const countdown = this.countdownText(latest);
    const weight = this.checklistTotalWeight(latest);
    if (countdown.length > 0 && weight > 0) {
      return countdown + ' · ' + this.formatKg(weight);
    }
    if (countdown.length > 0) {
      return countdown;
    }
    if (weight > 0) {
      return this.formatKg(weight);
    }
    return this.checklistMetaText(latest);
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
    this.editGearPanelScale = 0.85;
    this.editGearPanelOpacity = 0;
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.editGearPanelScale = 1;
      this.editGearPanelOpacity = 1;
    });
  }

  private closeEditGearPanel(): void {
    this.getUIContext().animateTo({
      duration: 200,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.showEditGearPanel = false;
        this.resetGearForm();
        this.errorText = '';
      }
    }, () => {
      this.editGearPanelScale = 0.9;
      this.editGearPanelOpacity = 0;
    });
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
    const dedupedIds: string[] = [];
    for (let index = 0; index < ids.length; index++) {
      if (ids[index].length > 0 && dedupedIds.indexOf(ids[index]) < 0) {
        dedupedIds.push(ids[index]);
      }
    }
    return dedupedIds;
  }

  private checklistHasGear(checklist: TripChecklist, gearId: string): boolean {
    for (let index = 0; index < checklist.items.length; index++) {
      if (checklist.items[index].fromGearId === gearId) {
        return true;
      }
    }
    return false;
  }

  private countableGearIds(checklist: TripChecklist, gearIds: string[]): string[] {
    const dedupedIds = this.uniqueGearIds(gearIds);
    const nextIds: string[] = [];
    for (let index = 0; index < dedupedIds.length; index++) {
      if (!this.checklistHasGear(checklist, dedupedIds[index])) {
        nextIds.push(dedupedIds[index]);
      }
    }
    return nextIds;
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
    return item.fromGearId !== undefined && item.fromGearId.length > 0;
  }

  private hasGearMarker(item: ChecklistItem): boolean {
    return this.isChecklistItemInGear(item);
  }

  private matchingGearForChecklistItem(item: ChecklistItem): GearItem | undefined {
    const name = item.name.trim();
    const group = item.group.trim().length === 0 ? '其他' : item.group.trim();
    for (let index = 0; index < this.gears.length; index++) {
      const gear = this.gears[index];
      if (gear.name.trim() === name && gear.category.trim() === group) {
        return gear;
      }
    }
    return undefined;
  }

  private openTripSheet(): void {
    this.tripTitle = '';
    this.tripDate = '';
    this.sheetMode = SHEET_TRIP;
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
    this.currentView = VIEW_CHECKLIST;
    this.startShakeListening();
    this.closeSheet();
  }

  private openChecklist(checklistId: string): void {
    this.selectedChecklistId = checklistId;
    this.collapsedGroups = [];
    this.currentView = VIEW_CHECKLIST;
    this.startShakeListening();
  }

  private returnToHome(): void {
    this.stopShakeListening();
    this.currentView = VIEW_HOME;
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
    this.currentView = VIEW_REVIEW;
  }

  private exitReviewMode(): void {
    this.reviewDragX = 0;
    this.currentView = VIEW_CHECKLIST;
    this.startShakeListening();
  }

  private startShakeListening(): void {
    if (this.shakeListening || this.currentView !== VIEW_CHECKLIST) {
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
    this.editItemPanelScale = 0.85;
    this.editItemPanelOpacity = 0;
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.editItemPanelScale = 1;
      this.editItemPanelOpacity = 1;
    });
  }

  private closeEditItemPanel(): void {
    this.getUIContext().animateTo({
      duration: 200,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.showEditItemPanel = false;
        this.editingItemId = '';
        this.editingItemName = '';
        this.editingItemGroup = '其他';
        this.editingItemWeight = '';
        this.editingItemPrice = '';
        this.errorText = '';
      }
    }, () => {
      this.editItemPanelScale = 0.9;
      this.editItemPanelOpacity = 0;
    });
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
    return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日';
  }

  private formatDateText(timestamp: number): string {
    const date = new Date(timestamp);
    return date.getFullYear().toString() + '-' + (date.getMonth() + 1).toString() + '-' + date.getDate().toString();
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
    if (this.importGearCategory === '全部') {
      return this.gears;
    }
    return this.gears.filter((item: GearItem) => item.category === this.importGearCategory);
  }

  private importGearMetaText(item: GearItem): string {
    let text = '';
    if (item.weight !== undefined) {
      text = text + item.weight.toString() + 'g';
    }
    if (item.price !== undefined) {
      if (text.length > 0) {
        text = text + '  ';
      }
      text = text + '¥' + item.price.toString();
    }
    return text;
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
    this.currentView = VIEW_CHECKLIST;
    this.startShakeListening();
  }

  private addItemsToChecklist(checklistId: string, items: ChecklistItem[]): TripChecklist[] {
    const nextChecklists: TripChecklist[] = [];
    for (let index = 0; index < this.checklists.length; index++) {
      const checklist = this.checklists[index];
      if (checklist.id === checklistId) {
        const nextItems: ChecklistItem[] = [];
        for (let itemIndex = 0; itemIndex < checklist.items.length; itemIndex++) {
          nextItems.push(checklist.items[itemIndex]);
        }
        for (let newIndex = 0; newIndex < items.length; newIndex++) {
          nextItems.push(items[newIndex]);
        }
        const updated: TripChecklist = {
          id: checklist.id,
          title: checklist.title,
          date: checklist.date,
          dateAt: checklist.dateAt,
          items: nextItems,
          createdAt: checklist.createdAt
        };
        nextChecklists.push(updated);
      } else {
        nextChecklists.push(checklist);
      }
    }
    return nextChecklists;
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
    this.applyChecklistState(nextChecklists, true);
    await this.store.saveChecklists(nextChecklists);
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
    this.sheetMode = SHEET_NONE;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.currentView === VIEW_HOME) {
          HomePage({
            checklists: this.checklists,
            gears: this.gears,
            onOpenTrip: () => {
              this.openTripSheet();
            },
            onOpenGear: () => {
              this.currentView = VIEW_GEAR;
            },
            onOpenChecklist: (id: string) => {
              this.openChecklist(id);
            },
            onConfirmDeleteChecklist: (item: TripChecklist) => {
              this.confirmDeleteChecklist(item);
            }
          });
        } else if (this.currentView === VIEW_GEAR) {
          GearPage({
            gears: this.gears,
            categories: this.categories,
            selectedGearCategory: this.selectedGearCategory,
            gearSearchKeyword: this.gearSearchKeyword,
            gearSortMode: this.gearSortMode,
            expandedGearId: this.expandedGearId,
            targetWeightGram: $targetWeightGram,
            multiSelectMode: this.multiSelectMode,
            selectedMultiGearIds: this.selectedMultiGearIds,
            showAllGearTags: this.showAllGearTags,
            onSelectCategory: (category: string) => {
              this.selectedGearCategory = category;
            },
            onSearchChange: (keyword: string) => {
              this.gearSearchKeyword = keyword;
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
            },
            onToggleAllGearTags: () => {
              this.showAllGearTags = !this.showAllGearTags;
            }
          });
        } else if (this.currentView === VIEW_REVIEW) {
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
          });
        } else {
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
          });
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BG)

      if (this.shouldShowBottomTabs()) {
        this.BottomTabBar();
      }
      if (this.sheetMode !== SHEET_NONE) {
        this.SheetOverlay();
      }
      if (this.showEditItemPanel) {
        this.EditItemPanelOverlay();
      }
      if (this.showEditGearPanel) {
        this.EditGearPanelOverlay();
      }
      if (this.showCompletionToast) {
        this.CompletionToast();
      }
    }
    .width('100%')
    .height('100%')
  }

  private shouldShowBottomTabs(): boolean {
    return this.currentView === VIEW_HOME || this.currentView === VIEW_GEAR;
  }

  @Builder
  private BottomTabBar() {
    Row() {
      this.BottomTabItem('清单', VIEW_HOME);
      this.BottomTabItem('装备库', VIEW_GEAR);
    }
    .width('60%')
    .height(56)
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(CARD_BG)
    .borderRadius(30)
    .shadow({ radius: 12, color: '#14000000', offsetX: 0, offsetY: 2 })
    .margin({ bottom: 20 })
  }

  @Builder
  private BottomTabItem(title: string, targetView: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(this.currentView === targetView ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentView === targetView ? PRIMARY_COLOR : TEXT_SECONDARY)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(44)
      .onClick(() => {
        this.currentView = targetView;
      })
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
      .transition({ type: TransitionType.Insert, translate: { y: -20 }, opacity: 0 })
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
      .transition({ type: TransitionType.Insert, translate: { y: 320 }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
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
        Text('✓')
          .fontSize(14)
          .fontColor(PRIMARY_COLOR)
      }
    }
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.gearSortMode === mode ? LIGHT_PRIMARY_COLOR : PAGE_BG)
    .borderRadius(12)
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
      this.FormInput('出发日期（可选）', this.tripDate, (value: string) => {
        this.tripDate = value;
      });
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
      this.FormInput('出发日期（可选）', this.tripDate, (value: string) => {
        this.tripDate = value;
      });
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
        Text('✓ 已添加')
          .fontSize(12)
          .fontColor(PRIMARY_COLOR)
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
  private EditItemPanelOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .backdropBlur(20)
      .opacity(this.editItemPanelOpacity)
      .onClick(() => {
        this.closeEditItemPanel();
      })

      Column({ space: 16 }) {
        Row() {
          Text('编辑物品')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Blank()
          Text('✕')
            .fontSize(20)
            .fontColor(TEXT_SECONDARY)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.closeEditItemPanel();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.FormInput('物品名称', this.editingItemName, (value: string) => {
          this.editingItemName = value;
        });

        Text('所属分组')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        this.EditItemCategoryTags()

        Row({ space: 12 }) {
          this.EditMetricInput('重量', this.editingItemWeight, 'g', (value: string) => {
            this.editingItemWeight = value;
          });
          this.EditMetricInput('价格', this.editingItemPrice, '¥', (value: string) => {
            this.editingItemPrice = value;
          });
        }
        .width('100%')

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Button('保存修改')
          .height(48)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.editingItemName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.editingItemName.trim().length > 0)
          .borderRadius(12)
          .onClick(() => {
            this.saveEditedItem();
          })
      }
      .width('85%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .backgroundColor(CARD_BG)
      .borderRadius(24)
      .shadow({ radius: 24, color: '#14000000', offsetX: 0, offsetY: 8 })
      .scale({ x: this.editItemPanelScale, y: this.editItemPanelScale })
      .opacity(this.editItemPanelOpacity)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private EditGearPanelOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .backdropBlur(20)
      .opacity(this.editGearPanelOpacity)
      .onClick(() => {
        this.closeEditGearPanel();
      })

      Column({ space: 16 }) {
        Row() {
          Text('编辑装备')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Blank()
          Text('✕')
            .fontSize(20)
            .fontColor(TEXT_SECONDARY)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.closeEditGearPanel();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.FormInput('装备名称（必填）', this.gearName, (value: string) => {
          this.gearName = value;
        });

        Text('选择分组')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        Scroll() {
          this.GearCategoryTags()
        }
        .height(96)
        .edgeEffect(EdgeEffect.Spring)

        Row({ space: 12 }) {
          this.EditMetricInput('重量', this.gearWeight, 'g', (value: string) => {
            this.gearWeight = value;
          });
          this.EditMetricInput('价格', this.gearPrice, '¥', (value: string) => {
            this.gearPrice = value;
          });
        }
        .width('100%')

        this.FormInput('备注（一行，可选）', this.gearNote, (value: string) => {
          this.gearNote = value;
        });

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Button('保存修改')
          .height(48)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.gearName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.gearName.trim().length > 0)
          .borderRadius(12)
          .onClick(() => {
            this.saveGear();
          })
      }
      .width('85%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .backgroundColor(CARD_BG)
      .borderRadius(24)
      .shadow({ radius: 24, color: '#14000000', offsetX: 0, offsetY: 8 })
      .scale({ x: this.editGearPanelScale, y: this.editGearPanelScale })
      .opacity(this.editGearPanelOpacity)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private EditMetricInput(label: string, textValue: string, unit: string, onValueChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      Row({ space: 6 }) {
        TextInput({ placeholder: '可选', text: textValue })
          .type(InputType.Number)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor('#00000000')
          .layoutWeight(1)
          .onChange((value: string) => {
            onValueChange(value);
          })
        Text(unit)
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
      }
      .height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(PAGE_BG)
      .borderRadius(12)
    }
    .layoutWeight(1)
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
  private EditItemCategoryTags() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      ForEach(this.presetCategories(), (category: string) => {
        Text(category)
          .fontSize(13)
          .fontColor(this.editingItemGroup === category ? '#FFFFFF' : '#666666')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.editingItemGroup === category ? PRIMARY_COLOR : CARD_BG)
          .border({ width: 1, color: this.editingItemGroup === category ? PRIMARY_COLOR : '#E0E0E0' })
          .borderRadius(12)
          .onClick(() => {
            this.editingItemGroup = category;
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
