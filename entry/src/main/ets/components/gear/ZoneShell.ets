// 统一清单视图 - Zone 统一外壳组件（D-1）
// 职责：定义「网格态格子」与「聚焦态卡片」共用的外壳结构，
//   从根上保证 geometryTransition 两端外壳 100% 一致——这是转场不闪烁的地基。
// 外壳 = 浅染标题行（色条彩 / 图标·名称 TEXT_MAIN 深色 + trailing 插槽）
//        + 内容白卡（CARD_BG + ZONE_*_STROKE 描边 + 柔和阴影 + content 插槽）。
// 两段式（标题行块 + 内容白卡块）而非单张大白卡——与 Phase B 已落地的网格态视觉对齐，零回退。
// 交互（按压缩放 / 点击进聚焦 / 拖拽高亮）由各自宿主（ZoneGridCell / FocusedZoneView）通过参数注入，
//   ZoneShell 只负责外壳视觉与结构。spec §2.2 / 路线图 D-1

import {
  CARD_BG,
  TEXT_MAIN,
  SHADOW_LIGHT,
  LIGHT_PRIMARY_COLOR,
  ZONE_MISC_COLOR,
  ZONE_MISC_STROKE,
  ZONE_MISC_TINT
} from '../../constants/Colors';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_MEDIUM
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import { SPRING_PRESS, PRESS_SCALE_DOWN, SPRING_GENERAL } from '../../constants/AnimationTokens';
import { BodyZone } from '../../constants/GearLoadout';
import { zoneDisplayName, zoneIconName } from '../../services/LoadoutService';

@Component
export struct ZoneShell {
  @Prop zone: string = BodyZone.Misc;
  @Prop zoneColor: string = ZONE_MISC_COLOR;
  @Prop zoneStroke: string = ZONE_MISC_STROKE;
  @Prop zoneTint: string = ZONE_MISC_TINT;

  // 标题行尺寸（网格态紧凑 28 / 聚焦态宽松，由宿主传入）
  @Prop titleBarHeight: number = 28;
  @Prop iconSize: number = 15;
  @Prop barWidth: number = 4;
  @Prop barHeight: number = 16;
  @Prop titleFontSize: number = FONT_SIZE_BODY_MEDIUM;

  // 内容白卡是否上淡绿底（C-2 拖拽目标格高亮复用）
  @Prop contentTinted: boolean = false;
  // 内容白卡描边是否显示（聚焦态卡片可能不需要内层描边，留开关）
  @Prop showContentBorder: boolean = true;
  // P1/P2：空态降级——内容容器退化为透明无装饰布局占位（无实白底/无描边/无阴影/不clip/不响应点击），
  //   虚线框降权视觉完全交由 content 插槽自绘（守住 B-3「空轻满重」分层，空态不进 geometryTransition）。
  //   true 时仅复用 ZoneShell 的统一标题行（解决 P1 浅染底不一致 + P2 平行实现），内容区不套实白卡。
  @Prop contentDashed: boolean = false;
  // 内容白卡是否响应点击/按压（网格态点白卡进聚焦；聚焦态卡内自有交互，关闭）
  @Prop contentClickable: boolean = false;
  // 内容白卡按压态（宿主透传 @State）
  @Prop contentPressed: boolean = false;
  // 内容白卡按压事件回上
  onContentTouch: (pressed: boolean) => void = () => {};
  // 内容白卡点击回调（网格态进聚焦）
  onTapContent: (zone: string) => void = () => {};

  // 标题行点击回调（网格态进聚焦 / 聚焦态可空）+ 按压态由宿主控制
  onTapTitle: (zone: string) => void = () => {};
  // 标题行是否响应点击与按压（聚焦态顶栏一般不需要整条点击）
  @Prop titleClickable: boolean = true;
  // 标题行按压态（宿主透传，保证与宿主其它按压联动一致）
  @Prop titlePressed: boolean = false;
  // 标题行按压事件回上（宿主维护 @State，避免 ZoneShell 自持状态与宿主脱节）
  onTitleTouch: (pressed: boolean) => void = () => {};

  // 内容插槽（必填）
  @BuilderParam content: () => void;
  // 标题行右侧插槽（网格态数量 / 聚焦态进度+关闭等，默认空）
  @BuilderParam titleTrailing: () => void = this.emptyTrailing;

  @Builder
  emptyTrailing() {
  }

  build() {
    Column({ space: 6 }) {
      this.buildTitleRow()

      // 内容白卡
      Column() {
        this.content()
      }
      .width('100%')
      .layoutWeight(1)
      // P1/P2：空态降级时透明底（虚线框交给 content 插槽），否则白卡/拖拽淡绿底
      // C-2：拖拽目标格淡绿底（仅 backgroundColor 走 SPRING_GENERAL，与原 ZoneGridCell 一致）
      .backgroundColor(this.contentDashed
        ? Color.Transparent
        : (this.contentTinted ? LIGHT_PRIMARY_COLOR : CARD_BG))
      .animation({ curve: SPRING_GENERAL() })
      // B-2：阴影升档 + 极淡部位色描边，形成盒子感（静态属性，由下方 SPRING_PRESS 段兜住）
      // 空态降级：无圆角填充/无描边/无阴影/不clip，纯透明布局占位
      .borderRadius(this.contentDashed ? 0 : CARD_RADIUS)
      .border(this.contentDashed || !this.showContentBorder
        ? undefined
        : { width: 0.5, color: this.zoneStroke, style: BorderStyle.Solid })
      .shadow(this.contentDashed ? undefined : { radius: 12, color: SHADOW_LIGHT, offsetY: 4 })
      .clip(!this.contentDashed)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .scale({
        x: this.contentClickable && this.contentPressed ? PRESS_SCALE_DOWN : 1.0,
        y: this.contentClickable && this.contentPressed ? PRESS_SCALE_DOWN : 1.0
      })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (!this.contentClickable) {
          return;
        }
        if (e.type === TouchType.Down) {
          this.onContentTouch(true);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.onContentTouch(false);
        }
      })
      .onClick(() => {
        if (this.contentClickable) {
          this.onTapContent(this.zone);
        }
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ---- 标题行：色条 + 图标 + 名称 + trailing 插槽 ----
  @Builder
  private buildTitleRow() {
    Row({ space: 6 }) {
      // Zone 主题色条（唯一保留部位彩色的色彩锚点）
      Row()
        .width(this.barWidth)
        .height(this.barHeight)
        .borderRadius(2)
        .backgroundColor(this.zoneColor)

      SymbolGlyph($r(zoneIconName(this.zone)))
        .fontSize(this.iconSize)
        .fontColor([TEXT_MAIN])

      Text(zoneDisplayName(this.zone))
        .fontSize(this.titleFontSize)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_MAIN)

      Blank()

      this.titleTrailing()
    }
    .width('100%')
    .height(this.titleBarHeight)
    .backgroundColor(this.zoneTint)
    .borderRadius(8)
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
    .scale({
      x: this.titleClickable && this.titlePressed ? PRESS_SCALE_DOWN : 1.0,
      y: this.titleClickable && this.titlePressed ? PRESS_SCALE_DOWN : 1.0
    })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (!this.titleClickable) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.onTitleTouch(true);
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.onTitleTouch(false);
      }
    })
    .onClick(() => {
      if (this.titleClickable) {
        this.onTapTitle(this.zone);
      }
    })
  }
}
