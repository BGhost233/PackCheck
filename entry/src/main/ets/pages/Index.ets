import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { sensor } from '@kit.SensorServiceKit';
import { hapticTime, hapticStrong } from '../utils/HapticUtils';
import { HdsTabs, HdsTabsController, hdsMaterial, HdsNavigation } from '@kit.UIDesignKit';
import { GearPage } from '../components/GearPage';
import { HomePage } from '../components/HomePage';
import { ReviewPage } from '../components/ReviewPage';
import { TripDetailPage } from '../components/gear/TripDetailPage';
import { TripCeremonyCard } from '../components/TripCeremonyCard';
import { EditItemPanel } from '../components/EditItemPanel';
import { EditGearPanel } from '../components/EditGearPanel';
import { GearFilterPanel } from '../components/GearFilterPanel';
import { SheetOverlay } from '../components/sheets/SheetOverlay';
import {
  CARD_BG,
  DANGER_COLOR,
  DIVIDER_COLOR,
  GEAR_SORT_GROUP,
  GLASS_BG_HEAVY,
  GROUP_HEADER_BG,
  OVERLAY_MASK,
  PAGE_BG,
  PRIMARY_COLOR,
  PRIMARY_SHADOW_LIGHT,
  SHADOW_DEFAULT,
  SHEET_EDIT_PROFILE,
  SHEET_EDIT_TRIP,
  SHEET_GEAR,
  SHEET_GEAR_SORT,
  SHEET_IMPORT,
  SHEET_NONE,
  SHEET_TEMP_ITEM,
  SHEET_TRIP,
  SHEET_GEAR_PICKER,
  SHEET_GEAR_ITEM_ACTION,
  SHEET_DAY_FORM,
  SHEET_SEGMENT_FORM,
  TEXT_MAIN,
  TEXT_TERTIARY,
  TRANSPARENT,
  WHITE
} from '../constants/DesignTokens';
import {
  FONT_SIZE_MINI, FONT_SIZE_BODY_MEDIUM, FONT_SIZE_OVERLINE, FONT_SIZE_PAGE_TITLE
} from '../constants/Typography';
import {
  SPRING_GENERAL,
  SPRING_CHEVRON,
  SPRING_TAB_BREATHE,
  SPRING_TAB_ICON,
  SPRING_HERO_EXPAND,
  SPRING_HERO_COLLAPSE,
  SPRING_PANEL_ENTER,
  SPRING_PANEL_EXIT,
  DURATION_RECOVER,
  DURATION_CEREMONY_SHAKE,
  CURVE_DECELERATE,
  PANEL_SCALE_START
} from '../constants/AnimationTokens';
import { CATEGORY_ALL, CATEGORY_FALLBACK, ChecklistItem, clampNumber, DayItinerary, DayPatch, GearItem, makeId, normalizeNumber, RouteSegment, SegmentPatch, TransportMode, TripChecklist } from '../models/PackModels';
import { allZones, zoneDisplayName } from '../services/LoadoutService';
import { getPackStore, PackStore } from '../services/PackStore';
import {
  normalizeGearCategories,
  presetCategories,
  uniqueGearIds,
  createGear,
  updateGear
} from '../services/GearService';
import {
  addCategory,
  deleteCategory,
  renameCategory,
  reorderCategories,
  migrateGearsOnDelete,
  migrateChecklistsOnDelete,
  renameGearsCategory,
  renameChecklistsCategory,
  countGearsInCategory,
  countChecklistItemsInCategory,
  validateCategoryName
} from '../services/CategoryService';
import {
  startOfDay,
  checkedCount,
  progressPercent,
  progressValue,
  progressTotal,
  progressText,
  checklistMetaText as calcChecklistMetaText,
  parseTripDateAt,
  countdownText,
  checklistItemWeight,
  checklistItemPrice,
  numberInputText,
  hasGearMarker,
  matchingGearForChecklistItem,
  formatTripDate,
  addItemsToChecklist,
  toggleItemInChecklists,
  removeItemFromChecklists,
  updateChecklistMeta,
  updateItemFields,
  buildItemsFromGears,
  prependChecklist,
  findLatestChecklist,
  TripProfileUpdate,
  resolveItemName,
  cloneChecklist,
  cloneChecklistItem,
  createChecklist as createChecklistFactory,
  createEmptyChecklistItem
} from '../services/ChecklistService';
import { ProfilePage } from '../components/ProfilePage';
import {
  addDay,
  insertDay,
  removeDay,
  updateDay,
  addSegment,
  removeSegment,
  updateSegment,
  createEmptySegment
} from '../services/ItineraryService';

@Entry
@Component
struct Index {
  private store: PackStore = getPackStore();

  @State private gears: GearItem[] = [];
  @State private checklists: TripChecklist[] = [];
  @State private categories: string[] = [];
  @State private selectedGearCategories: string[] = [CATEGORY_ALL];
  @State private gearFilterPanelExpanded: boolean = false;
  @State private currentTabIndex: number = 0;
  @State private homeSwipeResetNonce: number = 0;
  @State private gearSwipeResetNonce: number = 0;
  // visibility nonce：每次 tab 切至此组件时递增，驱动子组件入场动画重播
  // 解决 ArkUI TabContent 可能 keep-alive 导致 aboutToAppear 不触发、入场动画不重播的问题
  @State private homeVisibilityNonce: number = 0;
  @State private gearVisibilityNonce: number = 0;
  @State private profileVisibilityNonce: number = 0;
  @State private tabSwipeProgress: number = 0; // [-1, 1] 滑动进度，跟手指示器用
  private readonly tabCount: number = 3;
  private tabsWidth: number = 360; // Tabs 内容区宽度，onAreaChange 更新
  private touchStartX: number = 0; // 触摸起始 X 坐标
  private isSwiping: boolean = false; // 是否正在滑动中
  @State private contentBlur: number = 0;
  @State private contentScale: number = 1.0;
  private isClickSwitching: boolean = false;
  private tabsController: HdsTabsController = new HdsTabsController();
  private navPathStack: NavPathStack = new NavPathStack();
  private lastBackPressTime: number = 0;
  @State private gearSearchKeyword: string = '';
  @State private gearSortMode: string = GEAR_SORT_GROUP;
  @State private expandedGearId: string = '';
  @State private selectedChecklistId: string = '';
  // 问题4a：聚焦态 @State 源，向 TripDetailPage → UnifiedChecklistView @Link 透传。
  //   null = 网格态，非 null = 当前聚焦的 Zone。onBackPressed 据此分层拦截。
  @State private focusedZone: string | null = null;
  // 问题4a：递增此信号通知 UnifiedChecklistView 走带动画的收起聚焦（避免 Index 直接改 focusedZone 丢动画）。
  @State private focusedCloseSignal: number = 0;
  @State private sheetMode: string = SHEET_NONE;
  @State private sheetTranslateY: number = 800;
  @State private sheetOverlayOpacity: number = 0;
  @State private editingGearId: string = '';
  @State private gearName: string = '';
  @State private gearCategory: string = '其他';
  @State private gearWeight: string = '';
  @State private gearPrice: string = '';
  @State private gearNote: string = '';
  @State private tripTitle: string = '';
  @State private tripDate: string = '';
  @State private tripDestination: string = '';
  @State private tripDistanceKm: string = '';
  @State private tripMaxAltitude: string = '';
  @State private tripAscentM: string = '';
  @State private tripDurationHours: string = '';
  @State private tempItemName: string = '';
  @State private tempItemGroup: string = '其他';
  @State private importGearIds: string[] = [];
  @State private importGearCategory: string = CATEGORY_ALL;
  @State private actionSheetItem: ChecklistItem = createEmptyChecklistItem();
  // 从空格子进入 GearPicker 时的预选 Zone（空串 = 无预选，向后兼容），review I4
  @State private pickerPreselectZone: string = '';
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
  @State private reviewIndex: number = 0;
  @State private reviewFinished: boolean = false;
  // D-2：聚焦态「逐项核查本区」。非空时 Review 只展示 group===zone 的 item。
  @State private reviewZoneFilter: string | null = null;
  @State private reviewDragX: number = 0;
  @State private highlightedItemId: string = '';
  // checklistRenderNonce：load-bearing 渲染强制刷新计数器。ArkUI 的 ForEach 对嵌套数组（checklist.items）
  // 的深层不可变更新存在 diff 失效问题——仅替换数组引用时部分 item 不会重渲染。该 nonce 被拼进
  // checklistItemRenderKey() 的 key，每次 applyChecklistState 自增以强制整段 ForEach 重建。
  // 除非确认底层响应式已可靠工作，否则不要移除。
  @State private checklistRenderNonce: number = 0;
  // ===== 新建行程仪式感 =====
  @State private showTripCeremony: boolean = false;
  @State private ceremonyTripTitle: string = '';
  @State private ceremonyTripDate: string = '';
  @State private ceremonyDestination: string = '';
  @State private ceremonyDistanceKm: string = '';
  @State private ceremonyMaxAltitude: string = '';
  @State private ceremonyAscentM: string = '';
  @State private ceremonyDurationHours: string = '';

  // ===== 行程日表单（4 字段：出发地/目的地/日期/备注） =====
  @State private editingDayId: string = '';
  @State private dayFormFrom: string = '';
  @State private dayFormTo: string = '';
  @State private dayFormDate: string = '';
  @State private dayFormNote: string = '';
  // ===== 路段表单 =====
  @State private editingSegmentId: string = '';
  @State private editingSegDayId: string = '';  // 路段所属天 ID
  @State private segFormFrom: string = '';
  @State private segFormTo: string = '';
  @State private segFormTransport: TransportMode = 'other';
  @State private segFormDepartTime: string = '';
  @State private segFormArriveTime: string = '';
  @State private segFormNote: string = '';
  @State private segFormAccommodation: string = '';
  @State private segFormTicketCode: string = '';
  @State private segFormTicketSeat: string = '';
  @State private segFormTicketPrice: string = '';

  // ===== 分组编辑 Dialog =====
  @State private showCategoryDialog: boolean = false;
  @State private categoryDialogMode: string = 'add'; // 'add' | 'rename'
  @State private categoryDialogOldName: string = '';
  @State private categoryDialogInput: string = '';

  private pendingTimers: number[] = [];
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
    this.resolveSafeAreaInsets();
    this.loadAppData();
  }

  // 全屏沉浸后系统不再自动避让，取一次系统栏避让高度下发 AppStorage，各折叠头 @StorageProp 读取补 padding。
  // 单位换算成 vp（AvoidArea 返回的是 px）。
  private resolveSafeAreaInsets(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      window.getLastWindow(context).then((win: window.Window) => {
        const topArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const bottomArea: window.AvoidArea =
          win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        const topVp: number = this.getUIContext().px2vp(topArea.topRect.height);
        const bottomVp: number = this.getUIContext().px2vp(bottomArea.bottomRect.height);
        AppStorage.setOrCreate('statusBarHeight', topVp);
        AppStorage.setOrCreate('bottomBarHeight', bottomVp);
      }).catch((error: Object) => {
        AppStorage.setOrCreate('statusBarHeight', 0);
        AppStorage.setOrCreate('bottomBarHeight', 0);
        hilog.warn(0x0001, 'PackCheck', 'Failed to resolve safe area. Cause: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      AppStorage.setOrCreate('statusBarHeight', 0);
      AppStorage.setOrCreate('bottomBarHeight', 0);
      hilog.warn(0x0001, 'PackCheck', 'Failed to resolve safe area. Cause: %{public}s', JSON.stringify(error));
    }
  }

  aboutToDisappear(): void {
    this.stopShakeListening();
    this.pendingTimers.forEach((id: number) => clearTimeout(id));
    this.pendingTimers = [];
    this.store.forceFlush();
  }

  onPageHide(): void {
    // 切后台 / 被覆盖时立即刷盘，防止数据丢失
    this.store.forceFlush();
  }

  private async loadAppData(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.store.init(context);
      this.gears = await this.store.getGears();
      this.checklists = await this.store.getChecklists();
      this.checklists = [...this.checklists].sort((a: TripChecklist, b: TripChecklist) => b.createdAt - a.createdAt);
      this.categories = await this.store.getCategories();
      if (this.selectedChecklistId.length === 0 && this.checklists.length > 0) {
        this.selectedChecklistId = this.checklists[0].id;
      }
      if (this.categories.length > 0) {
        this.gearCategory = this.categories[0];
      }
      this.tempItemGroup = '其他';
    } catch (error) {
      this.errorText = '数据加载失败';
      hilog.error(0x0001, 'PackCheck', 'loadAppData failed: %{public}s', JSON.stringify(error));
    }
  }

  private applyChecklistState(nextChecklists: TripChecklist[], animated: boolean = false): void {
    const updateState = (): void => {
      this.checklists = nextChecklists;
      this.checklistRenderNonce = this.checklistRenderNonce + 1;
    };
    if (animated) {
      this.getUIContext().animateTo({ curve: SPRING_CHEVRON() }, updateState);
      return;
    }
    updateState();
  }

  private latestChecklist(): TripChecklist | undefined {
    return findLatestChecklist(this.checklists);
  }

  private currentChecklist(): TripChecklist | undefined {
    for (let index = 0; index < this.checklists.length; index++) {
      if (this.checklists[index].id === this.selectedChecklistId) {
        return this.checklists[index];
      }
    }
    return undefined;
  }

  private openGearFilterPanel(): void {
    this.gearFilterPanelExpanded = true;
  }

  private closeGearFilterPanel(categories: string[]): void {
    this.selectedGearCategories = normalizeGearCategories(categories);
    this.gearFilterPanelExpanded = false;
  }

  private presetCategories(): string[] {
    return presetCategories(this.categories);
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

  private checklistItemWeight(item: ChecklistItem): number | undefined {
    return checklistItemWeight(item, this.gears);
  }

  private checklistItemPrice(item: ChecklistItem): number | undefined {
    return checklistItemPrice(item, this.gears);
  }

  private resetGearForm(): void {
    this.editingGearId = '';
    this.gearName = '';
    this.gearWeight = '';
    this.gearPrice = '';
    this.gearNote = '';
    this.gearCategory = '其他';
  }

  private resetTripForm(): void {
    this.tripTitle = '';
    this.tripDate = '';
    this.tripDestination = '';
    this.tripDistanceKm = '';
    this.tripMaxAltitude = '';
    this.tripAscentM = '';
    this.tripDurationHours = '';
  }

  private openAddGear(): void {
    this.resetGearForm();
    this.returnToImportAfterGear = false;
    this.sheetMode = SHEET_GEAR;
    this.openSheetAnimated();
  }

  private openAddGearFromImport(): void {
    this.resetGearForm();
    this.returnToImportAfterGear = true;
    this.sheetMode = SHEET_GEAR;
    this.openSheetAnimated();
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
    try {
      const name = this.gearName.trim();
      const category = this.gearCategory.trim().length === 0 ? '其他' : this.gearCategory.trim();
      if (name.length === 0) {
        this.errorText = '装备名称不能为空';
        return;
      }

      const nextGears: GearItem[] = [];
      let updated = false;
      let oldPrice: number | undefined = undefined;
      const newPrice = clampNumber(this.gearPrice, 0, 9999999);
      for (let index = 0; index < this.gears.length; index++) {
        const item = this.gears[index];
        if (item.id === this.editingGearId) {
          oldPrice = item.price;
          const edited = updateGear(item, {
            name: name,
            category: category,
            weight: clampNumber(this.gearWeight, 0, 100000),
            price: newPrice,
            note: this.gearNote.trim()
          });
          nextGears.push(edited);
          updated = true;
        } else {
          nextGears.push(item);
        }
      }

      if (!updated) {
        const created = createGear({
          name: name,
          category: category,
          weight: clampNumber(this.gearWeight, 0, 100000),
          price: newPrice,
          note: this.gearNote.trim()
        });
        nextGears.unshift(created);
      }

      await this.store.saveGears(nextGears);
      this.gears = nextGears;
      // 「实时引用」模型：gear 数据变化后，行程内引用该 gear 的 item 展示名/重量/价格
      // 自动从新 gears 回查。但 ForEach key 不变导致不重渲染，需 nonce 强制刷新。
      if (updated) {
        this.checklistRenderNonce = this.checklistRenderNonce + 1;
      }

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
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'saveGear failed: %{public}s', JSON.stringify(error));
    }
  }

  private async ensureCategory(category: string): Promise<void> {
    try {
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
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'ensureCategory failed: %{public}s', JSON.stringify(error));
    }
  }

  // ===== 分组标签编辑 =====

  private handleCategoryRename(oldName: string, _newName: string): void {
    // _newName 为空表示需要弹出 Dialog 让用户输入
    this.showCategoryRenameDialog(oldName);
  }

  private handleCategoryDelete(category: string): void {
    const gearCount = countGearsInCategory(this.gears, category);
    const itemCount = countChecklistItemsInCategory(this.checklists, category);
    const totalCount = gearCount + itemCount;
    if (totalCount === 0) {
      // 空分组直接删除
      this.executeCategoryDelete(category);
    } else {
      // 有数据，弹确认
      this.showCategoryDeleteConfirm(category, gearCount, itemCount);
    }
  }

  private async executeCategoryDelete(category: string): Promise<void> {
    // 事务化：先构建完整新状态，全部持久化成功后才一次性赋值 @State
    const nextCategories = deleteCategory(this.categories, category);
    const nextGears = migrateGearsOnDelete(this.gears, category);
    const nextChecklists = migrateChecklistsOnDelete(this.checklists, category);
    try {
      await this.store.saveCategories(nextCategories);
      await this.store.saveGears(nextGears);
      await this.store.saveChecklists(nextChecklists);
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'executeCategoryDelete save failed, state NOT updated: %{public}s', JSON.stringify(error));
      return; // save 失败则不更新 @State，保持一致性
    }
    // 持久化成功，一次性更新 @State
    this.categories = nextCategories;
    this.gears = nextGears;
    this.checklists = nextChecklists;
    this.checklistRenderNonce++;
  }

  private async executeCategoryRename(oldName: string, newName: string): Promise<void> {
    // rename 场景：验证时排除 oldName，避免"同名已存在"误判
    const categoriesExcludingOld: string[] = [];
    for (let i = 0; i < this.categories.length; i++) {
      if (this.categories[i] !== oldName) {
        categoriesExcludingOld.push(this.categories[i]);
      }
    }
    const error = validateCategoryName(newName, categoriesExcludingOld);
    if (error.length > 0) {
      return;
    }
    const renameResult = renameCategory(this.categories, oldName, newName);
    if (!renameResult.renamed) {
      return;
    }
    // 事务化：先构建完整新状态
    const nextCategories = renameResult.categories;
    const nextGears = renameGearsCategory(this.gears, oldName, newName);
    const nextChecklists = renameChecklistsCategory(this.checklists, oldName, newName);
    try {
      await this.store.saveCategories(nextCategories);
      await this.store.saveGears(nextGears);
      await this.store.saveChecklists(nextChecklists);
    } catch (saveError) {
      hilog.error(0x0001, 'PackCheck', 'executeCategoryRename save failed, state NOT updated: %{public}s', JSON.stringify(saveError));
      return;
    }
    // 持久化成功，一次性更新 @State
    this.categories = nextCategories;
    this.gears = nextGears;
    this.checklists = nextChecklists;
    this.checklistRenderNonce++;
    // 如果当前选中的分组被重命名了，同步更新
    if (this.gearCategory === oldName) {
      this.gearCategory = newName;
    }
    if (this.tempItemGroup === oldName) {
      this.tempItemGroup = newName;
    }
  }

  private async executeCategoryAdd(name: string): Promise<void> {
    try {
      const error = validateCategoryName(name, this.categories);
      if (error.length > 0) {
        return;
      }
      const nextCategories = addCategory(this.categories, name);
      await this.store.saveCategories(nextCategories);
      this.categories = nextCategories;
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'executeCategoryAdd failed: %{public}s', JSON.stringify(error));
    }
  }

  private async executeCategoryReorder(newOrder: string[]): Promise<void> {
    try {
      const nextCategories = reorderCategories(newOrder);
      await this.store.saveCategories(nextCategories);
      this.categories = nextCategories;
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'executeCategoryReorder failed: %{public}s', JSON.stringify(error));
    }
  }

  private showCategoryRenameDialog(oldName: string): void {
    this.showCategoryInputPrompt(oldName, false);
  }

  private showCategoryDeleteConfirm(category: string, gearCount: number, itemCount: number): void {
    let message = '「' + category + '」分组下有';
    if (gearCount > 0) {
      message += ' ' + gearCount.toString() + ' 件装备';
    }
    if (itemCount > 0) {
      message += (gearCount > 0 ? '、' : ' ') + itemCount.toString() + ' 个行程物品';
    }
    message += '，删除后将自动归入「其他」分组。';
    AlertDialog.show({
      title: '删除分组',
      message: message,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: DANGER_COLOR,
        action: () => {
          this.executeCategoryDelete(category);
        }
      }
    });
  }

  private showCategoryInputPrompt(oldName: string, isAdd: boolean): void {
    // 使用 promptAction.showDialog 不支持输入框
    // 改用 @ohos.promptAction 的 showDialog 配合 TextInput
    // ArkUI 限制：AlertDialog/promptAction 都不支持自定义输入框
    // 方案：使用自定义 Dialog 状态
    if (isAdd) {
      this.categoryDialogMode = 'add';
      this.categoryDialogOldName = '';
      this.categoryDialogInput = '';
    } else {
      this.categoryDialogMode = 'rename';
      this.categoryDialogOldName = oldName;
      this.categoryDialogInput = oldName;
    }
    this.showCategoryDialog = true;
  }

  private async deleteGear(id: string): Promise<void> {
    try {
      const nextGears = this.gears.filter((item: GearItem) => item.id !== id);
      await this.store.saveGears(nextGears);
      this.gears = nextGears;
      // 「实时引用」：gear 删除后行程内引用变 orphaned，强制 UI 刷新
      this.checklistRenderNonce = this.checklistRenderNonce + 1;

      if (this.expandedGearId === id) {
        this.expandedGearId = '';
      }
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'deleteGear failed: %{public}s', JSON.stringify(error));
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


  // 问题9-B：单品拖拽落位——optimistic update。
  //   第一性原理：松手 = 视觉即时落位（同步当帧），持久化 = 后台事务。
  //   先同步回写 this.gears 让 UI 立即落位，saveGears 不 await（fire-and-forget 后台跑），
  //   避免 await 推迟 setState 造成松手卡顿。
  private reorderGears(nextGears: GearItem[]): void {
    this.gears = nextGears;
    this.checklistRenderNonce++;
    // 持久化后台异步进行，不阻塞视觉落位
    this.persistGearsInBackground(nextGears);
  }

  // 后台持久化（fire-and-forget）：不阻塞 UI 落位帧，错误仅记录不影响视觉
  private persistGearsInBackground(nextGears: GearItem[]): void {
    this.store.saveGears(nextGears).catch((err: Error) => {
      console.error('saveGears failed: ' + err.message);
    });
  }

  private toggleGearExpanded(id: string): void {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.expandedGearId = this.expandedGearId === id ? '' : id;
    });
  }



  private hasGearMarker(item: ChecklistItem): boolean {
    return hasGearMarker(item);
  }

  private matchingGearForChecklistItem(item: ChecklistItem): GearItem | undefined {
    return matchingGearForChecklistItem(item, this.gears);
  }

  private openTripSheet(): void {
    this.tripTitle = '';
    this.tripDate = '';
    this.sheetMode = SHEET_TRIP;
    this.openSheetAnimated();
  }

  // ===== 新建行程仪式感方法 =====
  private startTripCeremony(): void {
    this.ceremonyTripTitle = '';
    this.ceremonyTripDate = '';
    this.ceremonyDestination = '';
    this.ceremonyDistanceKm = '';
    this.ceremonyMaxAltitude = '';
    this.ceremonyAscentM = '';
    this.ceremonyDurationHours = '';
    this.errorText = '';
    this.showTripCeremony = true;
    // 背景下沉 + 模糊，营造空间纵深
    this.getUIContext().animateTo({
      curve: SPRING_PANEL_ENTER()
    }, () => {
      this.contentScale = 0.94;
      this.contentBlur = 12;
    });
  }

  private async finishTripCeremony(): Promise<void> {
    this.tripTitle = this.ceremonyTripTitle;
    this.tripDate = this.ceremonyTripDate;
    await this.createChecklist();
    this.showTripCeremony = false;
  }

  private dismissTripCeremony(): void {
    this.showTripCeremony = false;
    this.recoverTripBackground();
  }

  private recoverTripBackground(duration: number = DURATION_RECOVER): void {
    this.getUIContext().animateTo({
      duration: duration,
      curve: CURVE_DECELERATE
    }, () => {
      this.contentScale = 1.0;
      this.contentBlur = 0;
    });
  }

  private async createChecklist(): Promise<void> {
    const title = this.tripTitle.trim();
    if (title.length === 0) {
      this.errorText = '行程名称不能为空';
      return;
    }
    const created = createChecklistFactory(title, this.tripDate.trim(),
      parseTripDateAt(this.tripDate),
      this.ceremonyDestination.trim().length > 0 ? this.ceremonyDestination.trim() : undefined,
      clampNumber(this.ceremonyDistanceKm, 0, 100000),
      clampNumber(this.ceremonyMaxAltitude, -500, 9000),
      clampNumber(this.ceremonyAscentM, 0, 50000),
      clampNumber(this.ceremonyDurationHours, 0, 8760));
    const nextChecklists = prependChecklist(this.checklists, created);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    this.selectedChecklistId = created.id;
    this.closeSheet();
    this.startShakeListening();
    this.pushTripDetail();
  }

  private openChecklist(checklistId: string): void {
    this.selectedChecklistId = checklistId;
    this.collapsedGroups = [];
    this.startShakeListening();
    // 导航离开时收回清单页 swipeAction
    this.homeSwipeResetNonce++;
    this.pushTripDetail();
  }

  private pushTripDetail(): void {
    this.getUIContext().animateTo({
      curve: SPRING_HERO_EXPAND()
    }, () => {
      this.contentBlur = 12;
      this.contentScale = 0.94;
      this.navPathStack.pushPath({ name: 'TripDetailPage' }, false);
    });
  }

  private returnToHome(): void {
    // 问题4a：离开行程详情页时清空聚焦态，避免下次进入残留
    this.focusedZone = null;
    this.stopShakeListening();
    this.tabsController.changeIndex(0);
    if (this.navPathStack.size() > 0) {
      this.getUIContext().animateTo({
        curve: SPRING_HERO_COLLAPSE()
      }, () => {
        this.contentBlur = 0;
        this.contentScale = 1.0;
        this.navPathStack.pop(false);
      });
    }
  }

  private openReviewMode(): void {
    this.reviewZoneFilter = null;
    this.startReview();
  }

  // D-2：聚焦态「逐项核查本区」入口 — 进入 Review 只核查本 Zone item。
  private openZoneReview(zone: string): void {
    this.reviewZoneFilter = zone;
    this.startReview();
  }

  private startReview(): void {
    // filter 后计数：若本区无 item，提示并放弃
    const items = this.reviewZoneFilter !== null
      ? this.currentChecklist()?.items.filter(i => i.group === this.reviewZoneFilter) ?? []
      : this.currentChecklist()?.items ?? [];
    if (items.length === 0) {
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
      hilog.error(0x0001, 'PackCheck', 'startShakeListening failed: %{public}s', JSON.stringify(error));
    }
  }

  private stopShakeListening(): void {
    if (!this.shakeListening) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER, this.shakeCallback);
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'stopShakeListening failed: %{public}s', JSON.stringify(error));
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
    this.pendingTimers.push(setTimeout(() => {
      if (this.highlightedItemId === pick.id) {
        this.highlightedItemId = '';
      }
    }, 1200));
  }

  private async deleteChecklist(checklistId: string): Promise<void> {
    // 原子化：先计算好所有新状态，再一次性赋值
    const nextChecklists = this.checklists.filter((item: TripChecklist) => item.id !== checklistId);
    const nextSelectedId = this.selectedChecklistId === checklistId
      ? (nextChecklists.length === 0 ? '' : nextChecklists[0].id)
      : this.selectedChecklistId;
    // 一次性更新 @State，消灭中间帧 selectedIndex 越界
    this.selectedChecklistId = nextSelectedId;
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
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
    this.openSheetAnimated();
  }

  private openEditItemSheet(item: ChecklistItem): void {
    this.editingItemId = item.id;
    this.editingItemName = resolveItemName(item, this.gears);
    this.editingItemGroup = item.group;
    this.editingItemWeight = numberInputText(this.checklistItemWeight(item));
    this.editingItemPrice = numberInputText(this.checklistItemPrice(item));
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

    const name = resolveItemName(item, this.gears).trim();
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

    const created = createGear({ name: name, category: group, weight: item.weight, price: item.price });
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
    this.tripDestination = checklist.destination !== undefined ? checklist.destination : '';
    this.tripDistanceKm = typeof checklist.distanceKm === 'number' ? checklist.distanceKm.toString() : '';
    this.tripMaxAltitude = typeof checklist.maxAltitude === 'number' ? checklist.maxAltitude.toString() : '';
    this.tripAscentM = typeof checklist.ascentM === 'number' ? checklist.ascentM.toString() : '';
    this.tripDurationHours = typeof checklist.durationHours === 'number' ? checklist.durationHours.toString() : '';
    this.sheetMode = SHEET_EDIT_TRIP;
    this.openSheetAnimated();
  }

  private async saveTripInfo(): Promise<void> {
    const checklist = this.currentChecklist();
    const title = this.tripTitle.trim();
    if (checklist === undefined || title.length === 0) {
      this.errorText = '行程名称不能为空';
      return;
    }
    const profile: TripProfileUpdate = {
      destination: this.tripDestination.trim().length > 0 ? this.tripDestination.trim() : undefined,
      distanceKm: clampNumber(this.tripDistanceKm, 0, 100000),
      maxAltitude: clampNumber(this.tripMaxAltitude, -500, 9000),
      ascentM: clampNumber(this.tripAscentM, 0, 50000),
      durationHours: clampNumber(this.tripDurationHours, 0, 8760)
    };
    await this.updateChecklistInfo(checklist.id, title, this.tripDate.trim(), parseTripDateAt(this.tripDate), profile);
    this.closeSheet();
  }

  private openEditProfileSheet(): void {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    this.tripDate = checklist.date !== undefined ? checklist.date : '';
    this.tripDestination = checklist.destination !== undefined ? checklist.destination : '';
    this.tripDistanceKm = typeof checklist.distanceKm === 'number' ? checklist.distanceKm.toString() : '';
    this.tripMaxAltitude = typeof checklist.maxAltitude === 'number' ? checklist.maxAltitude.toString() : '';
    this.tripAscentM = typeof checklist.ascentM === 'number' ? checklist.ascentM.toString() : '';
    this.tripDurationHours = typeof checklist.durationHours === 'number' ? checklist.durationHours.toString() : '';
    this.sheetMode = SHEET_EDIT_PROFILE;
    this.openSheetAnimated();
  }

  private async saveProfileInfo(): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const profile: TripProfileUpdate = {
      destination: this.tripDestination.trim().length > 0 ? this.tripDestination.trim() : undefined,
      distanceKm: clampNumber(this.tripDistanceKm, 0, 100000),
      maxAltitude: clampNumber(this.tripMaxAltitude, -500, 9000),
      ascentM: clampNumber(this.tripAscentM, 0, 50000),
      durationHours: clampNumber(this.tripDurationHours, 0, 8760)
    };
    await this.updateChecklistInfo(checklist.id, checklist.title, this.tripDate.trim(), parseTripDateAt(this.tripDate), profile);
    this.closeSheet();
  }

  private async updateChecklistInfo(checklistId: string, title: string, date: string,
    dateAt: number | undefined, profile?: TripProfileUpdate): Promise<void> {
    const nextChecklists = updateChecklistMeta(this.checklists, checklistId, title, date, dateAt, profile);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  private openDatePicker(): void {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    DatePickerDialog.show({
      // 编辑已有行程时默认选中其既有出发日期，新建/无日期时回退到今天
      selected: checklist.dateAt !== undefined ? new Date(checklist.dateAt) : new Date(),
      lunar: false,
      showTime: false,
      onDateAccept: (date: Date) => {
        this.updateChecklistInfo(checklist.id, checklist.title, formatTripDate(date), startOfDay(date));
      }
    });
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
    const nextChecklists = addItemsToChecklist(this.checklists, checklist.id, [item]);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    await this.ensureCategory(group);
    this.tempItemName = '';
    this.showTempAddNotice = true;
    this.errorText = '';
    this.pendingTimers.push(setTimeout(() => {
      if (this.sheetMode === SHEET_TEMP_ITEM) {
        this.showTempAddNotice = false;
      }
    }, 500));
  }

  private async saveEditedItem(): Promise<void> {
    const name = this.editingItemName.trim();
    const group = this.editingItemGroup.trim().length === 0 ? '其他' : this.editingItemGroup.trim();
    const weight = clampNumber(this.editingItemWeight, 0, 100000);
    const price = clampNumber(this.editingItemPrice, 0, 9999999);
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
    const nextChecklists = updateItemFields(this.checklists, checklist.id, itemId, name, group, fromGearId, updateGearId, weight, price, updateMetrics);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  private openImportSheet(): void {
    this.importGearIds = [];
    this.importGearCategory = CATEGORY_ALL;
    this.sheetMode = SHEET_IMPORT;
    this.openSheetAnimated();
  }


  private openGearPickerSheet(zone?: string): void {
    // zone 非空时记录预选分区，picker 据此排序高亮 + 预选临时新建分区（review I4）
    this.pickerPreselectZone = (zone !== undefined && zone.length > 0) ? zone : '';
    this.sheetMode = SHEET_GEAR_PICKER;
    this.openSheetAnimated();
  }

  private openGearItemActionSheet(item: ChecklistItem): void {
    this.actionSheetItem = item;
    this.sheetMode = SHEET_GEAR_ITEM_ACTION;
    this.openSheetAnimated();
  }

  private currentTripGearIds(): string[] {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return [];
    }
    const ids: string[] = [];
    for (let i = 0; i < checklist.items.length; i++) {
      const gid = checklist.items[i].fromGearId;
      if (gid !== undefined && gid !== '') {
        ids.push(gid);
      }
    }
    return ids;
  }

  private async toggleGearInTrip(gear: GearItem): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    // 如果已存在则移除，否则添加
    const existingIndex = checklist.items.findIndex(item => item.fromGearId === gear.id);
    if (existingIndex >= 0) {
      const nextChecklists = removeItemFromChecklists(this.checklists, checklist.id, checklist.items[existingIndex].id);
      this.applyChecklistState(nextChecklists);
      await this.store.saveChecklists(nextChecklists);
    } else {
      // 透传 pickerPreselectZone：用户点的哪个格子，装备就直接进那个格子
      const zone = this.pickerPreselectZone.length > 0 ? this.pickerPreselectZone : undefined;
      const newItems = buildItemsFromGears(this.gears, [gear.id], zone);
      const nextChecklists = addItemsToChecklist(this.checklists, checklist.id, newItems);
      this.applyChecklistState(nextChecklists);
      await this.store.saveChecklists(nextChecklists);
    }
  }

  private async addTempGearToTrip(name: string, zone: string, weight: number | undefined): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const tempItem: ChecklistItem = {
      id: makeId('item'),
      name: name,
      group: zone,
      checked: false,
      weight: weight
    };
    const nextChecklists = addItemsToChecklist(this.checklists, checklist.id, [tempItem]);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  // P3：新建装备并存入装备库，同时加入当前行程。
  //   入库构造范式对齐 saveGear()，weight 已是规范化数值，category 为用户显式选择。
  //   zone = 用户当前点击的格子（pickerPreselectZone），直接归入该格子。
  private async createGearAndAddToTrip(name: string, zone: string, weight: number | undefined, category: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const safeCategory = category.trim().length === 0 ? CATEGORY_FALLBACK : category.trim();
    const created = createGear({ name: name, category: safeCategory, weight: weight });
    // 入库
    const nextGears: GearItem[] = [created].concat(this.gears);
    await this.store.saveGears(nextGears);
    this.gears = nextGears;
    await this.ensureCategory(safeCategory);
    // 挂入当前行程——直接使用用户选择的 zone，不走品类自动推断
    const targetZone = zone.length > 0 ? zone : undefined;
    const newItems = buildItemsFromGears(this.gears, [created.id], targetZone);
    const nextChecklists = addItemsToChecklist(this.checklists, checklist.id, newItems);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  private async moveItemToZone(itemId: string, zone: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists = this.checklists.map(cl => {
      if (cl.id !== checklist.id) {
        return cl;
      }
      // 找到目标 item 并创建更新后的副本
      const targetItem = cl.items.find(item => item.id === itemId);
      if (targetItem === undefined) {
        return cl;
      }
      const movedItem = cloneChecklistItem(targetItem, { group: zone });
      // 从数组中移除原 item（immutable spread 副本，避坑 #38）
      const withoutMoved = cl.items.filter(item => item.id !== itemId);
      // F-1：落点对齐目标格顶部（unshift）。
      // 找目标 zone 第一个 item 的索引，插到它前面；若目标 zone 为空，插到末尾。
      let insertAt = withoutMoved.length;
      for (let i = 0; i < withoutMoved.length; i++) {
        if (withoutMoved[i].group === zone) {
          insertAt = i;
          break;
        }
      }
      const updatedItems = withoutMoved.slice();
      updatedItems.splice(insertAt, 0, movedItem);
      return cloneChecklist(cl, { items: updatedItems });
    });
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    this.closeSheet();
  }

  // #10：格子内排序 — 按 orderedIds 重排指定 zone 的 items
  private async reorderChecklistItems(zone: string, orderedIds: string[]): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists = this.checklists.map(cl => {
      if (cl.id !== checklist.id) {
        return cl;
      }
      // 分离：该 zone 的 items 和其他 zone 的 items
      const zoneItems = cl.items.filter(item => item.group === zone);
      const otherItems = cl.items.filter(item => item.group !== zone);
      // 按 orderedIds 排序 zone items
      const reordered: ChecklistItem[] = [];
      for (const id of orderedIds) {
        const found = zoneItems.find(item => item.id === id);
        if (found !== undefined) {
          reordered.push(found);
        }
      }
      // 合并：保持其他 zone 的 items 位置不变，zone items 按新顺序插入原位置
      const result: ChecklistItem[] = [];
      let zoneInserted = false;
      for (const item of cl.items) {
        if (item.group === zone) {
          if (!zoneInserted) {
            // 第一次遇到该 zone 的 item 时，插入全部重排后的 items
            result.push(...reordered);
            zoneInserted = true;
          }
          // 跳过原始 zone items（已被 reordered 替代）
        } else {
          result.push(item);
        }
      }
      if (!zoneInserted) {
        result.push(...reordered);
      }
      return cloneChecklist(cl, { items: result });
    });
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

  // #1：批量移动 — 打开 Zone 选择面板（复用 actionSheet 模式，存 batch ids）
  @State private batchMoveItemIds: string[] = [];

  private openBatchMoveSheet(itemIds: string[]): void {
    this.batchMoveItemIds = itemIds;
    // 复用 actionSheetItem 的 zone 选择面板，用一个虚拟 item 触发
    // 实际上直接弹一个简单的 zone 选择 ActionSheet
    this.showBatchZoneSelector();
  }

  private showBatchZoneSelector(): void {
    // 使用系统 ActionSheet 让用户选择目标 Zone（过滤掉当前 zone）
    const zones: string[] = allZones();
    const currentZone = this.focusedZone;
    const sheets: SheetInfo[] = [];
    for (let i = 0; i < zones.length; i++) {
      const targetZone = zones[i];
      if (targetZone === currentZone) {
        continue; // 跳过当前 zone，移动到自身无意义
      }
      sheets.push({
        title: zoneDisplayName(targetZone),
        action: () => {
          this.batchMoveItemsToZone(this.batchMoveItemIds, targetZone);
        }
      });
    }
    ActionSheet.show({
      title: `移动 ${this.batchMoveItemIds.length} 件装备到…`,
      message: '选择目标区域',
      sheets: sheets,
      cancel: () => {}
    });
  }

  private async batchMoveItemsToZone(itemIds: string[], zone: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists = this.checklists.map(cl => {
      if (cl.id !== checklist.id) {
        return cl;
      }
      // 将所有选中 items 的 group 改为目标 zone
      const updatedItems = cl.items.map(item => {
        if (itemIds.indexOf(item.id) >= 0) {
          return cloneChecklistItem(item, { group: zone });
        }
        return item;
      });
      return cloneChecklist(cl, { items: updatedItems });
    });
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    this.batchMoveItemIds = [];
    // 批量移动完成后关闭聚焦视图（触发 onActiveChange → 自动退出多选模式）
    if (this.focusedZone != null) {
      this.focusedCloseSignal = this.focusedCloseSignal + 1;
    }
  }

  private async removeItemFromTrip(itemId: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists = removeItemFromChecklists(this.checklists, checklist.id, itemId);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    this.closeSheet();
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
    const items = buildItemsFromGears(this.gears, this.importGearIds);
    const nextChecklists = addItemsToChecklist(this.checklists, checklist.id, items);
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
    this.closeSheet();
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
    if (item === undefined) {
      return '';
    }
    return resolveItemName(item, this.gears);
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
    return '已带 ' + checkedCount(checklist).toString() + ' 件，未带 ' +
      (checklist.items.length - checkedCount(checklist)).toString() + ' 件';
  }

  private async markReviewItem(checked: boolean): Promise<void> {
    const item = this.currentReviewItem();
    const checklist = this.currentChecklist();
    if (item === undefined || checklist === undefined) {
      this.reviewFinished = true;
      return;
    }
    await this.setChecklistItemChecked(item.id, checked);
    // D-2：zone filter 时按过滤后的 item 数量判断 finish
    const totalItems = this.reviewZoneFilter !== null
      ? checklist.items.filter(i => i.group === this.reviewZoneFilter).length
      : checklist.items.length;
    const nextIndex = this.reviewIndex + 1;
    if (nextIndex >= totalItems) {
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
    const beforeCheckedCount = checkedCount(checklist);
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
            nextItems.push(cloneChecklistItem(item, { checked: checked }));
          } else {
            nextItems.push(item);
          }
        }
        const updatedChecklist = cloneChecklist(source, { items: nextItems });
        updatedCurrent = updatedChecklist;
        nextChecklists.push(updatedChecklist);
      } else {
        nextChecklists.push(source);
      }
    }
    this.applyChecklistState(nextChecklists, true);
    await this.store.saveChecklists(nextChecklists);
    if (updatedCurrent !== undefined && beforeTotal > 0 &&
      beforeCheckedCount === beforeTotal - 1 && checkedCount(updatedCurrent) === beforeTotal) {
      this.showAchievement();
    }
  }

  private async toggleChecklistItem(itemId: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const beforeCheckedCount = checkedCount(checklist);
    const beforeTotal = checklist.items.length;
    const nextChecklists = toggleItemInChecklists(this.checklists, checklist.id, itemId);
    this.highlightedItemId = itemId;
    this.applyChecklistState(nextChecklists, true);
    await this.store.saveChecklists(nextChecklists);
    this.pendingTimers.push(setTimeout(() => {
      if (this.highlightedItemId === itemId) {
        this.highlightedItemId = '';
      }
    }, 600));
    const updatedCurrent = nextChecklists.find((c: TripChecklist) => c.id === checklist.id);
    if (updatedCurrent !== undefined && beforeTotal > 0 &&
      beforeCheckedCount === beforeTotal - 1 && checkedCount(updatedCurrent) === beforeTotal) {
      this.showAchievement();
    }
  }

  private showAchievement(): void {
    // 克制高级：仅一条轻量胶囊提示，不阻断、不遮挡、快速自消失；去掉冗余系统 toast
    this.showCompletionToast = true;
    hapticStrong();
    this.pendingTimers.push(setTimeout(() => {
      this.showCompletionToast = false;
    }, 1600));
  }

  private showToastMessage(message: string, duration: number = 1500): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
    } catch (error) {
      hilog.error(0x0001, 'PackCheck', 'showToastMessage failed: %{public}s', JSON.stringify(error));
    }
  }

  private async triggerLightVibration(): Promise<void> {
    hapticTime(50);
  }

  private async deleteChecklistItem(itemId: string): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists = removeItemFromChecklists(this.checklists, checklist.id, itemId);
    // animated: true → ForEach 节点移除时播放退场动画（修复 #7 删除无即时反馈）
    this.applyChecklistState(nextChecklists, true);
    await this.store.saveChecklists(nextChecklists);
  }

  // ============ Itinerary CRUD ============

  /** 统一更新当前行程的 itinerary 并持久化 */
  private async updateItinerary(nextItinerary: DayItinerary[]): Promise<void> {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return;
    }
    const nextChecklists: TripChecklist[] = this.checklists.map((c: TripChecklist) => {
      if (c.id !== checklist.id) {
        return c;
      }
      return cloneChecklist(c, { itinerary: nextItinerary });
    });
    this.applyChecklistState(nextChecklists);
    await this.store.saveChecklists(nextChecklists);
  }

// ===== 新建/编辑一天 =====

private resetDayForm(): void {
this.editingDayId = '';
this.dayFormFrom = '';
this.dayFormTo = '';
this.dayFormDate = '';
this.dayFormNote = '';
}

private openAddDaySheet(): void {
this.resetDayForm();
this.sheetMode = SHEET_DAY_FORM;
this.openSheetAnimated();
}

private openEditDaySheet(dayId: string): void {
const itinerary = this.currentChecklist()?.itinerary ?? [];
const day = itinerary.find((d: DayItinerary) => d.id === dayId);
if (day === undefined) {
return;
}
this.editingDayId = dayId;
// 预填天级字段
this.dayFormFrom = day.from ?? '';
this.dayFormTo = day.to ?? '';
this.dayFormDate = day.date ?? '';
this.dayFormNote = day.note ?? '';
this.sheetMode = SHEET_DAY_FORM;
this.openSheetAnimated();
}

private async handleSubmitNewDay(day: DayItinerary): Promise<void> {
const itinerary = this.currentChecklist()?.itinerary ?? [];
const next = insertDay(itinerary, day);
await this.updateItinerary(next);
this.closeSheet();
}

private async handleSubmitEditDay(dayId: string, from: string, to: string, date: string, note: string): Promise<void> {
let itinerary = this.currentChecklist()?.itinerary ?? [];
// 纯天级 patch（from/to/date/note），不再联动 segments
const dayPatch: DayPatch = { from: from, to: to, date: date, note: note };
itinerary = updateDay(itinerary, dayId, dayPatch);
await this.updateItinerary(itinerary);
this.closeSheet();
}

private async handleDeleteDay(dayId: string): Promise<void> {
const itinerary = this.currentChecklist()?.itinerary ?? [];
const next = removeDay(itinerary, dayId);
await this.updateItinerary(next);
}

// ===== 新建/编辑路段 =====

private resetSegForm(): void {
this.editingSegmentId = '';
this.editingSegDayId = '';
this.segFormFrom = '';
this.segFormTo = '';
this.segFormTransport = 'other';
this.segFormDepartTime = '';
this.segFormArriveTime = '';
this.segFormNote = '';
this.segFormAccommodation = '';
this.segFormTicketCode = '';
this.segFormTicketSeat = '';
this.segFormTicketPrice = '';
}

private openAddSegmentSheet(dayId: string): void {
this.resetSegForm();
this.editingSegDayId = dayId;
this.sheetMode = SHEET_SEGMENT_FORM;
this.openSheetAnimated();
}

private openEditSegmentSheet(dayId: string, segId: string): void {
const itinerary = this.currentChecklist()?.itinerary ?? [];
const day = itinerary.find((d: DayItinerary) => d.id === dayId);
if (day === undefined) {
return;
}
const seg = day.segments.find((s: RouteSegment) => s.id === segId);
if (seg === undefined) {
return;
}
this.editingSegmentId = segId;
this.editingSegDayId = dayId;
this.segFormFrom = seg.from;
this.segFormTo = seg.to;
this.segFormTransport = seg.transport;
this.segFormDepartTime = seg.departTime ?? '';
this.segFormArriveTime = seg.arriveTime ?? '';
this.segFormNote = seg.note ?? '';
this.segFormAccommodation = seg.accommodation ?? '';
if (seg.ticket !== undefined) {
this.segFormTicketCode = seg.ticket.code ?? '';
this.segFormTicketSeat = seg.ticket.seat ?? '';
this.segFormTicketPrice = seg.ticket.price !== undefined ? seg.ticket.price.toString() : '';
} else {
this.segFormTicketCode = '';
this.segFormTicketSeat = '';
this.segFormTicketPrice = '';
}
this.sheetMode = SHEET_SEGMENT_FORM;
this.openSheetAnimated();
}

private async handleSubmitSegment(segment: RouteSegment): Promise<void> {
let itinerary = this.currentChecklist()?.itinerary ?? [];
if (this.editingSegmentId.length > 0) {
// 编辑模式：patch
const segPatch: SegmentPatch = {
  from: segment.from,
  to: segment.to,
  transport: segment.transport,
  departTime: segment.departTime ?? '',
  arriveTime: segment.arriveTime ?? '',
  note: segment.note ?? '',
  ticket: segment.ticket,
  accommodation: segment.accommodation ?? ''
};
itinerary = updateSegment(itinerary, this.editingSegDayId, this.editingSegmentId, segPatch);
} else {
// 新建模式：插入
itinerary = addSegment(itinerary, this.editingSegDayId, segment);
}
await this.updateItinerary(itinerary);
this.closeSheet();
}

private async handleDeleteSegment(dayId: string, segId: string): Promise<void> {
const itinerary = this.currentChecklist()?.itinerary ?? [];
const next = removeSegment(itinerary, dayId, segId);
await this.updateItinerary(next);
}

  private openSheetAnimated(): void {
    this.sheetTranslateY = 800;
    this.sheetOverlayOpacity = 0;
    this.getUIContext().animateTo({
      curve: SPRING_PANEL_ENTER()
    }, () => {
      this.sheetTranslateY = 0;
      this.sheetOverlayOpacity = 1;
      this.contentScale = 0.94;
      this.contentBlur = 12;
    });
  }

  private closeSheet(): void {
    this.errorText = '';
    this.returnToImportAfterGear = false;
    this.editingItemId = '';
    this.showTempAddNotice = false;
    // 防御性重置所有表单状态，避免残留脏数据
    this.resetGearForm();
    this.resetTripForm();
    this.resetDayForm();
    this.resetSegForm();
    this.getUIContext().animateTo({
      curve: SPRING_PANEL_EXIT(),
      onFinish: () => {
        this.sheetMode = SHEET_NONE;
      }
    }, () => {
      this.sheetTranslateY = 800;
      this.sheetOverlayOpacity = 0;
      this.contentScale = 1.0;
      this.contentBlur = 0;
    });
  }

  @Builder
  NavDestinationMap(name: string, param: Object) {
    if (name === 'TripDetailPage') {
      NavDestination() {
        TripDetailPage({
          checklists: this.checklists,
          gears: this.gears,
          selectedChecklistId: this.selectedChecklistId,
          checklistRenderNonce: this.checklistRenderNonce,
          focusedZone: this.focusedZone,
          closeFocusSignal: this.focusedCloseSignal,
          onReturnHome: () => {
            this.returnToHome();
          },
          onOpenEditTrip: () => {
            this.openEditTripSheet();
          },
          onOpenEditProfile: () => {
            this.openEditProfileSheet();
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
          onOpenZoneReview: (zone: string) => {
            this.openZoneReview(zone);
          },
          onOpenEditItem: (item: ChecklistItem) => {
            this.openEditItemSheet(item);
          },
          onToggleChecklistItem: (itemId: string) => {
            this.toggleChecklistItem(itemId);
          },
          onDeleteChecklistItem: (itemId: string) => {
            this.deleteChecklistItem(itemId);
          },
          onOpenGearPicker: (zone?: string) => {
            this.openGearPickerSheet(zone);
          },
          onMoveItemToZone: (itemId: string, zone: string) => {
            this.moveItemToZone(itemId, zone);
          },
          onRequestMoveSheet: (item: ChecklistItem) => {
            this.openGearItemActionSheet(item);
          },
          onReorderItems: (zone: string, orderedIds: string[]) => {
            this.reorderChecklistItems(zone, orderedIds);
          },
          onRequestBatchMoveSheet: (itemIds: string[]) => {
            this.openBatchMoveSheet(itemIds);
          },
          onAddDay: () => { this.openAddDaySheet(); },
          onEditDay: (dayId: string) => { this.openEditDaySheet(dayId); },
          onDeleteDay: (dayId: string) => { this.handleDeleteDay(dayId); },
          onAddSegment: (dayId: string) => { this.openAddSegmentSheet(dayId); },
          onEditSegment: (dayId: string, segId: string) => { this.openEditSegmentSheet(dayId, segId); },
          onDeleteSegment: (dayId: string, segId: string) => { this.handleDeleteSegment(dayId, segId); }
        })
      }
      .hideTitleBar(true)
      .width('100%')
      .height('100%')
      // 方案A 沉浸式：NavDestination 默认背景仅铺到安全区内，导致状态栏/Home条区露出 Navigation 背景
      //   产生肉眼色差与底部纯白条。expandSafeArea 让本页背景延伸至物理屏幕边缘，
      //   与内容背景同源同色，三段（状态栏/内容/Home条）无缝。内容仍由系统避让，不被遮挡。
      .backgroundColor(PAGE_BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .geometryTransition('trip-' + this.selectedChecklistId)
      .transition(TransitionEffect.opacity(0))
      .onBackPressed(() => {
        // 问题4a：系统返回/侧滑手势分层拦截——优先关 sheet，其次收聚焦，最后才返回首页。
        if (this.sheetMode !== SHEET_NONE) {
          this.closeSheet();
          return true;
        }
        if (this.focusedZone != null) {
          // 递增信号让 UnifiedChecklistView 走带动画收起（不直接改 focusedZone 以保留动画）
          this.focusedCloseSignal = this.focusedCloseSignal + 1;
          return true;
        }
        this.returnToHome();
        return true;
      })
    } else if (name === 'ReviewPage') {
      NavDestination() {
        ReviewPage({
          checklists: this.checklists,
          gears: this.gears,
          selectedChecklistId: this.selectedChecklistId,
          reviewIndex: this.reviewIndex,
          reviewFinished: this.reviewFinished,
          reviewDragX: this.reviewDragX,
          reviewZoneFilter: this.reviewZoneFilter,
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
      .onBackPressed(() => {
        this.exitReviewMode();
        return true;
      })
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
    // 即时切换 + 呼吸脉冲（并行，不阻塞切换）
    this.isClickSwitching = true;
    this.currentTabIndex = targetIndex;
    this.tabSwipeProgress = 0;
    this.tabsController.changeIndex(targetIndex);
    // visibility nonce：驱动目标 tab 子组件入场动画重播
    if (targetIndex === 0) { this.homeVisibilityNonce++; }
    else if (targetIndex === 1) { this.gearVisibilityNonce++; }
    else if (targetIndex === 2) { this.profileVisibilityNonce++; }
    // 呼吸下压（极短 EaseOut，不用 spring 避免拖尾）
    this.getUIContext().animateTo({
      duration: DURATION_CEREMONY_SHAKE, curve: CURVE_DECELERATE
    }, () => {
      this.contentScale = 0.97;
    });
    // 弹回（spring 回弹，灵动感）
    this.pendingTimers.push(setTimeout(() => {
      this.getUIContext().animateTo({
        curve: SPRING_TAB_BREATHE()
      }, () => {
        this.contentScale = 1.0;
      });
      this.isClickSwitching = false;
    }, 80));
  }

  // 计算 tab 项的视觉权重：1.0 = 完全选中，0.0 = 完全未选中
  private tabVisualWeight(index: number): number {
    const isCurrent = this.currentTabIndex === index;
    const progress = this.tabSwipeProgress; // 负值=向左滑（趋向 index+1），正值=向右滑（趋向 index-1）
    if (isCurrent) {
      // 当前选中项：随滑动逐渐"失去"选中态
      return 1.0 - Math.min(1.0, Math.abs(progress));
    }
    // 非当前项：判断是否是滑动目标
    const isSwipeTarget = (progress < 0 && index === this.currentTabIndex + 1) ||
      (progress > 0 && index === this.currentTabIndex - 1);
    if (isSwipeTarget) {
      return Math.min(1.0, Math.abs(progress));
    }
    return 0.0;
  }

  @Builder
  customTabBar(index: number, icon: Resource, label: string) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(FONT_SIZE_PAGE_TITLE)
        .fontColor([this.tabVisualWeight(index) > 0.5 ? PRIMARY_COLOR : TEXT_TERTIARY])
      Text(label)
        .fontSize(FONT_SIZE_MINI)
        .fontWeight(this.tabVisualWeight(index) > 0.5 ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.tabVisualWeight(index) > 0.5 ? PRIMARY_COLOR : TEXT_TERTIARY)
        .margin({ top: 2 })
      // 液态指示器小横条
      Row()
        .width(18 * this.tabVisualWeight(index))
        .height(3)
        .borderRadius(1.5)
        .backgroundColor(PRIMARY_COLOR)
        .margin({ top: 3 })
        .opacity(this.tabVisualWeight(index))
    }
    .justifyContent(FlexAlign.Center)
    .width(64)
    .height(48)
    .scale({
      x: 0.92 + 0.08 * this.tabVisualWeight(index),
      y: 0.92 + 0.08 * this.tabVisualWeight(index)
    })
    .opacity(0.6 + 0.4 * this.tabVisualWeight(index))
    .animation({ curve: SPRING_TAB_ICON() })
    .onClick(() => {
      if (this.currentTabIndex !== index) {
        this.triggerBlurPulse(index);
      }
    })
  }

  build() {
    Stack() {
      HdsNavigation(this.navPathStack) {
        Stack({ alignContent: Alignment.Bottom }) {
          HdsTabs({ controller: this.tabsController }) {
            TabContent() {
              HomePage({
                checklists: this.checklists,
                gears: this.gears,
                checklistRenderNonce: this.checklistRenderNonce,
                swipeResetNonce: this.homeSwipeResetNonce,
                tabVisibilityNonce: this.homeVisibilityNonce,
                onOpenTrip: () => {
                  this.startTripCeremony();
                },
                onQuickReview: (checklistId: string) => {
                  this.selectedChecklistId = checklistId;
                  const checklist = this.currentChecklist();
                  if (checklist !== undefined && checklist.items.length === 0) {
                    this.openChecklist(checklistId);
                    this.showToastMessage('先添加装备再核查');
                  } else {
                    this.openReviewMode();
                  }
                },
                onOpenChecklist: (id: string) => {
                  this.openChecklist(id);
                },
                onConfirmDeleteChecklist: (item: TripChecklist) => {
                  this.confirmDeleteChecklist(item);
                }
              });
            }
            .tabBar(this.customTabBar(0, $r('sys.symbol.map'), '行程'))

            TabContent() {
              GearPage({
                gears: this.gears,
                selectedGearCategories: this.selectedGearCategories,
                gearSearchKeyword: this.gearSearchKeyword,
                gearSortMode: this.gearSortMode,
                expandedGearId: this.expandedGearId,
                swipeResetNonce: this.gearSwipeResetNonce,
                tabVisibilityNonce: this.gearVisibilityNonce,
                checklists: this.checklists,
                onSearchChange: (keyword: string) => {
                  this.gearSearchKeyword = keyword;
                },
                onOpenFilterPanel: () => {
                  this.openGearFilterPanel();
                },
                onOpenSort: () => {
                  this.sheetMode = SHEET_GEAR_SORT;
                  this.openSheetAnimated();
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
                onReorderGears: (nextGears: GearItem[]) => {
                  this.reorderGears(nextGears);
                }
              });
            }
            .tabBar(this.customTabBar(1, $r('sys.symbol.bag'), '装备库'))

            TabContent() {
              ProfilePage({
                trips: this.checklists,
                gears: this.gears,
                tabVisibilityNonce: this.profileVisibilityNonce,
              });
            }
            .tabBar(this.customTabBar(2, $r('sys.symbol.person'), '我'))
          }
          .animationDuration(200)
          .barOverlap(true)
          .vertical(false)
          .scrollable(true)
          .barPosition(BarPosition.End)
          .barHeight(56)
          .barFloatingStyle({
            barBottomMargin: 28,
            // gradientMask 已移除：从下往上的灰色渐变遮罩观感糟糕，删除后底部更干净。
            //   保留 systemMaterialEffect 材质效果，Tab 悬浮胶囊外观不变。
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.IMMERSIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
            }
          })
          .width('100%')
          .height('100%')
          .backgroundColor(TRANSPARENT)
          .blur(this.contentBlur)
          .scale({ x: this.contentScale, y: this.contentScale })
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            this.tabsWidth = newValue.width as number;
          })
          .onTouch((event: TouchEvent) => {
            if (this.isClickSwitching) {
              return;
            }
            if (event.type === TouchType.Down) {
              this.touchStartX = event.touches[0].x;
              this.isSwiping = false;
            } else if (event.type === TouchType.Move) {
              const deltaX = event.touches[0].x - this.touchStartX;
              // 超过 10vp 才认为是水平滑动
              if (Math.abs(deltaX) > 10) {
                this.isSwiping = true;
              }
              if (this.isSwiping && this.tabsWidth > 0) {
                // deltaX > 0 = 手指向右 = 内容向右 = 趋向 index-1（progress > 0）
                let progress = deltaX / this.tabsWidth;
                // 边界限制：不能超出有效范围（3 Tab：左边界 index=0，右边界 index=2）
                if (this.currentTabIndex === 0 && progress > 0) {
                  progress = 0;
                } else if (this.currentTabIndex === this.tabCount - 1 && progress < 0) {
                  progress = 0;
                }
                this.tabSwipeProgress = Math.max(-1, Math.min(1, progress));
                // 呼吸感：滑动越深 scale 越小（最深 0.97），跟手同步无延迟
                const breathDepth = Math.min(1.0, Math.abs(progress) * 2.5);
                this.contentScale = 1.0 - 0.03 * breathDepth;
              }
            } else {
              // Up / Cancel
              if (this.isSwiping && this.contentScale < 1.0) {
                // 如果滑动未触发切换（onAnimationStart 不会调用），手动弹回
                this.getUIContext().animateTo({
                  curve: SPRING_GENERAL()
                }, () => {
                  this.contentScale = 1.0;
                });
              }
              this.isSwiping = false;
            }
          })
          .onAnimationStart((_from: number, to: number) => {
            // 松手后确定最终目标，立即将指示器弹到目标位置
            this.currentTabIndex = to;
            this.tabSwipeProgress = 0;
            // visibility nonce：驱动目标 tab 子组件入场动画重播
            if (to === 0) { this.homeVisibilityNonce++; }
            else if (to === 1) { this.gearVisibilityNonce++; }
            else if (to === 2) { this.profileVisibilityNonce++; }
            // 呼吸回弹：spring 弹回原始 scale
            this.getUIContext().animateTo({
              curve: SPRING_GENERAL()
            }, () => {
              this.contentScale = 1.0;
            });
          })
          .onChange((index: number) => {
            this.currentTabIndex = index;
            this.tabSwipeProgress = 0;
            // 切换 Tab 时收回两个页面已展开的 swipeAction
            this.homeSwipeResetNonce++;
            this.gearSwipeResetNonce++;
            // visibility nonce 不在此递增 — onAnimationStart（滑动）和 triggerBlurPulse（点击）已各自递增过，
            // onChange 是兜底确认回调，重复递增会导致 resetEntryStates 被调用两次造成闪烁
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
              },
              onRename: (oldName: string, _newName: string) => { this.handleCategoryRename(oldName, ''); },
              onDelete: (category: string) => { this.handleCategoryDelete(category); },
              onReorder: (categories: string[]) => { this.executeCategoryReorder(categories); },
              onAddCategory: (_name: string) => { this.showCategoryInputPrompt('', true); }
            })
          }
        }
        .width('100%')
        .height('100%')
      }
      .navDestination(this.NavDestinationMap)
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .backgroundColor(PAGE_BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 覆盖层：独立于 Navigation 层级，始终在 NavDestination 之上
      if (this.sheetMode !== SHEET_NONE) {
        SheetOverlay({
          sheetMode: this.sheetMode,
          sheetTranslateY: this.sheetTranslateY,
          sheetOverlayOpacity: this.sheetOverlayOpacity,
          errorText: this.errorText,
          gearSortMode: this.gearSortMode,
          gearName: this.gearName,
          gearCategory: this.gearCategory,
          gearWeight: this.gearWeight,
          gearPrice: this.gearPrice,
          gearNote: this.gearNote,
          editingGearId: this.editingGearId,
          categories: this.presetCategories(),
          tripTitle: this.tripTitle,
          tripDate: this.tripDate,
          tripDestination: this.tripDestination,
          tripDistanceKm: this.tripDistanceKm,
          tripMaxAltitude: this.tripMaxAltitude,
          tripAscentM: this.tripAscentM,
          tripDurationHours: this.tripDurationHours,
          tempItemName: this.tempItemName,
          tempItemGroup: this.tempItemGroup,
          showTempAddNotice: this.showTempAddNotice,
          gears: this.gears,
          importGearIds: this.importGearIds,
          importGearCategory: this.importGearCategory,
          onClose: () => { this.closeSheet(); },
          onSelectSort: (mode: string) => {
            this.gearSortMode = mode;
            this.closeSheet();
          },
          onGearNameChange: (value: string) => { this.gearName = value; },
          onGearCategoryChange: (value: string) => { this.gearCategory = value; },
          onGearWeightChange: (value: string) => { this.gearWeight = value; },
          onGearPriceChange: (value: string) => { this.gearPrice = value; },
          onGearNoteChange: (value: string) => { this.gearNote = value; },
          onSaveGear: () => { this.saveGear(); },
          onTripTitleChange: (value: string) => { this.tripTitle = value; },
          onTripDateChange: (value: string) => { this.tripDate = value; },
          onTripDestinationChange: (value: string) => { this.tripDestination = value; },
          onTripDistanceKmChange: (value: string) => { this.tripDistanceKm = value; },
          onTripMaxAltitudeChange: (value: string) => { this.tripMaxAltitude = value; },
          onTripAscentMChange: (value: string) => { this.tripAscentM = value; },
          onTripDurationHoursChange: (value: string) => { this.tripDurationHours = value; },
          onCreateTrip: () => { this.createChecklist(); },
          onSaveTrip: () => { this.saveTripInfo(); },
          onSaveProfile: () => { this.saveProfileInfo(); },
          onTempItemNameChange: (value: string) => { this.tempItemName = value; },
          onTempItemGroupChange: (value: string) => { this.tempItemGroup = value; },
          onAddTempItem: () => { this.addTempItem(); },
          onImportCategoryChange: (value: string) => { this.importGearCategory = value; },
          onToggleImportSelection: (id: string, checked: boolean) => { this.toggleImportSelection(id, checked); },
          onImportSelectedGear: () => { this.importSelectedGear(); },
          onAddGearFromImport: () => { this.openAddGearFromImport(); },
          onCategoryRename: (oldName: string, newName: string) => { this.handleCategoryRename(oldName, newName); },
          onCategoryDelete: (category: string) => { this.handleCategoryDelete(category); },
          onCategoryReorder: (categories: string[]) => { this.executeCategoryReorder(categories); },
          onCategoryAdd: (_name: string) => { this.showCategoryInputPrompt('', true); },
          pickerSelectedIds: this.currentTripGearIds(),
          pickerPreselectZone: this.pickerPreselectZone,
          onPickerToggleGear: (gear: GearItem) => { this.toggleGearInTrip(gear); },
          onPickerAddGear: (name: string, zone: string, weight: number | undefined, category: string, saveToLibrary: boolean) => {
            if (saveToLibrary) {
              this.createGearAndAddToTrip(name, zone, weight, category);
            } else {
              this.addTempGearToTrip(name, zone, weight);
            }
          },
          actionItem: this.actionSheetItem,
          onActionMoveToZone: (itemId: string, zone: string) => { this.moveItemToZone(itemId, zone); },
          onActionViewDetail: (item: ChecklistItem) => {
            // 返回首页 → 切换到装备库 Tab → 展开对应装备卡片
            // 序列化：先关闭 Sheet 动画完成后再执行 Tab 切换，避免 Spring 竞争
            this.errorText = '';
            this.returnToImportAfterGear = false;
            this.editingItemId = '';
            this.showTempAddNotice = false;
            this.getUIContext().animateTo({
              curve: SPRING_PANEL_EXIT(),
              onFinish: () => {
                this.sheetMode = SHEET_NONE;
                // Sheet 关闭完毕后执行导航
                if (item.fromGearId !== undefined && item.fromGearId !== '') {
                  this.expandedGearId = item.fromGearId;
                  this.stopShakeListening();
                  if (this.navPathStack.size() > 0) {
                    this.getUIContext().animateTo({
                      curve: SPRING_HERO_COLLAPSE()
                    }, () => {
                      this.navPathStack.pop(false);
                    });
                  }
                  this.currentTabIndex = 1;
                  this.tabsController.changeIndex(1);
                }
              }
            }, () => {
              this.sheetTranslateY = 800;
              this.sheetOverlayOpacity = 0;
              this.contentScale = 1.0;
              this.contentBlur = 0;
            });
          },
          onActionRemove: (itemId: string) => { this.removeItemFromTrip(itemId); },
          // DayForm
          editingDayId: this.editingDayId,
          dayFrom: this.dayFormFrom,
          dayTo: this.dayFormTo,
          dayDate: this.dayFormDate,
          dayNote: this.dayFormNote,
          onDayFromChange: (v: string) => { this.dayFormFrom = v; },
          onDayToChange: (v: string) => { this.dayFormTo = v; },
          onDayDateChange: (v: string) => { this.dayFormDate = v; },
          onDayNoteChange: (v: string) => { this.dayFormNote = v; },
          onSubmitDay: (day: DayItinerary) => { this.handleSubmitNewDay(day); },
          onSubmitEditDay: (dayId: string, from: string, to: string, date: string, note: string) => {
            this.handleSubmitEditDay(dayId, from, to, date, note);
          },
          // SegmentForm
          editingSegmentId: this.editingSegmentId,
          segFrom: this.segFormFrom,
          segTo: this.segFormTo,
          segTransport: this.segFormTransport,
          segDepartTime: this.segFormDepartTime,
          segArriveTime: this.segFormArriveTime,
          segNote: this.segFormNote,
          segAccommodation: this.segFormAccommodation,
          ticketCode: this.segFormTicketCode,
          ticketSeat: this.segFormTicketSeat,
          ticketPrice: this.segFormTicketPrice,
          onSegFromChange: (v: string) => { this.segFormFrom = v; },
          onSegToChange: (v: string) => { this.segFormTo = v; },
          onSegTransportChange: (v: TransportMode) => { this.segFormTransport = v; },
          onSegDepartTimeChange: (v: string) => { this.segFormDepartTime = v; },
          onSegArriveTimeChange: (v: string) => { this.segFormArriveTime = v; },
          onSegNoteChange: (v: string) => { this.segFormNote = v; },
          onSegAccommodationChange: (v: string) => { this.segFormAccommodation = v; },
          onTicketCodeChange: (v: string) => { this.segFormTicketCode = v; },
          onTicketSeatChange: (v: string) => { this.segFormTicketSeat = v; },
          onTicketPriceChange: (v: string) => { this.segFormTicketPrice = v; },
          onSubmitSegment: (segment: RouteSegment) => { this.handleSubmitSegment(segment); },
          onDeleteDayFromSheet: () => {
            this.handleDeleteDay(this.editingDayId);
            this.closeSheet();
          },
          onDeleteSegmentFromSheet: () => {
            this.handleDeleteSegment(this.editingSegDayId, this.editingSegmentId);
            this.closeSheet();
          }
        })
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
          },
          onRename: (oldName: string, _newName: string) => { this.handleCategoryRename(oldName, ''); },
          onDelete: (category: string) => { this.handleCategoryDelete(category); },
          onReorder: (categories: string[]) => { this.executeCategoryReorder(categories); },
          onAddCategory: (_name: string) => { this.showCategoryInputPrompt('', true); }
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
          },
          onRename: (oldName: string, _newName: string) => { this.handleCategoryRename(oldName, ''); },
          onDelete: (category: string) => { this.handleCategoryDelete(category); },
          onReorder: (categories: string[]) => { this.executeCategoryReorder(categories); },
          onAddCategory: (_name: string) => { this.showCategoryInputPrompt('', true); }
        })
      }
      if (this.showTripCeremony) {
        TripCeremonyCard({
          tripTitle: this.ceremonyTripTitle,
          tripDate: this.ceremonyTripDate,
          tripDestination: this.ceremonyDestination,
          tripDistanceKm: this.ceremonyDistanceKm,
          tripMaxAltitude: this.ceremonyMaxAltitude,
          tripAscentM: this.ceremonyAscentM,
          tripDurationHours: this.ceremonyDurationHours,
          onTitleChange: (value: string) => {
            this.ceremonyTripTitle = value;
          },
          onDateChange: (value: string) => {
            this.ceremonyTripDate = value;
          },
          onDestinationChange: (value: string) => {
            this.ceremonyDestination = value;
          },
          onDistanceChange: (value: string) => {
            this.ceremonyDistanceKm = value;
          },
          onAltitudeChange: (value: string) => {
            this.ceremonyMaxAltitude = value;
          },
          onAscentChange: (value: string) => {
            this.ceremonyAscentM = value;
          },
          onDurationChange: (value: string) => {
            this.ceremonyDurationHours = value;
          },
          onFinish: () => {
            this.finishTripCeremony();
          },
          onDismiss: () => {
            this.dismissTripCeremony();
          },
          onExitStart: () => {
            this.recoverTripBackground(400);
          }
        })
      }
      if (this.showCompletionToast) {
        this.CompletionToast();
      }
      if (this.showCategoryDialog) {
        this.CategoryInputDialog();
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .overlay(this.NoiseTextureLayer())
  }



  @Builder
  private NoiseTextureLayer() {
    Image($r('app.media.noise_64'))
      .width('100%')
      .height('100%')
      .objectRepeat(ImageRepeat.XY)
      .objectFit(ImageFit.None)
      .opacity(0.025)
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private CompletionToast() {
    // 克制高级：无 emoji 的白毛玻璃胶囊，轻量上移、Spring 进出，不阻断不遮挡内容
    Column() {
      Row({ space: 6 }) {
        Circle({ width: 7, height: 7 })
          .fill(PRIMARY_COLOR)
        Text('全部就绪，出发吧')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_COLOR)
      }
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .backgroundColor(GLASS_BG_HEAVY)
      .backdropBlur(20)
      .borderRadius(20)
      .shadow({ radius: 16, color: PRIMARY_SHADOW_LIGHT, offsetX: 0, offsetY: 4 })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -12 }))
        .combine(TransitionEffect.scale({ x: PANEL_SCALE_START, y: PANEL_SCALE_START }))
        .animation({ curve: SPRING_PANEL_ENTER() })
      )
    }
    .width('100%')
    .height('100%')
    .padding({ top: 64 })
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private CategoryInputDialog() {
    Stack() {
      // 半透明遮罩 — 淡入淡出
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OVERLAY_MASK)
        .onClick(() => { this.showCategoryDialog = false; })
        .transition(TransitionEffect.OPACITY.animation({ curve: SPRING_PANEL_ENTER() }))

      // 对话框 — 缩放 + 淡入 + 轻微上移
      Column({ space: 16 }) {
        Text(this.categoryDialogMode === 'add' ? '新增分组' : '重命名分组')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        TextInput({ text: this.categoryDialogInput, placeholder: '输入分组名称' })
          .width('100%')
          .height(44)
          .maxLength(50)
          .fontSize(FONT_SIZE_OVERLINE)
          .borderRadius(10)
          .backgroundColor(GROUP_HEADER_BG)
          .onChange((value: string) => { this.categoryDialogInput = value; })

        Row({ space: 12 }) {
          Button('取消')
            .fontSize(FONT_SIZE_OVERLINE)
            .fontColor(TEXT_TERTIARY)
            .backgroundColor(DIVIDER_COLOR)
            .borderRadius(10)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.showCategoryDialog = false; })

          Button('确认')
            .fontSize(FONT_SIZE_OVERLINE)
            .fontColor(WHITE)
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(10)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              const input = this.categoryDialogInput.trim();
              if (input.length === 0) {
                return;
              }
              if (this.categoryDialogMode === 'add') {
                this.executeCategoryAdd(input);
              } else {
                this.executeCategoryRename(this.categoryDialogOldName, input);
              }
              this.showCategoryDialog = false;
            })
        }
        .width('100%')
      }
      .width('80%')
      .padding(24)
      .backgroundColor(CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 4 })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: PANEL_SCALE_START, y: PANEL_SCALE_START }))
        .combine(TransitionEffect.translate({ y: 8 }))
        .animation({ curve: SPRING_PANEL_ENTER() })
      )
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
