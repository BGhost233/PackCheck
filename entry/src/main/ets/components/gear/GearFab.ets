import {
  SPRING_FAB_SNAP, SPRING_GENERAL, SPRING_PRESS
} from '../../constants/AnimationTokens';
import {
  GLASS_BG, PRIMARY_COLOR, PRIMARY_SHADOW
} from '../../constants/DesignTokens';
import { FONT_SIZE_TITLE_LARGE } from '../../constants/Typography';

const FAB_SIZE: number = 50;
const FAB_MARGIN: number = 16;
const FAB_MIN_Y: number = 80;
const FAB_BOTTOM_CLEARANCE: number = 140;

/**
 * 装备库浮动操作按钮（FAB）。
 * 支持拖拽重定位 + 松手吸附屏幕两侧 + 折叠屏尺寸自适应。
 *
 * 父组件仅需通过 @Prop 传入 areaWidth/areaHeight，尺寸变化时
 * 内部 @Watch 自动触发 spring 动画重映射坐标。
 */
@Component
export struct GearFab {
  /** 可用区域宽度（由父容器 onAreaChange 下发） */
  @Prop @Watch('onAreaSizeChange') areaWidth: number = 360;
  /** 可用区域高度 */
  @Prop @Watch('onAreaSizeChange') areaHeight: number = 780;

  onTap: () => void = () => {};

  @State private fabX: number = -1;
  @State private fabY: number = -1;
  @State private fabDragging: boolean = false;
  private fabStartX: number = 0;
  private fabStartY: number = 0;
  private prevAreaWidth: number = 0;
  private initialized: boolean = false;

  aboutToAppear(): void {
    this.prevAreaWidth = this.areaWidth;
    this.fabX = this.areaWidth - FAB_SIZE - FAB_MARGIN;
    this.fabY = this.areaHeight - FAB_SIZE - FAB_BOTTOM_CLEARANCE;
    this.initialized = true;
  }

  /** @Watch handler: 区域尺寸变化时 spring 动画重映射坐标 */
  private onAreaSizeChange(): void {
    if (!this.initialized) { return; }
    const wasOnRight = (this.fabX + FAB_SIZE / 2) > this.prevAreaWidth / 2;
    const targetX = wasOnRight ? this.areaWidth - FAB_SIZE - FAB_MARGIN : FAB_MARGIN;
    const maxY = this.areaHeight - FAB_SIZE - FAB_BOTTOM_CLEARANCE;
    const targetY = Math.max(FAB_MIN_Y, Math.min(maxY, this.fabY));
    this.prevAreaWidth = this.areaWidth;
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.fabX = targetX;
      this.fabY = targetY;
    });
  }

  private snapToEdge(): void {
    const centerX = this.fabX + FAB_SIZE / 2;
    const targetX = centerX < this.areaWidth / 2 ? FAB_MARGIN : this.areaWidth - FAB_SIZE - FAB_MARGIN;
    const maxY = this.areaHeight - FAB_SIZE - FAB_BOTTOM_CLEARANCE;
    const targetY = Math.max(FAB_MIN_Y, Math.min(maxY, this.fabY));
    this.getUIContext().animateTo({ curve: SPRING_FAB_SNAP() }, () => {
      this.fabX = targetX;
      this.fabY = targetY;
    });
  }

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(FONT_SIZE_TITLE_LARGE)
        .fontColor([PRIMARY_COLOR])
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE)
    .borderRadius(FAB_SIZE / 2)
    .backgroundColor(GLASS_BG)
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 16, color: PRIMARY_SHADOW, offsetX: 0, offsetY: 6 })
    .position({ x: this.fabX, y: this.fabY })
    .scale({ x: this.fabDragging ? 1.08 : 1, y: this.fabDragging ? 1.08 : 1 })
    .gesture(
      PanGesture({ fingers: 1, distance: 5 })
        .onActionStart(() => {
          this.fabStartX = this.fabX;
          this.fabStartY = this.fabY;
          this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
            this.fabDragging = true;
          });
        })
        .onActionUpdate((event: GestureEvent) => {
          this.fabX = this.fabStartX + event.offsetX;
          this.fabY = this.fabStartY + event.offsetY;
        })
        .onActionEnd(() => {
          this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
            this.fabDragging = false;
          });
          this.snapToEdge();
        })
    )
    .onClick(() => {
      if (!this.fabDragging) {
        this.onTap();
      }
    })
  }
}
