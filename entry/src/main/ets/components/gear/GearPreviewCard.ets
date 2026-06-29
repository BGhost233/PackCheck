import { GearItem } from '../../models/PackModels';
import { formatDateText } from '../../services/ChecklistService';
import { getGroupColor } from '../../utils/ColorUtils';
import {
  CARD_BG, SHADOW_DEFAULT, TEXT_MAIN, TEXT_TERTIARY
} from '../../constants/DesignTokens';
import {
  FONT_SIZE_BODY_SMALL, FONT_SIZE_PANEL_TITLE
} from '../../constants/Typography';

/**
 * 装备预览卡（长按菜单 overlay 中的详情卡）。
 * 纯 @Prop 驱动，零内部状态。
 */
@Component
export struct GearPreviewCard {
  @Prop item: GearItem = {} as GearItem;
  @Prop tripCount: number = 0;

  @Builder
  private PreviewLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FONT_SIZE_BODY_SMALL)
        .fontColor(TEXT_TERTIARY)
        .width(40)
      Text(value)
        .fontSize(FONT_SIZE_BODY_SMALL)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Row()
          .width(4)
          .height(28)
          .borderRadius(2)
          .backgroundColor(getGroupColor(this.item.category))
        Text(this.item.name)
          .fontSize(FONT_SIZE_PANEL_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        this.PreviewLine('分组', this.item.category)
        this.PreviewLine('重量', this.item.weight === undefined ? '未填写' : this.item.weight.toString() + 'g')
        this.PreviewLine('价格', this.item.price === undefined ? '未填写' : '¥' + this.item.price.toString())
        this.PreviewLine('出行', this.tripCount > 0 ? '×' + this.tripCount.toString() : '未出行')
        if (this.item.note !== undefined && this.item.note.length > 0) {
          this.PreviewLine('备注', this.item.note)
        }
        this.PreviewLine('添加', formatDateText(this.item.createdAt))
      }
      .width('100%')
    }
    .width('72%')
    .constraintSize({ maxWidth: 320, minWidth: 240 })
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
    .shadow({ radius: 24, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 8 })
  }
}
