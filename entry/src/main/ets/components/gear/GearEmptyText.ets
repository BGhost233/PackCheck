import { CARD_BG, TEXT_TERTIARY } from '../../constants/DesignTokens';

/**
 * 装备库轻量空提示 — 如「未找到相关装备」。纯展示，仅一行文案卡片。
 */
@Component
export struct GearEmptyText {
  @Prop message: string = '';

  build() {
    Text(this.message)
      .fontSize(14)
      .fontColor(TEXT_TERTIARY)
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding(18)
      .backgroundColor(CARD_BG)
      .borderRadius(16)
  }
}
