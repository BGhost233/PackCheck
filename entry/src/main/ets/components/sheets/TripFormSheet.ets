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

@Component
export struct TripFormSheet {
  @Prop tripTitle: string = '';
  @Prop tripDate: string = '';
  @Prop isEditMode: boolean = false;
  // 行程画像字段（编辑模式可用）
  @Prop tripDestination: string = '';
  @Prop tripDistanceKm: string = '';
  @Prop tripMaxAltitude: string = '';
  @Prop tripAscentM: string = '';
  @Prop tripDurationHours: string = '';

  onTitleChange: (value: string) => void = (value: string): void => {};
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
          this.onTitleChange(value);
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
            .onChange((value: string) => { this.onDestinationChange(value); })
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
              .onChange((value: string) => { this.onDistanceKmChange(value); })
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
              .onChange((value: string) => { this.onMaxAltitudeChange(value); })
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
              .onChange((value: string) => { this.onAscentMChange(value); })
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
              .onChange((value: string) => { this.onDurationHoursChange(value); })
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
          this.onConfirm();
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
          this.onDateChange(yearPrefix + month.toString() + '\u6708' + day.toString() + '\u65e5');
        }
      });
    })
  }
}
