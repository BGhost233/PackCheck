import {
  CARD_BG,
  SHADOW_MICRO
} from '../../constants/DesignTokens';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';

// 首页快捷入口胶囊：纯展示 + 自包含按压态。
//   原 HomePage.QuickEntry Builder 剥离而来，按压互斥由组件自管 @State，消除父级 quickEntryPressed 字段。
@Component
export struct HomeQuickEntry {
  @Prop icon: Resource;
  @Prop title: string = '';
  @Prop bg: string = CARD_BG;
  @Prop color: string = '';
  action: () => void = (): void => {};

  @State private pressed: boolean = false;

  build() {
    Column({ space: 5 }) {
      SymbolGlyph(this.icon)
        .fontSize(22)
        .fontColor([this.color])
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.color)
    }
    .height(80)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.bg)
    .borderRadius(16)
    .shadow({ radius: this.bg === CARD_BG ? 8 : 0, color: SHADOW_MICRO, offsetX: 0, offsetY: 1 })
    .scale({ x: this.pressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST, y: this.pressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(this.action)
  }
}
