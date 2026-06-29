import { PRIMARY_COLOR, GLASS_BG_HEAVY, PRIMARY_SHADOW_LIGHT } from '../constants/DesignTokens';
import { FONT_SIZE_BODY_MEDIUM } from '../constants/Typography';
import { SPRING_PANEL_ENTER, PANEL_SCALE_START } from '../constants/AnimationTokens';

@Component
export struct CompletionToast {
  build() {
    Column() {
      Row({ space: 6 }) {
        Circle({ width: 7, height: 7 })
          .fill(PRIMARY_COLOR)
        Text('全部就绪，出发吧')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_COLOR)
      }
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .backgroundColor(GLASS_BG_HEAVY)
      .backdropBlur(20)
      .borderRadius(20)
      .shadow({ radius: 16, color: PRIMARY_SHADOW_LIGHT, offsetX: 0, offsetY: 4 })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -12 }))
        .combine(TransitionEffect.scale({ x: PANEL_SCALE_START, y: PANEL_SCALE_START }))
        .animation({ curve: SPRING_PANEL_ENTER() })
      )
    }
    .width('100%')
    .height('100%')
    .padding({ top: 64 })
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
  }
}
