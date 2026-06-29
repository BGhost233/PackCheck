import { Footprint } from '../../services/FootprintService';
import {
  CARD_BG,
  CHIP_RADIUS,
  FONT_FEATURE_TNUM,
  SHADOW_MICRO,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import { FONT_SIZE_MINI } from '../../constants/Typography';

/**
 * 人生足迹精简聚合行（装备库顶部黄金区，提纲 §3.4）。
 * 类似 Apple Health 摘要卡片：单行 chip 展示关键足迹数据，克制不抢装备列表主视觉。
 * 纯展示：聚合后的 Footprint 视图模型由父级单向下发。
 */
@Component
export struct GearFootprintRow {
  @Prop footprint: Footprint;

  build() {
    Row({ space: 8 }) {
      if (this.footprint.totalDistanceKm > 0) {
        this.FootprintChip(this.footprint.totalDistanceKm.toString() + 'km')
      }
      if (this.footprint.totalAscentM > 0) {
        this.FootprintChip(this.footprint.totalAscentM.toString() + 'm↑')
      }
      if (this.footprint.maxAltitude > 0) {
        this.FootprintChip('▲' + this.footprint.maxAltitude.toString() + 'm')
      }
      if (this.footprint.longestCompanion !== undefined && this.footprint.longestCompanion.name.length > 0) {
        this.FootprintChip(this.footprint.longestCompanion.name)
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 4, bottom: 8 })
  }

  @Builder
  private FootprintChip(text: string) {
    Text(text)
      .fontSize(FONT_SIZE_MINI)
      .fontColor(TEXT_SECONDARY)
      .fontWeight(FontWeight.Medium)
      .fontFeature(FONT_FEATURE_TNUM)
      .maxLines(1)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(CARD_BG)
      .borderRadius(CHIP_RADIUS)
      .shadow({ radius: 3, color: SHADOW_MICRO, offsetY: 1 })
  }
}
