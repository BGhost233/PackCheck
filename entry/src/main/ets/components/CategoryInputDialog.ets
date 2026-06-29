import {
  CARD_BG,
  DIVIDER_COLOR,
  GROUP_HEADER_BG,
  OVERLAY_MASK,
  PRIMARY_COLOR,
  SHADOW_DEFAULT,
  TEXT_MAIN,
  TEXT_TERTIARY,
  WHITE
} from '../constants/DesignTokens';
import { FONT_SIZE_OVERLINE, FONT_SIZE_PANEL_TITLE } from '../constants/Typography';
import { SPRING_PANEL_ENTER, PANEL_SCALE_START } from '../constants/AnimationTokens';

/**
 * 分组新增/重命名 Dialog。
 * 由外部 if(visible) 条件渲染控制显隐，内部管理 input @State。
 */
@Component
export struct CategoryInputDialog {
  /** 'add' | 'rename' */
  @Prop mode: string = 'add';
  /** 重命名模式下的旧名（新增模式忽略） */
  initialOldName: string = '';

  onConfirm: (input: string) => void = () => {};
  onClose: () => void = () => {};

  @State private inputText: string = '';

  aboutToAppear(): void {
    this.inputText = this.mode === 'rename' ? this.initialOldName : '';
  }

  build() {
    Stack() {
      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OVERLAY_MASK)
        .onClick(() => { this.onClose(); })
        .transition(TransitionEffect.OPACITY.animation({ curve: SPRING_PANEL_ENTER() }))

      // 对话框
      Column({ space: 16 }) {
        Text(this.mode === 'add' ? '新增分组' : '重命名分组')
          .fontSize(FONT_SIZE_PANEL_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        TextInput({ text: this.inputText, placeholder: '输入分组名称' })
          .width('100%')
          .height(44)
          .maxLength(50)
          .fontSize(FONT_SIZE_OVERLINE)
          .borderRadius(10)
          .backgroundColor(GROUP_HEADER_BG)
          .onChange((value: string) => { this.inputText = value; })

        Row({ space: 12 }) {
          Button('取消')
            .fontSize(FONT_SIZE_OVERLINE)
            .fontColor(TEXT_TERTIARY)
            .backgroundColor(DIVIDER_COLOR)
            .borderRadius(10)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.onClose(); })

          Button('确认')
            .fontSize(FONT_SIZE_OVERLINE)
            .fontColor(WHITE)
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(10)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              const input = this.inputText.trim();
              if (input.length === 0) {
                return;
              }
              this.onConfirm(input);
            })
        }
        .width('100%')
      }
      .width('80%')
      .padding(24)
      .backgroundColor(CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 4 })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: PANEL_SCALE_START, y: PANEL_SCALE_START }))
        .combine(TransitionEffect.translate({ y: 8 }))
        .animation({ curve: SPRING_PANEL_ENTER() })
      )
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
