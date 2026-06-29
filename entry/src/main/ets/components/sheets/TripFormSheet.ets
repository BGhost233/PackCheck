import {
  INPUT_BG,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../../constants/DesignTokens';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION,
  FONT_SIZE_SUBTITLE_LARGE
} from '../../constants/Typography';
import {
  WHITE,
  DISABLED_COLOR
} from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

/**
 * 行程表单 Sheet — 新建/编辑行程。
 *
 * §4.6 内化模式：外部通过 initialXxx 传入初始值，内部 @State 持有编辑态，
 * 提交时通过 onConfirm 回调将最终数据回传给父组件。
 */
@Component
export struct TripFormSheet {
  @Prop isEditMode: boolean = false;

  // 初始值 props（外部传入，仅用于 aboutToAppear 初始化）
  initialTitle: string = '';
  initialDate: string = '';
  // 行程画像字段（编辑模式可用）
  initialDestination: string = '';
  initialDistanceKm: string = '';
  initialMaxAltitude: string = '';
  initialAscentM: string = '';
  initialDurationHours: string = '';

  // 表单字段 — 内部状态
  @State private tripTitle: string = '';
  @State private tripDate: string = '';
  @State private tripDestination: string = '';
  @State private tripDistanceKm: string = '';
  @State private tripMaxAltitude: string = '';
  @State private tripAscentM: string = '';
  @State private tripDurationHours: string = '';

  // 回调：提交表单数据
  onConfirm: (title: string, date: string, destination: string,
    distanceKm: string, maxAltitude: string, ascentM: string, durationHours: string) => void = () => {};

  @State private buttonPressed: boolean = false;
  @State private dateRowPressed: boolean = false;

  aboutToAppear(): void {
    this.tripTitle = this.initialTitle;
    this.tripDate = this.initialDate;
    this.tripDestination = this.initialDestination;
    this.tripDistanceKm = this.initialDistanceKm;
    this.tripMaxAltitude = this.initialMaxAltitude;
    this.tripAscentM = this.initialAscentM;
    this.tripDurationHours = this.initialDurationHours;
  }

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '行程名称', text: this.tripTitle })
        .type(InputType.Normal)
        .maxLength(50)
        .height(48)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_MAIN)
        .placeholderColor(TEXT_SECONDARY)
        .backgroundColor(PAGE_BG)
        .borderRadius(12)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.tripTitle = value;
        })
      this.DatePickerField('出发日期（可选）', this.tripDate)

      // 行程画像字段（编辑模式展示）
      if (this.isEditMode) {
        Column({ space: 8 }) {
          Text('行程信息')
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_TERTIARY)
            .margin({ top: 4 })
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
          Row({ space: 8 }) {
            TextInput({ placeholder: '里程 km', text: this.tripDistanceKm })
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
              .onChange((value: string) => { this.tripDistanceKm = value; })
            TextInput({ placeholder: '海拔 m', text: this.tripMaxAltitude })
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
              .onChange((value: string) => { this.tripMaxAltitude = value; })
          }
          .width('100%')
          Row({ space: 8 }) {
            TextInput({ placeholder: '爬升 m', text: this.tripAscentM })
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
              .onChange((value: string) => { this.tripAscentM = value; })
            TextInput({ placeholder: '时长 h', text: this.tripDurationHours })
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
              .onChange((value: string) => { this.tripDurationHours = value; })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Button(this.isEditMode ? '确认保存' : '创建')
        .height(48)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(WHITE)
        .backgroundColor(this.tripTitle.trim().length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.tripTitle.trim().length > 0)
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
          this.onConfirm(this.tripTitle, this.tripDate, this.tripDestination,
            this.tripDistanceKm, this.tripMaxAltitude, this.tripAscentM, this.tripDurationHours);
        })
    }
  }

  @Builder
  private DatePickerField(placeholder: string, dateText: string) {
    Row() {
      Text(dateText.length > 0 ? dateText : placeholder)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(dateText.length > 0 ? TEXT_MAIN : TEXT_SECONDARY)
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(FONT_SIZE_SUBTITLE_LARGE)
        .fontColor([TEXT_TERTIARY])
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .backgroundColor(PAGE_BG)
    .borderRadius(12)
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
        end: new Date('2030-12-31'),
        selected: new Date(),
        lunar: false,
        onDateAccept: (value: Date) => {
          const year = value.getFullYear();
          const month = value.getMonth() + 1;
          const day = value.getDate();
          const yearPrefix = year !== new Date().getFullYear() ? year.toString() + '\u5e74' : '';
          this.tripDate = yearPrefix + month.toString() + '\u6708' + day.toString() + '\u65e5';
        }
      });
    })
  }
}
