import {
  FONT_FEATURE_TNUM,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  WHITE,
  DISABLED_COLOR
} from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

@Component
export struct GenerateTripSheet {
  @Prop selectedCount: number = 0;
  @Prop generateTripTitle: string = '';
  onTitleChange: (value: string) => void = (value: string): void => {};
  onConfirm: () => void = (): void => {};

  @State private buttonPressed: boolean = false;

  build() {
    Column({ space: 12 }) {
      Text('已选择 ' + this.selectedCount.toString() + ' 件装备')
        .fontSize(12)
        .fontColor(TEXT_SECONDARY)
        .fontFeature(FONT_FEATURE_TNUM)
        .width('100%')
      TextInput({ placeholder: '行程名称', text: this.generateTripTitle })
        .type(InputType.Normal)
        .height(48)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
        .placeholderColor(TEXT_SECONDARY)
        .backgroundColor(PAGE_BG)
        .borderRadius(12)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.onTitleChange(value);
        })
      Button('确认生成')
        .height(48)
        .fontSize(14)
        .fontColor(WHITE)
        .backgroundColor(this.generateTripTitle.trim().length === 0 || this.selectedCount === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.generateTripTitle.trim().length > 0 && this.selectedCount > 0)
        .scale({ x: this.buttonPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
          y: this.buttonPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.buttonPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.buttonPressed = false;
          }
        })
        .onClick(() => {
          this.onConfirm();
        })
    }
    .width('100%')
  }
}
