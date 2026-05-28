import { LengthMetrics } from '@kit.ArkUI';
import {
  CARD_BG,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';

@Component
export struct TempItemSheet {
  @Prop tempItemName: string = '';
  @Prop tempItemGroup: string = '其他';
  @Prop showTempAddNotice: boolean = false;
  @Prop categories: string[] = [];
  onNameChange: (value: string) => void = (value: string): void => {};
  onGroupChange: (value: string) => void = (value: string): void => {};
  onConfirm: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '输入物品名称', text: this.tempItemName })
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
      if (this.showTempAddNotice) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(12)
            .fontColor([PRIMARY_COLOR])
          Text('已添加')
            .fontSize(12)
            .fontColor(PRIMARY_COLOR)
        }
        .width('100%')
      }
      Button('确认添加')
        .height(48)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(this.tempItemName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.tempItemName.trim().length > 0)
        .onClick(() => {
          this.onConfirm();
        })
    }
  }

  @Builder
  private CategoryTags() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      ForEach(this.categories, (category: string) => {
        Text(category)
          .fontSize(13)
          .fontColor(this.tempItemGroup === category ? '#FFFFFF' : '#666666')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.tempItemGroup === category ? PRIMARY_COLOR : CARD_BG)
          .border({ width: 1, color: this.tempItemGroup === category ? PRIMARY_COLOR : '#E0E0E0' })
          .borderRadius(12)
          .onClick(() => {
            this.onGroupChange(category);
          })
      }, (category: string) => category)
    }
    .width('100%')
  }
}
