// 统一清单视图 - 网格态单格组件
// 职责：渲染单个 BodyZone 的格子（有内容态白卡 / 空态虚线框）
// 标题行 = Zone 色条 + 图标 + 名称 + 数量；点击标题进全屏聚焦（Phase 3 接入）
// Phase 1：仅骨架（标题 + 空态/有内容态外壳 + item 名称占位）；CheckMark / 勾选交互留 Phase 2
// spec §2.1.3 / §2.1.2

import {
  CARD_BG,
  TEXT_MAIN,
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
import { SPRING_PRESS, PRESS_SCALE_DOWN } from '../../constants/AnimationTokens';
import { ChecklistItem } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { zoneDisplayName, zoneIconName } from '../../services/LoadoutService';

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

  // 标题行按压
  @State private titlePressed: boolean = false;

  build() {
    if (this.items.length === 0) {
      this.buildEmptyCell()
    } else {
      this.buildContentCell()
    }
  }

  // ---- 有内容态：标题行 + 白卡列表 ----
  @Builder
  private buildContentCell() {
    Column({ space: 6 }) {
      // 标题行（可点击进全屏聚焦）
      this.buildTitleRow(true)

      // 内容白卡：前 N 条 item 名称占位 + 折叠提示
      Column({ space: 0 }) {
        ForEach(this.previewItems(), (item: ChecklistItem) => {
          Row() {
            Text(item.name)
              .fontSize(FONT_SIZE_BODY_MEDIUM)
              .fontColor(TEXT_MAIN)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(40)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12 })
        }, (item: ChecklistItem) => item.id)

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
    }
    .width('100%')
    .height(this.cellHeight)
    .alignItems(HorizontalAlign.Start)
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
    .height(this.cellHeight)
    .alignItems(HorizontalAlign.Start)
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
