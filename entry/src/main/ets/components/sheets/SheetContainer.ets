import {
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_BODY_SMALL
} from '../../constants/Typography';
import {
  CARD_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  TRANSPARENT,
  OVERLAY_SUBTLE
} from '../../constants/Colors';
import { SPRING_GENERAL } from '../../constants/AnimationTokens';

@Component
export struct SheetContainer {
  // ===== 动画控制（父级驱动） =====
  @Prop sheetTranslateY: number = 800;
  @Prop sheetOverlayOpacity: number = 0;

  // ===== 标题 =====
  @Prop sheetTitle: string = '';
  @Prop showHeader: boolean = true;

  // ===== 关闭按钮文案（默认 '关闭'，可传 '完成' 等） =====
  @Prop closeButtonText: string = '关闭';

  // ===== 头部可选额外按钮（标题和关闭按钮之间） =====
  @Prop headerActionText: string = '';
  onHeaderAction: () => void = () => {};

  // ===== 错误提示 =====
  @Prop errorText: string = '';

  // ===== 行为 =====
  onClose: () => void = () => {};

  // ===== 内容槽 =====
  @BuilderParam content: () => void;

  // ===== 手势状态（内部） =====
  @State private sheetDragOffset: number = 0;
  @State private cardHeight: number = 600;

  build() {
    Column() {
      // 顶部空白区域：点击关闭
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.onClose();
        })

      // 卡片主体
      Column({ space: 14 }) {
        // 标题栏（部分 Sheet 自建 head，跳过统一标题）
        if (this.showHeader) {
          Row() {
            Text(this.sheetTitle)
              .fontSize(FONT_SIZE_BODY_LARGE)
              .fontWeight(FontWeight.Medium)
              .fontColor(TEXT_MAIN)
              .layoutWeight(1)
            if (this.headerActionText.length > 0) {
              Button(this.headerActionText)
                .fontSize(FONT_SIZE_BODY_MEDIUM)
                .fontColor(PRIMARY_COLOR)
                .backgroundColor(TRANSPARENT)
                .onClick(() => {
                  this.onHeaderAction();
                })
            }
            Button(this.closeButtonText)
              .fontSize(FONT_SIZE_BODY_SMALL)
              .fontColor(TEXT_SECONDARY)
              .backgroundColor(TRANSPARENT)
              .onClick(() => {
                this.onClose();
              })
          }
        }

        // 错误提示
        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor('#E53935')
            .width('100%')
        }

        // 内容槽
        this.content()
      }
      .width('100%')
      .height('72%')
      .padding({ left: 16, right: 16, top: this.showHeader ? 16 : 10, bottom: 20 })
      .backgroundColor(CARD_BG)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .translate({ y: this.sheetTranslateY + this.sheetDragOffset })
      .onAreaChange((_old: Area, newArea: Area) => {
        this.cardHeight = newArea.height as number;
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
          .onActionUpdate((event: GestureEvent) => {
            if (event.offsetY > 0) {
              this.sheetDragOffset = event.offsetY * 0.3;
            }
          })
          .onActionEnd((_event: GestureEvent) => {
            if (this.sheetDragOffset > this.cardHeight * 0.25) {
              this.sheetDragOffset = 0;
              this.onClose();
            } else {
              this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
                this.sheetDragOffset = 0;
              });
            }
          })
          .onActionCancel(() => {
            this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
              this.sheetDragOffset = 0;
            });
          })
      )
    }
    .width('100%')
    .height('100%')
    .opacity(this.sheetOverlayOpacity)
    .backgroundColor(OVERLAY_SUBTLE)
    .backdropBlur(16)
  }
}
