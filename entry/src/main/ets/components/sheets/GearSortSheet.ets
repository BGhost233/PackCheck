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
  SPRING_PRESS,
  SPRING_GENERAL,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_BOUNCE,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

@Component
export struct GearSortSheet {
  @Prop gearSortMode: string = GEAR_SORT_GROUP;
  onSelectSort: (mode: string) => void = (mode: string): void => {};

  @State private pressedOption: string = '';
  // 超时守卫 timer：防止 onFinish 链中断导致 bounce 状态永久残留
  private bounceGuardTimerId: number = -1;

  aboutToDisappear(): void {
    if (this.bounceGuardTimerId >= 0) {
      clearTimeout(this.bounceGuardTimerId);
      this.bounceGuardTimerId = -1;
    }
  }

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
    .scale({ x: this.pressedOption === mode ? PRESS_SCALE_DOWN :
        (this.pressedOption === '__bounce_' + mode ? PRESS_SCALE_BOUNCE : PRESS_SCALE_REST),
      y: this.pressedOption === mode ? PRESS_SCALE_DOWN :
        (this.pressedOption === '__bounce_' + mode ? PRESS_SCALE_BOUNCE : PRESS_SCALE_REST) })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedOption = mode;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        // 三段式: 0.96 → 1.02 → 1.0（onFinish 链式，不用 setTimeout）
        //   加超时守卫：500ms 后强制清 bounce 状态，防止 onFinish 链中断导致永久残留
        if (this.bounceGuardTimerId >= 0) {
          clearTimeout(this.bounceGuardTimerId);
        }
        this.getUIContext().animateTo({
          curve: SPRING_PRESS(),
          onFinish: () => {
            this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
              this.pressedOption = '';
              this.bounceGuardTimerId = -1;
            });
          }
        }, () => {
          this.pressedOption = '__bounce_' + mode;
        });
        this.bounceGuardTimerId = setTimeout(() => {
          this.pressedOption = '';
          this.bounceGuardTimerId = -1;
        }, 500);
      }
    })
    .onClick(() => {
      this.onSelectSort(mode);
    })
  }
}
