import {
  GEAR_SORT_GROUP,
  GEAR_SORT_PRICE,
  GEAR_SORT_TIME,
  GEAR_SORT_TRIP_COUNT,
  GEAR_SORT_VALUE,
  GEAR_SORT_WEIGHT,
  LIGHT_PRIMARY_COLOR,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN
} from '../../constants/DesignTokens';
import {
  SPRING_GENERAL,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

@Component
export struct GearSortSheet {
  @Prop gearSortMode: string = GEAR_SORT_GROUP;
  onSelectSort: (mode: string) => void = (mode: string): void => {};

  build() {
    Column({ space: 10 }) {
      this.SortOption('按分组（默认）', GEAR_SORT_GROUP);
      this.SortOption('按价格（高→低）', GEAR_SORT_PRICE);
      this.SortOption('按重量（重→轻）', GEAR_SORT_WEIGHT);
      this.SortOption('按添加时间（新→旧）', GEAR_SORT_TIME);
      this.SortOption('按克单价（高→低）', GEAR_SORT_VALUE);
      this.SortOption('按出行次数（高→低）', GEAR_SORT_TRIP_COUNT);
    }
    .width('100%')
  }

  @Builder
  private SortOption(title: string, mode: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor(this.gearSortMode === mode ? PRIMARY_COLOR : TEXT_MAIN)
        .fontWeight(this.gearSortMode === mode ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)
      if (this.gearSortMode === mode) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(14)
          .fontColor([PRIMARY_COLOR])
      }
    }
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.gearSortMode === mode ? LIGHT_PRIMARY_COLOR : PAGE_BG)
    .borderRadius(12)
    .scale({ x: PRESS_SCALE_REST, y: PRESS_SCALE_REST })
    .animation({ curve: SPRING_GENERAL() })
    .onClick(() => {
      this.onSelectSort(mode);
    })
  }
}
