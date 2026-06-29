import {
  INPUT_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  PLACEHOLDER_COLOR
} from '../../constants/DesignTokens';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_SUBTITLE_LARGE
} from '../../constants/Typography';
import { WHITE } from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

/**
 * 行程画像编辑 Sheet。
 *
 * §4.6 内化模式：外部通过 initialXxx 传入初始值，内部 @State 持有编辑态，
 * 提交时通过 onConfirm 回调将最终数据回传给父组件。
 */
@Component
export struct ProfileEditSheet {
  // 初始值 props（外部传入，仅用于 aboutToAppear 初始化）
  initialDate: string = '';
  initialDestination: string = '';
  initialDistanceKm: string = '';
  initialMaxAltitude: string = '';
  initialAscentM: string = '';
  initialDurationHours: string = '';

  // 表单字段 — 内部状态
  @State private tripDate: string = '';
  @State private tripDestination: string = '';
  @State private tripDistanceKm: string = '';
  @State private tripMaxAltitude: string = '';
  @State private tripAscentM: string = '';
  @State private tripDurationHours: string = '';

  // 回调：提交表单数据
  onConfirm: (date: string, destination: string,
    distanceKm: string, maxAltitude: string, ascentM: string, durationHours: string) => void = () => {};

  @State private buttonPressed: boolean = false;
  @State private dateRowPressed: boolean = false;

  aboutToAppear(): void {
    this.tripDate = this.initialDate;
    this.tripDestination = this.initialDestination;
    this.tripDistanceKm = this.initialDistanceKm;
    this.tripMaxAltitude = this.initialMaxAltitude;
    this.tripAscentM = this.initialAscentM;
    this.tripDurationHours = this.initialDurationHours;
  }

  build() {
    Column({ space: 12 }) {
      // 出行时间（点击弹出日期选择器）
      Row() {
        Text(this.tripDate.length > 0 ? this.tripDate : '出发日期')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(this.tripDate.length > 0 ? TEXT_MAIN : PLACEHOLDER_COLOR)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(FONT_SIZE_SUBTITLE_LARGE)
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
            this.tripDate = dateStr;
          }
        });
      })

      // 目的地（全宽）
      TextInput({ placeholder: '目的地', text: this.tripDestination })
        .height(44)
        .maxLength(100)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_MAIN)
        .placeholderColor(TEXT_SECONDARY)
        .backgroundColor(INPUT_BG)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => { this.tripDestination = value; })

      // 里程 + 海拔（2 列）
      Row({ space: 8 }) {
        this.FieldInput('里程 km', this.tripDistanceKm, (v: string) => { this.tripDistanceKm = v; })
        this.FieldInput('最高海拔 m', this.tripMaxAltitude, (v: string) => { this.tripMaxAltitude = v; })
      }
      .width('100%')

      // 爬升 + 时长（2 列）
      Row({ space: 8 }) {
        this.FieldInput('累计爬升 m', this.tripAscentM, (v: string) => { this.tripAscentM = v; })
        this.FieldInput('时长 h', this.tripDurationHours, (v: string) => { this.tripDurationHours = v; })
      }
      .width('100%')

      // 保存按钮
      Button('保存')
        .height(44)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
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
          this.onConfirm(this.tripDate, this.tripDestination,
            this.tripDistanceKm, this.tripMaxAltitude, this.tripAscentM, this.tripDurationHours);
        })
    }
  }

  @Builder
  private FieldInput(placeholder: string, text: string, onChange: (value: string) => void) {
    TextInput({ placeholder: placeholder, text: text })
      .height(44)
      .maxLength(20)
      .fontSize(FONT_SIZE_BODY_MEDIUM)
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
