import { common } from '@kit.AbilityKit';
import { curves, display } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { GearItem, TripChecklist } from '../models/PackModels';
import { PackStore } from '../services/PackStore';
import { WeightGauge } from './WeightGauge';
import { EmptyIllustration } from './EmptyIllustration';
import {
  ARROW_COLOR,
  CARD_BG,
  DANGER_COLOR,
  DIVIDER_COLOR,
  FONT_FEATURE_TNUM,
  GEAR_HEADER_COLLAPSED,
  GEAR_HEADER_EXPANDED,
  GEAR_SORT_GROUP,
  GEAR_SORT_PRICE,
  GEAR_SORT_TIME,
  GEAR_SORT_TRIP_COUNT,
  GEAR_SORT_VALUE,
  GEAR_SORT_WEIGHT,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PAGE_PADDING,
  PRIMARY_COLOR,
  PRIMARY_TINT_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../constants/DesignTokens';
import { getGroupColor } from '../utils/ColorUtils';

interface TripCardArea {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

@Component
export struct GearPage {
  @Prop gears: GearItem[] = [];
  @Prop selectedGearCategories: string[] = ['全部'];
  @Prop gearSearchKeyword: string = '';
  @Prop gearSortMode: string = GEAR_SORT_GROUP;
  @Prop expandedGearId: string = '';
  @Link targetWeightGram: number;
  @Prop multiSelectMode: boolean = false;
  @Prop selectedMultiGearIds: string[] = [];
  @Prop gearBudget: number = 0;

@State private pressedGearId: string = '';
@State private swipedGearId: string = '';
@State private swipeOffsetX: number = 0;
@State private showMoveGroupSheet: boolean = false;
@State private searchExpanded: boolean = false;
  @State private showWeightEditor: boolean = false;
  @State private targetWeightInput: string = '';
  @State private targetWeightError: string = '';
  @State private fabX: number = -1; // -1 表示未初始化，使用默认右下角位置
  @State private fabY: number = -1;
  @State private fabDragging: boolean = false;
  private fabStartX: number = 0;
  private fabStartY: number = 0;
  @State private gearScrollOffset: number = 0;
  @State private collapsedGearGroups: string[] = [];
  @State private gearGroupExpandTrigger: number = 0;
  @State private categoryOrder: string[] = [];

  @State private pressedGroupId: string = '';

  // --- 分组拖拽排序 ---
  @State private groupDragMode: boolean = false;
  @State private groupDragGroup: string = '';
  @State private groupDragY: number = 0;
  @State private groupDragOffsetY: number = 0;
  @State private groupReorderList: string[] = [];
  private groupCardHeights: Map<string, number> = new Map();

  // --- 拖拽到行程 ---
  @State private dragMode: boolean = false;
  @State private dragX: number = 0;
  @State private dragY: number = 0;
  @State private dragOverTripId: string = '';
  @State private showTripTray: boolean = false;
  @Prop checklists: TripChecklist[] = [];

  private store: PackStore = new PackStore();
  private gearListScroller: Scroller = new Scroller();
  private tripTrayScroller: Scroller = new Scroller();
  private trayAutoScrollTimer: number = -1;
  private screenWidth: number = 360; // fallback
  private screenHeight: number = 780;

  aboutToAppear(): void {
    // 获取屏幕尺寸（vp）
    try {
      const defaultDisplay = display.getDefaultDisplaySync();
      this.screenWidth = px2vp(defaultDisplay.width);
      this.screenHeight = px2vp(defaultDisplay.height);
    } catch (e) {
      // fallback
    }
    // 初始位置：右下角
    this.fabX = this.screenWidth - 50 - 16;
    this.fabY = this.screenHeight - 50 - 160; // 留出 TabBar 空间
    // 恢复折叠状态 + 分组顺序
    this.loadCollapsedGroups();
    this.loadCategoryOrder();
  }

  private async loadCollapsedGroups(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      const saved = await this.store.getCollapsedGearGroups();
      if (saved.length > 0) {
        this.collapsedGearGroups = saved;
      }
    } catch (e) {
      // 降级：全展开
    }
  }

  private async persistCollapsedGroups(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      await this.store.saveCollapsedGearGroups(this.collapsedGearGroups);
    } catch (e) {
      // 静默失败
    }
  }

  private async loadCategoryOrder(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      const saved = await this.store.getCategoryOrder();
      if (saved.length > 0) {
        this.categoryOrder = saved;
      }
    } catch (e) {
      // 降级：使用默认字母序
    }
  }

  private async persistCategoryOrder(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      await this.store.saveCategoryOrder(this.categoryOrder);
    } catch (e) {
      // 静默失败
    }
  }

  // FAB 吸附到最近的屏幕边缘
  private snapFabToEdge(): void {
    const fabSize = 50;
    const centerX = this.fabX + fabSize / 2;
    const targetX = centerX < this.screenWidth / 2 ? 16 : this.screenWidth - fabSize - 16;
    // Clamp Y 在安全区域内
    const minY = 80;
    const maxY = this.screenHeight - fabSize - 140;
    const targetY = Math.max(minY, Math.min(maxY, this.fabY));

    this.getUIContext().animateTo({
      duration: 400,
      curve: curves.springMotion(0.28, 0.76)
    }, () => {
      this.fabX = targetX;
      this.fabY = targetY;
    });
  }

  // --- 拖拽到行程: 碰撞检测区域 ---
  private tripCardAreas: TripCardArea[] = [];

  private enterDragMode(startX: number, startY: number): void {
    this.dragMode = true;
    this.dragX = startX;
    this.dragY = startY;
    // 触觉确认
    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: 'touch' });
    } catch (e) { /* 静默 */ }
    // 弹出托盘 + 背景模糊
    this.getUIContext().animateTo({
      duration: 350,
      curve: curves.springMotion(0.35, 0.8)
    }, () => {
      this.showTripTray = true;
    });
  }

  private updateDragPosition(x: number, y: number): void {
    this.dragX = x;
    this.dragY = y;
    // 碰撞检测
    let hitId = '';
    for (const area of this.tripCardAreas) {
      if (x >= area.x && x <= area.x + area.w && y >= area.y && y <= area.y + area.h) {
        hitId = area.id;
        break;
      }
    }
    if (hitId !== this.dragOverTripId) {
      this.dragOverTripId = hitId;
      if (hitId !== '') {
        // 振动反馈：进入目标
        try {
          vibrator.startVibration({ type: 'time', duration: 15 }, { usage: 'touch' });
        } catch (e) { /* 静默 */ }
      }
    }
    // 边缘自动滚动：手指在屏幕左/右 50vp 内时自动滚动托盘
    const edgeThreshold = 50;
    if (this.showTripTray && y > this.screenHeight - 200) {
      if (x < edgeThreshold) {
        this.startTrayAutoScroll(-4);
      } else if (x > this.screenWidth - edgeThreshold) {
        this.startTrayAutoScroll(4);
      } else {
        this.stopTrayAutoScroll();
      }
    } else {
      this.stopTrayAutoScroll();
    }
  }

  private startTrayAutoScroll(delta: number): void {
    if (this.trayAutoScrollTimer >= 0) {
      return; // 已在滚动
    }
    this.trayAutoScrollTimer = setInterval(() => {
      const current = this.tripTrayScroller.currentOffset().xOffset;
      this.tripTrayScroller.scrollTo({ xOffset: current + delta, yOffset: 0 });
    }, 16) as number;
  }

  private stopTrayAutoScroll(): void {
    if (this.trayAutoScrollTimer >= 0) {
      clearInterval(this.trayAutoScrollTimer);
      this.trayAutoScrollTimer = -1;
    }
  }

  private completeDrag(): void {
    this.stopTrayAutoScroll();
    const hitTarget = this.dragOverTripId;
    if (hitTarget !== '' && this.selectedMultiGearIds.length > 0) {
      // 成功释放：强振动确认
      try {
        vibrator.startVibration({ type: 'time', duration: 40 }, { usage: 'touch' });
      } catch (e) { /* 静默 */ }
      if (hitTarget === '__new_trip__') {
        this.onAddGearsToNewTrip(this.selectedMultiGearIds);
      } else {
        this.onAddGearsToTrip(this.selectedMultiGearIds, hitTarget);
      }
    }
    // 退出拖拽态
    this.getUIContext().animateTo({
      duration: 300,
      curve: curves.springMotion(0.35, 0.8)
    }, () => {
      this.dragMode = false;
      this.showTripTray = false;
      this.dragOverTripId = '';
    });
  }

  private cancelDrag(): void {
    this.stopTrayAutoScroll();
    this.getUIContext().animateTo({
      duration: 300,
      curve: curves.springMotion(0.35, 0.8)
    }, () => {
      this.dragMode = false;
      this.showTripTray = false;
      this.dragOverTripId = '';
    });
  }

  onSearchChange: (keyword: string) => void = (keyword: string): void => {};
  onOpenFilterPanel: () => void = (): void => {};
  onOpenSort: () => void = (): void => {};
  onStartMultiSelect: () => void = (): void => {};
  onOpenAddGear: () => void = (): void => {};
  onOpenEditGear: (item: GearItem) => void = (item: GearItem): void => {};
  onConfirmDeleteGear: (item: GearItem) => void = (item: GearItem): void => {};
  onToggleGearExpanded: (id: string) => void = (id: string): void => {};
  onEnterGearMultiSelect: (id: string) => void = (id: string): void => {};
  onToggleMultiGearSelection: (id: string) => void = (id: string): void => {};
  onCancelGearMultiSelect: () => void = (): void => {};
  onOpenGenerateTripSheet: () => void = (): void => {};
  onBatchDeleteGears: (ids: string[]) => void = (ids: string[]): void => {};
  onBatchMoveGroup: (ids: string[], targetGroup: string) => void = (ids: string[], targetGroup: string): void => {};
  onAddGearsToTrip: (gearIds: string[], tripId: string) => void = (gearIds: string[], tripId: string): void => {};
  onAddGearsToNewTrip: (gearIds: string[]) => void = (gearIds: string[]): void => {};

  private numberOrZero(value: number | undefined): number {
    return value === undefined ? 0 : value;
  }

  private gearTripCount(item: GearItem): number {
    return item.tripCount === undefined ? 0 : item.tripCount;
  }

  private gearValueRatio(item: GearItem): number {
    if (item.price === undefined || item.weight === undefined || item.weight <= 0) {
      return 0;
    }
    return item.price / item.weight;
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
      // 按 categoryOrder 自定义顺序排
      const leftIdx = this.categoryOrder.indexOf(left.category);
      const rightIdx = this.categoryOrder.indexOf(right.category);
      const li = leftIdx >= 0 ? leftIdx : 9999;
      const ri = rightIdx >= 0 ? rightIdx : 9999;
      if (li !== ri) {
        return li - ri;
      }
      return left.category.localeCompare(right.category);
    });
    return sorted;
  }

  private activeCategories(): string[] {
    if (this.selectedGearCategories.length === 0 || this.selectedGearCategories.indexOf('全部') >= 0) {
      return ['全部'];
    }
    const categories: string[] = [];
    for (let index = 0; index < this.selectedGearCategories.length; index++) {
      const category = this.selectedGearCategories[index];
      if (category.length > 0 && categories.indexOf(category) < 0) {
        categories.push(category);
      }
    }
    if (categories.length === 0) {
      return ['全部'];
    }
    return categories;
  }

  private activeCategoryText(): string {
    const categories = this.activeCategories();
    if (categories.length === 0 || categories.indexOf('全部') >= 0) {
      return '全部';
    }
    if (categories.length === 1) {
      return categories[0];
    }
    if (categories.length === 2) {
      return categories[0] + ' +1';
    }
    return categories.length.toString() + '个分组';
  }

  private filteredGears(): GearItem[] {
    const filtered: GearItem[] = [];
    const keyword = this.gearSearchKeyword.trim().toLowerCase();
    const activeCategories = this.activeCategories();
    const showAllCategories = activeCategories.indexOf('全部') >= 0;
    for (let index = 0; index < this.gears.length; index++) {
      const item = this.gears[index];
      const note = item.note === undefined ? '' : item.note;
      const categoryMatched = showAllCategories || activeCategories.indexOf(item.category) >= 0;
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

  private allGearGroups(): string[] {
    const groups: string[] = [];
    for (let i = 0; i < this.gears.length; i++) {
      const cat = this.gears[i].category;
      if (cat.length > 0 && groups.indexOf(cat) < 0) {
        groups.push(cat);
      }
    }
    return groups;
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
    // 按 categoryOrder 排序
    if (this.gearSortMode === GEAR_SORT_GROUP && this.categoryOrder.length > 0) {
      groups.sort((a: string, b: string): number => {
        const ai = this.categoryOrder.indexOf(a);
        const bi = this.categoryOrder.indexOf(b);
        const aIdx = ai >= 0 ? ai : 9999;
        const bIdx = bi >= 0 ? bi : 9999;
        if (aIdx !== bIdx) {
          return aIdx - bIdx;
        }
        return a.localeCompare(b);
      });
    }
    return groups;
  }

  private displayGearGroups(): string[] {
    if (this.groupDragMode && this.groupReorderList.length > 0) {
      return this.groupReorderList;
    }
    return this.filteredGearGroups();
  }

  private filteredGearsByGroup(group: string): GearItem[] {
    const items = this.filteredGears();
    if (this.gearSortMode !== GEAR_SORT_GROUP) {
      return items;
    }
    return items.filter((item: GearItem) => item.category === group);
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

  private formatKg(weightGram: number): string {
    if (weightGram <= 0) {
      return '0kg';
    }
    return (Math.round(weightGram / 100) / 10).toString() + 'kg';
  }

  private targetInputText(): string {
    if (this.targetWeightGram <= 0) {
      return '10';
    }
    return (Math.round(this.targetWeightGram / 10) / 100).toString();
  }

  private hasMultiGearSelection(id: string): boolean {
    return this.selectedMultiGearIds.indexOf(id) >= 0;
  }

  private gearGroupCount(group: string): number {
    return this.filteredGearsByGroup(group).length;
  }

  private isGearGroupCollapsed(group: string): boolean {
    return this.collapsedGearGroups.indexOf(group) >= 0;
  }

  private isFirstGearGroup(group: string): boolean {
    const groups = this.filteredGearGroups();
    return groups.length > 0 && groups[0] === group;
  }

  private toggleGearGroupCollapse(group: string): void {
    const idx = this.collapsedGearGroups.indexOf(group);
    if (idx >= 0) {
      const next = this.collapsedGearGroups;
      next.splice(idx, 1);
      this.collapsedGearGroups = next;
      this.gearGroupExpandTrigger++;
    } else {
      this.collapsedGearGroups = this.collapsedGearGroups.concat([group]);
    }
    this.persistCollapsedGroups();
  }

  private gearMetaText(item: GearItem): string {
    let text = item.category;
    if (item.weight !== undefined) {
      text = text + ' · ' + item.weight.toString() + 'g';
    }
    if (item.price !== undefined) {
      text = text + ' · ¥' + item.price.toString();
    }
    return text;
  }

  private formatDateText(timestamp: number): string {
    const date = new Date(timestamp);
    return date.getFullYear().toString() + '-' + (date.getMonth() + 1).toString() + '-' + date.getDate().toString();
  }

  private gearSummaryText(): string {
    return this.gears.length.toString() + '件 · ' + this.formatKg(this.totalGearWeight()) +
      ' · ¥' + this.totalGearPrice().toString();
  }

  private openWeightEditor(): void {
    this.targetWeightInput = this.targetInputText();
    this.targetWeightError = '';
    this.showWeightEditor = true;
  }

  private closeWeightEditor(): void {
    this.showWeightEditor = false;
    this.targetWeightError = '';
  }

  private async saveTargetWeight(): Promise<void> {
    const value = parseFloat(this.targetWeightInput.trim());
    if (Number.isNaN(value) || value <= 0 || value > 100) {
      this.targetWeightError = '请输入 0-100kg 之间的目标重量';
      return;
    }
    const nextWeight = Math.round(value * 1000);
    this.targetWeightGram = nextWeight;
    this.closeWeightEditor();
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      await this.store.saveGearTargetWeight(nextWeight);
    } catch (error) {
    }
  }

  private gearTitleFontSize(): number {
    return 28 - this.gearScrollProgress() * 10;
  }

  private gearRingOpacity(): number {
    return Math.max(0, 1 - this.gearScrollProgress() * 2.5);
  }

  private gearRingScale(): number {
    return 1 - this.gearScrollProgress() * 0.4;
  }

  private gearPillOpacity(): number {
    return Math.max(0, 1 - this.gearScrollProgress() * 2);
  }

  private gearCollapsedOpacity(): number {
    const p = this.gearScrollProgress();
    if (p < 0.5) {
      return 0;
    }
    return Math.min(1, (p - 0.5) * 2);
  }

  private gearScrollProgress(): number {
    const range = GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED;
    if (range <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(1, this.gearScrollOffset / range));
  }

  // 计算目标装备所在分组在 List 中的 index（用于 scrollToIndex）
  private gearListIndex(targetId: string): number {
    let idx = 1; // index 0 是 top spacer
    const groups = this.filteredGearGroups();
    for (let g = 0; g < groups.length; g++) {
      if (!this.isGearGroupCollapsed(groups[g])) {
        const items = this.filteredGearsByGroup(groups[g]);
        for (let i = 0; i < items.length; i++) {
          if (items[i].id === targetId) {
            return idx; // 返回该分组卡片的 index
          }
        }
      }
      idx++; // 每个分组是一个 ListItem
    }
    return -1;
  }

  // 展开详情后滚动到该装备居中显示
  private scrollToExpandedGear(id: string): void {
    setTimeout(() => {
      const idx = this.gearListIndex(id);
      if (idx >= 0) {
        this.gearListScroller.scrollToIndex(idx, true, ScrollAlign.CENTER);
      }
    }, 50);
  }

  // 动态底部 spacer：确保内容少时仍可折叠 header，内容多时仅保留 TabBar 避让
  private bottomSpacerHeight(): number {
    const collapseRange = GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED;
    // 每个装备行约 52vp (44 content + 4*2 padding)，分组标题 28vp + 卡片间距 16vp
    const groups = this.filteredGearGroups();
    const estimatedContentHeight = this.filteredGears().length * 52 + groups.length * 44;
    // 如果内容自身足够多，不需要额外空间来触发折叠
    if (estimatedContentHeight > collapseRange) {
      return 80; // 仅 TabBar 避让
    }
    // 内容不够时，补足让 scroll 范围 ≥ collapseRange
    return collapseRange - estimatedContentHeight + 80;
  }

  // 渐进式模糊强度：0~0.3 无 | 0.3~1.0 线性增到 40
  private gearHeaderBlurRadius(): number {
    if (this.searchExpanded) {
      return 0;
    }
    const p = this.gearScrollProgress();
    if (p < 0.3) {
      return 0;
    }
    return Math.round(((p - 0.3) / 0.7) * 40);
  }

  // Header 动态高度：跟随滚动从 EXPANDED 收缩到 COLLAPSED
  private gearHeaderHeight(): number {
    if (this.searchExpanded) {
      return GEAR_HEADER_COLLAPSED; // 搜索时强制收缩 header
    }
    const p = this.gearScrollProgress();
    return GEAR_HEADER_EXPANDED - (GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED) * p;
  }

  // 渐进式背景色：PAGE_BG → BLUR_BG，alpha 从 00 到 CC 跟随 progress
  private gearHeaderBgColor(): string {
    if (this.searchExpanded) {
      return PAGE_BG;
    }
    const p = this.gearScrollProgress();
    if (p < 0.3) {
      return PAGE_BG; // #F8F9FA 全不透明背景
    }
    // 0.3~1.0 线性插值 alpha: 0x00 → 0xCC (204)
    const t = Math.min(1, (p - 0.3) / 0.7);
    const alpha = Math.round(t * 0xCC);
    const hex = alpha < 16 ? '0' + alpha.toString(16).toUpperCase() : alpha.toString(16).toUpperCase();
    return '#' + hex + 'F8F9FA';
  }

  // 顶部 spacer 高度：给 Header 腾出空间
  private topSpacerHeight(): number {
    if (this.multiSelectMode || this.searchExpanded) {
      return GEAR_HEADER_COLLAPSED;
    }
    return GEAR_HEADER_EXPANDED - 20; // 减去 List padding-top(6) + space(16) 的多余间距，消除灰色间隙
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Stack() {
          List({ space: 16, scroller: this.gearListScroller }) {
            ListItem() {
              Column()
                .width('100%')
                .height(this.topSpacerHeight())
            }
            if (this.gears.length === 0) {
              ListItem() {
                this.EmptyState();
              }
            } else if (this.filteredGears().length === 0) {
              ListItem() {
                this.EmptyText('未找到相关装备');
              }
            } else {
              ForEach(this.displayGearGroups(), (group: string) => {
                ListItem() {
                  this.GearGroupCard(group);
                }
                .transition(TransitionEffect.OPACITY.combine(
                  TransitionEffect.translate({ y: 8 })
                ).animation({ duration: 300, curve: curves.springMotion(0.35, 0.8) }))
              }, (group: string) => group)
            }
            ListItem() {
              Column()
                .width('100%')
                .height(this.bottomSpacerHeight())
            }
          }
          .width('100%')
          .height('100%')
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .enableScrollInteraction(!this.groupDragMode)
          .backgroundColor(Color.Transparent)
          .onDidScroll(() => {
            this.gearScrollOffset = this.gearListScroller.currentOffset().yOffset;
          })
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 6 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      this.CollapsingHeader();
      if (!this.multiSelectMode) {
        this.Fab();
      }
      if (this.showWeightEditor) {
        this.WeightTargetEditor();
      }

      // --- 分组拖拽浮动层 ---
      if (this.groupDragMode) {
        this.FloatingGroupCard()
      }

      // --- 拖拽覆盖层 ---
      if (this.dragMode) {
        // 背景遮罩 + 模糊
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .backdropBlur(20)
          .onClick(() => {
            this.cancelDrag();
          })

        // 底部行程托盘
        this.TripDropTray()

        // 浮动装备堆
        this.DragGearStack()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const newWidth = newArea.width as number;
      const newHeight = newArea.height as number;
      if (newWidth > 0 && newHeight > 0 &&
        (Math.abs(newWidth - this.screenWidth) > 1 || Math.abs(newHeight - this.screenHeight) > 1)) {
        const oldWidth = this.screenWidth;
        this.screenWidth = newWidth;
        this.screenHeight = newHeight;
        // 按比例映射 FAB X 到新屏幕宽度，保持相对边缘位置
        const fabSize = 50;
        const wasOnRight = (this.fabX + fabSize / 2) > oldWidth / 2;
        const targetX = wasOnRight ? newWidth - fabSize - 16 : 16;
        const maxY = newHeight - fabSize - 140;
        const targetY = Math.max(80, Math.min(maxY, this.fabY));
        this.getUIContext().animateTo({
          duration: 300,
          curve: curves.springMotion(0.3, 0.8)
        }, () => {
          this.fabX = targetX;
          this.fabY = targetY;
        });
      }
    })
    .gesture(
      SwipeGesture({ direction: SwipeDirection.Horizontal, speed: 80 })
        .onAction((event: GestureEvent) => {
          if (this.multiSelectMode && event.angle > -45 && event.angle < 45) {
            // 右滑退出多选
            this.onCancelGearMultiSelect();
          }
        })
    )
  }

  @Builder
  private CollapsingHeader() {
    if (this.multiSelectMode) {
      // 多选模式：固定收缩态，显示选中计数 + 操作按钮
      Row() {
        Text('已选 ' + this.selectedMultiGearIds.length.toString() + ' 件')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .fontFeature(FONT_FEATURE_TNUM)
          .layoutWeight(1)
        Button('生成清单')
          .height(32)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.selectedMultiGearIds.length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .enabled(this.selectedMultiGearIds.length > 0)
          .onClick(() => {
            this.onOpenGenerateTripSheet();
          })
        Button('取消')
          .height(32)
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
          .backgroundColor('#00000000')
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            this.onCancelGearMultiSelect();
          })
      }
      .width('100%')
      .height(GEAR_HEADER_COLLAPSED)
      .alignItems(VerticalAlign.Center)
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 6 })
      .backgroundColor(PAGE_BG)
      .position({ x: 0, y: 0 })
      .zIndex(10)
    } else {
      // 普通模式：可折叠 Header
      Stack({ alignContent: Alignment.TopStart }) {
        // 等高线视差装饰层（最底层）
        Shape() {
          Path()
            .commands(
              'M 0 60 C 30 55 60 65 90 58 C 120 51 150 62 180 56 C 210 50 240 60 270 54 C 300 48 330 58 360 52 ' +
              'M 0 120 C 40 112 80 125 120 115 C 160 105 200 118 240 110 C 280 102 320 115 360 108 ' +
              'M 0 180 C 35 172 70 182 105 175 C 140 168 175 178 210 170 C 245 162 280 174 315 166 C 340 160 355 168 360 165 ' +
              'M 0 240 C 45 232 90 244 135 235 C 180 226 225 238 270 230 C 315 222 345 234 360 228'
            )
            .stroke('#0A2D7D46')
            .strokeWidth(1)
            .fill('#00000000')
            .strokeLineCap(LineCapStyle.Round)
            .antiAlias(true)
        }
        .viewPort({ x: 0, y: 0, width: 360, height: 340 })
        .width('100%')
        .height(GEAR_HEADER_EXPANDED)
        .translate({ y: -(this.gearScrollOffset * 0.3) })
        .animation({ duration: 80, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.None)

        // 主内容层
        Column() {
          Row() {
            Text('我的装备库')
              .fontSize(this.gearTitleFontSize())
              .fontWeight(FontWeight.Bold)
              .fontColor(TEXT_MAIN)
              .animation({ duration: 80 })
            Text(this.gearSummaryText())
              .fontSize(13)
              .fontColor(TEXT_TERTIARY)
              .fontFeature(FONT_FEATURE_TNUM)
              .maxLines(1)
              .constraintSize({ maxWidth: 160 })
              .margin({ left: 8 })
              .opacity(this.gearCollapsedOpacity())
              .translate({ x: this.gearCollapsedOpacity() > 0 ? 0 : -12 })
              .animation({ duration: 260, curve: curves.springMotion(0.35, 0.85) })
            Blank()
            // 搜索按钮 / 搜索框：原地变形
            Row() {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(this.searchExpanded ? 16 : 20)
                .fontColor([this.gearSearchKeyword.length > 0 ? PRIMARY_COLOR : TEXT_SECONDARY])
                .margin({ left: this.searchExpanded ? 2 : 0, right: this.searchExpanded ? 6 : 0 })
              if (this.searchExpanded) {
                TextInput({ placeholder: '搜索装备', text: this.gearSearchKeyword })
                  .height(28)
                  .fontSize(14)
                  .fontColor(TEXT_MAIN)
                  .placeholderColor(TEXT_TERTIARY)
                  .backgroundColor('#00000000')
                  .padding({ left: 0, right: 0 })
                  .layoutWeight(1)
                  .defaultFocus(true)
                  .onChange((value: string) => {
                    this.onSearchChange(value);
                  })
                Text('取消')
                  .fontSize(13)
                  .fontColor(TEXT_SECONDARY)
                  .padding({ left: 8, right: 2 })
                  .onClick(() => {
                    this.getUIContext().animateTo({
                      duration: 350,
                      curve: curves.springMotion(0.35, 0.82)
                    }, () => {
                      this.searchExpanded = false;
                      this.onSearchChange('');
                    });
                  })
              }
            }
            .height(36)
            .width(this.searchExpanded ? undefined : 36)
            .layoutWeight(this.searchExpanded ? 1 : 0)
            .justifyContent(this.searchExpanded ? FlexAlign.Start : FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .padding(this.searchExpanded ? { left: 12, right: 10 } : { left: 0, right: 0 })
            .borderRadius(18)
            .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
              colorMode: ThemeColorMode.SYSTEM,
              adaptiveColor: AdaptiveColor.DEFAULT
            })
            .backgroundColor(this.searchExpanded ? '#B0FFFFFF' : PRIMARY_TINT_COLOR)
            .animation({ duration: 350, curve: curves.springMotion(0.35, 0.82) })
            .onClick(() => {
              if (!this.searchExpanded) {
                this.getUIContext().animateTo({
                  duration: 350,
                  curve: curves.springMotion(0.35, 0.82)
                }, () => {
                  this.searchExpanded = true;
                  this.gearListScroller.scrollTo({ xOffset: 0, yOffset: 0 });
                  this.gearScrollOffset = 0;
                });
              }
            })
            if (!this.searchExpanded) {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_up_and_down_square_portrait'))
                  .fontSize(18)
                  .fontColor([TEXT_SECONDARY])
              }
              .width(36)
              .height(36)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(PRIMARY_TINT_COLOR)
              .borderRadius(18)
              .margin({ left: 10 })
              .onClick(() => {
                this.onOpenSort();
              })
            }
          }
          .width('100%')
          .height(GEAR_HEADER_COLLAPSED)
          .alignItems(VerticalAlign.Center)
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 6 })

          if (this.gearScrollProgress() < 1) {
            Column() {
              Row({ space: 4 }) {
                Text(this.activeCategoryText())
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_COLOR)
                  .maxLines(1)
                SymbolGlyph($r('sys.symbol.chevron_down'))
                  .fontSize(12)
                  .fontColor([PRIMARY_COLOR])
              }
              .height(32)
              .padding({ left: 12, right: 12 })
              .backgroundColor(PRIMARY_TINT_COLOR)
              .borderRadius(16)
              .margin({ left: PAGE_PADDING, top: 6, bottom: 4 })
              .opacity(this.gearPillOpacity())
              .onClick(() => {
                this.onOpenFilterPanel();
              })

              WeightGauge({
                currentWeight: this.totalGearWeight(),
                targetWeight: this.targetWeightGram,
                gearCount: this.gears.length,
                totalPrice: this.totalGearPrice(),
                budget: this.gearBudget
              })
                .opacity(this.gearRingOpacity())
                .scale({ x: this.gearRingScale(), y: this.gearRingScale() })
            }
            .width('100%')
            .height((GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED) * (1 - this.gearScrollProgress()))
            .clip(true)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')

      }
      .width('100%')
      .height(this.gearHeaderHeight())
      .clip(true)
      .backgroundColor(this.gearHeaderBgColor())
      .backdropBlur(this.gearHeaderBlurRadius())
      .position({ x: 0, y: 0 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private MultiSelectBar() {
    Row({ space: 8 }) {
      Text('选中 ' + this.selectedMultiGearIds.length.toString() + ' 件')
        .fontSize(13)
        .fontColor(TEXT_MAIN)
        .fontFeature(FONT_FEATURE_TNUM)
      Blank()
      Button('移动分组')
        .height(32)
        .fontSize(12)
        .fontColor(this.selectedMultiGearIds.length === 0 ? '#CCCCCC' : TEXT_MAIN)
        .backgroundColor(this.selectedMultiGearIds.length === 0 ? '#F5F5F5' : '#F0F0F0')
        .enabled(this.selectedMultiGearIds.length > 0)
        .onClick(() => {
          this.showMoveGroupSheet = true;
        })
        .bindSheet($$this.showMoveGroupSheet, this.MoveGroupSheetContent(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          backgroundColor: CARD_BG
        })
      Button('删除')
        .height(32)
        .fontSize(12)
        .fontColor(this.selectedMultiGearIds.length === 0 ? '#CCCCCC' : DANGER_COLOR)
        .backgroundColor(this.selectedMultiGearIds.length === 0 ? '#F5F5F5' : '#FFF0F0')
        .enabled(this.selectedMultiGearIds.length > 0)
        .onClick(() => {
          this.onBatchDeleteGears(this.selectedMultiGearIds);
        })
      Button('生成清单')
        .height(32)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .backgroundColor(this.selectedMultiGearIds.length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .enabled(this.selectedMultiGearIds.length > 0)
        .onClick(() => {
          this.onOpenGenerateTripSheet();
        })
      Button('取消')
        .height(32)
        .fontSize(12)
        .fontColor(TEXT_TERTIARY)
        .backgroundColor('#00000000')
        .onClick(() => {
          this.onCancelGearMultiSelect();
        })
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 8 })
  }

  @Builder
  private MoveGroupSheetContent() {
    Column({ space: 12 }) {
      Text('移动到分组')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .padding({ top: 8 })
      ForEach(this.allGearGroups(), (group: string) => {
        Row() {
          Row()
            .width(3)
            .height(14)
            .backgroundColor(getGroupColor(group))
            .borderRadius(1.5)
            .margin({ right: 10 })
          Text(group)
            .fontSize(15)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16 })
        .borderRadius(12)
        .backgroundColor('#F8F9FA')
        .onClick(() => {
          this.onBatchMoveGroup(this.selectedMultiGearIds, group);
          this.showMoveGroupSheet = false;
        })
      }, (group: string) => group)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 34 })
  }


  @Builder
  private GearGroupCard(group: string) {
    Column() {
      // 分组标题行（轻量标签，在卡片外部）
      Row({ space: 6 }) {
        Row()
          .width(3)
          .height(14)
          .backgroundColor(this.gearSortMode === GEAR_SORT_GROUP ? getGroupColor(group) : PRIMARY_COLOR)
          .borderRadius(1.5)
        Text(group)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_SECONDARY)
          .layoutWeight(1)
        Text(this.gearGroupCount(group).toString())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
          .fontFeature(FONT_FEATURE_TNUM)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor([TEXT_TERTIARY])
          .rotate({ angle: this.isGearGroupCollapsed(group) ? -90 : 0 })
          .animation({ duration: 300, curve: curves.springMotion(0.22, 0.82) })
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 4, right: 4 })
      .scale({
        x: this.pressedGroupId === group ? 0.97 : 1.0,
        y: this.pressedGroupId === group ? 0.97 : 1.0
      })
      .animation({ duration: 200, curve: curves.springMotion(0.25, 0.7) })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedGroupId = group;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedGroupId = '';
        }
      })
      .onClick(() => {
        if (!this.groupDragMode) {
          this.toggleGearGroupCollapse(group);
        }
      })
      .gesture(
        GestureGroup(GestureMode.Sequence,
          LongPressGesture({ fingers: 1, repeat: false, duration: 300 })
            .onAction((event: GestureEvent) => {
              if (this.gearSortMode !== GEAR_SORT_GROUP || this.multiSelectMode || this.searchExpanded) {
                return;
              }
              this.enterGroupDrag(group, event.fingerList[0].globalY);
            }),
          PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 0 })
            .onActionUpdate((event: GestureEvent) => {
              if (this.groupDragMode) {
                this.updateGroupDrag(event.fingerList[0].globalY);
              }
            })
            .onActionEnd(() => {
              if (this.groupDragMode) {
                this.completeGroupDrag();
              }
            })
        )
      )

      // 分组内容卡片
      if (!this.isGearGroupCollapsed(group)) {
        Column() {
          ForEach(this.filteredGearsByGroup(group), (item: GearItem, index: number) => {
            this.GearRow(item);
            // 非最后一项加分割线
            if (index < this.filteredGearsByGroup(group).length - 1 && this.expandedGearId !== item.id) {
              Divider()
                .strokeWidth(0.5)
                .color(DIVIDER_COLOR)
                .margin({ left: 14, right: 14 })
            }
          }, (item: GearItem) => item.id)
        }
        .width('100%')
        .backgroundColor(CARD_BG)
        .borderRadius(14)
        .clip(true)
      }
    }
    .width('100%')
    .opacity(this.groupDragMode && this.groupDragGroup === group ? 0 : (this.groupDragMode ? 0.6 : 1.0))
    .animation({ duration: 200, curve: Curve.EaseOut })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const h = newArea.height as number;
      if (h > 0) {
        this.groupCardHeights.set(group, h);
      }
    })
  }

  @Builder
  private GearNameText(name: string) {
    if (this.gearSearchKeyword.trim().length === 0) {
      Text(name)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text() {
        ForEach(this.splitByKeyword(name, this.gearSearchKeyword.trim()), (segment: string, index: number) => {
          if (segment.toLowerCase() === this.gearSearchKeyword.trim().toLowerCase()) {
            Span(segment)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY_COLOR)
          } else {
            Span(segment)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(TEXT_MAIN)
          }
        }, (segment: string, index: number) => index.toString())
      }
      .layoutWeight(1)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  private splitByKeyword(text: string, keyword: string): string[] {
    if (keyword.length === 0) {
      return [text];
    }
    const parts: string[] = [];
    const lowerText = text.toLowerCase();
    const lowerKey = keyword.toLowerCase();
    let startIndex = 0;
    while (startIndex < text.length) {
      const foundIndex = lowerText.indexOf(lowerKey, startIndex);
      if (foundIndex < 0) {
        parts.push(text.substring(startIndex));
        break;
      }
      if (foundIndex > startIndex) {
        parts.push(text.substring(startIndex, foundIndex));
      }
      parts.push(text.substring(foundIndex, foundIndex + keyword.length));
      startIndex = foundIndex + keyword.length;
    }
    return parts;
  }

  @Builder
  private GearRow(item: GearItem) {
    if (this.multiSelectMode) {
      // 多选模式：紧凑行 + Checkbox
      Column() {
        Row({ space: 10 }) {
          Checkbox()
            .select(this.hasMultiGearSelection(item.id))
            .width(18)
            .height(18)
            .onChange((checked: boolean) => {
              this.onToggleMultiGearSelection(item.id);
            })
            .transition(TransitionEffect.OPACITY.combine(
              TransitionEffect.translate({ x: -12 })
            ).animation({ duration: 260, curve: curves.springMotion(0.3, 0.8) }))
          this.GearNameText(item.name)
          if (item.weight !== undefined && item.weight > 0) {
            Text(item.weight.toString() + 'g')
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
              .fontFeature(FONT_FEATURE_TNUM)
          }
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 4, bottom: 4 })
      .backgroundColor(this.hasMultiGearSelection(item.id) ? LIGHT_PRIMARY_COLOR : CARD_BG)
      .opacity(this.dragMode && this.hasMultiGearSelection(item.id) ? 0.4 : 1)
      .animation({ duration: 200, curve: Curve.EaseOut })
      .onClick(() => {
        this.onToggleMultiGearSelection(item.id);
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedGearId = item.id;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedGearId = '';
        }
      })
      .gesture(
        GestureGroup(GestureMode.Sequence,
          LongPressGesture({ fingers: 1, repeat: false, duration: 400 })
            .onAction((event: GestureEvent) => {
              if (this.hasMultiGearSelection(item.id)) {
                this.enterDragMode(event.fingerList[0].globalX, event.fingerList[0].globalY);
              }
            }),
          PanGesture({ fingers: 1, distance: 0 })
            .onActionUpdate((event: GestureEvent) => {
              if (this.dragMode) {
                this.updateDragPosition(event.fingerList[0].globalX, event.fingerList[0].globalY);
              }
            })
            .onActionEnd(() => {
              if (this.dragMode) {
                this.completeDrag();
              }
            })
            .onActionCancel(() => {
              if (this.dragMode) {
                this.cancelDrag();
              }
            })
        )
      )
    } else {
      // 普通模式：紧凑行 + 左滑删除
      Stack() {
        // 底层：删除按钮（仅在侧滑时渲染，避免 rest 态红色暴露）
        if (this.swipedGearId === item.id) {
          Row() {
            Blank()
            Text('删除')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .width(70)
              .height('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(DANGER_COLOR)
              .onClick(() => {
                this.swipedGearId = '';
                this.swipeOffsetX = 0;
                this.onConfirmDeleteGear(item);
              })
          }
          .width('100%')
          .height('100%')
        }

        // 上层：内容行
        Column() {
          Row({ space: 10 }) {
            this.GearNameText(item.name)
            if (item.weight !== undefined && item.weight > 0) {
              Text(item.weight.toString() + 'g')
                .fontSize(12)
                .fontColor(TEXT_TERTIARY)
                .fontFeature(FONT_FEATURE_TNUM)
            }
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(12)
              .fontColor([ARROW_COLOR])
              .rotate({ angle: this.expandedGearId === item.id ? 180 : 0 })
              .animation({ duration: 300, curve: curves.springMotion(0.22, 0.82) })
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (this.swipedGearId === item.id) {
              // 已滑开状态下点击 = 收回
              this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion(0.3, 0.85) }, () => {
                this.swipedGearId = '';
                this.swipeOffsetX = 0;
              });
              return;
            }
            const isExpanding = this.expandedGearId !== item.id;
            this.onToggleGearExpanded(item.id);
            if (isExpanding) {
              this.scrollToExpandedGear(item.id);
            }
          })
          if (this.expandedGearId === item.id) {
            this.Detail(item);
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 4, bottom: 4 })
        .backgroundColor(this.pressedGearId === item.id ? '#F5F5F5' : CARD_BG)
        .animation({ duration: 150, curve: Curve.EaseOut })
        .translate({ x: this.swipedGearId === item.id ? this.swipeOffsetX : 0 })
        .animation({ duration: 0 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedGearId = item.id;
            // 点击其他行时收回已滑开的行
            if (this.swipedGearId !== '' && this.swipedGearId !== item.id) {
              this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion(0.3, 0.85) }, () => {
                this.swipedGearId = '';
                this.swipeOffsetX = 0;
              });
            }
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedGearId = '';
          }
        })
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 10 })
            .onActionUpdate((event: GestureEvent) => {
              const offsetX = event.offsetX;
              if (this.swipedGearId === item.id) {
                // 已滑开状态：在 -70 基础上继续滑动
                const newOffset = Math.min(0, Math.max(-140, -70 + offsetX));
                this.swipeOffsetX = newOffset;
              } else {
                // 未滑开：只允许左滑
                const newOffset = Math.min(0, Math.max(-100, offsetX));
                this.swipeOffsetX = newOffset;
                if (newOffset < -5) {
                  this.swipedGearId = item.id;
                }
              }
            })
            .onActionEnd((event: GestureEvent) => {
              // 判断是否吸附到打开状态
              if (this.swipeOffsetX < -35) {
                this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion(0.3, 0.85) }, () => {
                  this.swipeOffsetX = -70;
                });
              } else {
                this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion(0.3, 0.85) }, () => {
                  this.swipedGearId = '';
                  this.swipeOffsetX = 0;
                });
              }
            })
            .onActionCancel(() => {
              this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion(0.3, 0.85) }, () => {
                if (this.swipeOffsetX < -35) {
                  this.swipeOffsetX = -70;
                } else {
                  this.swipedGearId = '';
                  this.swipeOffsetX = 0;
                }
              });
            })
        )
        .bindContextMenu(this.GearContextMenu(item), ResponseType.LongPress, {
          preview: this.GearPreviewCard(item),
          previewAnimationOptions: { scale: [0.92, 1.05] },
          transition: TransitionEffect.asymmetric(
            TransitionEffect.scale({ x: 0.9, y: 0.9 })
              .combine(TransitionEffect.OPACITY)
              .animation({ curve: curves.springMotion(0.35, 0.78) }),
            TransitionEffect.scale({ x: 0.95, y: 0.95 })
              .combine(TransitionEffect.OPACITY)
              .animation({ curve: curves.springMotion(0.28, 0.85) })
          ),
          placement: Placement.Bottom,
          borderRadius: 20
        })
      }
      .width('100%')
      .clip(true)
    }
  }

  @Builder
  private GearPreviewCard(item: GearItem) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Row()
          .width(4)
          .height(28)
          .borderRadius(2)
          .backgroundColor(getGroupColor(item.category))
        Text(item.name)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        this.PreviewLine('分组', item.category)
        this.PreviewLine('重量', item.weight === undefined ? '未填写' : item.weight.toString() + 'g')
        this.PreviewLine('价格', item.price === undefined ? '未填写' : '¥' + item.price.toString())
        this.PreviewLine('出行', this.gearTripCount(item) > 0 ? '×' + this.gearTripCount(item).toString() : '未出行')
        if (item.note !== undefined && item.note.length > 0) {
          this.PreviewLine('备注', item.note)
        }
        this.PreviewLine('添加', this.formatDateText(item.createdAt))
      }
      .width('100%')
    }
    .width('72%')
    .constraintSize({ maxWidth: 320, minWidth: 240 })
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
    .shadow({ radius: 24, color: '#1A000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  private PreviewLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(TEXT_TERTIARY)
        .width(40)
      Text(value)
        .fontSize(13)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private GearContextMenu(item: GearItem) {
    Menu() {
      MenuItem({ content: '编辑', labelInfo: '' })
        .onClick(() => {
          this.onOpenEditGear(item);
        })
      MenuItem({ content: '多选', labelInfo: '' })
        .onClick(() => {
          this.onEnterGearMultiSelect(item.id);
        })
      MenuItem({ content: '删除', labelInfo: '' })
        .contentFontColor(DANGER_COLOR)
        .onClick(() => {
          this.onConfirmDeleteGear(item);
        })
    }
  }

  @Builder
  private Detail(item: GearItem) {
    Column({ space: 8 }) {
      Divider()
        .strokeWidth(1)
        .color(DIVIDER_COLOR)
      this.DetailLine('分组', item.category);
      this.DetailLine('重量', item.weight === undefined ? '未填写' : item.weight.toString() + 'g');
      this.DetailLine('价格', item.price === undefined ? '未填写' : '¥' + item.price.toString());
      this.DetailLine('备注', item.note === undefined || item.note.length === 0 ? '未填写' : item.note);
      this.DetailLine('添加时间', this.formatDateText(item.createdAt));
      this.DetailLine('出行次数', '×' + this.gearTripCount(item).toString());
    }
    .width('100%')
    .padding({ top: 12 })
  }

  @Builder
  private DetailLine(label: string, value: string) {
    Row() {
      Text(label + '：')
        .fontSize(12)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(12)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private DeleteAction(item: GearItem) {
    Row() {
      Text('删除')
        .fontSize(14)
        .fontColor('#FFFFFF')
    }
    .height(56)
    .padding({ left: 18, right: 18 })
    .margin({ left: 10 })
    .backgroundColor(DANGER_COLOR)
    .borderRadius(12)
    .onClick(() => {
      this.onConfirmDeleteGear(item);
    })
  }

  @Builder
  private Fab() {
    Column() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(24)
        .fontColor([PRIMARY_COLOR])
    }
    .width(50)
    .height(50)
    .borderRadius(25)
    .backgroundColor('#B0FFFFFF')
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 16, color: '#1A2D7D46', offsetX: 0, offsetY: 6 })
    .position({ x: this.fabX, y: this.fabY })
    .scale({ x: this.fabDragging ? 1.08 : 1, y: this.fabDragging ? 1.08 : 1 })
    .gesture(
      PanGesture({ fingers: 1, distance: 5 })
        .onActionStart(() => {
          this.fabStartX = this.fabX;
          this.fabStartY = this.fabY;
          this.getUIContext().animateTo({
            duration: 150, curve: Curve.EaseOut
          }, () => {
            this.fabDragging = true;
          });
        })
        .onActionUpdate((event: GestureEvent) => {
          this.fabX = this.fabStartX + event.offsetX;
          this.fabY = this.fabStartY + event.offsetY;
        })
        .onActionEnd(() => {
          this.getUIContext().animateTo({
            duration: 150, curve: Curve.EaseOut
          }, () => {
            this.fabDragging = false;
          });
          this.snapFabToEdge();
        })
    )
    .onClick(() => {
      if (!this.fabDragging) {
        this.onOpenAddGear();
      }
    })
  }

  @Builder
  private WeightTargetEditor() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .backdropBlur(20)
        .onClick(() => {
          this.closeWeightEditor();
        })

      Column({ space: 16 }) {
        Row() {
          Text('设置目标重量')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Blank()
          Row() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([TEXT_SECONDARY])
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.closeWeightEditor();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          TextInput({ text: this.targetWeightInput, placeholder: '例如 8.5' })
            .type(InputType.Number)
            .height(48)
            .fontSize(16)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_TERTIARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.targetWeightInput = value;
              this.targetWeightError = '';
            })
          Text('kg')
            .fontSize(15)
            .fontColor(TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.targetWeightError.length > 0) {
          Text(this.targetWeightError)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Row({ space: 12 }) {
          Button('取消')
            .height(44)
            .fontSize(14)
            .fontColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .layoutWeight(1)
            .onClick(() => {
              this.closeWeightEditor();
            })
          Button('确认')
            .height(44)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(12)
            .layoutWeight(1)
            .onClick(() => {
              this.saveTargetWeight();
            })
        }
        .width('100%')
      }
      .width('84%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .backgroundColor(CARD_BG)
      .borderRadius(24)
      .shadow({ radius: 24, color: '#14000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private EmptyState() {
    Column({ space: 12 }) {
      EmptyIllustration({ type: 'gear' })
      Text('还没有装备，添加第一件吧')
        .fontSize(14)
        .fontColor(TEXT_TERTIARY)
      Button('添加装备')
        .height(44)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY_COLOR)
        .padding({ left: 24, right: 24 })
        .borderRadius(22)
        .onClick(() => {
          this.onOpenAddGear();
        })
    }
    .width('100%')
    .height(260)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(CARD_BG)
    .borderRadius(16)
  }

  @Builder
  private EmptyText(message: string) {
    Text(message)
      .fontSize(14)
      .fontColor(TEXT_TERTIARY)
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding(18)
      .backgroundColor(CARD_BG)
      .borderRadius(16)
  }

  // --- 行程托盘 ---
  @Builder
  private TripDropTray() {
    Column() {
      // 顶部拖拽指示器
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#33000000')
        .margin({ top: 10, bottom: 6 })

      // 标题行
      Row() {
        Text('拖入行程')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
        Text(' · ' + this.checklists.length.toString() + ' 个')
          .fontSize(13)
          .fontColor(TEXT_TERTIARY)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 12 })

      // 横向行程卡片列表
      Scroll(this.tripTrayScroller) {
        Row({ space: 12 }) {
          ForEach(this.checklists, (trip: TripChecklist) => {
            this.TripCard(trip)
          }, (trip: TripChecklist) => trip.id)

          // 新建行程卡片
          Column({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(24)
              .fontColor([this.dragOverTripId === '__new_trip__' ? '#FFFFFF' : PRIMARY_COLOR])
            Text('新建')
              .fontSize(12)
              .fontColor(this.dragOverTripId === '__new_trip__' ? '#FFFFFF' : TEXT_SECONDARY)
          }
          .width(100)
          .height(80)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(12)
          .backgroundColor(this.dragOverTripId === '__new_trip__' ? PRIMARY_COLOR : '#00000000')
          .border({
            width: 1.5,
            color: this.dragOverTripId === '__new_trip__' ? PRIMARY_COLOR : TEXT_TERTIARY,
            style: this.dragOverTripId === '__new_trip__' ? BorderStyle.Solid : BorderStyle.Dashed
          })
          .scale({
            x: this.tripCardScale('__new_trip__'),
            y: this.tripCardScale('__new_trip__')
          })
          .translate({ y: this.tripCardLift('__new_trip__') })
          .animation({ duration: 160, curve: Curve.EaseOut })
          .onAreaChange((_old: Area, area: Area) => {
            const pos = area.globalPosition as Position;
            this.updateTripCardArea('__new_trip__',
              pos.x as number, pos.y as number,
              area.width as number, area.height as number);
          })
        }
        .padding({ left: 20, right: 20 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(96)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#E8FFFFFF')
    .backdropBlur(40)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({ radius: 20, color: '#1A000000', offsetX: 0, offsetY: -6 })
    .position({ x: 0, y: this.showTripTray ? this.screenHeight - 200 : this.screenHeight })
    .animation({ duration: 350, curve: curves.springMotion(0.35, 0.8) })
  }

  @Builder
  private TripCard(trip: TripChecklist) {
    Column({ space: 4 }) {
      Text(trip.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.dragOverTripId === trip.id ? '#FFFFFF' : TEXT_MAIN)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(trip.items.length.toString() + ' 件装备')
        .fontSize(11)
        .fontColor(this.dragOverTripId === trip.id ? '#CCFFFFFF' : TEXT_TERTIARY)
    }
    .width(100)
    .height(80)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 10, right: 10 })
    .borderRadius(12)
    .backgroundColor(this.dragOverTripId === trip.id ? PRIMARY_COLOR : CARD_BG)
    .shadow({ radius: this.dragOverTripId === trip.id ? 16 : 4, color: '#0A000000', offsetX: 0, offsetY: 2 })
    .scale({
      x: this.tripCardScale(trip.id),
      y: this.tripCardScale(trip.id)
    })
    .translate({ y: this.tripCardLift(trip.id) })
    .animation({ duration: 160, curve: Curve.EaseOut })
    .onAreaChange((_old: Area, area: Area) => {
      const pos = area.globalPosition as Position;
      this.updateTripCardArea(trip.id,
        pos.x as number, pos.y as number,
        area.width as number, area.height as number);
    })
  }

  private updateTripCardArea(id: string, x: number, y: number, w: number, h: number): void {
    const area: TripCardArea = { id: id, x: x, y: y, w: w, h: h };
    const idx = this.tripCardAreas.findIndex(a => a.id === id);
    if (idx >= 0) {
      this.tripCardAreas[idx] = area;
    } else {
      this.tripCardAreas.push(area);
    }
  }

  // 磁吸效果：计算卡片基于手指距离的 proximity (0~1)
  private tripCardProximity(id: string): number {
    if (!this.dragMode) {
      return 0;
    }
    const area = this.tripCardAreas.find(a => a.id === id);
    if (area === undefined) {
      return 0;
    }
    const centerX = area.x + area.w / 2;
    const centerY = area.y + area.h / 2;
    const dx = this.dragX - centerX;
    const dy = this.dragY - centerY;
    const distance = Math.sqrt(dx * dx + dy * dy);
    const threshold = 140; // 影响半径 vp
    return Math.max(0, 1 - distance / threshold);
  }

  // 基于 proximity 的 scale: 1.0 ~ 1.12
  private tripCardScale(id: string): number {
    if (this.dragOverTripId === id) {
      return 1.1;
    }
    return 1 + 0.1 * this.tripCardProximity(id);
  }

  // 基于 proximity 的 translateY: 0 ~ -10vp (向上涌起)
  private tripCardLift(id: string): number {
    if (this.dragOverTripId === id) {
      return -10;
    }
    return -8 * this.tripCardProximity(id);
  }

  // --- 浮动装备堆 ---
  @Builder
  private DragGearStack() {
    Row({ space: 6 }) {
      Text(this.dragGearFirstName())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.selectedMultiGearIds.length > 1) {
        Text('×' + this.selectedMultiGearIds.length.toString())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(PRIMARY_COLOR)
          .borderRadius(10)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
    }
    .width(140)
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#EEFFFFFF')
    .backdropBlur(20)
    .borderRadius(12)
    .shadow({ radius: 20, color: '#28000000', offsetX: 0, offsetY: 6 })
    .rotate({ angle: -2 })
    .position({ x: this.dragX - 70, y: this.dragY - 56 })
    .animation({ duration: 0 })
  }

  private dragGearFirstName(): string {
    if (this.selectedMultiGearIds.length > 0) {
      const firstId = this.selectedMultiGearIds[0];
      const gear = this.gears.find(g => g.id === firstId);
      if (gear !== undefined) {
        return gear.name;
      }
    }
    return '装备';
  }

  // ===== 分组拖拽排序 =====

  private enterGroupDrag(group: string, fingerY: number): void {
    // 初始化拖拽
    this.groupDragGroup = group;
    this.groupDragY = fingerY;
    this.groupDragOffsetY = 0;
    // 快照当前分组顺序
    this.groupReorderList = this.filteredGearGroups().slice();
    // 进入拖拽态
    this.groupDragMode = true;
    // 触觉反馈
    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: 'touch' });
    } catch (e) {
      // 静默
    }
  }

  private updateGroupDrag(fingerY: number): void {
    this.groupDragY = fingerY;
    // 碰撞检测：计算当前拖拽分组应该在列表中的位置
    const currentIdx = this.groupReorderList.indexOf(this.groupDragGroup);
    if (currentIdx < 0) {
      return;
    }
    // 计算各分组的累积 Y 位置
    let accumulatedY = 0;
    for (let i = 0; i < this.groupReorderList.length; i++) {
      const g = this.groupReorderList[i];
      const h = this.groupCardHeights.get(g) ?? 80;
      const midY = accumulatedY + h / 2;
      if (i !== currentIdx && g !== this.groupDragGroup) {
        // 判断手指是否越过此分组的中线
        const dragCenterY = this.groupDragY - this.groupDragOffsetY;
        if (currentIdx < i && dragCenterY > midY) {
          // 向下移动：animateTo 驱动让位动画
          this.getUIContext().animateTo({
            duration: 300,
            curve: curves.springMotion(0.35, 0.8)
          }, () => {
            this.groupReorderList.splice(currentIdx, 1);
            this.groupReorderList.splice(i, 0, this.groupDragGroup);
          });
          // 棘轮振动反馈
          try {
            vibrator.startVibration({ type: 'time', duration: 20 }, { usage: 'touch' });
          } catch (e) { /* 静默 */ }
          return;
        } else if (currentIdx > i && dragCenterY < midY) {
          // 向上移动：animateTo 驱动让位动画
          this.getUIContext().animateTo({
            duration: 300,
            curve: curves.springMotion(0.35, 0.8)
          }, () => {
            this.groupReorderList.splice(currentIdx, 1);
            this.groupReorderList.splice(i, 0, this.groupDragGroup);
          });
          // 棘轮振动反馈
          try {
            vibrator.startVibration({ type: 'time', duration: 20 }, { usage: 'touch' });
          } catch (e) { /* 静默 */ }
          return;
        }
      }
      accumulatedY += h + 16; // 16 = list space
    }
  }

  private completeGroupDrag(): void {
    // 保存新顺序到 categoryOrder
    this.categoryOrder = this.groupReorderList.slice();
    this.persistCategoryOrder();
    // 退出拖拽态
    animateTo({
      duration: 300,
      curve: curves.springMotion(0.35, 0.8)
    }, () => {
      this.groupDragMode = false;
      this.groupDragGroup = '';
      this.groupReorderList = [];
    });
    // 振动确认
    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: 'touch' });
    } catch (e) {
      // 静默
    }
  }

  @Builder
  private FloatingGroupCard() {
    Column() {
      // 分组标题行（复制 GearGroupCard 的 header）
      Row({ space: 6 }) {
        Row()
          .width(3)
          .height(14)
          .backgroundColor(getGroupColor(this.groupDragGroup))
          .borderRadius(1.5)
        Text(this.groupDragGroup)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_SECONDARY)
          .layoutWeight(1)
        Text(this.gearGroupCount(this.groupDragGroup).toString())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
          .fontFeature(FONT_FEATURE_TNUM)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor([TEXT_TERTIARY])
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 4, right: 4 })

      // 分组内容卡片
      if (!this.isGearGroupCollapsed(this.groupDragGroup)) {
        Column() {
          ForEach(this.filteredGearsByGroup(this.groupDragGroup), (item: GearItem, index: number) => {
            this.GearRow(item);
            if (index < this.filteredGearsByGroup(this.groupDragGroup).length - 1 &&
              this.expandedGearId !== item.id) {
              Divider()
                .strokeWidth(0.5)
                .color(DIVIDER_COLOR)
                .margin({ left: 14, right: 14 })
            }
          }, (item: GearItem) => 'float_' + item.id)
        }
        .width('100%')
        .backgroundColor(CARD_BG)
        .borderRadius(14)
        .clip(true)
      }
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
    .scale({ x: 1.03, y: 1.03 })
    .rotate({ angle: -1 })
    .shadow({ radius: 24, color: '#30000000', offsetX: 0, offsetY: 8 })
    .position({ x: 0, y: this.groupDragY - (this.groupCardHeights.get(this.groupDragGroup) ?? 80) / 2 })
    .animation({ duration: 0 })
    .zIndex(100)
    .hitTestBehavior(HitTestMode.None)
  }
}
