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
  PRIMARY_COLOR,
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
import { vibrator } from '@kit.SensorServiceKit';

// 网格态单格内最多预览的 item 数（超出折叠为「+N 件」提示）。spec §2.1.3
// P4：收缩态露 4 个装备名（配合降格高）
const MAX_PREVIEW_ITEMS: number = 4;
// P4：网格态核查行压缩一档（聚焦态仍用默认宽松尺寸）
const GRID_ROW_HEIGHT: number = 32;
const GRID_CHECK_SIZE: number = 20;

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
  // Phase 4：网格态长按+拖拽回调（full mode）
  onLongPressItem: (item: ChecklistItem, globalX: number, globalY: number) => void = () => {};
  onPanUpdate: (offsetX: number, offsetY: number) => void = () => {};
  onPanFinish: (offsetX: number, offsetY: number) => void = () => {};

  // 拖拽悬停高亮：拖拽胶囊进入本格子时父层设为 true，格子边框 glow 绿光
  @Prop isDropTarget: boolean = false;

  // 标题行按压
  @State private titlePressed: boolean = false;
  // P2：白卡主体（装备名/空白）按压——点这里整卡进全屏聚焦，与标题行同语义
  @State private contentPressed: boolean = false;

  build() {
    // if/else 而非 Stack 双层常驻：空态和有内容态不可同时存在于视图树，
    // 消除 HitTestMode.None 在 ArkUI 中不阻止子元素 onClick 的不可靠性。
    // 外层 Column 承载 cellHeight 约束（v3 中由 Stack 提供）。
    Column() {
      if (this.items.length === 0) {
        this.buildEmptyCell()
      } else {
        this.buildContentCell()
      }
    }
    .width('100%')
    .height(this.cellHeight)
    .borderRadius(CARD_RADIUS)
    .border({
      width: this.isDropTarget ? 2.5 : 0,
      color: this.isDropTarget ? PRIMARY_COLOR : 'transparent',
      style: BorderStyle.Solid
    })
    .shadow(this.isDropTarget
      ? { radius: 16, color: '#402D7D46', offsetY: 0 }
      : undefined)
    .animation({ curve: SPRING_GENERAL() })
    .clip(true)
  }

  // ---- 有内容态：标题行 + 白卡列表 ----
  @Builder
  private buildContentCell() {
    Column({ space: 6 }) {
      // 标题行（可点击进全屏聚焦）
      this.buildTitleRow(true)

      // 内容白卡：前 N 条 item 核查行 + 折叠提示
      // P2/问题1：ChecklistRow 走双热区（checkOnlyHotzone），点 check 圆圈仅勾选；
      //   点装备名/行空白由 ChecklistRow 直接调 onTapRow→onTapTitle 进聚焦（ArkUI onClick 消费事件不冒泡，
      //   不能靠白卡 onClick 接装备行点击，故由本行直接回调）。白卡 onClick 仅兜底空白/折叠提示区。
      // Phase 4：每行用 Column wrapper 承载 GestureGroup(Sequence, LongPress+Pan)。
      // 关键：手势必须绑在「有点击响应」的元素所在的同层或上层，而非下层 Image 层——
      // ArkUI 中子元素 onClick 会独占触摸序列，下层 Image 的 LongPressGesture 永远等不到 400ms。
      // 此处 wrapper 只有 gesture、没有 onClick——tap 由 ChecklistRow 内部 onClick 处理，
      // long press + pan 由 wrapper 的 GestureGroup 处理，两者不互斥。
      Column({ space: 0 }) {
        ForEach(this.previewItems(), (item: ChecklistItem) => {
          Column() {
            ChecklistRow({
              item: item,
              rowHeight: GRID_ROW_HEIGHT,
              checkSize: GRID_CHECK_SIZE,
              checkOnlyHotzone: true,
              onToggleCheck: this.onToggleCheck,
              onTapRow: () => { this.onTapTitle(this.zone); }
            })
          }
          .width('100%')
          .height(GRID_ROW_HEIGHT)
          .gesture(
            GestureGroup(
              GestureMode.Sequence,
              LongPressGesture({ repeat: false, duration: 400 })
                .onAction((event: GestureEvent) => {
                  this.triggerHaptic();
                  const finger = event.fingerList[0];
                  this.onLongPressItem(item, finger.globalX, finger.globalY);
                }),
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionUpdate((event: GestureEvent) => {
                  this.onPanUpdate(event.offsetX, event.offsetY);
                })
                .onActionEnd((event: GestureEvent) => {
                  this.onPanFinish(event.offsetX, event.offsetY);
                })
            )
          )
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

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.soft',
        count: 1
      }, { usage: 'touch' });
    } catch (_e) {
      // 模拟器/无振动器设备静默失败
    }
  }
}
