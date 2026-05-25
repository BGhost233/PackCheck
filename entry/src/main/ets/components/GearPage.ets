import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { DEFAULT_CATEGORIES, GearItem } from '../models/PackModels';
import { PackStore } from '../services/PackStore';
import { WeightGauge } from './WeightGauge';
import {
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
  @Prop categories: string[] = [];
  @Prop selectedGearCategory: string = '全部';
  @Prop gearSearchKeyword: string = '';
  @Prop gearSortMode: string = GEAR_SORT_GROUP;
  @Prop expandedGearId: string = '';
  @Link targetWeightGram: number;
  @Prop multiSelectMode: boolean = false;
  @Prop selectedMultiGearIds: string[] = [];
  @Prop showAllGearTags: boolean = false;

  @State private gearHeaderCollapsed: boolean = false;
  @State private gearHeaderAnimating: boolean = false;
  @State private showWeightEditor: boolean = false;
  @State private targetWeightInput: string = '';
  @State private targetWeightError: string = '';

  private store: PackStore = new PackStore();
  private gearListScroller: Scroller = new Scroller();
  private readonly gearCollapseThreshold: number = 60;
  private readonly gearExpandThreshold: number = 30;

  onSelectCategory: (category: string) => void = (category: string): void => {};
  onSearchChange: (keyword: string) => void = (keyword: string): void => {};
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
  onToggleAllGearTags: () => void = (): void => {};

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

  private filteredGears(): GearItem[] {
    const filtered: GearItem[] = [];
    const keyword = this.gearSearchKeyword.trim().toLowerCase();
    for (let index = 0; index < this.gears.length; index++) {
      const item = this.gears[index];
      const note = item.note === undefined ? '' : item.note;
      const categoryMatched = this.selectedGearCategory === '全部' || item.category === this.selectedGearCategory;
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

  private groupsWithGear(): string[] {
    const groups: string[] = [];
    for (let index = 0; index < this.gears.length; index++) {
      const group = this.gears[index].category;
      if (groups.indexOf(group) < 0) {
        groups.push(group);
      }
    }
    return groups;
  }

  private visibleTagTabs(): string[] {
    const tabs: string[] = ['全部'];
    const groups = this.groupsWithGear();
    for (let index = 0; index < groups.length; index++) {
      tabs.push(groups[index]);
    }
    return tabs;
  }

  private collapsedTagTabs(): string[] {
    const sourceTabs = this.visibleTagTabs();
    const tabs: string[] = [];
    const maxCount = 3;
    for (let index = 0; index < sourceTabs.length && tabs.length < maxCount; index++) {
      tabs.push(sourceTabs[index]);
    }
    if (this.selectedGearCategory !== '全部' && tabs.indexOf(this.selectedGearCategory) < 0 && tabs.length > 0) {
      tabs[tabs.length - 1] = this.selectedGearCategory;
    }
    return tabs;
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
      ' / 目标' + this.formatKg(this.targetWeightGram);
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

  private updateGearHeaderCollapsed(offset: number): void {
    let nextCollapsed = this.gearHeaderCollapsed;
    if (!this.gearHeaderCollapsed && offset > this.gearCollapseThreshold) {
      nextCollapsed = true;
    } else if (this.gearHeaderCollapsed && offset < this.gearExpandThreshold) {
      nextCollapsed = false;
    }
    if (nextCollapsed === this.gearHeaderCollapsed || this.gearHeaderAnimating) {
      return;
    }
    this.gearHeaderAnimating = true;
    this.getUIContext().animateTo({
      duration: 250,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.gearHeaderAnimating = false;
      }
    }, () => {
      this.gearHeaderCollapsed = nextCollapsed;
    });
  }

  private resetGearHeaderCollapsed(): void {
    if (!this.gearHeaderCollapsed && !this.gearHeaderAnimating) {
      return;
    }
    this.gearHeaderAnimating = true;
    this.getUIContext().animateTo({
      duration: 250,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.gearHeaderAnimating = false;
      }
    }, () => {
      this.gearHeaderCollapsed = false;
    });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.Header();
        if (this.multiSelectMode) {
          this.MultiSelectBar();
        }
        this.FilterBar();
        this.SearchBox();
        List({ space: 8, scroller: this.gearListScroller }) {
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
            }, (group: string) => group)
          }
        }
        .edgeEffect(EdgeEffect.Spring)
        .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
          this.updateGearHeaderCollapsed(this.gearListScroller.currentOffset().yOffset);
        })
        .onReachStart(() => {
          this.resetGearHeaderCollapsed();
        })
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 6, bottom: 112 })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

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
  }

  @Builder
  private Header() {
    Column({ space: this.gearHeaderCollapsed ? 0 : 12 }) {
      Row() {
        Text('我的装备库')
          .fontSize(this.gearHeaderCollapsed ? 20 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .layoutWeight(1)
        if (this.gearHeaderCollapsed) {
          Text(this.gearSummaryText())
            .fontSize(13)
            .fontColor(TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.resetGearHeaderCollapsed();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column() {
        WeightGauge({
          currentWeight: this.totalGearWeight(),
          targetWeight: this.targetWeightGram,
          gearCount: this.gears.length,
          totalPrice: this.totalGearPrice(),
          onEditTargetWeight: () => {
            this.openWeightEditor();
          }
        })
      }
      .width('100%')
      .height(this.gearHeaderCollapsed ? 0 : 268)
      .clip(true)
      .opacity(this.gearHeaderCollapsed ? 0 : 1)
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 20, bottom: this.gearHeaderCollapsed ? 12 : 10 })
    .backgroundColor(PAGE_BG)
    .shadow(this.gearHeaderCollapsed ?
      { radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 } :
      { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
    .animation({ duration: 250, curve: Curve.EaseInOut })
  }

  @Builder
  private MultiSelectBar() {
    Row() {
      Text('选中 ' + this.selectedMultiGearIds.length.toString() + ' 件')
        .fontSize(13)
        .fontColor(TEXT_MAIN)
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
  private FilterBar() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Flex({ wrap: FlexWrap.NoWrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(0) } }) {
          ForEach(this.collapsedTagTabs(), (category: string) => {
            this.TagChip(category, this.selectedGearCategory === category);
          }, (category: string) => category)
        }
        .height(38)
        .layoutWeight(1)
        .clip(true)
        Text(this.showAllGearTags ? '收起 ∧' : '展开 ∨')
          .fontSize(13)
          .fontColor(PRIMARY_COLOR)
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .borderRadius(18)
          .border({ width: 1, color: LIGHT_PRIMARY_COLOR })
          .onClick(() => {
            this.onToggleAllGearTags();
          })
        Row({ space: 8 }) {
          this.SmallAction('排序', () => {
            this.onOpenSort();
          });
          if (!this.multiSelectMode) {
            this.SmallAction('多选', () => {
              this.onStartMultiSelect();
            });
          }
        }
      }
      .width('100%')

      if (this.showAllGearTags) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.presetCategories(), (category: string) => {
            this.TagChip(category, this.selectedGearCategory === category);
          }, (category: string) => category)
        }
        .width('100%')
        .padding({ right: 60, bottom: 12 })
        .transition({ type: TransitionType.Insert, opacity: 0 })
      }
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 4 })
  }

  @Builder
  private TagChip(label: string, isActive: boolean) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(isActive ? '#FFFFFF' : TEXT_MAIN)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(isActive ? PRIMARY_COLOR : PRIMARY_TINT_COLOR)
      .borderRadius(18)
      .onClick(() => {
        this.onSelectCategory(label);
      })
  }

  @Builder
  private SmallAction(title: string, action: () => void) {
    Text(title)
      .fontSize(13)
      .fontColor(PRIMARY_COLOR)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(PRIMARY_TINT_COLOR)
      .borderRadius(18)
      .onClick(action)
  }

  @Builder
  private SearchBox() {
    TextInput({ placeholder: '搜索装备', text: this.gearSearchKeyword })
      .height(40)
      .fontSize(14)
      .fontColor(TEXT_MAIN)
      .placeholderColor(TEXT_TERTIARY)
      .backgroundColor(GROUP_HEADER_BG)
      .borderRadius(20)
      .padding({ left: 14, right: 14 })
      .margin({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 6 })
      .onChange((value: string) => {
        this.onSearchChange(value);
      })
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
        .layoutWeight(1)
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12 })
    .margin({ top: 8, bottom: 2 })
    .backgroundColor(GROUP_HEADER_BG)
    .borderRadius(10)
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
          }
          if (item.price !== undefined && item.price > 0) {
            Text('¥' + item.price.toString())
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
          if (this.gearTripCount(item) > 0) {
            Text('×' + this.gearTripCount(item).toString())
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
        }
        .alignItems(HorizontalAlign.End)
        if (!this.multiSelectMode) {
          Text(this.expandedGearId === item.id ? '∧' : '∨')
            .fontSize(16)
            .fontColor(TEXT_TERTIARY)
        }
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.multiSelectMode) {
          this.onToggleMultiGearSelection(item.id);
        } else {
          this.onToggleGearExpanded(item.id);
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
    .shadow({ radius: 8, color: '#08000000', offsetX: 0, offsetY: 1 })
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
    Row() {
      Text('+')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .width(56)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(PRIMARY_COLOR)
    .borderRadius(28)
    .shadow({ radius: 16, color: '#4D2D7D46', offsetX: 0, offsetY: 4 })
    .position({ right: 16, bottom: 80 })
    .onClick(() => {
      this.onOpenAddGear();
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
          Text('✕')
            .fontSize(20)
            .fontColor(TEXT_SECONDARY)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
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
