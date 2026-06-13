// 统一清单视图 - Zone 统一外壳组件（D-1 / 便单式淡色块容器重构）
// 职责：定义「网格态格子」与「聚焦态卡片」共用的外壳结构，
//   从根上保证 geometryTransition 两端外壳 100% 一致——这是转场不闪烁的地基。
// 外壳 = 一整块淡色填充容器（ZONE_*_FILL 底 + ZONE_*_STROKE 描边 + 圆角 + clip），
//        顶部坐「居中彩色标题」（zoneColor 文字，无色条/无独立染色块），
//        标题下方直接排内容（content 插槽），无白卡内层、顶部对齐、空白由淡色背景自然消化。
// 设计参考：便单四象限色块（满色填充容器 + 居中彩标题 + 顶部对齐 + 留白同色不显脏）。
// 交互（按压缩放 / 点击进聚焦 / 拖拽高亮）由各自宿主（ZoneGridCell / FocusedZoneView）通过参数注入，
//   ZoneShell 只负责外壳视觉与结构。spec §2.2 / 路线图 D-1
//
// 空轻满重（B-3）：空态（contentDashed=true）整块底色降级为更淡的中性，描边更细，
//   标题降灰——在淡彩网格中明显「轻一档」，不抢满格子视觉权重。

import {
  TEXT_TERTIARY,
  DIVIDER_COLOR,
  LIGHT_PRIMARY_COLOR,
  ZONE_MISC_COLOR,
  ZONE_MISC_STROKE,
  ZONE_MISC_FILL
} from '../../constants/Colors';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_BOLD
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import { SPRING_PRESS, PRESS_SCALE_DOWN, SPRING_GENERAL } from '../../constants/AnimationTokens';
import { BodyZone } from '../../constants/GearLoadout';
import { zoneDisplayName } from '../../services/LoadoutService';

@Component
export struct ZoneShell {
  @Prop zone: string = BodyZone.Misc;
  // 标题彩色文字色（= 该 Zone 主题色）
  @Prop zoneColor: string = ZONE_MISC_COLOR;
  // 整块容器描边色
  @Prop zoneStroke: string = ZONE_MISC_STROKE;
  // 整块容器淡色填充底（便单式色块）
  @Prop zoneFill: string = ZONE_MISC_FILL;

  // 标题区高度（网格态紧凑 / 聚焦态宽松，由宿主传入）
  @Prop titleBarHeight: number = 28;
  @Prop titleFontSize: number = FONT_SIZE_BODY_MEDIUM;

  // C-2：拖拽目标格高亮——整块容器叠一层淡绿（仅 backgroundColor 走 SPRING_GENERAL）
  @Prop contentTinted: boolean = false;
  // 整块容器描边是否显示
  @Prop showContentBorder: boolean = true;
  // B-3 空态降级：整块底色更淡（中性）、描边更细、标题降灰，内容区交给 content 插槽自绘虚线降权框。
  @Prop contentDashed: boolean = false;
  // 聚焦态描边加重：边框 2vp + zoneColor 主题色实色（轻透明 stroke 色变实色主题色）。
  //   网格态描边轻（不抑底色块）；聚焦态是独立卡片需明确轮廓，加粗 + 实色才有「实体卡片」感。
  @Prop focusBorder: boolean = false;
  // 整块容器是否响应点击/按压（网格态点格子进聚焦；聚焦态卡内自有交互，关闭）
  @Prop contentClickable: boolean = false;
  // 问题6：tap 是否要求「原地静止」才生效。
  //   false（默认，网格态）：用 onClick——依赖 ArkUI「子 onClick 消费则父 onClick 不触发」
  //     的互斥语义，点 check 圈/装备名不会误冒泡进聚焦（原设计依赖，不可破坏）。
  //   true（聚焦态）：用 onTouch 全程位移判定——聚焦态列表内容不足一屏时上下滑空白区会被
  //     误判为 click 触发收起，故只认「位移 < TAP_SLOP 的原地轻点」，滑动一律忽略。
  @Prop tapNeedsStationary: boolean = false;
  // 整块容器按压态（宿主透传 @State）
  @Prop contentPressed: boolean = false;
  // 整块容器按压事件回上
  onContentTouch: (pressed: boolean) => void = () => {};
  // 整块容器点击回调（网格态进聚焦）
  onTapContent: (zone: string) => void = () => {};

  // 内容插槽（必填）
  @BuilderParam content: () => void;
  // 标题右侧 trailing 插槽（网格态数量 / 聚焦态关闭键等，默认空）
  @BuilderParam titleTrailing: () => void = this.emptyTrailing;
  // 标题点击/clickable 在新模型下整块容器统一承接，标题不单独响应，保留空壳避免宿主报错
  @Prop titleClickable: boolean = true;

  @Builder
  emptyTrailing() {
  }

  // 问题6 修复：tap 关闭/进聚焦的位移判定。
  //   原先整块容器用无脑 onClick → onTapContent，当聚焦态列表内容不足一屏时，
  //   在内容空白区上下滑动（List 滚不动）→ 垂直 pan 冒泡到根节点被判成 click → 误触发收起。
  //   第一性原理：浏览手势（上下滑）与返回手势（轻点）必须正交。改为 onTouch 全程记录
  //   按下坐标，抬手时仅当位移 < TAP_SLOP 才认定为「原地轻点」，否则视为滑动、忽略。
  private static readonly TAP_SLOP: number = 10;
  private touchDownX: number = 0;
  private touchDownY: number = 0;
  private touchMoved: boolean = false;

  build() {
    // 整块淡色容器：标题坐顶部，内容排标题下方，顶部对齐，空白由淡色背景消化。
    Column() {
      this.buildTitleRow()

      // 内容区：占据标题下剩余高度（layoutWeight 1），透明无装饰，顶部对齐。
      //   白卡层已移除——内容直接坐在淡色容器里，留白即同色背景（便单式）。
      Column() {
        this.content()
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    // 整块淡色填充底：空态降级为更淡中性、拖拽态叠淡绿，否则 zoneFill
    .backgroundColor(this.contentDashed
      ? DIVIDER_COLOR
      : (this.contentTinted ? LIGHT_PRIMARY_COLOR : this.zoneFill))
    .animation({ curve: SPRING_GENERAL() })
    .borderRadius(CARD_RADIUS)
    // 描边：空态更细更浅（降权）；聚焦态 2vp + zoneColor 主题色实色（明确轮廓+实体感）；否则网格态 1vp + 轻 zoneStroke
    .border(!this.showContentBorder
      ? undefined
      : (this.contentDashed
        ? { width: 0.5, color: DIVIDER_COLOR, style: BorderStyle.Solid }
        : (this.focusBorder
          ? { width: 2, color: this.zoneColor, style: BorderStyle.Solid }
          : { width: 1, color: this.zoneStroke, style: BorderStyle.Solid })))
    .clip(true)
    .scale({
      x: this.contentClickable && this.contentPressed ? PRESS_SCALE_DOWN : 1.0,
      y: this.contentClickable && this.contentPressed ? PRESS_SCALE_DOWN : 1.0
    })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (!this.contentClickable) {
        return;
      }
      const touch = e.touches.length > 0 ? e.touches[0] : undefined;
      if (e.type === TouchType.Down) {
        this.onContentTouch(true);
        this.touchMoved = false;
        if (touch !== undefined) {
          this.touchDownX = touch.x;
          this.touchDownY = touch.y;
        }
      } else if (e.type === TouchType.Move) {
        // 累积位移超阈值即标记为「滑动」，后续抬手不再触发轻点关闭
        if (touch !== undefined) {
          const dx = touch.x - this.touchDownX;
          const dy = touch.y - this.touchDownY;
          if (Math.abs(dx) > ZoneShell.TAP_SLOP || Math.abs(dy) > ZoneShell.TAP_SLOP) {
            this.touchMoved = true;
          }
        }
      } else if (e.type === TouchType.Up) {
        this.onContentTouch(false);
        // 聚焦态（tapNeedsStationary）：仅「原地轻点」（位移 < TAP_SLOP）才触发，滑动一律忽略。
        //   网格态由 onClick 处理（互斥语义），此处不重复触发。
        if (this.tapNeedsStationary && !this.touchMoved) {
          this.onTapContent(this.zone);
        }
      } else if (e.type === TouchType.Cancel) {
        this.onContentTouch(false);
        this.touchMoved = false;
      }
    })
    .onClick(() => {
      // 网格态：保留 onClick 互斥语义（子 onClick 消费则不触发），点 check 圈/装备名不误进聚焦。
      //   聚焦态走 onTouch 位移判定，这里跳过避免双触发。
      if (this.contentClickable && !this.tapNeedsStationary) {
        this.onTapContent(this.zone);
      }
    })
  }

  // ---- 标题：居中、彩色文字（无色条、无独立染色块） + trailing 插槽 ----
  // 便单式：标题就是容器顶部的一行彩色居中文字，trailing（数量/关闭键）靠右悬浮。
  @Builder
  private buildTitleRow() {
    Stack({ alignContent: Alignment.Center }) {
      // 居中彩色标题
      Text(zoneDisplayName(this.zone))
        .fontSize(this.titleFontSize)
        .fontWeight(FONT_WEIGHT_BOLD)
        // 空态标题降灰（B-3 轻一档），否则彩色
        .fontColor(this.contentDashed ? TEXT_TERTIARY : this.zoneColor)

      // trailing 靠右（数量 / 关闭键）
      Row() {
        this.titleTrailing()
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.titleBarHeight)
    .padding({ left: 12, right: 12 })
  }
}
