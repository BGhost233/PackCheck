// 统一清单视图 - 网格态单格组件
// 职责：渲染单个 BodyZone 的格子（有内容态白卡 / 空态虚线框）
// 标题行 = Zone 色条 + 图标 + 名称 + 数量；点击标题/白卡主体进全屏聚焦
// P2 双热区：白卡内 ChecklistRow 走 checkOnlyHotzone——点 check 圆圈仅勾选，
//   点装备名/空白/标题冒泡到外层触发全屏聚焦。空态点虚线框打开 picker。
// spec §2.1.3 / §2.1.2

import {
  CARD_BG,
  TEXT_TERTIARY,
  DIVIDER_COLOR,
  SHADOW_SUBTLE,
  TRANSPARENT,
  ZONE_MISC_COLOR
} from '../../constants/Colors';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION,
  FONT_WEIGHT_MEDIUM
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import { SPRING_PRESS, PRESS_SCALE_DOWN, SPRING_GENERAL } from '../../constants/AnimationTokens';
import { ChecklistItem } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { zoneDisplayName, zoneIconName } from '../../services/LoadoutService';
import { ChecklistRow } from './ChecklistRow';

// 网格态单格内最多预览的 item 数（超出折叠为「+N 件」提示）。spec §2.1.3
const MAX_PREVIEW_ITEMS: number = 3;

@Component
export struct ZoneGridCell {
  @Prop zone: string = BodyZone.Misc;
  @Prop items: ChecklistItem[] = [];
  @Prop zoneColor: string = ZONE_MISC_COLOR;
  @Prop cellHeight: number = 160;

  // 回调（Phase 2/3 接入）
  onTapTitle: (zone: string) => void = () => {};
  onTapEmpty: (zone: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};

  // 标题行按压
  @State private titlePressed: boolean = false;
  // P2：白卡主体（装备名/空白）按压——点这里整卡进全屏聚焦，与标题行同语义
  @State private contentPressed: boolean = false;

  build() {
    // 空态与有内容态双层常驻，用 opacity 互斥做 crossfade，避免 if/else 硬切（review V3）。
    // opacity / hitTestBehavior / animation 加在各 @Builder 内部根节点（ArkUI 不允许在 @Builder 调用处外部追加属性）。
    // 依赖隐式动画驱动：items 数量变化时 opacity 自动 Spring 过渡，不依赖父层 animateTo。
    Stack() {
      this.buildContentCell()
      this.buildEmptyCell()
    }
    .width('100%')
    .height(this.cellHeight)
  }

  // ---- 有内容态：标题行 + 白卡列表 ----
  @Builder
  private buildContentCell() {
    Column({ space: 6 }) {
      // 标题行（可点击进全屏聚焦）
      this.buildTitleRow(true)

      // 内容白卡：前 N 条 item 核查行 + 折叠提示
      // P2：白卡整体绑 onClick→进全屏聚焦；ChecklistRow 走双热区（checkOnlyHotzone），
      //   点 check 圆圈仅勾选不冒泡，点装备名/空白冒泡到这里触发聚焦。
      Column({ space: 0 }) {
        ForEach(this.previewItems(), (item: ChecklistItem) => {
          ChecklistRow({
            item: item,
            rowHeight: 40,
            checkSize: 22,
            checkOnlyHotzone: true,
            onToggleCheck: this.onToggleCheck
          })
        }, (item: ChecklistItem) => item.id + '_' + (item.checked ? '1' : '0'))

        // 超过 N 件：折叠提示行
        if (this.items.length > MAX_PREVIEW_ITEMS) {
          Row() {
            Text('+' + (this.items.length - MAX_PREVIEW_ITEMS).toString() + ' 件')
              .fontSize(FONT_SIZE_CAPTION)
              .fontColor(TEXT_TERTIARY)
          }
          .width('100%')
          .height(28)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(CARD_BG)
      .borderRadius(CARD_RADIUS)
      .shadow({ radius: 8, color: SHADOW_SUBTLE, offsetY: 2 })
      .clip(true)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .scale({ x: this.contentPressed ? PRESS_SCALE_DOWN : 1.0, y: this.contentPressed ? PRESS_SCALE_DOWN : 1.0 })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.contentPressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.contentPressed = false;
        }
      })
      .onClick(() => {
        // 点装备名/空白/折叠提示均进全屏聚焦（check 圆圈已拦截不冒泡到此）
        this.onTapTitle(this.zone);
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.items.length > 0 ? 1 : 0)
    .hitTestBehavior(this.items.length > 0 ? HitTestMode.Default : HitTestMode.None)
    .animation({ curve: SPRING_GENERAL() })
  }

  // ---- 空态：标题行 + 虚线占位区 ----
  @Builder
  private buildEmptyCell() {
    Column({ space: 6 }) {
      this.buildTitleRow(false)

      // 虚线占位区，撑满整格高度，「+」居中
      Column() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(20)
          .fontColor([TEXT_TERTIARY])
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(CARD_RADIUS)
      .border({
        width: 1.5,
        color: DIVIDER_COLOR,
        style: BorderStyle.Dashed,
        radius: CARD_RADIUS
      })
      .scale({ x: this.titlePressed ? PRESS_SCALE_DOWN : 1.0, y: this.titlePressed ? PRESS_SCALE_DOWN : 1.0 })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.titlePressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.titlePressed = false;
        }
      })
      .onClick(() => {
        this.onTapEmpty(this.zone);
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.items.length === 0 ? 1 : 0)
    .hitTestBehavior(this.items.length === 0 ? HitTestMode.Default : HitTestMode.None)
    .animation({ curve: SPRING_GENERAL() })
  }

  // ---- 标题行：色条 + 图标 + 名称 + 数量 ----
  @Builder
  private buildTitleRow(clickable: boolean) {
    Row({ space: 6 }) {
      // Zone 主题色条 4×16
      Row()
        .width(4)
        .height(16)
        .borderRadius(2)
        .backgroundColor(this.zoneColor)

      SymbolGlyph($r(zoneIconName(this.zone)))
        .fontSize(15)
        .fontColor([this.zoneColor])

      Text(zoneDisplayName(this.zone))
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(this.zoneColor)

      Blank()

      if (this.items.length > 0) {
        Text(this.items.length.toString())
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_TERTIARY)
      }
    }
    .width('100%')
    .height(24)
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
    .scale({
      x: clickable && this.titlePressed ? PRESS_SCALE_DOWN : 1.0,
      y: clickable && this.titlePressed ? PRESS_SCALE_DOWN : 1.0
    })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (!clickable) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.titlePressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.titlePressed = false;
      }
    })
    .onClick(() => {
      if (clickable) {
        this.onTapTitle(this.zone);
      }
    })
  }

  private previewItems(): ChecklistItem[] {
    if (this.items.length <= MAX_PREVIEW_ITEMS) {
      return this.items;
    }
    return this.items.slice(0, MAX_PREVIEW_ITEMS);
  }
}
