import { GearItem } from '../../models/PackModels';
import { formatDateText } from '../../services/ChecklistService';
import { companionDays, companionDaysLabel } from '../../services/GearService';
import {
  CHIP_RADIUS,
  DIVIDER_COLOR,
  PRIMARY_TINT_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../../constants/DesignTokens';
import {
  FONT_SIZE_BODY_SMALL, FONT_SIZE_CAPTION, FONT_SIZE_MINI,
  FONT_SIZE_TITLE_LARGE
} from '../../constants/Typography';

/**
 * 装备展开详情面板（属性区 + 陪伴区）。
 * 纯 @Prop 驱动，零内部状态。
 */
@Component
export struct GearDetailPanel {
  @Prop item: GearItem = {} as GearItem;
  @Prop tripCount: number = 0;

  @Builder
  private DetailLine(label: string, value: string) {
    Row() {
      Text(label + '：')
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private CompanionChip(text: string) {
    Text(text)
      .fontSize(FONT_SIZE_MINI)
      .fontColor(TEXT_SECONDARY)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(PRIMARY_TINT_COLOR)
      .borderRadius(CHIP_RADIUS)
      .margin({ bottom: 4 })
  }

  build() {
    Column({ space: 0 }) {
      // ——— 属性区 ———
      Column({ space: 8 }) {
        Divider()
          .strokeWidth(1)
          .color(DIVIDER_COLOR)
        this.DetailLine('分组', this.item.category);
        this.DetailLine('重量', this.item.weight === undefined ? '未填写' : this.item.weight.toString() + 'g');
        if (this.item.brand !== undefined && this.item.brand.length > 0) {
          this.DetailLine('品牌', this.item.brand);
        }
        this.DetailLine('价格', this.item.price === undefined ? '未填写' : '¥' + this.item.price.toString());
        if (this.item.note !== undefined && this.item.note.length > 0) {
          this.DetailLine('备注', this.item.note);
        }
      }
      .width('100%')

      // ——— 分隔 ———
      Row()
        .width('100%')
        .height(1)
        .backgroundColor(DIVIDER_COLOR)
        .margin({ top: 12, bottom: 12 })

      // ——— 陪伴区 ———
      Column({ space: 8 }) {
        Row() {
          Text(companionDays(this.item).toString())
            .fontSize(FONT_SIZE_TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .fontFeature("'tnum'")
          Text(companionDaysLabel(this.item))
            .fontSize(FONT_SIZE_BODY_SMALL)
            .fontColor(TEXT_SECONDARY)
            .margin({ bottom: 2 })
        }
        .alignItems(VerticalAlign.Bottom)

        Row({ space: 8 }) {
          this.CompanionChip('同行 ' + this.tripCount.toString() + ' 次');
          this.CompanionChip('相伴 ' + companionDays(this.item).toString() + ' 天');
          this.CompanionChip('添加于 ' + formatDateText(this.item.createdAt));
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12 })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
  }
}
