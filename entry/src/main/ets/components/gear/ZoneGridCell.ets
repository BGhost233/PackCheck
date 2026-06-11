// 统一清单视图 - 网格态单格组件
// 职责：渲染单个 BodyZone 的格子（有内容态白卡 / 空态虚线框）
// 标题行 = Zone 色条 + 图标 + 名称 + 数量；点击标题/白卡主体进全屏聚焦
// P2 双热区：白卡内 ChecklistRow 走 checkOnlyHotzone——点 check 圆圈仅勾选，
//   点装备名/空白/标题冒泡到外层触发全屏聚焦。空态点虚线框打开 picker。
// spec §2.1.3 / §2.1.2

import {
  TEXT_MAIN,
  TEXT_TERTIARY,
  DIVIDER_COLOR,
  PLACEHOLDER_COLOR,
  PRIMARY_COLOR,
  PRIMARY_SHADOW_GLOW,
  ZONE_MISC_COLOR,
  ZONE_MISC_STROKE,
  ZONE_MISC_TINT
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
import { ZoneShell } from './ZoneShell';
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
  // B-2：容器描边色 + 标题行浅染底（由父层 zoneStroke/zoneTint helper 传入）
  @Prop zoneStroke: string = ZONE_MISC_STROKE;
  @Prop zoneTint: string = ZONE_MISC_TINT;
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

  // C-1：当前被拖拽 item 的 id（空串表示无拖拽）。命中行在源位置渲染虚线空槽，明确"从哪拿的"
  @Prop draggingItemId: string = '';

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
      ? { radius: 16, color: PRIMARY_SHADOW_GLOW, offsetY: 0 }
      : undefined)
    .animation({ curve: SPRING_GENERAL() })
    .clip(true)
  }

  // ---- 有内容态：ZoneShell（标题行 + 白卡）包裹 ----
  // D-1：外壳（标题行浅染 + 白卡描边阴影 + 按压缩放 + 点击进聚焦）全部下放到 ZoneShell，
  //   两端共用同一外壳结构，是 geometryTransition 不闪烁的地基。
  //   本组件只往插槽里塞「数量 Text（titleTrailing）」与「核查行 ForEach（content）」。
  @Builder
  private buildContentCell() {
    ZoneShell({
      zone: this.zone,
      zoneColor: this.zoneColor,
      zoneStroke: this.zoneStroke,
      zoneTint: this.zoneTint,
      // C-2：拖拽目标格白卡叠淡绿底（与外层绿框+glow 三重反馈）
      contentTinted: this.isDropTarget,
      titleClickable: true,
      titlePressed: this.titlePressed,
      onTitleTouch: (pressed: boolean) => { this.titlePressed = pressed; },
      onTapTitle: (zone: string) => { this.onTapTitle(zone); },
      contentClickable: true,
      contentPressed: this.contentPressed,
      onContentTouch: (pressed: boolean) => { this.contentPressed = pressed; },
      onTapContent: (zone: string) => { this.onTapTitle(zone); },
      titleTrailing: () => { this.buildCountTrailing() },
      content: () => { this.buildPreviewList() }
    })
  }

  // 标题行右侧：数量
  @Builder
  private buildCountTrailing() {
    if (this.items.length > 0) {
      Text(this.items.length.toString())
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_TERTIARY)
    }
  }

  // 内容白卡内容：前 N 条核查行 + 折叠提示
  // P2/问题1：ChecklistRow 走双热区（checkOnlyHotzone），点 check 圆圈仅勾选；
  //   点装备名/行空白由 ChecklistRow 直接调 onTapRow→onTapTitle 进聚焦（ArkUI onClick 消费事件不冒泡）。
  // Phase 4：每行用 Column wrapper 承载 GestureGroup(Sequence, LongPress+Pan)。
  //   手势必须绑在「有点击响应」元素的同层/上层；wrapper 只有 gesture 无 onClick，
  //   tap 由 ChecklistRow 内部 onClick 处理，long press + pan 由 wrapper 处理，两者不互斥。
  @Builder
  private buildPreviewList() {
    Column({ space: 0 }) {
      ForEach(this.previewItems(), (item: ChecklistItem) => {
        if (this.draggingItemId.length > 0 && item.id === this.draggingItemId) {
          // C-1：被拖拽项在源位置留虚线空槽，同高不塌陷，不绑手势
          Row()
            .width('100%')
            .height(GRID_ROW_HEIGHT - 4)
            .margin({ top: 2, bottom: 2 })
            .borderRadius(6)
            .border({ width: 1, color: DIVIDER_COLOR, style: BorderStyle.Dashed })
        } else {
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
        }
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
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  // ---- 空态：标题行 + 虚线占位区 ----
  @Builder
  private buildEmptyCell() {
    Column({ space: 6 }) {
      this.buildTitleRow(false)

      // B-3：虚线框高度封顶 132vp，多出空间在框外居中留白（保持同行对齐），
      // 虚线淡化（宽 1）+「+」降权 + 部位名提示，使空格子视觉重量低于满格子。
      Column() {
        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(18)
            .fontColor([PLACEHOLDER_COLOR])

          Text(zoneDisplayName(this.zone))
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(PLACEHOLDER_COLOR)
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxHeight: 132 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(CARD_RADIUS)
        .border({
          width: 1,
          color: DIVIDER_COLOR,
          style: BorderStyle.Dashed,
          radius: CARD_RADIUS
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
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
        .fontColor([TEXT_MAIN])

      Text(zoneDisplayName(this.zone))
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_MAIN)

      Blank()

      if (this.items.length > 0) {
        Text(this.items.length.toString())
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_TERTIARY)
      }
    }
    .width('100%')
    .height(28)
    // B-2：标题行浅彩底 + 圆角，色条保留部位色作色彩锚点，图标/文字改深色
    .backgroundColor(this.zoneTint)
    .borderRadius(8)
    .padding({ left: 8, right: 8 })
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
