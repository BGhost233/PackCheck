import { LengthMetrics } from '@kit.ArkUI';
import {
  CARD_BG,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';

@Component
export struct GearFormSheet {
  @Prop gearName: string = '';
  @Prop gearCategory: string = '其他';
  @Prop gearWeight: string = '';
  @Prop gearPrice: string = '';
  @Prop gearNote: string = '';
  @Prop editingGearId: string = '';
  @Prop categories: string[] = [];
  onNameChange: (value: string) => void = (value: string): void => {};
  onCategoryChange: (value: string) => void = (value: string): void => {};
  onWeightChange: (value: string) => void = (value: string): void => {};
  onPriceChange: (value: string) => void = (value: string): void => {};
  onNoteChange: (value: string) => void = (value: string): void => {};
  onSave: () => void = (): void => {};

  build() {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ placeholder: '装备名称（必填）', text: this.gearName })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onNameChange(value);
          })
        Text('选择分组')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        this.CategoryTags()
        Row({ space: 12 }) {
          TextInput({ placeholder: '重量(g)', text: this.gearWeight })
            .type(InputType.Number)
            .height(48)
            .fontSize(14)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.onWeightChange(value);
            })
          TextInput({ placeholder: '价格(¥)', text: this.gearPrice })
            .type(InputType.Number)
            .height(48)
            .fontSize(14)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.onPriceChange(value);
            })
        }
        TextInput({ placeholder: '备注（一行，可选）', text: this.gearNote })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onNoteChange(value);
          })
        Button(this.editingGearId.length === 0 ? '确认添加' : '确认保存')
          .height(48)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.gearName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.gearName.trim().length > 0)
          .onClick(() => {
            this.onSave();
          })
      }
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }

  @Builder
  private CategoryTags() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      ForEach(this.categories, (category: string) => {
        Text(category)
          .fontSize(13)
          .fontColor(this.gearCategory === category ? '#FFFFFF' : '#666666')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.gearCategory === category ? PRIMARY_COLOR : CARD_BG)
          .border({ width: 1, color: this.gearCategory === category ? PRIMARY_COLOR : '#E0E0E0' })
          .borderRadius(12)
          .onClick(() => {
            this.onCategoryChange(category);
          })
      }, (category: string) => category)
    }
    .width('100%')
  }
}
