import { SPRING_GENERAL } from '../../constants/AnimationTokens';
import {
  PRIMARY_COLOR,
  PRIMARY_TINT_COLOR,
  TEXT_MAIN,
  TEXT_TERTIARY,
  WHITE
} from '../../constants/DesignTokens';

/**
 * 装备库空态 — 无任何装备时的占位（图标 + 文案 + 添加按钮）。
 * 纯展示：入场动画由父级 entered 驱动，添加动作回调透传。
 */
@Component
export struct GearEmptyState {
  @Prop entered: boolean = false;
  onAddGear: () => void = (): void => {};

  build() {
    Column({ space: 20 }) {
      // 图标：轻量圆形背景 + 系统图标
      Row() {
        SymbolGlyph($r('sys.symbol.bag'))
          .fontSize(32)
          .fontColor([PRIMARY_COLOR])
      }
      .width(64)
      .height(64)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(PRIMARY_TINT_COLOR)
      .borderRadius(32)
      .opacity(this.entered ? 1 : 0)
      .scale({ x: this.entered ? 1 : 0.9, y: this.entered ? 1 : 0.9 })
      .animation({ curve: SPRING_GENERAL(), delay: 60 })

      // 文案
      Column({ space: 6 }) {
        Text('装备库空空如也')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
        Text('添加你的第一件装备，开始记录户外家当')
          .fontSize(13)
          .fontColor(TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Center)

      // 行动按钮
      Button('添加装备')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(WHITE)
        .backgroundColor(PRIMARY_COLOR)
        .padding({ left: 24, right: 24 })
        .borderRadius(20)
        .onClick(() => {
          this.onAddGear();
        })
    }
    .width('100%')
    .padding({ top: 48, bottom: 48 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
