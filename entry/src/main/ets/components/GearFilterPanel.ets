import { curves, LengthMetrics } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
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
  @State private pressedCategory: string = '';

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

  private filteredGearCount(): number {
    const normalized = this.normalizeCategories(this.tempCategories);
    if (normalized.indexOf('全部') >= 0) {
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

  private toggleCategory(category: string): void {
    // 触觉反馈
    try {
      vibrator.startVibration({ type: 'time', duration: 25 }, { usage: 'touch' });
    } catch (e) {
      // 静默失败
    }
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

      Column({ space: 8 }) {
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
        .padding({ left: 16, right: 16, top: 12, bottom: 2 })
        .alignItems(VerticalAlign.Center)

        Text('已选：' + this.filterText() + ' · 共' + this.filteredGearCount().toString() + '件')
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            ForEach(this.allFilterCategories(), (category: string) => {
              this.CategoryChip(category, this.isCategorySelected(category))
            }, (category: string) => category + '_' + this.isCategorySelected(category).toString())
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12, top: 4 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .constraintSize({ maxHeight: '60%' })
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
  private CategoryChip(category: string, isActive: boolean) {
    Row({ space: 4 }) {
      Text(category)
        .fontSize(13)
        .fontWeight(isActive ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(isActive ? '#FFFFFF' : TEXT_MAIN)
        .maxLines(1)
      if (this.categoryCount(category) > 0) {
        Text(this.categoryCount(category).toString())
          .fontSize(11)
          .fontColor(isActive ? '#CCFFFFFF' : TEXT_TERTIARY)
      }
    }
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor(isActive ?
      (this.pressedCategory === category ? '#1F5C32' : PRIMARY_COLOR) :
      (this.pressedCategory === category ? '#E8EBE8' : '#F5F7F5'))
    .borderRadius(16)
    .scale({
      x: this.pressedCategory === category ? 0.88 : 1,
      y: this.pressedCategory === category ? 0.88 : 1
    })
    .transition({ type: TransitionType.Insert, translate: { y: STAGGER_OFFSET_Y }, opacity: 0 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.getUIContext().animateTo({
          curve: curves.springMotion(0.18, 0.65)
        }, () => {
          this.pressedCategory = category;
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.getUIContext().animateTo({
          curve: curves.springMotion(0.22, 0.62)
        }, () => {
          this.pressedCategory = '';
        });
      }
    })
    .onClick(() => {
      this.toggleCategory(category);
    })
  }
}
