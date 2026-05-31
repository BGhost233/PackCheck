import { ChecklistItem, GearItem, TripChecklist } from '../models/PackModels';
import {
  ARROW_COLOR,
  CARD_BG,
  DANGER_COLOR,
  DISABLED_COLOR,
  DIVIDER_COLOR,
  FONT_FEATURE_TNUM,
  GROUP_HEADER_BG,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PAGE_PADDING,
  PLACEHOLDER_COLOR,
  PRIMARY_COLOR,
  PRIMARY_TINT_COLOR,
  PROGRESS_END_COLOR,
  SHADOW_SUBTLE,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  TRANSPARENT,
  WHITE
} from '../constants/DesignTokens';
import {
  SPRING_PRESS,
  SPRING_GENERAL,
  SPRING_CHEVRON,
  DURATION_NORMAL,
  DURATION_SLOW,
  DURATION_HEADER,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  STAGGER_OFFSET_Y,
  staggerDelay,
  CURVE_STANDARD
} from '../constants/AnimationTokens';
import { getGroupColor } from '../utils/ColorUtils';

@Component
export struct ChecklistDetail {
  @Prop checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedChecklistId: string = '';
  @Prop collapsedGroups: string[] = [];
  @Prop highlightedItemId: string = '';
  @Prop progressPulse: boolean = false;
  @Prop checklistRenderNonce: number = 0;

  @State private headerCollapsed: boolean = false;
  @State private headerAnimating: boolean = false;
  @State private pressedItemId: string = '';

  private listScroller: Scroller = new Scroller();
  private readonly collapseThreshold: number = 80;
  private readonly expandThreshold: number = 30;

  onReturnHome: () => void = (): void => {};
  onOpenEditTrip: () => void = (): void => {};
  onOpenDatePicker: () => void = (): void => {};
  onOpenTempItem: () => void = (): void => {};
  onOpenImport: () => void = (): void => {};
  onOpenReview: () => void = (): void => {};
  onToggleGroup: (group: string) => void = (group: string): void => {};
  onOpenEditItem: (item: ChecklistItem) => void = (item: ChecklistItem): void => {};
  onToggleChecklistItem: (itemId: string) => void = (itemId: string): void => {};
  onSaveChecklistItemToGear: (item: ChecklistItem) => void = (item: ChecklistItem): void => {};
  onDeleteChecklistItem: (itemId: string) => void = (itemId: string): void => {};

  private currentChecklist(): TripChecklist | undefined {
    for (let index = 0; index < this.checklists.length; index++) {
      if (this.checklists[index].id === this.selectedChecklistId) {
        return this.checklists[index];
      }
    }
    return undefined;
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
    return this.checkedCount(checklist);
  }

  private progressTotal(checklist: TripChecklist): number {
    return checklist.items.length === 0 ? 1 : checklist.items.length;
  }

  private progressText(checklist: TripChecklist): string {
    return this.checkedCount(checklist).toString() + '/' + checklist.items.length.toString();
  }

  private isChecklistDone(checklist: TripChecklist): boolean {
    return checklist.items.length > 0 && this.checkedCount(checklist) === checklist.items.length;
  }

  private currentChecklistTitle(): string {
    const checklist = this.currentChecklist();
    return checklist === undefined ? '' : checklist.title;
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

  private startOfDay(date: Date): number {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  }

  private parseTripDateAt(text: string): number | undefined {
    const monthIndex = text.indexOf('月');
    const dayIndex = text.indexOf('日');
    if (monthIndex > 0 && dayIndex > monthIndex) {
      const month = Number(text.substring(0, monthIndex));
      const day = Number(text.substring(monthIndex + 1, dayIndex));
      if (!Number.isNaN(month) && !Number.isNaN(day)) {
        return new Date(new Date().getFullYear(), month - 1, day).getTime();
      }
    }
    return undefined;
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
    const dayDiff = Math.floor((dateAt - this.startOfDay(new Date())) / 86400000);
    if (dayDiff > 0) {
      return '还有 ' + dayDiff.toString() + ' 天出发';
    }
    if (dayDiff === 0) {
      return '今天出发！';
    }
    return '已出发 ' + Math.abs(dayDiff).toString() + ' 天';
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

  private checkedWeight(checklist: TripChecklist): number {
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

  private formatKg(weightGram: number): string {
    if (weightGram <= 0) {
      return '0kg';
    }
    return (Math.round(weightGram / 100) / 10).toString() + 'kg';
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

  private groupCheckedCount(group: string): number {
    const items = this.checklistItemsByGroup(group);
    let count = 0;
    for (let index = 0; index < items.length; index++) {
      if (items[index].checked) {
        count++;
      }
    }
    return count;
  }

  private isGroupDone(group: string): boolean {
    const total = this.groupItemCount(group);
    return total > 0 && this.groupCheckedCount(group) === total;
  }

  private isGroupCollapsed(group: string): boolean {
    return this.collapsedGroups.indexOf(group) >= 0;
  }

  private isFirstGroup(group: string): boolean {
    const groups = this.checklistGroups();
    return groups.length > 0 && groups[0] === group;
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
    return item !== undefined && item.checked;
  }

  private hasGearMarker(item: ChecklistItem): boolean {
    return item.fromGearId !== undefined && item.fromGearId.length > 0;
  }

  private checklistItemRenderKey(item: ChecklistItem): string {
    return item.id + '|' + item.name + '|' + item.group + '|' +
      (item.checked ? '1' : '0') + '|' + this.numberKey(item.weight) + '|' +
      this.numberKey(item.price) + '|' + this.checklistRenderNonce.toString();
  }

  private numberKey(value: number | undefined): string {
    return value === undefined ? '' : value.toString();
  }

  private updateHeaderCollapsed(offset: number): void {
    let nextCollapsed = this.headerCollapsed;
    if (!this.headerCollapsed && offset > this.collapseThreshold) {
      nextCollapsed = true;
    } else if (this.headerCollapsed && offset < this.expandThreshold) {
      nextCollapsed = false;
    }
    if (nextCollapsed === this.headerCollapsed || this.headerAnimating) {
      return;
    }
    this.headerAnimating = true;
    this.getUIContext().animateTo({
      duration: DURATION_HEADER,
      curve: CURVE_STANDARD,
      onFinish: () => {
        this.headerAnimating = false;
      }
    }, () => {
      this.headerCollapsed = nextCollapsed;
    });
  }

  private resetHeaderCollapsed(): void {
    if (!this.headerCollapsed && !this.headerAnimating) {
      return;
    }
    this.headerAnimating = true;
    this.getUIContext().animateTo({
      duration: DURATION_HEADER,
      curve: CURVE_STANDARD,
      onFinish: () => {
        this.headerAnimating = false;
      }
    }, () => {
      this.headerCollapsed = false;
    });
  }

  private handleAddItem(): void {
    this.onOpenTempItem();
  }

  private handleImportFromGear(): void {
    this.onOpenImport();
  }

  private handleSequentialCheck(): void {
    this.onOpenReview();
  }

  build() {
    Column() {
      if (this.currentChecklist() === undefined) {
        this.NavBar();
        this.EmptyText('没有找到这个行程。');
      } else {
        this.CollapsingHeader();
        List({ space: 8, scroller: this.listScroller }) {
          if (this.currentChecklist()!.items.length === 0) {
            ListItem() {
              this.EmptyText('行程物品还是空的，先添加或导入装备。');
            }
          } else {
            ForEach(this.checklistGroups(), (group: string) => {
              ListItem() {
                this.GroupHeader(group);
              }
              if (!this.isGroupCollapsed(group)) {
                ForEach(this.checklistItemsByGroup(group), (item: ChecklistItem) => {
                  ListItem() {
                    this.ItemRow(item);
                  }
                  .swipeAction({
                    start: {
                      builder: this.ItemSaveAction(item),
                      actionAreaDistance: 108,
                      onAction: () => {
                        this.onSaveChecklistItemToGear(item);
                      }
                    },
                    end: {
                      builder: this.ItemDeleteAction(item.id),
                      actionAreaDistance: 80,
                      onAction: () => {
                        this.onDeleteChecklistItem(item.id);
                      }
                    }
                  })
                }, (item: ChecklistItem) => this.checklistItemRenderKey(item))
              }
            }, (group: string) => group)
          }
        }
        .edgeEffect(EdgeEffect.Spring)
        .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
          this.updateHeaderCollapsed(this.listScroller.currentOffset().yOffset);
        })
        .onReachStart(() => {
          this.resetHeaderCollapsed();
        })
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 6, bottom: 34 })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .borderRadius(0)
    .geometryTransition('trip-' + this.selectedChecklistId)
    .transition(TransitionEffect.opacity(0.99))
  }

  @Builder
  private CollapsingHeader() {
    if (this.headerCollapsed) {
      this.CollapsedHeader();
    } else {
      Column() {
        this.NavBar();
        this.Header();
        this.ActionRow();
      }
      .width('100%')
      .backgroundColor(PAGE_BG)
      .animation({ duration: DURATION_HEADER, curve: CURVE_STANDARD })
    }
  }

  @Builder
  private CollapsedHeader() {
    if (this.currentChecklist() !== undefined) {
      Row({ space: 10 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([PRIMARY_COLOR])
        }
        .width(32)
        .height(40)
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.onReturnHome();
        })
        Text(this.currentChecklistTitle() + ' · ' + this.progressText(this.currentChecklist()!) +
          ' · ' + this.progressPercent(this.currentChecklist()!).toString() + '%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .fontFeature(FONT_FEATURE_TNUM)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Row({ space: 8 }) {
          this.MiniActionButton($r('sys.symbol.plus'), () => {
            this.handleAddItem();
          });
          this.MiniActionButton($r('sys.symbol.square_and_arrow_down'), () => {
            this.handleImportFromGear();
          });
          this.MiniActionButton($r('sys.symbol.list_checkmark'), () => {
            this.handleSequentialCheck();
          });
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(PAGE_BG)
      .shadow({ radius: 4, color: SHADOW_SUBTLE, offsetX: 0, offsetY: 2 })
      .animation({ duration: DURATION_HEADER, curve: CURVE_STANDARD })
    }
  }

  @Builder
  private MiniActionButton(icon: Resource, action: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(16)
        .fontColor([PRIMARY_COLOR])
    }
    .width(32)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(PRIMARY_TINT_COLOR)
    .borderRadius(16)
    .onClick(action)
  }

  @Builder
  private NavBar() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([PRIMARY_COLOR])
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onReturnHome();
      })
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 18, bottom: 4 })
  }

  @Builder
  private Header() {
    if (this.currentChecklist() !== undefined) {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Text(this.currentChecklistTitle())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(TEXT_MAIN)
              .width('100%')
              .onClick(() => {
                this.onOpenEditTrip();
              })
            Text(this.currentChecklistSubtitle())
              .fontSize(13)
              .fontColor(TEXT_TERTIARY)
              .width('100%')
              .onClick(() => {
                this.onOpenDatePicker();
              })
            this.MetaRow(this.currentChecklist());
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          this.RingProgress(this.currentChecklist());
        }
        this.ProgressLine(this.progressPercent(this.currentChecklist()!));
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 14 })
    }
  }

  @Builder
  private MetaRow(checklist: TripChecklist | undefined) {
    if (checklist !== undefined && (this.countdownText(checklist).length > 0 || this.checkedWeight(checklist) > 0)) {
      Row({ space: 10 }) {
        if (this.countdownText(checklist).length > 0) {
          Text(this.countdownText(checklist))
            .fontSize(12)
            .fontColor(this.countdownText(checklist) === '今天出发！' ? PRIMARY_COLOR : TEXT_SECONDARY)
            .fontFeature(FONT_FEATURE_TNUM)
        }
        if (this.checkedWeight(checklist) > 0) {
          Row({ space: 3 }) {
            SymbolGlyph($r('sys.symbol.weight_unit'))
              .fontSize(14)
              .fontColor([TEXT_SECONDARY])
            Text(this.formatKg(this.checkedWeight(checklist)))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(TEXT_SECONDARY)
              .fontFeature(FONT_FEATURE_TNUM)
          }
        }
      }
      .width('100%')
    }
  }

  @Builder
  private RingProgress(checklist: TripChecklist | undefined) {
    if (checklist !== undefined) {
      if (this.isChecklistDone(checklist)) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 44, height: 44 })
            .fill(PRIMARY_COLOR)
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(20)
            .fontColor([WHITE])
        }
        .width(44)
        .height(44)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 44, height: 44 })
            .fill(TRANSPARENT)
            .stroke(LIGHT_PRIMARY_COLOR)
            .strokeWidth(5)
          Progress({
            value: this.progressValue(checklist),
            total: this.progressTotal(checklist),
            type: ProgressType.Ring
          })
            .width(44)
            .height(44)
            .color(PRIMARY_COLOR)
            .style({ strokeWidth: 5, enableSmoothEffect: true })
          Text(this.progressText(checklist))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_COLOR)
            .fontFeature(FONT_FEATURE_TNUM)
        }
        .width(44)
        .height(44)
      }
    }
  }

  @Builder
  private ProgressLine(percent: number) {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .borderRadius(3)
          .backgroundColor(DIVIDER_COLOR)
        Row()
          .width(percent.toString() + '%')
          .height(6)
          .borderRadius(3)
          .linearGradient({
            angle: 90,
            colors: [[PROGRESS_END_COLOR, 0], [PRIMARY_COLOR, 1]]
          })
          .opacity(this.progressPulse && percent >= 100 ? 0.55 : 1)
      }
      .height(6)
      .layoutWeight(1)
      Text(percent.toString() + '%')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(PRIMARY_COLOR)
        .fontFeature(FONT_FEATURE_TNUM)
    }
    .width('100%')
  }

  @Builder
  private ActionRow() {
    Row({ space: 10 }) {
      this.ActionChip($r('sys.symbol.plus'), '添加物品', () => {
        this.handleAddItem();
      });
      this.ActionChip($r('sys.symbol.square_and_arrow_down'), '从装备库导入', () => {
        this.handleImportFromGear();
      });
      this.ActionChip($r('sys.symbol.list_checkmark'), '逐项核查', () => {
        this.handleSequentialCheck();
      });
    }
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 14 })
  }

  @Builder
  private ActionChip(icon: Resource, label: string, action: () => void) {
    Row({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(14)
        .fontColor([PRIMARY_COLOR])
      Text(label)
        .fontSize(13)
        .fontColor(PRIMARY_COLOR)
    }
    .height(38)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(PRIMARY_TINT_COLOR)
    .borderRadius(20)
    .onClick(action)
  }

  @Builder
  private GroupHeader(group: string) {
    Row() {
      Row()
        .width(4)
        .height(24)
        .borderRadius(2)
        .backgroundColor(getGroupColor(group))
      Text(group)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isGroupDone(group) ? TEXT_TERTIARY : TEXT_MAIN)
        .margin({ left: 10 })
      Text(this.groupCheckedCount(group).toString() + '/' + this.groupItemCount(group).toString())
        .fontSize(12)
        .fontColor(TEXT_TERTIARY)
        .fontFeature(FONT_FEATURE_TNUM)
        .margin({ left: 6 })
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(14)
        .fontColor([TEXT_TERTIARY])
        .rotate({ angle: this.isGroupCollapsed(group) ? -90 : 0 })
        .animation({ duration: DURATION_SLOW, curve: SPRING_CHEVRON() })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(GROUP_HEADER_BG)
    .borderRadius(10)
    .margin({ top: this.isFirstGroup(group) ? 4 : 20, bottom: 2 })
    .onClick(() => {
      this.onToggleGroup(group);
    })
    .animation({ duration: DURATION_NORMAL, curve: CURVE_STANDARD })
  }

  @Builder
  private ItemRow(item: ChecklistItem) {
    Row({ space: 12 }) {
      this.CheckMark(item.id);
      Text(item.name)
        .fontSize(16)
        .fontColor(item.checked ? PLACEHOLDER_COLOR : TEXT_MAIN)
        .decoration(item.checked ? { type: TextDecorationType.LineThrough, color: DISABLED_COLOR } : undefined)
        .layoutWeight(1)
        .onClick(() => {
          this.onOpenEditItem(item);
        })
      Row({ space: 6 }) {
        if (this.checklistItemWeight(item) !== undefined && this.checklistItemWeight(item)! > 0) {
          Text(this.checklistItemWeight(item)!.toString() + 'g')
            .fontSize(12)
            .fontColor(DISABLED_COLOR)
            .fontFeature(FONT_FEATURE_TNUM)
        }
        if (this.hasGearMarker(item)) {
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
        }
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.highlightedItemId === item.id ? LIGHT_PRIMARY_COLOR : CARD_BG)
    .borderRadius(12)
    .scale({ x: this.pressedItemId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST, y: this.pressedItemId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
    .opacity(this.pressedItemId === item.id ? 0.9 : 1)
    .animation({ duration: DURATION_NORMAL, curve: SPRING_PRESS() })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedItemId = item.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedItemId = '';
      }
    })
    .onClick(() => {
      this.onOpenEditItem(item);
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 450 })
        .onAction(() => {
          this.onOpenEditItem(item);
        })
    )
  }

  @Builder
  private CheckMark(itemId: string) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 28, height: 28 })
          .fill(this.isChecklistItemChecked(itemId) ? PRIMARY_COLOR : TRANSPARENT)
          .stroke(this.isChecklistItemChecked(itemId) ? PRIMARY_COLOR : ARROW_COLOR)
          .strokeWidth(2)
        if (this.isChecklistItemChecked(itemId)) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(15)
            .fontColor([WHITE])
            .fontWeight(FontWeight.Bold)
        }
      }
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onToggleChecklistItem(itemId);
    })
    .animation({ duration: DURATION_NORMAL, curve: SPRING_PRESS() })
  }

  @Builder
  private ItemSaveAction(item: ChecklistItem) {
    Row() {
      Text(this.hasGearMarker(item) ? '已在装备库中' : '存入装备库')
        .fontSize(14)
        .fontColor(this.hasGearMarker(item) ? TEXT_TERTIARY : PRIMARY_COLOR)
    }
    .height(52)
    .padding({ left: 18, right: 18 })
    .margin({ right: 10 })
    .backgroundColor(this.hasGearMarker(item) ? DIVIDER_COLOR : LIGHT_PRIMARY_COLOR)
    .borderRadius(12)
    .onClick(() => {
      this.onSaveChecklistItemToGear(item);
    })
  }

  @Builder
  private ItemDeleteAction(itemId: string) {
    Row() {
      Text('删除')
        .fontSize(14)
        .fontColor(WHITE)
    }
    .height(52)
    .padding({ left: 18, right: 18 })
    .margin({ left: 10 })
    .backgroundColor(DANGER_COLOR)
    .borderRadius(12)
    .onClick(() => {
      this.onDeleteChecklistItem(itemId);
    })
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
