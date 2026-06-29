import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import {
  SPRING_SWIPE_RESET, SPRING_FAB_SNAP, SPRING_GENERAL, SPRING_SEARCH,
  SPRING_CHEVRON, SPRING_PRESS, SPRING_CEREMONY_FLIP,
  SPRING_SCROLL, SPRING_REORDER,
  EASE_FADE, DURATION_OVERLAY_FADE,
  DURATION_FAST,
  DURATION_NONE,
  PRESS_SCALE_DOWN, PRESS_SCALE_REST,
  STAGGER_OFFSET_Y, staggerDelay
} from '../constants/AnimationTokens';
import { HeadCollapseController } from '../utils/HeadCollapseController';
import { hapticTime } from '../utils/HapticUtils';
import { hdsEffect } from '@kit.UIDesignKit';
import { CATEGORY_ALL, GearItem, TripChecklist } from '../models/PackModels';
import { getPackStore, PackStore } from '../services/PackStore';
import { buildGearTripCountMap } from '../services/FootprintService';
import { numberOrZero, gearValueRatio, gearSortLabel, totalGearWeight, totalGearPrice, updateGear } from '../services/GearService';
import {
  ARROW_COLOR,
  CARD_BG,
  CHIP_RADIUS,
  SMALL_CARD_RADIUS,
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
  GLASS_BG,
  GROUP_HEADER_BG,
  OVERLAY_DIM,
  PAGE_BG,
  PAGE_PADDING,
  PRIMARY_COLOR,
  PRIMARY_SHADOW,
  PRIMARY_TINT_COLOR,
  SHADOW_DEFAULT,
  SHADOW_MEDIUM,
  SHADOW_SUBTLE,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  TRANSPARENT,
  WHITE
} from '../constants/DesignTokens';
import { getGroupColor } from '../utils/ColorUtils';
import { GearEmptyState } from './gear/GearEmptyState';
import { GearEmptyText } from './gear/GearEmptyText';

interface TripCardArea {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

enum OverlayPhase {
  IDLE = 'idle',
  MENU = 'menu',
  DRAGGING = 'dragging'
}

// 折叠态单品行高（44 content + 4*2 padding），拖拽让位平移量与命中检测共用
const GEAR_ROW_HEIGHT: number = 52;

@Component
export struct GearPage {
  @Prop @Watch('onGearDataChange') gears: GearItem[] = [];
  @Prop @Watch('onFilterSortChange') selectedGearCategories: string[] = [CATEGORY_ALL];
  @Prop @Watch('onFilterSortChange') gearSearchKeyword: string = '';
  @Prop @Watch('onFilterSortChange') gearSortMode: string = GEAR_SORT_GROUP;
  @Prop expandedGearId: string = '';
  @Prop @Watch('onSwipeResetNonceChange') swipeResetNonce: number = 0;
  // tabVisibilityNonce：父层每次切至此 tab 时递增，驱动入场动画重播
  // 解决 ArkUI TabContent keep-alive 时 aboutToAppear 不触发的问题
  @Prop @Watch('onTabVisibilityNonceChange') tabVisibilityNonce: number = 0;

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
  @State @Watch('onFilterSortChange') private categoryOrder: string[] = [];

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

  // --- 问题9：单品长按 → 菜单 → 拖动排序（自绘 overlay 状态机，替代系统 bindContextMenu）---
  //   范式对齐 UnifiedChecklistView：overlayPhase 状态机（idle→menu→dragging）+ 双坐标系
  //   （长按锚点全局坐标 longPress* + Pan 累积 offset 推出实时全局坐标，转局部驱动飞行胶囊）。
  //   menu 态：在锚点处弹自绘菜单（编辑/删除）；手指开始拖动则收菜单进 dragging 态。
  @State private gearOverlayPhase: OverlayPhase = OverlayPhase.IDLE;
  @State private gearOverlayItem: GearItem | null = null;
  @State private gearOverlayVisible: boolean = false; // 入场/退场动画开关（opacity/scale）
  // 拖拽态：飞行胶囊的局部坐标（相对 overlay 容器原点）+ Pan 累积偏移
  @State private gearDragCurrentX: number = 0;
  @State private gearDragCurrentY: number = 0;
  private gearDragOffsetX: number = 0;
  private gearDragOffsetY: number = 0;
  // 长按瞬间手指的全局坐标锚点（Pan offset 在此之上累加得实时全局坐标）
  private gearLongPressGlobalX: number = 0;
  private gearLongPressGlobalY: number = 0;
  // overlay 容器在屏幕中的原点（全局→局部转换用），由根容器 onAreaChange 记录
  private gearOverlayOriginX: number = 0;
  private gearOverlayOriginY: number = 0;
  // 命中目标：拖拽悬停的目标分类 + 目标插入索引（同组/跨组复用）
  @State private gearDropCategory: string = '';
  @State private gearDropIndex: number = -1;
  // 各单品行的全局矩形（命中检测用）：key=item.id → {x,y,w,h}（全局 vp）
  private gearRowRects: Map<string, TripCardArea> = new Map();
  // 各分组卡的全局矩形（跨分类落点用）：key=category → {x,y,w,h}
  private gearGroupRects: Map<string, TripCardArea> = new Map();
  // 拖拽边缘自动滚动
  private gearAutoScrollTimer: number = -1;
  private gearAutoScrollSpeed: number = 0;
  // 匿名 setTimeout 数组（listEntered/scrollToExpandedGear/enterGearOverlay/completeGearDrag）
  private timerIds: number[] = [];
  // 性能优化：拖拽期 item.id → index 查表（gearRowShiftY 热路径，避免 O(N) findIndex）
  private dragItemIndexMap: Map<string, number> = new Map();
  private dragSrcIdx: number = -1;
  // 拖拽 spring-load 自动展开：悬停在折叠分组上一段时间 → 临时展开；路过则收回。
  //   与持久化折叠偏好 collapsedGearGroups 解耦，落位时再决定转正/收回。
  private gearHoverGroup: string = '';          // 当前悬停的分组（判悬停目标是否切换）
  private gearHoverExpandTimer: number = -1;     // 悬停展开计时器
  @State private gearDragTempExpanded: string[] = []; // 拖拽期临时展开的分组集合
  // 菜单实测高度（onAreaChange 动态采集，用于底部边界检测 + 翻转弹出）
  private gearMenuMeasuredHeight: number = 320;

  @Prop @Watch('onGearDataChange') checklists: TripChecklist[] = [];
  private store: PackStore = getPackStore();
  private gearListScroller: Scroller = new Scroller();

  // 统一折叠控制器（overlay 范式：header 定高浮在 List 上、靠内部元素变形）。
  //   只接管「滚动数学」：progress 计算 + 跟手 + 松手就近吸附（补齐原本缺失的 onScrollStop）。
  //   collapseDistance = EXPANDED-COLLAPSED。锁定态（searchExpanded）的高度/背景/模糊特判均保留在各函数内（是高度自定义视觉，不属于「折叠」语义）。
  private headController: HeadCollapseController = new HeadCollapseController({
    collapseDistance: GEAR_HEADER_EXPANDED - GEAR_HEADER_COLLAPSED,
    enableSnap: true,
    getUIContext: () => this.getUIContext(),
    onChange: (progress: number, snapping: boolean) => {
      this.gearHeadSnapping = snapping;
      this.gearHeadProgress = progress;
    }
  });
  private screenWidth: number = 360; // fallback
  private screenHeight: number = 780;
  private isAlive: boolean = true;

  // ---- 性能缓存：filteredGears / groups / byGroup 一帧只算一次 ----
  // ⚠️ 必须 @State：rebuildGearCache() 重新赋值时需触发 ArkUI 依赖追踪，
  //   否则 ForEach 数据源引用不变 → 拖拽重排/跨分类移动后列表不刷新。
  @State private cachedFilteredGears: GearItem[] = [];
  @State private cachedGearGroups: string[] = [];
  @State private cachedGearsByGroup: Map<string, GearItem[]> = new Map();

  private onGearDataChange(): void {
    if (this.isAlive) {
      this.refreshGearTripCounts();
      this.rebuildGearCache();
    }
  }

  private onFilterSortChange(): void {
    if (this.isAlive) {
      this.rebuildGearCache();
    }
  }

  /** 一次性计算 filtered → sorted → 分组，结果写入缓存供 build 读取 */
  private rebuildGearCache(): void {
    // 1. 筛选 + 排序
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
    this.cachedFilteredGears = this.sortedGears(filtered);

    // 2. 分组列表
    const groups: string[] = [];
    for (let index = 0; index < this.cachedFilteredGears.length; index++) {
      const group = this.gearSortMode === GEAR_SORT_GROUP
        ? this.cachedFilteredGears[index].category
        : gearSortLabel(this.gearSortMode);
      if (groups.indexOf(group) < 0) {
        groups.push(group);
      }
    }
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
    this.cachedGearGroups = groups;

    // 3. 按分组分桶
    const byGroup = new Map<string, GearItem[]>();
    if (this.gearSortMode !== GEAR_SORT_GROUP) {
      // 非分组模式：只有一个虚拟组，所有 items 在同一桶
      for (let i = 0; i < groups.length; i++) {
        byGroup.set(groups[i], this.cachedFilteredGears);
      }
    } else {
      for (let i = 0; i < groups.length; i++) {
        byGroup.set(groups[i], []);
      }
      for (let i = 0; i < this.cachedFilteredGears.length; i++) {
        const cat = this.cachedFilteredGears[i].category;
        const bucket = byGroup.get(cat);
        if (bucket !== undefined) {
          bucket.push(this.cachedFilteredGears[i]);
        }
      }
    }
    this.cachedGearsByGroup = byGroup;
  }

  private onSwipeResetNonceChange(): void {
    if (this.swipedGearId !== '') {
      this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
        this.swipedGearId = '';
        this.swipeOffsetX = 0;
      });
    }
  }

  // shared：列表错落入场调度（被 aboutToAppear 和 onTabVisibilityNonceChange 复用）
  private triggerListStagger(): void {
    this.listEntered = false;
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.listEntered = true;
    }, 20) as number;
    this.timerIds.push(id);
  }

  // tab 可见性变化时重播列表 stager
  onTabVisibilityNonceChange(): void {
    this.triggerListStagger();
    // 重型计算（screen size / collapsedGroups / cache）不重跑
    // 交互状态（searchExpanded / overlayPhase / fabX/Y）保持不重置
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
    // 预计算出行次数
    this.refreshGearTripCounts();
    // 初始位置：右下角
    this.fabX = this.screenWidth - 50 - 16;
    this.fabY = this.screenHeight - 50 - 160; // 留出 TabBar 空间
    // 恢复折叠状态 + 分组顺序
    this.loadCollapsedGroups();
    this.loadCategoryOrder();
    // 性能优化：初始构建缓存
    this.rebuildGearCache();
    // 触发列表错落入场
    this.triggerListStagger();
  }

  // 预计算 gear→出行次数 map（排序/详情展示用），避免每次排序/渲染重复遍历
  private refreshGearTripCounts(): void {
    this.gearTripCountMap = buildGearTripCountMap(this.checklists);
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    this.stopGearAutoScroll();
    if (this.gearHoverExpandTimer >= 0) {
      clearTimeout(this.gearHoverExpandTimer);
      this.gearHoverExpandTimer = -1;
    }
    // 清理所有匿名 setTimeout
    for (let i = 0; i < this.timerIds.length; i++) {
      clearTimeout(this.timerIds[i]);
    }
    this.timerIds = [];
    // 重置 overlay 状态，防止组件销毁时残留
    this.gearOverlayPhase = OverlayPhase.IDLE;
    this.gearOverlayItem = null;
    this.gearOverlayVisible = false;
    this.gearDragTempExpanded = [];
    this.gearDropCategory = '';
    this.gearDropIndex = -1;
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

  onSearchChange: (keyword: string) => void = (keyword: string): void => {};
  onOpenFilterPanel: () => void = (): void => {};
  onOpenSort: () => void = (): void => {};
  onOpenAddGear: () => void = (): void => {};
  onOpenEditGear: (item: GearItem) => void = (item: GearItem): void => {};
  onConfirmDeleteGear: (item: GearItem) => void = (item: GearItem): void => {};
  onToggleGearExpanded: (id: string) => void = (id: string): void => {};
  // 问题9：单品拖拽排序/跨分类移动后，回传全量 gears 由父组件 saveGears + 回写 @Prop
  onReorderGears: (nextGears: GearItem[]) => void = (nextGears: GearItem[]): void => {};

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
        // 问题9：同分类内优先按手动拖动排序权重 order 升序；无 order 的旧数据回退 createdAt 倒序。
        //   一方有 order 一方无：有 order 的排前（手动整理过的优先稳定在前）。
        const lo = left.order;
        const ro = right.order;
        if (lo !== undefined && ro !== undefined) {
          return lo - ro;
        }
        if (lo !== undefined) {
          return -1;
        }
        if (ro !== undefined) {
          return 1;
        }
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

  /** 返回缓存的筛选+排序结果（rebuildGearCache 预算）。O(1) 读取。 */
  private filteredGears(): GearItem[] {
    return this.cachedFilteredGears;
  }

  /** 返回缓存的分组列表（rebuildGearCache 预算）。O(1) 读取。 */
  private filteredGearGroups(): string[] {
    return this.cachedGearGroups;
  }

  private displayGearGroups(): string[] {
    if (this.groupDragMode && this.groupReorderList.length > 0) {
      return this.groupReorderList;
    }
    return this.filteredGearGroups();
  }

  /** 返回缓存的分组 items（rebuildGearCache 预算）。O(1) Map 查表。 */
  private filteredGearsByGroup(group: string): GearItem[] {
    return this.cachedGearsByGroup.get(group) ?? this.cachedFilteredGears;
  }

  /** 构建拖拽目标分类的 id→index 映射，进入 dragging 态及跨分类切换时调用 */
  private rebuildDragIndexMap(): void {
    this.dragItemIndexMap.clear();
    if (this.gearOverlayItem === null) {
      this.dragSrcIdx = -1;
      return;
    }
    const category = this.gearOverlayItem.category;
    const rows = this.filteredGearsByGroup(category);
    for (let i = 0; i < rows.length; i++) {
      this.dragItemIndexMap.set(rows[i].id, i);
    }
    this.dragSrcIdx = this.dragItemIndexMap.get(this.gearOverlayItem.id) ?? -1;
  }

  // 问题9-A 避让：把「被拖项留下的透明洞」视觉迁移到插入点。
  //   第一性原理：插到这里，洞与插入点之间的东西自动腾位填洞/让缝。
  //   坐标系与 hitTestGearDrop 完全一致——均基于「含被拖项的完整分组列表」full index。
  //   被拖项在 srcIdx，落点 dropIndex（插入索引）：
  //     - 向下拖（dropIndex > srcIdx）：(srcIdx, dropIndex) 区间内的行上移一行高，
  //       原洞被填、缝自然出现在 dropIndex-1 槽。
  //     - 向上拖（dropIndex < srcIdx）：[dropIndex, srcIdx) 区间内的行下移一行高，
  //       缝出现在 dropIndex 槽。
  private gearRowShiftY(item: GearItem): number {
    if (this.gearOverlayPhase !== OverlayPhase.DRAGGING) {
      return 0;
    }
    if (this.gearDropCategory === '' || this.gearDropIndex < 0) {
      return 0;
    }
    if (item.category !== this.gearDropCategory) {
      return 0;
    }
    const draggingId: string = this.gearOverlayItem !== null ? this.gearOverlayItem.id : '';
    if (item.id === draggingId) {
      return 0;
    }
    // 性能优化：O(1) 查表替代 O(N) findIndex
    const myIdx = this.dragItemIndexMap.get(item.id) ?? -1;
    if (myIdx < 0) {
      return 0;
    }
    const srcIdx = this.dragSrcIdx;
    const dropIdx: number = this.gearDropIndex;
    if (srcIdx < 0) {
      // 被拖项不在本分类（跨分类拖入）：落点及之后的行整体下移腾缝
      return myIdx >= dropIdx ? GEAR_ROW_HEIGHT : 0;
    }
    if (dropIdx > srcIdx) {
      // 向下：原洞之下、落点之前的行上移填洞
      return (myIdx > srcIdx && myIdx < dropIdx) ? -GEAR_ROW_HEIGHT : 0;
    }
    if (dropIdx < srcIdx) {
      // 向上：落点及之后、原洞之前的行下移让缝
      return (myIdx >= dropIdx && myIdx < srcIdx) ? GEAR_ROW_HEIGHT : 0;
    }
    return 0;
  }

  private formatKg(weightGram: number): string {
    if (weightGram <= 0) {
      return '0kg';
    }
    return (Math.round(weightGram / 100) / 10).toString() + 'kg';
  }


  private gearGroupCount(group: string): number {
    return this.filteredGearsByGroup(group).length;
  }

  private isGearGroupCollapsed(group: string): boolean {
    // 搜索模式下所有分组强制展开，用户取消搜索后恢复原折叠偏好
    if (this.gearSearchKeyword.trim().length > 0) {
      return false;
    }
    // 拖拽 spring-load 临时展开：复用现有展开渲染链路（含 SPRING 过渡），落位时再清理
    if (this.gearDragTempExpanded.indexOf(group) >= 0) {
      return false;
    }
    return this.collapsedGearGroups.indexOf(group) >= 0;
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
    let timerId = setTimeout(() => {
      if (!this.isAlive) { return; }
      const idx = this.gearListIndex(id);
      if (idx >= 0) {
        this.gearListScroller.scrollToIndex(idx, true, ScrollAlign.CENTER);
      }
    }, 50) as number;
    this.timerIds.push(timerId);
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
    if (this.searchExpanded) {
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
      this.Fab();

      // --- 分组拖拽浮动层 ---
      if (this.groupDragMode) {
        this.FloatingGroupCard()
      }

      // --- 问题9：单品长按 overlay（菜单态 + 拖拽飞行胶囊）---
      if (this.gearOverlayItem !== null) {
        this.GearDragOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const newWidth = newArea.width as number;
      const newHeight = newArea.height as number;
      // 问题9：记录根 Stack 全局原点，供单品拖拽飞行胶囊全局→局部坐标转换
      if (newArea.globalPosition !== undefined) {
        this.gearOverlayOriginX = newArea.globalPosition.x as number;
        this.gearOverlayOriginY = newArea.globalPosition.y as number;
      }
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
  }

  @Builder
  private CollapsingHeader() {
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
                  .maxLength(50)
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
              if (this.gearSortMode !== GEAR_SORT_GROUP || this.searchExpanded) {
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
      // 记录分组全局矩形：用于跨分类拖拽落点判定
      if (newArea.globalPosition !== undefined) {
        this.gearGroupRects.set(group, {
          id: group,
          x: newArea.globalPosition.x as number,
          y: newArea.globalPosition.y as number,
          w: newArea.width as number,
          h: newArea.height as number
        });
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
      // 拖拽态：原行隐身（透明洞占位），由 overlay 飞行胶囊接管视觉
      .opacity(this.gearOverlayPhase === OverlayPhase.DRAGGING && this.gearOverlayItem?.id === item.id ? 0 : 1)
      // 问题9-A 让位：被拖项留下的透明洞「视觉迁移」到插入点——
      //   洞与插入点之间的兄弟行 SPRING 平移一行高，把洞推到落点位置。
      .translate({ y: this.gearRowShiftY(item) })
      .animation({ curve: SPRING_REORDER() })
      // 记录该行全局矩形：用于拖拽命中检测（splice 让位 + drop 落点）
      //   拖拽态冻结：让位平移会改变 onAreaChange 上报的 globalPosition，若此时更新
      //   会让命中目标随让位漂移形成反馈回路，故仅在静止态采集 rect。
      .onAreaChange((_oldVal: Area, newVal: Area) => {
        if (this.gearOverlayPhase === OverlayPhase.DRAGGING) {
          return;
        }
        if (newVal.globalPosition !== undefined) {
          this.gearRowRects.set(item.id, {
            id: item.id,
            x: newVal.globalPosition.x as number,
            y: newVal.globalPosition.y as number,
            w: newVal.width as number,
            h: newVal.height as number
          });
        }
      })
      // 长按进入自绘 overlay（menu 态）→ 上滑/下滑切 dragging 态实时跟手
      .gesture(
        GestureGroup(GestureMode.Sequence,
          LongPressGesture({ fingers: 1, repeat: false, duration: 400 })
            .onAction((event: GestureEvent) => {
              this.enterGearOverlay(item, event.fingerList[0].globalX, event.fingerList[0].globalY);
            }),
          PanGesture({ fingers: 1, distance: 5 })
            .onActionUpdate((event: GestureEvent) => {
              this.updateGearDrag(event.offsetX, event.offsetY);
            })
            .onActionEnd(() => {
              this.completeGearDrag();
            })
            .onActionCancel(() => {
              this.dismissGearOverlay();
            })
        )
      )
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

  // --- 问题9：单品长按 overlay（菜单态 + 拖拽飞行胶囊）---
  @Builder
  private GearDragOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 背景遮罩：仅 menu 态压暗可点击关闭；dragging 态完全淡出，消除全页压灰中间态
      // （对齐 UnifiedChecklistView：不用 backdropBlur，dragging 时背景不变深）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OVERLAY_DIM)
        .opacity(this.gearOverlayPhase === OverlayPhase.MENU && this.gearOverlayVisible ? 1 : 0)
        .animation({ curve: EASE_FADE, duration: DURATION_OVERLAY_FADE })
        .onClick(() => {
          if (this.gearOverlayPhase !== OverlayPhase.DRAGGING) {
            this.dismissGearOverlay();
          }
        })

      // menu 态：预览卡 + 菜单——常驻渲染，opacity 控制可见性（不用 if 硬切销毁）
      if (this.gearOverlayItem !== null) {
        this.GearOverlayMenu(this.gearOverlayItem)
      }

      // dragging 态：飞行胶囊（跟手）——常驻渲染，opacity 控制可见性
      if (this.gearOverlayItem !== null) {
        this.GearDragChip(this.gearOverlayItem)
      }
    }
    .width('100%')
    .height('100%')
    // 仅 menu 可见阶段拦截触摸（遮罩点击关闭）；idle/dragging 一律穿透
    .hitTestBehavior(
      this.gearOverlayPhase === OverlayPhase.MENU && this.gearOverlayVisible
        ? HitTestMode.Default
        : HitTestMode.None)
  }

  // menu 态：预览卡 + 编辑/删除 菜单（自绘，替代系统 bindContextMenu）
  @Builder
  private GearOverlayMenu(item: GearItem) {
    Column({ space: 10 }) {
      // 预览卡（复用既有 GearPreviewCard）
      this.GearPreviewCard(item)
      // 菜单
      Column() {
        this.GearOverlayMenuItem('编辑', false, () => {
          this.dismissGearOverlay();
          this.onOpenEditGear(item);
        })
        Divider().strokeWidth(0.5).color(DIVIDER_COLOR)
        this.GearOverlayMenuItem('删除', true, () => {
          this.dismissGearOverlay();
          this.onConfirmDeleteGear(item);
        })
      }
      .width('72%')
      .constraintSize({ maxWidth: 320, minWidth: 240 })
      .backgroundColor(CARD_BG)
      .borderRadius(SMALL_CARD_RADIUS)
      .clip(true)
      .shadow({ radius: 24, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    // 动态采集菜单实际高度，用于底部翻转判断
    .onAreaChange((_old: Area, newArea: Area) => {
      const h = newArea.height as number;
      if (h > 0) {
        this.gearMenuMeasuredHeight = h;
      }
    })
    // 锚点附近垂直定位：以长按局部 Y 为基准，底部不足时翻转到上方
    .margin({ top: this.gearOverlayMenuTop() })
    // 常驻渲染，仅 menu 阶段可见；进入 dragging 时随胶囊交叉淡出
    .scale({
      x: this.gearOverlayPhase === OverlayPhase.MENU && this.gearOverlayVisible ? 1 : 0.92,
      y: this.gearOverlayPhase === OverlayPhase.MENU && this.gearOverlayVisible ? 1 : 0.92
    })
    .opacity(this.gearOverlayPhase === OverlayPhase.MENU && this.gearOverlayVisible ? 1 : 0)
    .animation({ curve: SPRING_CEREMONY_FLIP() })
    .hitTestBehavior(this.gearOverlayPhase === OverlayPhase.MENU ? HitTestMode.Default : HitTestMode.None)
  }

  // 菜单定位：以长按锚点为基准，底部空间不足时翻转到锚点上方弹出。
  private gearOverlayMenuTop(): number {
    const anchorLocalY = this.gearLongPressGlobalY - this.gearOverlayOriginY;
    const menuH = this.gearMenuMeasuredHeight; // onAreaChange 动态采集
    const tabBarReserve = 84; // TabBar 56vp + 底部安全距离 28vp
    const topSafe = 60; // 顶部安全距离（状态栏 + 余量）
    const availableBelow = this.screenHeight - anchorLocalY - tabBarReserve;

    if (availableBelow >= menuH) {
      // 正常向下：锚点略上移 20vp，避免被手指遮挡
      let top = anchorLocalY - 20;
      // clamp 底部：菜单底边不超出安全区
      const maxTop = this.screenHeight - tabBarReserve - menuH;
      if (top > maxTop) {
        top = maxTop;
      }
      if (top < topSafe) {
        top = topSafe;
      }
      return top;
    } else {
      // 翻转到上方：菜单底边对齐锚点位置（锚点上方 20vp 余量）
      let top = anchorLocalY - menuH - 20;
      if (top < topSafe) {
        top = topSafe;
      }
      return top;
    }
  }

  @Builder
  private GearOverlayMenuItem(label: string, danger: boolean, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(danger ? DANGER_COLOR : TEXT_MAIN)
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      onTap();
    })
  }

  // dragging 态：飞行胶囊（紧凑名称卡，跟手；用 position 无动画 1:1 跟手）
  @Builder
  private GearDragChip(item: GearItem) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Row()
          .width(3)
          .height(14)
          .borderRadius(1.5)
          .backgroundColor(getGroupColor(this.gearDropCategory.length > 0 ? this.gearDropCategory : item.category))
        Text(item.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)
      // 跨分类移动时显示目标分类
      if (this.gearDropCategory.length > 0 && this.gearDropCategory !== item.category) {
        Text('→ ' + this.gearDropCategory)
          .fontSize(11)
          .fontColor(PRIMARY_COLOR)
      }
    }
    .constraintSize({ maxWidth: 200 })
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    // 实色卡 + 阴影（对齐 UnifiedChecklistView 范式，去毛玻璃叠半透明产生的灰雾脏阴影）
    .backgroundColor(CARD_BG)
    .borderRadius(12)
    .shadow({ radius: 20, color: SHADOW_MEDIUM, offsetX: 0, offsetY: 8 })
    // position 消费局部坐标 1:1 跟手（无动画）
    .position({ x: this.gearDragCurrentX - 90, y: this.gearDragCurrentY - 50 })
    .animation({ duration: DURATION_NONE })
    // 进入 dragging 时浮起放大 + 微倾斜，弹性曲线属性级承接
    .scale({
      x: this.gearOverlayPhase === OverlayPhase.DRAGGING ? 1.04 : 0.9,
      y: this.gearOverlayPhase === OverlayPhase.DRAGGING ? 1.04 : 0.9
    })
    .animation({ curve: SPRING_PRESS() })
    .rotate({ angle: this.gearOverlayPhase === OverlayPhase.DRAGGING ? -2 : 0 })
    .animation({ curve: SPRING_PRESS() })
    // 常驻渲染，仅 dragging 阶段可见
    .opacity(this.gearOverlayPhase === OverlayPhase.DRAGGING ? 1 : 0)
    .animation({ curve: EASE_FADE, duration: DURATION_OVERLAY_FADE })
    .hitTestBehavior(HitTestMode.None)
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

  // ============ 问题9：单品长按菜单 → 拖动排序（自绘 overlay 状态机）============

  // 长按触发：进入 menu 态，记录手指全局坐标锚点，弹出自绘菜单。
  //   仅 GROUP 排序态生效（其它排序模式 order 不参与，拖动无意义）；搜索态屏蔽。
  private enterGearOverlay(item: GearItem, globalX: number, globalY: number): void {
    if (this.gearSortMode !== GEAR_SORT_GROUP || this.searchExpanded) {
      return;
    }
    // 长按前若有左滑打开的行，先收回，避免视觉残留
    if (this.swipedGearId !== '') {
      this.getUIContext().animateTo({ curve: SPRING_SWIPE_RESET() }, () => {
        this.swipedGearId = '';
        this.swipeOffsetX = 0;
      });
    }
    this.gearOverlayItem = item;
    this.gearOverlayPhase = OverlayPhase.MENU;
    this.gearLongPressGlobalX = globalX;
    this.gearLongPressGlobalY = globalY;
    this.gearDragOffsetX = 0;
    this.gearDragOffsetY = 0;
    // 胶囊初始局部坐标 = 锚点局部坐标
    this.gearDragCurrentX = globalX - this.gearOverlayOriginX;
    this.gearDragCurrentY = globalY - this.gearOverlayOriginY;
    this.gearDropCategory = item.category;
    this.gearDropIndex = -1;
    hapticTime(30);
    // 入场动画
    let id = setTimeout(() => {
      if (!this.isAlive) {
        return;
      }
      this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
        this.gearOverlayVisible = true;
      });
    }, 16) as number;
    this.timerIds.push(id);
  }

  // Pan 更新：menu 态首次移动收菜单进 dragging 态；累加 offset 推实时全局坐标 → 局部驱动胶囊。
  private updateGearDrag(offsetX: number, offsetY: number): void {
    if (this.gearOverlayItem === null) {
      return;
    }
    if (this.gearOverlayPhase === OverlayPhase.MENU) {
      // 进入拖拽态：收菜单
      this.gearOverlayPhase = OverlayPhase.DRAGGING;
      hapticTime(20);
      // 性能优化：预构建当前分组的 id→index 映射，gearRowShiftY O(1) 查表
      this.rebuildDragIndexMap();
    }
    this.gearDragOffsetX = offsetX;
    this.gearDragOffsetY = offsetY;
    const fingerGlobalX = this.gearLongPressGlobalX + offsetX;
    const fingerGlobalY = this.gearLongPressGlobalY + offsetY;
    this.gearDragCurrentX = fingerGlobalX - this.gearOverlayOriginX;
    this.gearDragCurrentY = fingerGlobalY - this.gearOverlayOriginY;
    // 边缘自动滚动（用局部 Y）
    this.checkGearAutoScroll(this.gearDragCurrentY);
    // 命中检测：先判落在哪个分类（跨分类移动），再在该分类内判插入索引
    this.hitTestGearDrop(fingerGlobalX, fingerGlobalY);
  }

  // 命中检测：确定 gearDropCategory + gearDropIndex（拖拽悬停目标）
  private hitTestGearDrop(globalX: number, globalY: number): void {
    const prevCategory = this.gearDropCategory;
    const prevIndex = this.gearDropIndex;
    // 1) 先判落在哪个分组卡区域内 → 目标分类
    let hitCategory = '';
    this.gearGroupRects.forEach((rect: TripCardArea, category: string) => {
      if (globalY >= rect.y && globalY <= rect.y + rect.h) {
        hitCategory = category;
      }
    });
    if (hitCategory === '') {
      // 不在任何分组内：保持上次目标分类（避免空档抖动）
      return;
    }
    // 1.5) spring-load 悬停展开管理：悬停目标切换时，处理计时器 + 临时展开收回
    this.handleGearHover(hitCategory);
    // 2) 在目标分类内按各行中线确定插入索引
    const rows = this.filteredGearsByGroup(hitCategory);
    let insertIdx = rows.length; // 默认插到末尾
    for (let i = 0; i < rows.length; i++) {
      const rect = this.gearRowRects.get(rows[i].id);
      if (rect === undefined) {
        continue;
      }
      const midY = rect.y + rect.h / 2;
      if (globalY < midY) {
        insertIdx = i;
        break;
      }
    }
    this.gearDropCategory = hitCategory;
    this.gearDropIndex = insertIdx;
    // 性能优化：跨分类切换时重建 id→index 映射
    if (hitCategory !== prevCategory) {
      this.dragItemIndexMap.clear();
      for (let i = 0; i < rows.length; i++) {
        this.dragItemIndexMap.set(rows[i].id, i);
      }
      // 跨分类时被拖项不在目标分类，srcIdx = -1
      const draggingId = this.gearOverlayItem !== null ? this.gearOverlayItem.id : '';
      this.dragSrcIdx = this.dragItemIndexMap.get(draggingId) ?? -1;
    }
    // 进入新目标格触觉反馈
    if (hitCategory !== prevCategory || insertIdx !== prevIndex) {
      hapticTime(15);
    }
  }

  // spring-load 悬停管理：悬停目标变化时重置计时器；悬停在折叠分组上超时则临时展开。
  //   第一性原理：拖拽时分组是「落点容器」，悬停=意图进入→自动敞开；路过=未停留→保持闭合/收回。
  private handleGearHover(hitCategory: string): void {
    if (hitCategory === this.gearHoverGroup) {
      return; // 悬停目标未变，计时器继续走
    }
    // 悬停目标切换：清旧计时器
    if (this.gearHoverExpandTimer >= 0) {
      clearTimeout(this.gearHoverExpandTimer);
      this.gearHoverExpandTimer = -1;
    }
    // 离开旧分组：若旧分组是「临时展开」的（非用户偏好展开），路过即收回
    const prevHover = this.gearHoverGroup;
    if (prevHover !== '' && this.gearDragTempExpanded.indexOf(prevHover) >= 0) {
      this.collapseTempGroup(prevHover);
    }
    this.gearHoverGroup = hitCategory;
    // 新悬停分组若处于折叠态：启动 spring-load 计时器，超时临时展开
    if (this.isGearGroupCollapsed(hitCategory)) {
      this.gearHoverExpandTimer = setTimeout(() => {
        this.gearHoverExpandTimer = -1;
        // 仍悬停在同一分组、且仍是折叠态才展开（避免计时期间已离开）
        if (this.gearOverlayPhase === OverlayPhase.DRAGGING
          && this.gearHoverGroup === hitCategory
          && this.isGearGroupCollapsed(hitCategory)) {
          this.expandTempGroup(hitCategory);
        }
      }, 500);
    }
  }

  // 临时展开某分组（SPRING 丝滑），并触觉提示
  private expandTempGroup(group: string): void {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.gearDragTempExpanded = this.gearDragTempExpanded.concat([group]);
    });
    hapticTime(20);
  }

  // 收回某临时展开的分组（SPRING 丝滑）
  private collapseTempGroup(group: string): void {
    const idx = this.gearDragTempExpanded.indexOf(group);
    if (idx < 0) {
      return;
    }
    const next = this.gearDragTempExpanded.slice();
    next.splice(idx, 1);
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.gearDragTempExpanded = next;
    });
  }

  // 清理所有 spring-load 临时展开态（落位/取消时调用）
  private clearGearHoverState(): void {
    if (this.gearHoverExpandTimer >= 0) {
      clearTimeout(this.gearHoverExpandTimer);
      this.gearHoverExpandTimer = -1;
    }
    this.gearHoverGroup = '';
  }

  // Pan 结束：落位 → 重排 + 持久化 → 退出
  //   时序关键：先清 drop 状态（让 gearRowShiftY 对所有行归零），再提交重排，
  //   最后异帧收 overlay。避免「重排渲染时行仍处于让位偏移、再弹回原位」的二次跳动。
  private completeGearDrag(): void {
    this.stopGearAutoScroll();
    const dragged = this.gearOverlayItem;
    if (dragged === null) {
      this.dismissGearOverlay();
      return;
    }
    let committed = false;
    const dropCategory = this.gearDropCategory;
    const dropIndex = this.gearDropIndex;
    if (this.gearOverlayPhase === OverlayPhase.DRAGGING && dropCategory !== '' && dropIndex >= 0) {
      // 先清让位状态：gearRowShiftY 对所有行返回 0，列表渲染时行在自然位置
      this.gearOverlayPhase = OverlayPhase.IDLE;
      this.gearDropCategory = '';
      this.gearDropIndex = -1;
      const next = this.reorderGearsByDrop(dragged, dropCategory, dropIndex);
      if (next !== null) {
        this.onReorderGears(next); // optimistic：当帧落位
        hapticTime(30);
        committed = true;
      }
    }
    // spring-load 收尾：落位分组转正保持展开，其余临时展开收回
    this.finalizeGearTempExpand(committed ? dropCategory : '');
    if (committed) {
      // 落位帧与收起帧解耦：下一帧再收 overlay，让列表先完成重排渲染
      let id = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.dismissGearOverlay();
      }, 0) as number;
      this.timerIds.push(id);
    } else {
      this.dismissGearOverlay();
    }
  }

  // spring-load 收尾：keepGroup 为落位分组——若它是临时展开的，则转正（移出持久化折叠偏好）
  //   保持展开；其余临时展开的分组全部收回。先转正再清空临时集合，避免落位分组闪一下折叠。
  private finalizeGearTempExpand(keepGroup: string): void {
    this.clearGearHoverState();
    if (this.gearDragTempExpanded.length === 0) {
      return;
    }
    // 落位分组转正：从持久化折叠偏好里移除并落盘
    if (keepGroup !== '' && this.collapsedGearGroups.indexOf(keepGroup) >= 0) {
      const idx = this.collapsedGearGroups.indexOf(keepGroup);
      const nextCollapsed = this.collapsedGearGroups.slice();
      nextCollapsed.splice(idx, 1);
      this.collapsedGearGroups = nextCollapsed;
      this.gearGroupExpandTrigger++;
      this.persistCollapsedGroups();
    }
    // 清空临时集合：落位分组已转正（不再依赖临时态），其余分组随之 SPRING 收回
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.gearDragTempExpanded = [];
    });
  }

  // 核心重排：把 dragged 移到 targetCategory 的 targetIndex 位置，重写该分类内所有 order，
  //   跨分类时同时改 dragged.category。返回全量新 gears（保持其它分类不变）。
  //   order 策略：目标分类内可见项按落位后的新顺序，从 0 起步连续赋值（稀疏度无所谓，只看相对大小）。
  private reorderGearsByDrop(dragged: GearItem, targetCategory: string, targetIndex: number): GearItem[] | null {
    // 目标分类当前可见顺序（已按 order/createdAt 排序）
    const targetRows = this.filteredGearsByGroup(targetCategory).slice();
    // 从目标分类移除 dragged（同分类重排时它本就在列表里）
    const withoutDragged: GearItem[] = [];
    for (let i = 0; i < targetRows.length; i++) {
      if (targetRows[i].id !== dragged.id) {
        withoutDragged.push(targetRows[i]);
      }
    }
    // clamp 插入索引
    let idx = targetIndex;
    if (idx > withoutDragged.length) {
      idx = withoutDragged.length;
    }
    if (idx < 0) {
      idx = 0;
    }
    // 构造目标分类的新顺序
    const draggedNext = updateGear(dragged, { category: targetCategory, order: idx });
    const orderedTarget: GearItem[] = [];
    for (let i = 0; i < withoutDragged.length; i++) {
      orderedTarget.push(withoutDragged[i]);
    }
    orderedTarget.splice(idx, 0, draggedNext);
    // 重写目标分类内连续 order
    const orderById = new Map<string, GearItem>();
    for (let i = 0; i < orderedTarget.length; i++) {
      const reIndexed = updateGear(orderedTarget[i], { order: i });
      orderById.set(reIndexed.id, reIndexed);
    }
    // 合并回全量 gears：目标分类内的项用重排后的，其它原样
    const result: GearItem[] = [];
    let changed = false;
    for (let i = 0; i < this.gears.length; i++) {
      const g = this.gears[i];
      const replaced = orderById.get(g.id);
      if (replaced !== undefined) {
        result.push(replaced);
        if (replaced.order !== g.order || replaced.category !== g.category) {
          changed = true;
        }
      } else {
        result.push(g);
      }
    }
    return changed ? result : null;
  }

  // 退出 overlay（点菜单项 / 拖拽结束 / 点空白）
  private dismissGearOverlay(): void {
    this.stopGearAutoScroll();
    // spring-load 兜底：清理悬停计时器；取消路径（未落位）残留的临时展开全部 SPRING 收回。
    //   落位路径已由 finalizeGearTempExpand 清空，这里 length===0 自然跳过，幂等不冲突。
    this.clearGearHoverState();
    if (this.gearDragTempExpanded.length > 0) {
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.gearDragTempExpanded = [];
      });
    }
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL(),
      onFinish: () => {
        this.gearOverlayItem = null;
        this.gearOverlayPhase = OverlayPhase.IDLE;
        this.gearDragOffsetX = 0;
        this.gearDragOffsetY = 0;
        this.gearDropCategory = '';
        this.gearDropIndex = -1;
      }
    }, () => {
      this.gearOverlayVisible = false;
    });
  }

  // 拖拽边缘自动滚动（局部 Y 命中顶部/底部热区）
  private checkGearAutoScroll(localY: number): void {
    const edge = 90;
    const h = this.screenHeight;
    if (localY < edge) {
      this.gearAutoScrollSpeed = -((edge - localY) / edge) * 12;
      this.startGearAutoScroll();
    } else if (localY > h - edge) {
      this.gearAutoScrollSpeed = ((localY - (h - edge)) / edge) * 12;
      this.startGearAutoScroll();
    } else {
      this.stopGearAutoScroll();
    }
  }

  private startGearAutoScroll(): void {
    if (this.gearAutoScrollTimer >= 0) {
      return;
    }
    this.gearAutoScrollTimer = setInterval(() => {
      this.gearListScroller.scrollBy(0, this.gearAutoScrollSpeed);
    }, 16);
  }

  private stopGearAutoScroll(): void {
    if (this.gearAutoScrollTimer >= 0) {
      clearInterval(this.gearAutoScrollTimer);
      this.gearAutoScrollTimer = -1;
      this.gearAutoScrollSpeed = 0;
    }
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
