import { common } from '@kit.AbilityKit';
import { curves, display } from '@kit.ArkUI';
import { GearItem } from '../models/PackModels';
import { PackStore } from '../services/PackStore';
import { WeightGauge } from './WeightGauge';
import {
  CARD_BG,
  CARD_BORDER_BOTTOM_COLOR,
  CARD_BORDER_BOTTOM_WIDTH,
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
  GROUP_HEADER_BG,
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

  private store: PackStore = new PackStore();
  private gearListScroller: Scroller = new Scroller();
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

  // 计算目标装备在 List 中的 index（用于 scrollToIndex）
  private gearListIndex(targetId: string): number {
    let idx = 1; // index 0 是 top spacer
    const groups = this.filteredGearGroups();
    for (let g = 0; g < groups.length; g++) {
      idx++; // group header
      if (!this.isGearGroupCollapsed(groups[g])) {
        const items = this.filteredGearsByGroup(groups[g]);
        for (let i = 0; i < items.length; i++) {
          if (items[i].id === targetId) {
            return idx;
          }
          idx++;
        }
      }
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
    // 每个装备行约 92vp (64 content + 14*2 padding)，加 group header 约 40vp
    const groups = this.filteredGearGroups();
    const estimatedContentHeight = this.filteredGears().length * 92 + groups.length * 40;
    // 如果内容自身足够多，不需要额外空间来触发折叠
    if (estimatedContentHeight > collapseRange) {
      return 80; // 仅 TabBar 避让
    }
    // 内容不够时，补足让 scroll 范围 ≥ collapseRange
    return collapseRange - estimatedContentHeight + 80;
  }

  // 渐进式模糊：0~0.3 无 | 0.3~0.7 Thin | >0.7 Regular
  private gearHeaderBlurStyle(): BlurStyle {
    const p = this.gearScrollProgress();
    if (p < 0.3) {
      return BlurStyle.NONE;
    } else if (p < 0.7) {
      return BlurStyle.Thin;
    }
    return BlurStyle.Regular;
  }

  // 渐进式背景色：PAGE_BG → BLUR_BG，alpha 从 00 到 CC 跟随 progress
  private gearHeaderBgColor(): string {
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (this.searchExpanded) {
          this.SearchBar();
        }
        if (this.multiSelectMode) {
          this.MultiSelectBar();
        }
        Stack() {
          List({ space: 8, scroller: this.gearListScroller }) {
            ListItem() {
              Column()
                .width('100%')
                .height(GEAR_HEADER_EXPANDED)
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
              ForEach(this.filteredGearGroups(), (group: string) => {
                ListItem() {
                  this.GroupHeader(group);
                }
                if (!this.isGearGroupCollapsed(group)) {
                  ForEach(this.filteredGearsByGroup(group), (item: GearItem) => {
                    ListItem() {
                      this.GearRow(item);
                    }
                    .swipeAction({
                    end: {
                      builder: this.DeleteAction(item),
                      actionAreaDistance: 80,
                      onAction: () => {
                        this.onConfirmDeleteGear(item);
                      }
                    }
                  })
                }, (item: GearItem) => item.id)
                }
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
          .edgeEffect(EdgeEffect.Spring)
          .backgroundColor(CARD_BG)
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
  }

  @Builder
  private CollapsingHeader() {
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
        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(20)
            .fontColor([this.gearSearchKeyword.length > 0 ? PRIMARY_COLOR : TEXT_SECONDARY])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(PRIMARY_TINT_COLOR)
        .borderRadius(18)
        .onClick(() => {
          this.searchExpanded = true;
        })
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
    .backgroundColor(this.gearHeaderBgColor())
    .backgroundBlurStyle(this.gearHeaderBlurStyle())
    .position({ x: 0, y: 0 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private MultiSelectBar() {
    Row() {
      Text('选中 ' + this.selectedMultiGearIds.length.toString() + ' 件')
        .fontSize(13)
        .fontColor(TEXT_MAIN)
        .fontFeature(FONT_FEATURE_TNUM)
        .layoutWeight(1)
      Button('生成清单')
        .height(34)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .backgroundColor(this.selectedMultiGearIds.length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .enabled(this.selectedMultiGearIds.length > 0)
        .onClick(() => {
          this.onOpenGenerateTripSheet();
        })
      Button('取消')
        .height(34)
        .fontSize(13)
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
  private SearchBar() {
    Row({ space: 10 }) {
      TextInput({ placeholder: '搜索装备', text: this.gearSearchKeyword })
        .height(36)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
        .placeholderColor(TEXT_TERTIARY)
        .backgroundColor(CARD_BG)
        .borderRadius(18)
        .padding({ left: 14, right: 14 })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.onSearchChange(value);
        })
      Text('取消')
        .fontSize(14)
        .fontColor(TEXT_SECONDARY)
        .height(36)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.searchExpanded = false;
          this.onSearchChange('');
        })
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 8 })
    .backgroundColor(PAGE_BG)
  }

  @Builder
  private GroupHeader(group: string) {
    Row({ space: 10 }) {
      Row()
        .width(4)
        .height(22)
        .backgroundColor(this.gearSortMode === GEAR_SORT_GROUP ? getGroupColor(group) : PRIMARY_COLOR)
        .borderRadius(2)
      Text(group + ' (' + this.gearGroupCount(group).toString() + ')')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .fontFeature(FONT_FEATURE_TNUM)
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(14)
        .fontColor([TEXT_TERTIARY])
        .rotate({ angle: this.isGearGroupCollapsed(group) ? -90 : 0 })
        .animation({ duration: 300, curve: curves.springMotion(0.22, 0.82) })
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12 })
    .margin({ top: this.isFirstGearGroup(group) ? 4 : 20, bottom: 2 })
    .backgroundColor(GROUP_HEADER_BG)
    .borderRadius(10)
    .onClick(() => {
      this.toggleGearGroupCollapse(group);
    })
  }

  @Builder
  private GearRow(item: GearItem) {
    Column() {
      Row({ space: 12 }) {
        Row()
          .width(4)
          .height(42)
          .borderRadius(2)
          .backgroundColor(getGroupColor(item.category))
        if (this.multiSelectMode) {
          Checkbox()
            .select(this.hasMultiGearSelection(item.id))
            .onChange((checked: boolean) => {
              this.onToggleMultiGearSelection(item.id);
            })
        }
        Column({ space: 4 }) {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
          Text(item.category)
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 3 }) {
          if (item.weight !== undefined && item.weight > 0) {
            Text(item.weight.toString() + 'g')
              .fontSize(13)
              .fontColor(TEXT_SECONDARY)
              .fontFeature(FONT_FEATURE_TNUM)
          }
          if (item.price !== undefined && item.price > 0) {
            Text('¥' + item.price.toString())
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
              .fontFeature(FONT_FEATURE_TNUM)
          }
          if (this.gearTripCount(item) > 0) {
            Text('×' + this.gearTripCount(item).toString())
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
              .fontFeature(FONT_FEATURE_TNUM)
          }
        }
        .alignItems(HorizontalAlign.End)
        if (!this.multiSelectMode) {
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([TEXT_TERTIARY])
            .rotate({ angle: this.expandedGearId === item.id ? 180 : 0 })
            .animation({ duration: 300, curve: curves.springMotion(0.22, 0.82) })
        }
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.multiSelectMode) {
          this.onToggleMultiGearSelection(item.id);
        } else {
          const isExpanding = this.expandedGearId !== item.id;
          this.onToggleGearExpanded(item.id);
          if (isExpanding) {
            this.scrollToExpandedGear(item.id);
          }
        }
      })
      if (!this.multiSelectMode && this.expandedGearId === item.id) {
        this.Detail(item);
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(CARD_BG)
    .borderRadius(12)
    .border({ width: { bottom: CARD_BORDER_BOTTOM_WIDTH }, color: { bottom: CARD_BORDER_BOTTOM_COLOR } })
    .shadow({ radius: 8, color: '#08000000', offsetX: 0, offsetY: 1 })
    .scale({ x: this.pressedGearId === item.id ? 0.97 : 1, y: this.pressedGearId === item.id ? 0.97 : 1 })
    .opacity(this.pressedGearId === item.id ? 0.85 : 1)
    .animation({ duration: 260, curve: curves.springMotion(0.22, 0.82) })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedGearId = item.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedGearId = '';
      }
    })
    .gesture(
      LongPressGesture({ duration: 500 })
        .onAction(() => {
          this.onEnterGearMultiSelect(item.id);
        })
    )
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
      Row() {
        Button('编辑')
          .height(36)
          .fontSize(13)
          .fontColor(PRIMARY_COLOR)
          .backgroundColor(LIGHT_PRIMARY_COLOR)
          .borderRadius(18)
          .onClick(() => {
            this.onOpenEditGear(item);
          })
        Blank()
        Button('删除')
          .height(36)
          .fontSize(13)
          .fontColor(DANGER_COLOR)
          .backgroundColor('#FFF1F0')
          .borderRadius(18)
          .onClick(() => {
            this.onConfirmDeleteGear(item);
          })
      }
      .width('100%')
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
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 12, color: '#1A2D7D46', offsetX: 0, offsetY: 4 })
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
    .height(240)
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
}
