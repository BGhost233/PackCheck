import { curves, LengthMetrics } from '@kit.ArkUI';
import {
  CARD_BG,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../constants/DesignTokens';
import {
  DURATION_NORMAL,
  DURATION_SLOW,
  SPRING_GENERAL,
  SPRING_PANEL_EXIT,
  STAGGER_OFFSET_Y
} from '../constants/AnimationTokens';
import { GearItem } from '../models/PackModels';
import { GearCalc } from '../services/GearService';

@Component
export struct GearFilterPanel {
  @Prop categories: string[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedCategories: string[] = ['全部'];

  onApply: (categories: string[]) => void = () => {};
  onDismiss: () => void = () => {};

  // 内部状态：临时选择 + 动画
  @State private tempCategories: string[] = ['全部'];
  @State private panelTranslateY: number = -600;
  @State private overlayOpacity: number = 0;

  aboutToAppear(): void {
    // 初始化临时筛选为外部传入值
    this.tempCategories = this.normalizeCategories(this.selectedCategories);
    // 入场动画
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: DURATION_SLOW,
        curve: SPRING_GENERAL()
      }, () => {
        this.panelTranslateY = 0;
        this.overlayOpacity = 1;
      });
    }, 0);
  }

  private normalizeCategories(input: string[]): string[] {
    return GearCalc.normalizeGearCategories(input);
  }

  private allFilterCategories(): string[] {
    return GearCalc.allGearFilterCategories(this.categories);
  }

  private categoryCount(category: string): number {
    return GearCalc.gearCategoryCount(this.gears, category);
  }

  private isCategorySelected(category: string): boolean {
    return this.normalizeCategories(this.tempCategories).indexOf(category) >= 0;
  }

  private filterText(): string {
    return GearCalc.tempGearFilterText(this.tempCategories);
  }

  private toggleCategory(category: string): void {
    if (category === '全部') {
      this.tempCategories = ['全部'];
      return;
    }
    const nextCategories: string[] = [];
    const normalized = this.normalizeCategories(this.tempCategories);
    for (let index = 0; index < normalized.length; index++) {
      if (normalized[index] !== '全部' && normalized[index] !== category) {
        nextCategories.push(normalized[index]);
      }
    }
    if (normalized.indexOf(category) < 0) {
      nextCategories.push(category);
    }
    this.tempCategories = nextCategories.length === 0 ? ['全部'] : nextCategories;
  }

  private clearSelection(): void {
    this.tempCategories = ['全部'];
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#4D000000')
        .backdropBlur(20)
        .opacity(this.overlayOpacity)
        .onClick(() => {
          this.applyAndClose();
        })

      Column({ space: 10 }) {
        Row() {
          Text('分组筛选')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
          Blank()
          Text('清除')
            .fontSize(14)
            .fontColor(TEXT_TERTIARY)
            .height(32)
            .padding({ left: 10, right: 10 })
            .onClick(() => {
              this.clearSelection();
            })
          Button('确认')
            .height(32)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(16)
            .margin({ left: 8 })
            .onClick(() => {
              this.applyAndClose();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 4 })
        .alignItems(VerticalAlign.Center)

        Text('已选：' + this.filterText())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Scroll() {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.allFilterCategories(), (category: string) => {
              this.CategoryCard(category, this.isCategorySelected(category))
            }, (category: string) => category + '_' + this.isCategorySelected(category).toString())
          }
          .width('100%')
          .padding({ left: 16, right: 6, bottom: 18, top: 10 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
      }
      .width('100%')
      .height('52%')
      .backgroundColor('#EBFFFFFF')
      .backdropBlur(20)
      .borderRadius({ bottomLeft: 20, bottomRight: 20 })
      .shadow({ radius: 20, color: '#1A000000', offsetX: 0, offsetY: 4 })
      .translate({ y: this.panelTranslateY })
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private CategoryCard(category: string, isActive: boolean) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Text(category)
        .fontSize(14)
        .fontWeight(isActive ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(isActive ? '#FFFFFF' : TEXT_MAIN)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .height(42)
        .padding({ left: 8, right: 8 })
        .backgroundColor(isActive ? PRIMARY_COLOR : '#F5F7F5')
        .borderRadius(12)
        .animation({ duration: 150, curve: Curve.EaseInOut })

      if (this.categoryCount(category) > 0) {
        Text(this.categoryCount(category).toString())
          .fontSize(10)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width(this.categoryCount(category) > 9 ? 24 : 18)
          .height(18)
          .padding({ left: 4, right: 4 })
          .backgroundColor(isActive ? '#FF6B6B' : PRIMARY_COLOR)
          .borderRadius(9)
          .margin({ top: -6, right: -6 })
      }
    }
    .width('30.5%')
    .height(42)
    .clip(false)
    .margin({ right: 10, bottom: 10 })
    .transition({ type: TransitionType.Insert, translate: { y: STAGGER_OFFSET_Y }, opacity: 0 })
    .onClick(() => {
      this.toggleCategory(category);
    })
  }
}
