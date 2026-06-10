import {
  INPUT_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  PLACEHOLDER_COLOR
} from '../../constants/DesignTokens';
import { WHITE } from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

@Component
export struct ProfileEditSheet {
  @Prop tripDate: string = '';
  @Prop tripDestination: string = '';
  @Prop tripDistanceKm: string = '';
  @Prop tripMaxAltitude: string = '';
  @Prop tripAscentM: string = '';
  @Prop tripDurationHours: string = '';

  onDateChange: (value: string) => void = (value: string): void => {};
  onDestinationChange: (value: string) => void = (value: string): void => {};
  onDistanceKmChange: (value: string) => void = (value: string): void => {};
  onMaxAltitudeChange: (value: string) => void = (value: string): void => {};
  onAscentMChange: (value: string) => void = (value: string): void => {};
  onDurationHoursChange: (value: string) => void = (value: string): void => {};
  onConfirm: () => void = (): void => {};

  @State private buttonPressed: boolean = false;
  @State private dateRowPressed: boolean = false;

  build() {
    Column({ space: 12 }) {
      // 出行时间（点击弹出日期选择器）
      Row() {
        Text(this.tripDate.length > 0 ? this.tripDate : '出发日期')
          .fontSize(14)
          .fontColor(this.tripDate.length > 0 ? TEXT_MAIN : PLACEHOLDER_COLOR)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(18)
          .fontColor([TEXT_SECONDARY])
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .backgroundColor(INPUT_BG)
      .borderRadius(10)
      .scale({ x: this.dateRowPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
        y: this.dateRowPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.dateRowPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.dateRowPressed = false;
        }
      })
      .onClick(() => {
        DatePickerDialog.show({
          start: new Date('2020-1-1'),
          end: new Date(`${new Date().getFullYear() + 10}-12-31`),
          selected: new Date(),
          lunar: false,
          onDateAccept: (value: Date) => {
            const year = value.getFullYear();
            const month = value.getMonth() + 1;
            const day = value.getDate();
            const dateStr = year.toString() + '年' + month.toString() + '月' + day.toString() + '日';
            this.onDateChange(dateStr);
          }
        });
      })

      // 目的地（全宽）
      TextInput({ placeholder: '目的地', text: this.tripDestination })
        .height(44)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
        .placeholderColor(TEXT_SECONDARY)
        .backgroundColor(INPUT_BG)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => { this.onDestinationChange(value); })

      // 里程 + 海拔（2 列）
      Row({ space: 8 }) {
        this.FieldInput('里程 km', this.tripDistanceKm, (v: string) => { this.onDistanceKmChange(v); })
        this.FieldInput('最高海拔 m', this.tripMaxAltitude, (v: string) => { this.onMaxAltitudeChange(v); })
      }
      .width('100%')

      // 爬升 + 时长（2 列）
      Row({ space: 8 }) {
        this.FieldInput('累计爬升 m', this.tripAscentM, (v: string) => { this.onAscentMChange(v); })
        this.FieldInput('时长 h', this.tripDurationHours, (v: string) => { this.onDurationHoursChange(v); })
      }
      .width('100%')

      // 保存按钮
      Button('保存')
        .height(44)
        .fontSize(14)
        .fontColor(WHITE)
        .backgroundColor(PRIMARY_COLOR)
        .width('100%')
        .borderRadius(12)
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
  }

  @Builder
  private FieldInput(placeholder: string, text: string, onChange: (value: string) => void) {
    TextInput({ placeholder: placeholder, text: text })
      .height(44)
      .fontSize(14)
      .fontColor(TEXT_MAIN)
      .placeholderColor(TEXT_SECONDARY)
      .backgroundColor(INPUT_BG)
      .borderRadius(10)
      .padding({ left: 12, right: 12 })
      .type(InputType.Number)
      .layoutWeight(1)
      .onChange((value: string) => { onChange(value); })
  }
}
