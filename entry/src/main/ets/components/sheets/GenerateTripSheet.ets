import {
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';

@Component
export struct GenerateTripSheet {
  @Prop selectedCount: number = 0;
  @Prop generateTripTitle: string = '';
  onTitleChange: (value: string) => void = (value: string): void => {};
  onConfirm: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      Text('已选择 ' + this.selectedCount.toString() + ' 件装备')
        .fontSize(12)
        .fontColor(TEXT_SECONDARY)
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
        .fontColor('#FFFFFF')
        .backgroundColor(this.generateTripTitle.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.generateTripTitle.trim().length > 0)
        .onClick(() => {
          this.onConfirm();
        })
    }
    .width('100%')
  }
}
