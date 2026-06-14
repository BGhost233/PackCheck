import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import {
  SPRING_SWIPE_RESET, SPRING_FAB_SNAP, SPRING_GENERAL, SPRING_SEARCH,
  SPRING_CHEVRON, SPRING_PRESS, SPRING_CEREMONY_FLIP, SPRING_CONTEXT_EXIT,
  SPRING_TRAY_CARD, SPRING_SCROLL,
  DURATION_TICK, DURATION_FAST,
  DURATION_CEREMONY_SHAKE,
  DURATION_NONE,
  PRESS_SCALE_DOWN, PRESS_SCALE_REST,
  CURVE_LINEAR,
  STAGGER_OFFSET_Y, staggerDelay
} from '../constants/AnimationTokens';
import { HeadCollapseController } from '../utils/HeadCollapseController';
import { hapticTime } from '../utils/HapticUtils';
import { hdsEffect } from '@kit.UIDesignKit';
import { CATEGORY_ALL, GearItem, TripChecklist } from '../models/PackModels';
import { PackStore } from '../services/PackStore';
import { computeGearTripCount } from '../services/FootprintService';
import { buildGearTripCountMap } from '../services/FootprintService';
import { computeFootprint, Footprint, LongestCompanion } from '../services/FootprintService';
import { numberOrZero, gearValueRatio, gearSortLabel, totalGearWeight, totalGearPrice } from '../services/GearService';
import {
  ARROW_COLOR,
  CARD_BG,
  CARD_PADDING,
  CHIP_RADIUS,
  DANGER_COLOR,
  DANGER_TINT,
  DISABLED_COLOR,
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
  GLASS_BG,
  GLASS_BG_LIGHT,
  GLASS_BG_MEDIUM,
  GROUP_HEADER_BG,
  LIGHT_PRIMARY_COLOR,
  OVERLAY_DIM,
  OVERLAY_MASK,
  PAGE_BG,
  PAGE_PADDING,
  PRIMARY_COLOR,
  PRIMARY_SHADOW,
  PRIMARY_TINT_COLOR,
  SHADOW_DEFAULT,
  SHADOW_LIGHT,
  SHADOW_MEDIUM,
  SHADOW_SUBTLE,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  TRANSPARENT,
  WHITE,
  WHITE_SECONDARY,
  AMBER_ACCENT
} from '../constants/DesignTokens';
import { getGroupColor } from '../utils/ColorUtils';
import { GearEmptyState } from './gear/GearEmptyState';
import { GearEmptyText } from './gear/GearEmptyText';
import { GearFootprintRow } from './gear/GearFootprintRow';

interface TripCardArea {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

@Component
export struct GearPage {
  @Prop @Watch('onGearDataChange') gears: GearItem[] = [];
  @Prop selectedGearCategories: string[] = [CATEGORY_ALL];
  @Prop gearSearchKeyword: string = '';
  @Prop gearSortMode: string = GEAR_SORT_GROUP;
  @Prop expandedGearId: string = '';
  @Prop multiSelectMode: boolean = false;
  @Prop selectedMultiGearIds: string[] = [];
  @Prop @Watch('onSwipeResetNonceChange') swipeResetNonce: number = 0;

  // 人生足迹精简聚合（装备库顶部黄金区，提纲 §3.4）
  @State private footprintVm: Footprint = {
    tripCount: 0, totalDistanceKm: 0, totalAscentM: 0, totalDurationHours: 0,
    maxAltitude: 0, placeCount: 0, gearCount: 0, recentTrips: [],
  };
  // gear id → 出行次数预计算 Map（避免 O(trips×items) 重复遍历）
  @State private gearTripCountMap: Map<string, number> = new Map();

@State private pressedGearId: string = '';
@State private swipedGearId: string = '';
@State private swipeOffsetX: number = 0;
@State private searchExpanded: boolean = false;
  @State private fabX: number = -1; // -1 表示未初始化，使用默认右下角位置
  @State private fabY: number = -1;
  @State private fabDragging: boolean = false;
  private fabStartX: number = 0;
  private fabStartY: number = 0;
  // 全屏沉浸：状态栏高度由 EntryAbility/Index 通过 AppStorage 全局下发，折叠头顶部据此避让。
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // head 折叠进度镜像（0=全展开，1=全折叠）。
  //   ⚠️ 刷新陷阱：render 必须读此 @State（非 controller.progress()），controller.onChange 推动更新。
  @State private gearHeadProgress: number = 0;
  @State private gearHeadSnapping: boolean = false;
  @State private collapsedGearGroups: string[] = [];
  @State private gearGroupExpandTrigger: number = 0;
  @State private categoryOrder: string[] = [];

    @State private pressedGroupId: string = '';
  @State private pressedSortBtn: boolean = false;
  @State private pressedFilterPill: boolean = false;
  @State private pressedSearchBtn: boolean = false;
  @State private pressedCancelText: boolean = false;
  @State private listEntered: boolean = false;

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
  @Prop @Watch('onGearDataChange') checklists: TripChecklist[] = [];
  private store: PackStore = new PackStore();
  private gearListScroller: Scroller = new Scroller();

  // 统一折叠控制器（overlay 范式：header 定高浮在 List 上、靠内部元素变形）。
  //   只接管「滚动数学」：progress 计算 + 跟手 + 松手就近吸附（补齐原本缺失的 onScrollStop）。
  //   collapseDistance = EXPANDED-COLLAPSED。锁定态（searchExpanded/multiSelect）的高度/背景/模糊特判均保留在各函数内（是高度自定义视觉，不属于「折叠」语义）。
  private headController: HeadCollapseController = new HeadCollapseController({
    collapseDistance: GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED,
    enableSnap: true,
    getUIContext: () => this.getUIContext(),
    onChange: (progress: number, snapping: boolean) => {
      this.gearHeadSnapping = snapping;
      this.gearHeadProgress = progress;
    }
  });
  private tripTrayScroller: Scroller = new Scroller();
  private trayAutoScrollTimer: number = -1;
  private screenWidth: number = 360; // fallback
  private screenHeight: number = 780;
  private isAlive: boolean = true;

  private onGearDataChange(): void {
    if (this.isAlive) {
      this.refreshFootprint();
    }
  }

  private onSwipeResetNonceChange(): void {
    if (this.swipedGearId !== '') {
      this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
        this.swipedGearId = '';
        this.swipeOffsetX = 0;
      });
    }
  }

  aboutToAppear(): void {
    this.isAlive = true;
    // 获取屏幕尺寸（vp）
    try {
      const defaultDisplay = display.getDefaultDisplaySync();
      this.screenWidth = px2vp(defaultDisplay.width);
      this.screenHeight = px2vp(defaultDisplay.height);
    } catch (e) {
      // fallback
    }
    // 人生足迹聚合
    this.refreshFootprint();
    // 初始位置：右下角
    this.fabX = this.screenWidth - 50 - 16;
    this.fabY = this.screenHeight - 50 - 160; // 留出 TabBar 空间
    // 恢复折叠状态 + 分组顺序
    this.loadCollapsedGroups();
    this.loadCategoryOrder();
    // 触发列表错落入场
    setTimeout(() => {
      this.listEntered = true;
    }, 20);
  }

  // 人生足迹聚合
  private refreshFootprint(): void {
    this.footprintVm = computeFootprint(this.checklists, this.gears);
    // 预计算 gear→出行次数 map，渲染/排序时查表无需遍历
    this.gearTripCountMap = buildGearTripCountMap(this.checklists);
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    this.stopTrayAutoScroll();
    // 退出拖拽态：清理可能残留的拖拽动画状态
    if (this.dragMode) {
      this.dragMode = false;
      this.showTripTray = false;
      this.dragOverTripId = '';
    }
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
      curve: SPRING_FAB_SNAP()
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
    hapticTime(30);
    // 弹出托盘 + 背景模糊
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
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
        hapticTime(15);
      }
    }
    // 动态边缘滚动：越靠近边缘速度越快，中间区域不滚动
    const edgeZone = 100; // 边缘触发区宽度 vp
    const minSpeed = 2;
    const maxSpeed = 12;
    if (this.showTripTray) {
      const leftDist = x; // 距离左边缘
      const rightDist = this.screenWidth - x; // 距离右边缘
      if (leftDist < edgeZone) {
        // 左边缘：越靠左越快
        const t = 1 - leftDist / edgeZone; // 0~1，越靠边越大
        const speed = minSpeed + (maxSpeed - minSpeed) * t * t; // 平方加速
        this.startTrayAutoScroll(-speed);
      } else if (rightDist < edgeZone) {
        // 右边缘：越靠右越快
        const t = 1 - rightDist / edgeZone;
        const speed = minSpeed + (maxSpeed - minSpeed) * t * t;
        this.startTrayAutoScroll(speed);
      } else {
        this.stopTrayAutoScroll();
      }
    } else {
      this.stopTrayAutoScroll();
    }
  }

  private trayScrollSpeed: number = 0;

  private startTrayAutoScroll(speed: number): void {
    this.trayScrollSpeed = speed;
    if (this.trayAutoScrollTimer >= 0) {
      return; // 已在滚动，只更新速度
    }
    this.trayAutoScrollTimer = setInterval(() => {
      if (!this.isAlive) {
        clearInterval(this.trayAutoScrollTimer);
        this.trayAutoScrollTimer = -1;
        return;
      }
      const current = this.tripTrayScroller.currentOffset().xOffset;
      this.tripTrayScroller.scrollTo({
        xOffset: current + this.trayScrollSpeed,
        yOffset: 0,
        animation: { duration: DURATION_TICK, curve: CURVE_LINEAR }
      });
    }, 16);
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
      hapticTime(40);
      if (hitTarget === '__new_trip__') {
        this.onAddGearsToNewTrip(this.selectedMultiGearIds);
      } else {
        this.onAddGearsToTrip(this.selectedMultiGearIds, hitTarget);
      }
    }
    // 退出拖拽态
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.dragMode = false;
      this.showTripTray = false;
      this.dragOverTripId = '';
    });
  }

  private cancelDrag(): void {
    this.stopTrayAutoScroll();
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
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
  onOpenMoveGroupSheet: () => void = (): void => {};
  onAddGearsToTrip: (gearIds: string[], tripId: string) => void = (gearIds: string[], tripId: string): void => {};
  onAddGearsToNewTrip: (gearIds: string[]) => void = (gearIds: string[]): void => {};

  // 同行次数实时派生：查预计算 Map，O(1)，避免每次排序/渲染重复遍历
  private gearTripCount(item: GearItem): number {
    return this.gearTripCountMap.get(item.id) ?? 0;
  }

  private sortedGears(items: GearItem[]): GearItem[] {
    const sorted: GearItem[] = [];
    for (let index = 0; index < items.length; index++) {
      sorted.push(items[index]);
    }
    sorted.sort((left: GearItem, right: GearItem): number => {
      if (this.gearSortMode === GEAR_SORT_PRICE) {
        return numberOrZero(right.price) - numberOrZero(left.price);
      }
      if (this.gearSortMode === GEAR_SORT_WEIGHT) {
        return numberOrZero(right.weight) - numberOrZero(left.weight);
      }
      if (this.gearSortMode === GEAR_SORT_TIME) {
        return right.createdAt - left.createdAt;
      }
      if (this.gearSortMode === GEAR_SORT_VALUE) {
        return gearValueRatio(right) - gearValueRatio(left);
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
    if (this.selectedGearCategories.length === 0 || this.selectedGearCategories.indexOf(CATEGORY_ALL) >= 0) {
      return [CATEGORY_ALL];
    }
    const categories: string[] = [];
    for (let index = 0; index < this.selectedGearCategories.length; index++) {
      const category = this.selectedGearCategories[index];
      if (category.length > 0 && categories.indexOf(category) < 0) {
        categories.push(category);
      }
    }
    if (categories.length === 0) {
      return [CATEGORY_ALL];
    }
    return categories;
  }

  private activeCategoryText(): string {
    const categories = this.activeCategories();
    if (categories.length === 0 || categories.indexOf(CATEGORY_ALL) >= 0) {
      return CATEGORY_ALL;
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
    const showAllCategories = activeCategories.indexOf(CATEGORY_ALL) >= 0;
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
      const group = this.gearSortMode === GEAR_SORT_GROUP ? items[index].category : gearSortLabel(this.gearSortMode);
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

  private formatKg(weightGram: number): string {
    if (weightGram <= 0) {
      return '0kg';
    }
    return (Math.round(weightGram / 100) / 10).toString() + 'kg';
  }

  private hasMultiGearSelection(id: string): boolean {
    return this.selectedMultiGearIds.indexOf(id) >= 0;
  }

  private gearGroupCount(group: string): number {
    return this.filteredGearsByGroup(group).length;
  }

  private isGearGroupCollapsed(group: string): boolean {
    // 搜索模式下所有分组强制展开，用户取消搜索后恢复原折叠偏好
    if (this.gearSearchKeyword.trim().length > 0) {
      return false;
    }
    return this.collapsedGearGroups.indexOf(group) >= 0;
  }

  private isFirstGearGroup(group: string): boolean {
    const groups = this.filteredGearGroups();
    return groups.length > 0 && groups[0] === group;
  }

  private toggleGearGroupCollapse(group: string): void {
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      const idx = this.collapsedGearGroups.indexOf(group);
      if (idx >= 0) {
        const next = [...this.collapsedGearGroups];
        next.splice(idx, 1);
        this.collapsedGearGroups = next;
        this.gearGroupExpandTrigger++;
      } else {
        this.collapsedGearGroups = this.collapsedGearGroups.concat([group]);
      }
    });
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

  private companionDaysText(item: GearItem): string {
    const start: number = typeof item.acquiredAt === 'number' ? item.acquiredAt : item.createdAt;
    const days = Math.max(0, Math.floor((Date.now() - start) / 86400000));
    return days.toString();
  }

  // 陪伴天数来源标签：有 acquiredAt 不显示前缀；无 acquiredAt 时提示「大约」表示 fallback
  private companionDaysLabel(item: GearItem): string {
    if (typeof item.acquiredAt === 'number') {
      return ' 天';
    }
    return ' 天左右';
  }

  @Builder
  private CompanionChip(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(TEXT_SECONDARY)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(PRIMARY_TINT_COLOR)
      .borderRadius(CHIP_RADIUS)
      .margin({ bottom: 4 })
  }

  private gearSummaryText(): string {
    return this.gears.length.toString() + '件 · ' + this.formatKg(totalGearWeight(this.gears)) +
      ' · ¥' + totalGearPrice(this.gears).toString();
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

  // head 折叠进度（0~1）。读 @State 镜像（非 controller.progress()）以触发 ArkUI 依赖收集。
  private gearScrollProgress(): number {
    return this.gearHeadProgress;
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
    // Bug1 修复：只计算可见（未折叠）分组中的装备数量
    let visibleItemCount = 0;
    for (let g = 0; g < groups.length; g++) {
      if (!this.isGearGroupCollapsed(groups[g])) {
        visibleItemCount += this.filteredGearsByGroup(groups[g]).length;
      }
    }
    const estimatedContentHeight = visibleItemCount * 52 + groups.length * 44;
    // 如果内容自身足够多，不需要额外空间来触发折叠
    if (estimatedContentHeight > collapseRange) {
      return 80; // 仅 TabBar 避让
    }
    // 内容不够时，补足让 scroll 范围 ≥ collapseRange
    return collapseRange - estimatedContentHeight + 80;
  }

  // 折叠态底部 hairline 分隔线：alpha 随 progress 0→1 浮现（对齐 iOS Large Title）
  private gearHeaderBorderColor(): string {
    if (this.searchExpanded) {
      return '#00' + DIVIDER_COLOR.substring(1); // 搜索态不显示分隔线
    }
    const p = this.gearScrollProgress();
    const t = p < 0.5 ? 0 : Math.min(1, (p - 0.5) * 2);
    const alpha = Math.round(t * 0xFF);
    const hex = alpha < 16 ? '0' + alpha.toString(16).toUpperCase() : alpha.toString(16).toUpperCase();
    return '#' + hex + DIVIDER_COLOR.substring(1); // DIVIDER_COLOR with dynamic alpha
  }

  // Header 动态高度：跟随滚动从 EXPANDED 收缩到 COLLAPSED
  private gearHeaderHeight(): number {
    if (this.searchExpanded) {
      return GEAR_HEADER_COLLAPSED; // 搜索时强制收缩 header
    }
    const p = this.gearScrollProgress();
    return GEAR_HEADER_EXPANDED - (GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED) * p;
  }

  // Header 背景：全程实色羽白（折叠态去毛玻璃，避免半透明 + blur 合成发灰）
  private gearHeaderBgColor(): string {
    return PAGE_BG; // #F8F9FA 全不透明背景
  }

  // 顶部 spacer 高度：给 Header 腾出空间（含状态栏避让）
  private topSpacerHeight(): number {
    if (this.multiSelectMode || this.searchExpanded) {
      return this.statusBarHeight + GEAR_HEADER_COLLAPSED;
    }
    return this.statusBarHeight + GEAR_HEADER_EXPANDED - 20; // 减去 List padding-top(6) + space(16) 的多余间距，消除灰色间隙
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
            // 人生足迹精简聚合区（装备库顶部黄金区，提纲 §3.4）
            if (this.gears.length > 0 && this.footprintVm.tripCount > 0) {
              ListItem() {
                GearFootprintRow({ footprint: this.footprintVm })
              }
              .opacity(this.listEntered ? 1 : 0)
              .translate({ y: this.listEntered ? 0 : STAGGER_OFFSET_Y })
              .animation({ delay: staggerDelay(0, 30, 4, 200), curve: SPRING_GENERAL() })
            }
            if (this.gears.length === 0) {
              ListItem() {
                GearEmptyState({ entered: this.listEntered, onAddGear: () => { this.onOpenAddGear(); } })
              }
            } else if (this.filteredGears().length === 0) {
              ListItem() {
                GearEmptyText({ message: '未找到相关装备' })
              }
            } else {
              ForEach(this.displayGearGroups(), (group: string, index: number) => {
                ListItem() {
                  this.GearGroupCard(group);
                }
                .opacity(this.listEntered ? 1 : 0)
                .translate({ y: this.listEntered ? 0 : STAGGER_OFFSET_Y })
                .animation({ delay: staggerDelay(index), curve: SPRING_GENERAL() })
                .transition(TransitionEffect.OPACITY.combine(
                  TransitionEffect.translate({ y: 8 })
                ).animation({ curve: SPRING_GENERAL() }))
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
          .backgroundColor(TRANSPARENT)
          // 跟手：progress 严格 1:1 实时映射（零吸附、不抢手感）。
          .onDidScroll(() => {
            this.headController.handleScroll(this.gearListScroller);
          })
          // 补齐 Large Title 就近吸附：松手惯性停在中间态时吸附到 0/1，绝不留半折叠残缺态。
          .onScrollStop(() => {
            this.headController.handleScrollStop(this.gearListScroller);
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down && this.swipedGearId !== '') {
              this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
                this.swipedGearId = '';
                this.swipeOffsetX = 0;
              });
            }
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
          .backgroundColor(OVERLAY_MASK)
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
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
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
          curve: SPRING_GENERAL()
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
        Button('生成行程')
          .height(32)
          .fontSize(13)
          .fontColor(WHITE)
          .backgroundColor(this.selectedMultiGearIds.length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
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
          .backgroundColor(TRANSPARENT)
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            this.onCancelGearMultiSelect();
          })
      }
      .width('100%')
      .height(this.statusBarHeight + GEAR_HEADER_COLLAPSED)
      .alignItems(VerticalAlign.Center)
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: this.statusBarHeight + 6 })
      .backgroundColor(PAGE_BG)
      .position({ x: 0, y: 0 })
      .zIndex(10)
    } else {
      // 普通模式：可折叠 Header
      Stack({ alignContent: Alignment.TopStart }) {
        // 主内容层
        Column() {
          Row() {
            if (!this.searchExpanded) {
              Text('我的装备库')
                .fontSize(this.gearTitleFontSize())
                .fontWeight(FontWeight.Bold)
                .fontColor(TEXT_MAIN)
                .animation({ curve: SPRING_GENERAL() })
              Text(this.gearSummaryText())
                .fontSize(13)
                .fontColor(TEXT_TERTIARY)
                .fontFeature(FONT_FEATURE_TNUM)
                .maxLines(1)
                .constraintSize({ maxWidth: 160 })
                .margin({ left: 8 })
                .opacity(this.gearCollapsedOpacity())
                .translate({ x: -12 * (1 - this.gearCollapsedOpacity()) })
                .animation({ curve: SPRING_SCROLL() })
              Blank()
            }
            // 搜索按钮 / 搜索框：原地变形
            Row() {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(this.searchExpanded ? 16 : 20)
                .fontColor([this.gearSearchKeyword.length > 0 ? PRIMARY_COLOR : TEXT_SECONDARY])
                .margin({ left: this.searchExpanded ? 2 : 0, right: this.searchExpanded ? 6 : 0 })
              if (this.searchExpanded) {
                TextInput({ placeholder: '搜索装备', text: this.gearSearchKeyword })
                  .height(32)
                  .fontSize(15)
                  .fontColor(TEXT_MAIN)
                  .placeholderColor(TEXT_TERTIARY)
                  .backgroundColor(TRANSPARENT)
                  .padding({ left: 0, right: 0 })
                  .layoutWeight(1)
                  .defaultFocus(true)
                  .onChange((value: string) => {
                    this.onSearchChange(value);
                  })
                Text('取消')
                  .fontSize(14)
                  .fontColor(TEXT_SECONDARY)
                  .padding({ left: 10, right: 4 })
                  .scale({ x: this.pressedCancelText ? PRESS_SCALE_DOWN : 1.0,
                    y: this.pressedCancelText ? PRESS_SCALE_DOWN : 1.0 })
                  .animation({ curve: SPRING_PRESS() })
                  .onTouch((e: TouchEvent) => {
                    if (e.type === TouchType.Down) {
                      this.pressedCancelText = true;
                    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                      this.pressedCancelText = false;
                    }
                  })
                  .onClick(() => {
                    this.getUIContext().animateTo({
                      curve: SPRING_SEARCH()
                    }, () => {
                      this.searchExpanded = false;
                      this.onSearchChange('');
                    });
                  })
              }
            }
            .height(38)
            .layoutWeight(this.searchExpanded ? 1 : 0)
            .width(this.searchExpanded ? undefined : 36)
            .justifyContent(this.searchExpanded ? FlexAlign.Start : FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .padding(this.searchExpanded ? { left: 14, right: 10 } : { left: 0, right: 0 })
            .borderRadius(19)
            .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
              colorMode: ThemeColorMode.SYSTEM,
              adaptiveColor: AdaptiveColor.DEFAULT
            })
            .backgroundColor(this.searchExpanded ? GLASS_BG : PRIMARY_TINT_COLOR)
            .scale({ x: (!this.searchExpanded && this.pressedSearchBtn) ? PRESS_SCALE_DOWN : 1.0,
              y: (!this.searchExpanded && this.pressedSearchBtn) ? PRESS_SCALE_DOWN : 1.0 })
            .animation({ curve: SPRING_SEARCH() })
            .onTouch((e: TouchEvent) => {
              if (!this.searchExpanded) {
                if (e.type === TouchType.Down) {
                  this.pressedSearchBtn = true;
                } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  this.pressedSearchBtn = false;
                }
              }
            })
            .onClick(() => {
              if (!this.searchExpanded) {
                this.pressedSearchBtn = false;
                this.getUIContext().animateTo({
                  curve: SPRING_SEARCH()
                }, () => {
                  this.searchExpanded = true;
                  this.gearListScroller.scrollTo({ xOffset: 0, yOffset: 0 });
                  this.gearHeadProgress = 0;
                  this.gearHeadSnapping = false;
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
              .scale({ x: this.pressedSortBtn ? PRESS_SCALE_DOWN : 1.0,
                y: this.pressedSortBtn ? PRESS_SCALE_DOWN : 1.0 })
              .animation({ curve: SPRING_PRESS() })
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.pressedSortBtn = true;
                } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  this.pressedSortBtn = false;
                }
              })
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
              Row() {
                // 分类筛选 pill
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
                .scale({ x: this.pressedFilterPill ? PRESS_SCALE_DOWN : 1.0,
                  y: this.pressedFilterPill ? PRESS_SCALE_DOWN : 1.0 })
                .animation({ curve: SPRING_PRESS() })
                .onTouch((e: TouchEvent) => {
                  if (e.type === TouchType.Down) {
                    this.pressedFilterPill = true;
                  } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                    this.pressedFilterPill = false;
                  }
                })
                .onClick(() => {
                  this.onOpenFilterPanel();
                })

                Blank()

                // 轻量统计摘要
                Text(this.gearSummaryText())
                  .fontSize(12)
                  .fontColor(TEXT_TERTIARY)
                  .fontFeature(FONT_FEATURE_TNUM)
              }
              .width('100%')
              .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 10 })
              .alignItems(VerticalAlign.Center)
              .opacity(this.gearPillOpacity())
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
      .height(this.statusBarHeight + this.gearHeaderHeight())
      .padding({ top: this.statusBarHeight })
      .clip(true)
      .backgroundColor(this.gearHeaderBgColor())
      .border({ width: { bottom: 0.5 }, color: { bottom: this.gearHeaderBorderColor() } })
      .position({ x: 0, y: 0 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
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
          .animation({ curve: SPRING_CHEVRON() })
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 4, right: 4 })
      .scale({
        x: this.pressedGroupId === group ? PRESS_SCALE_DOWN : 1.0,
        y: this.pressedGroupId === group ? PRESS_SCALE_DOWN : 1.0
      })
      .animation({ curve: SPRING_PRESS() })
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
        .transition(TransitionEffect.OPACITY.combine(
          TransitionEffect.translate({ y: -6 })
        ).animation({ curve: SPRING_GENERAL() }))
      }
    }
    .width('100%')
    .opacity(this.groupDragMode && this.groupDragGroup === group ? 0 : (this.groupDragMode ? 0.6 : 1.0))
    .animation({ curve: SPRING_GENERAL() })
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
            .hitTestBehavior(HitTestMode.None)
            .transition(TransitionEffect.OPACITY.combine(
              TransitionEffect.translate({ x: -12 })
            ).animation({ curve: SPRING_GENERAL() }))
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
      .scale({
        x: this.pressedGearId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
        y: this.pressedGearId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
      })
      .opacity(this.dragMode && this.hasMultiGearSelection(item.id) ? 0.4 : 1)
      .animation({ curve: SPRING_PRESS() })
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
          PanGesture({ fingers: 1, distance: 5 })
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
      // 普通模式：左滑删除（仅折叠态可滑动，展开态互斥）
      Stack({ alignContent: Alignment.End }) {
        // 底层：删除按钮（固定高度 52vp = 折叠态内容行高度）
        if (this.swipedGearId === item.id) {
          Column({ space: 2 }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(16)
              .fontColor([WHITE])
            Text('删除')
              .fontSize(11)
              .fontColor(WHITE)
          }
          .width(80)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(DANGER_COLOR)
          .borderRadius({ topRight: 12, bottomRight: 12 })
          .onClick(() => {
            this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
              this.swipedGearId = '';
              this.swipeOffsetX = 0;
            });
            this.onConfirmDeleteGear(item);
          })
          .transition(
            TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ x: 30 }))
                .animation({ curve: SPRING_SWIPE_RESET() }),
              TransitionEffect.OPACITY
                .animation({ duration: DURATION_FAST })
            )
          )
        }

        // 上层：内容行（translate 由 animateTo 驱动弹性动画）
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
              .animation({ curve: SPRING_CHEVRON() })
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (this.swipedGearId === item.id) {
              // 滑开态点击：收回滑动
              this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
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
        .backgroundColor(this.pressedGearId === item.id ? GROUP_HEADER_BG : CARD_BG)
        .scale({
          x: this.pressedGearId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
          y: this.pressedGearId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
        })
        // hdsEffect 按压阴影：按下「陷入材质」高级感（仅真机生效，模拟器降级为无）
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pressShadow(this.pressedGearId === item.id
            ? hdsEffect.PressShadowType.BLEND_GRADIENT
            : hdsEffect.PressShadowType.NONE)
          .buildEffect())
        .animation({ curve: SPRING_PRESS() })
        .translate({ x: this.swipedGearId === item.id ? this.swipeOffsetX : 0 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedGearId = item.id;
            if (this.swipedGearId !== '' && this.swipedGearId !== item.id) {
              this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
                this.swipedGearId = '';
                this.swipeOffsetX = 0;
              });
            }
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedGearId = '';
          }
        })
        .priorityGesture(
          PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 5 })
            .onActionUpdate((event: GestureEvent) => {
              // 展开态禁止左滑
              if (this.expandedGearId === item.id) {
                return;
              }
              const offsetX = event.offsetX;
              if (this.swipedGearId === item.id) {
                const newOffset = Math.min(0, Math.max(-160, -80 + offsetX));
                this.swipeOffsetX = newOffset;
              } else {
                const newOffset = Math.min(0, Math.max(-100, offsetX));
                this.swipeOffsetX = newOffset;
                if (newOffset < -5) {
                  this.swipedGearId = item.id;
                }
              }
            })
            .onActionEnd((event: GestureEvent) => {
              if (this.expandedGearId === item.id) {
                return;
              }
              if (this.swipeOffsetX < -40) {
                this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
                  this.swipeOffsetX = -80;
                });
              } else {
                this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
                  this.swipedGearId = '';
                  this.swipeOffsetX = 0;
                });
              }
            })
            .onActionCancel(() => {
              this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
                if (this.swipeOffsetX < -40) {
                  this.swipeOffsetX = -80;
                } else {
                  this.swipedGearId = '';
                  this.swipeOffsetX = 0;
                }
              });
            })
        )
      }
      .width('100%')
      .clip(true)
      .bindContextMenu(this.GearContextMenu(item), ResponseType.LongPress, {
        preview: this.GearPreviewCard(item),
        previewAnimationOptions: { scale: [0.92, 1.05] },
        transition: TransitionEffect.asymmetric(
          TransitionEffect.scale({ x: 0.9, y: 0.9 })
            .combine(TransitionEffect.OPACITY)
            .animation({ curve: SPRING_CEREMONY_FLIP() }),
          TransitionEffect.scale({ x: 0.95, y: 0.95 })
            .combine(TransitionEffect.OPACITY)
            .animation({ curve: SPRING_CONTEXT_EXIT() })
        ),
        placement: Placement.Bottom,
        borderRadius: 20
      })
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
    .shadow({ radius: 24, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 8 })
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
    Column({ space: 0 }) {
      // ——— 属性区（packing：出行前看实用属性）———
      Column({ space: 8 }) {
        Divider()
          .strokeWidth(1)
          .color(DIVIDER_COLOR)
        this.DetailLine('分组', item.category);
        this.DetailLine('重量', item.weight === undefined ? '未填写' : item.weight.toString() + 'g');
        if (item.brand !== undefined && item.brand.length > 0) {
          this.DetailLine('品牌', item.brand);
        }
        this.DetailLine('价格', item.price === undefined ? '未填写' : '¥' + item.price.toString());
        if (item.note !== undefined && item.note.length > 0) {
          this.DetailLine('备注', item.note);
        }
      }
      .width('100%')

      // ——— 分隔 ———
      Row()
        .width('100%')
        .height(1)
        .backgroundColor(DIVIDER_COLOR)
        .margin({ top: 12, bottom: 12 })

      // ——— 陪伴区（archive：出行后看情感记录）———
      Column({ space: 8 }) {
        // 陪伴天数大数字
        Row() {
          Text(this.companionDaysText(item))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .fontFeature("'tnum'")
          Text(this.companionDaysLabel(item))
            .fontSize(13)
            .fontColor(TEXT_SECONDARY)
            .margin({ bottom: 2 })
        }
        .alignItems(VerticalAlign.Bottom)

        // 三 chip
        Row({ space: 8 }) {
          this.CompanionChip('同行 ' + this.gearTripCount(item).toString() + ' 次');
          this.CompanionChip('相伴 ' + this.companionDaysText(item) + ' 天');
          this.CompanionChip('添加于 ' + this.formatDateText(item.createdAt));
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12 })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
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
  private Fab() {
    Column() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(24)
        .fontColor([PRIMARY_COLOR])
    }
    .width(50)
    .height(50)
    .borderRadius(25)
    .backgroundColor(GLASS_BG)
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 16, color: PRIMARY_SHADOW, offsetX: 0, offsetY: 6 })
    .position({ x: this.fabX, y: this.fabY })
    .scale({ x: this.fabDragging ? 1.08 : 1, y: this.fabDragging ? 1.08 : 1 })
    .gesture(
      PanGesture({ fingers: 1, distance: 5 })
        .onActionStart(() => {
          this.fabStartX = this.fabX;
          this.fabStartY = this.fabY;
          this.getUIContext().animateTo({
            curve: SPRING_PRESS()
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
            curve: SPRING_GENERAL()
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

  // --- 行程托盘 ---
  @Builder
  private TripDropTray() {
    Column() {
      // 顶部拖拽指示器
      Row()
        .width(40)
        .height(4)
        .borderRadius(2)
        .backgroundColor(OVERLAY_DIM)
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
        Row({ space: 10 }) {
          ForEach(this.checklists, (trip: TripChecklist) => {
            this.TripCard(trip)
          }, (trip: TripChecklist) => trip.id)

          // 新建行程卡片
          Column({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(22)
              .fontColor([this.dragOverTripId === '__new_trip__' ? WHITE : PRIMARY_COLOR])
            Text('新建')
              .fontSize(11)
              .fontColor(this.dragOverTripId === '__new_trip__' ? WHITE : TEXT_SECONDARY)
          }
          .width(88)
          .height(68)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(12)
          .backgroundColor(this.dragOverTripId === '__new_trip__' ? PRIMARY_COLOR : TRANSPARENT)
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
          .animation({ curve: SPRING_TRAY_CARD() })
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
      .height(82)
    }
    .width('100%')
    .height(274)
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 34 })
    .backgroundColor(GLASS_BG_MEDIUM)
    .backdropBlur(40)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({ radius: 20, color: SHADOW_DEFAULT, offsetX: 0, offsetY: -6 })
    .position({ x: 0, y: this.showTripTray ? this.screenHeight - 274 : this.screenHeight })
    .animation({ curve: SPRING_GENERAL() })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private TripCard(trip: TripChecklist) {
    Column({ space: 3 }) {
      Text(trip.title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.dragOverTripId === trip.id ? WHITE : TEXT_MAIN)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(trip.items.length.toString() + ' 件装备')
        .fontSize(10)
        .fontColor(this.dragOverTripId === trip.id ? WHITE_SECONDARY : TEXT_TERTIARY)
    }
    .width(88)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 10, right: 10 })
    .borderRadius(12)
    .backgroundColor(this.dragOverTripId === trip.id ? PRIMARY_COLOR : CARD_BG)
    .shadow({ radius: this.dragOverTripId === trip.id ? 16 : 4, color: SHADOW_SUBTLE, offsetX: 0, offsetY: 2 })
    .scale({
      x: this.tripCardScale(trip.id),
      y: this.tripCardScale(trip.id)
    })
    .translate({ y: this.tripCardLift(trip.id) })
    .animation({ curve: SPRING_TRAY_CARD() })
    .onAreaChange((_old: Area, area: Area) => {
      const pos = area.globalPosition as Position;
      this.updateTripCardArea(trip.id,
        pos.x as number, pos.y as number,
        area.width as number, area.height as number);
    })
  }

  private updateTripCardArea(id: string, x: number, y: number, w: number, h: number): void {
    const area: TripCardArea = { id: id, x: x, y: y, w: w, h: h };
    const idx = this.tripCardAreas.findIndex((a: TripCardArea) => a.id === id);
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
    const area = this.tripCardAreas.find((a: TripCardArea) => a.id === id);
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

  // 基于 proximity 的 scale: 1.0 ~ 1.25 (命中时 1.25，接近时渐变)
  private tripCardScale(id: string): number {
    if (this.dragOverTripId === id) {
      return 1.25;
    }
    const p = this.tripCardProximity(id);
    return 1 + 0.25 * p * p; // 平方曲线：接近时加速放大
  }

  // 基于 proximity 的 translateY: 0 ~ -22vp (向上涌起)
  private tripCardLift(id: string): number {
    if (this.dragOverTripId === id) {
      return -22;
    }
    const p = this.tripCardProximity(id);
    return -20 * p * p;
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
          .fontColor(WHITE)
          .backgroundColor(PRIMARY_COLOR)
          .borderRadius(10)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
    }
    .width(140)
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(GLASS_BG_LIGHT)
    .backdropBlur(20)
    .borderRadius(12)
    .shadow({ radius: 20, color: SHADOW_MEDIUM, offsetX: 0, offsetY: 6 })
    .rotate({ angle: -2 })
    .position({ x: this.dragX - 70, y: this.dragY - 56 })
    .animation({ duration: DURATION_NONE })
  }

  private dragGearFirstName(): string {
    if (this.selectedMultiGearIds.length > 0) {
      const firstId = this.selectedMultiGearIds[0];
      const gear = this.gears.find((g: GearItem) => g.id === firstId);
      if (gear !== undefined) {
        return gear.name;
      }
    }
    return '装备';
  }

  // ===== 分组拖拽排序 =====

  // 记录初始拖拽手指位置和被拖分组在列表中的原始 index
  private groupDragStartFingerY: number = 0;
  private groupDragOriginalIdx: number = 0;

  private enterGroupDrag(group: string, fingerY: number): void {
    // 快照当前分组顺序
    const groups = this.filteredGearGroups().slice();
    this.groupReorderList = groups;
    this.groupDragGroup = group;
    this.groupDragOriginalIdx = groups.indexOf(group);

    // 记录手指初始位置（用于计算浮动卡片 position）
    this.groupDragStartFingerY = fingerY;
    this.groupDragY = fingerY;

    // 计算手指到被拖分组顶部的偏移（用于碰撞检测）
    // 被拖分组的顶部在列表中的累积 Y
    let dragGroupTopY = 0;
    for (let i = 0; i < this.groupDragOriginalIdx; i++) {
      const h = this.groupCardHeights.get(groups[i]) ?? 60;
      dragGroupTopY += h + 16; // 16 = list space
    }
    const dragGroupH = this.groupCardHeights.get(group) ?? 60;
    // offsetY = 手指到分组中心的距离（用于碰撞检测中的虚拟位置）
    this.groupDragOffsetY = dragGroupTopY + dragGroupH / 2;

    // 进入拖拽态
    this.groupDragMode = true;
    // 触觉反馈
    hapticTime(30);
  }

  private updateGroupDrag(fingerY: number): void {
    this.groupDragY = fingerY;

    // 计算手指移动的 delta
    const deltaY = fingerY - this.groupDragStartFingerY;
    // 被拖分组的虚拟中心 Y = 原始中心Y + deltaY
    const virtualCenterY = this.groupDragOffsetY + deltaY;

    // 碰撞检测
    const currentIdx = this.groupReorderList.indexOf(this.groupDragGroup);
    if (currentIdx < 0) {
      return;
    }

    // 计算各分组中线位置（不包含被拖分组）
    let accumulatedY = 0;
    for (let i = 0; i < this.groupReorderList.length; i++) {
      const g = this.groupReorderList[i];
      const h = this.groupCardHeights.get(g) ?? 60;
      if (g === this.groupDragGroup) {
        // 被拖分组不占空间（它被浮起了）
        continue;
      }
      const midY = accumulatedY + h / 2;

      if (currentIdx < i && virtualCenterY > midY) {
        // 向下移动
        this.getUIContext().animateTo({
          curve: SPRING_GENERAL()
        }, () => {
          const next = [...this.groupReorderList];
          next.splice(currentIdx, 1);
          next.splice(i, 0, this.groupDragGroup);
          this.groupReorderList = next;
        });
        hapticTime(20);
        return;
      } else if (currentIdx > i && virtualCenterY < midY) {
        // 向上移动
        this.getUIContext().animateTo({
          curve: SPRING_GENERAL()
        }, () => {
          const next = [...this.groupReorderList];
          next.splice(currentIdx, 1);
          next.splice(i, 0, this.groupDragGroup);
          this.groupReorderList = next;
        });
        hapticTime(20);
        return;
      }
      accumulatedY += h + 16; // 16 = list space
    }
  }

  private completeGroupDrag(): void {
    // 保存新顺序到 categoryOrder
    this.categoryOrder = this.groupReorderList.slice();
    this.persistCategoryOrder();
    // 退出拖拽态
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.groupDragMode = false;
      this.groupDragGroup = '';
      this.groupReorderList = [];
    });
    // 振动确认
    hapticTime(30);
  }

  @Builder
  private FloatingGroupCard() {
    // 只展示分组标题行作为浮动副本（轻量、辨识度高）
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
    .height(40)
    .alignItems(VerticalAlign.Center)
    .padding({ left: PAGE_PADDING + 4, right: PAGE_PADDING + 4 })
    .backgroundColor(CARD_BG)
    .borderRadius(12)
    .scale({ x: 1.02, y: 1.02 })
    .shadow({ radius: 20, color: SHADOW_MEDIUM, offsetX: 0, offsetY: 6 })
    .position({ x: 0, y: this.groupDragY - 14 })
    .animation({ duration: DURATION_NONE })
    .zIndex(100)
    .hitTestBehavior(HitTestMode.None)
  }
}
