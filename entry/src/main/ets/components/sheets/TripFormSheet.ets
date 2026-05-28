import {
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../../constants/DesignTokens';

@Component
export struct TripFormSheet {
  @Prop tripTitle: string = '';
  @Prop tripDate: string = '';
  @Prop isEditMode: boolean = false;
  onTitleChange: (value: string) => void = (value: string): void => {};
  onDateChange: (value: string) => void = (value: string): void => {};
  onConfirm: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '行程名称', text: this.tripTitle })
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
      this.DatePickerField('出发日期（可选）', this.tripDate)
      Button(this.isEditMode ? '确认保存' : '创建')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY_COLOR)
        .width('100%')
        .onClick(() => {
          this.onConfirm();
        })
    }
  }

  @Builder
  private DatePickerField(placeholder: string, dateText: string) {
    Row() {
      Text(dateText.length > 0 ? dateText : placeholder)
        .fontSize(14)
        .fontColor(dateText.length > 0 ? TEXT_MAIN : TEXT_SECONDARY)
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(18)
        .fontColor([TEXT_TERTIARY])
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .backgroundColor(PAGE_BG)
    .borderRadius(12)
    .onClick(() => {
      DatePickerDialog.show({
        start: new Date('2020-1-1'),
        end: new Date('2030-12-31'),
        selected: new Date(),
        lunar: false,
        onDateAccept: (value: Date) => {
          const month = value.getMonth() + 1;
          const day = value.getDate();
          this.onDateChange(month.toString() + '\u6708' + day.toString() + '\u65e5');
        }
      });
    })
  }
}
