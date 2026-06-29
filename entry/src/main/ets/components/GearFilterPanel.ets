import {
  GLASS_BG_HEAVY,
  OVERLAY_MASK_LIGHT,
  PRIMARY_COLOR,
  SHADOW_DEFAULT,
  TEXT_MAIN,
  TEXT_TERTIARY,
  WHITE
} from '../constants/DesignTokens';
import {
SPRING_GENERAL,
SPRING_PANEL_EXIT
} from '../constants/AnimationTokens';
import {
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION
} from '../constants/Typography';
import { CATEGORY_ALL, GearItem } from '../models/PackModels';
import { normalizeGearCategories, allGearFilterCategories, gearCategoryCount, tempGearFilterText } from '../services/GearService';
import { CategoryTagGroup } from './CategoryTagGroup';

@Component
export struct GearFilterPanel {
  @Prop categories: string[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedCategories: string[] = [CATEGORY_ALL];

  onApply: (categories: string[]) => void = () => {};
  onDismiss: () => void = () => {};
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAddCategory: (name: string) => void = () => {};

  // 内部状态：临时选择 + 动画
  @State private tempCategories: string[] = [CATEGORY_ALL];
  @State private panelTranslateY: number = -600;
  @State private overlayOpacity: number = 0;
  private entryTimerId: number = -1;

  aboutToAppear(): void {
    // 初始化临时筛选为外部传入值
    this.tempCategories = this.normalizeCategories(this.selectedCategories);
    // 入场动画
    this.entryTimerId = setTimeout(() => {
      this.entryTimerId = -1;
      this.getUIContext().animateTo({
        curve: SPRING_GENERAL()
      }, () => {
        this.panelTranslateY = 0;
        this.overlayOpacity = 1;
      });
    }, 0);
  }

  aboutToDisappear(): void {
    if (this.entryTimerId !== -1) {
      clearTimeout(this.entryTimerId);
      this.entryTimerId = -1;
    }
  }

  private normalizeCategories(input: string[]): string[] {
    return normalizeGearCategories(input);
  }

  private filterText(): string {
    return tempGearFilterText(this.tempCategories);
  }

  private filteredGearCount(): number {
    const normalized = this.normalizeCategories(this.tempCategories);
    if (normalized.indexOf(CATEGORY_ALL) >= 0) {
      return this.gears.length;
    }
    let count = 0;
    for (let i = 0; i < this.gears.length; i++) {
      if (normalized.indexOf(this.gears[i].category) >= 0) {
        count++;
      }
    }
    return count;
  }

  private clearSelection(): void {
    this.tempCategories = [CATEGORY_ALL];
  }

  private applyAndClose(): void {
    const result = this.normalizeCategories(this.tempCategories);
    this.getUIContext().animateTo({
      curve: SPRING_PANEL_EXIT(),
      onFinish: () => {
        this.onApply(result);
      }
    }, () => {
      this.panelTranslateY = -600;
      this.overlayOpacity = 0;
    });
  }

  private buildCountMap(): Record<string, number> {
    const map: Record<string, number> = {};
    const allCats = allGearFilterCategories(this.categories);
    for (let i = 0; i < allCats.length; i++) {
      map[allCats[i]] = gearCategoryCount(this.gears, allCats[i]);
    }
    return map;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OVERLAY_MASK_LIGHT)
        .backdropBlur(20)
        .opacity(this.overlayOpacity)
        .onClick(() => {
          this.applyAndClose();
        })

      Column({ space: 8 }) {
        Row() {
          Text('分组筛选')
            .fontSize(FONT_SIZE_BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
          Blank()
          Text('清除')
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(TEXT_TERTIARY)
            .height(32)
            .padding({ left: 10, right: 10 })
            .onClick(() => {
              this.clearSelection();
            })
          Button('确认')
            .height(32)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(WHITE)
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(16)
            .margin({ left: 8 })
            .onClick(() => {
              this.applyAndClose();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 2 })
        .alignItems(VerticalAlign.Center)

        Text('已选：' + this.filterText() + ' · 共' + this.filteredGearCount().toString() + '件')
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_TERTIARY)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Scroll() {
          Column() {
            CategoryTagGroup({
              categories: this.categories,
              selectedCategories: this.tempCategories,
              mode: 'multi',
              showAllOption: true,
              editable: true,
              showCount: true,
              countMap: this.buildCountMap(),
              onMultiSelect: (categories: string[]) => {
                this.tempCategories = categories;
              },
              onRename: (oldName: string, _newName: string) => {
                this.onRename(oldName, '');
              },
              onDelete: (category: string) => {
                this.onDelete(category);
              },
              onReorder: (categories: string[]) => {
                this.onReorder(categories);
              },
              onAdd: (_name: string) => {
                this.onAddCategory('');
              }
            })
          }
          .padding({ left: 16, right: 16, bottom: 12, top: 4 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .constraintSize({ maxHeight: '60%' })
      .backgroundColor(GLASS_BG_HEAVY)
      .backdropBlur(20)
      .borderRadius({ bottomLeft: 20, bottomRight: 20 })
      .shadow({ radius: 20, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 4 })
      .translate({ y: this.panelTranslateY })
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
  }
}
