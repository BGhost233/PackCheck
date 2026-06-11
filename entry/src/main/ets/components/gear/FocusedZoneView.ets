// 统一清单视图 - 全屏聚焦单格子视图
// 职责：点击网格格子标题后，该 Zone 从网格位置 geometryTransition 放大铺满全屏
// 顶栏（× 关闭 + Zone 名 + 该区进度 + 逐项核查入口）+ 全量装备列表（ChecklistRow 52vp）+ 底部虚线添加行
// 与网格态格子共用 geometryTransition('zone_' + zone) id 完成共享元素转场（F-3：两端节点全程存在）
// spec §2.2 / §4.5.6
// Phase 3：聚焦布局 + 共享元素转场 + 核查复用；长按菜单（仅菜单模式）留 Phase 4

import {
  PRIMARY_COLOR,
  CARD_BG,
  PAGE_BG,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  DIVIDER_COLOR
} from '../../constants/Colors';
import {
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_MEDIUM,
  FONT_WEIGHT_BOLD
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  SPRING_GENERAL,
  STAGGER_OFFSET_Y,
  staggerDelay
} from '../../constants/AnimationTokens';
import { ChecklistItem } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { zoneDisplayName, zoneIconName, calcProgress, LoadoutProgress } from '../../services/LoadoutService';
import { ChecklistRow } from './ChecklistRow';

// 「逐项核查本区」入口（D-2）依赖携 Zone 进入 Review 的 onReviewZone 链路，
// 该链路在 Phase 4 接入后才有真实响应；在此之前隐藏按钮，避免上线即摆设。
// TODO Phase 4: onReviewZone callback 贯通到 Index 后置为 true 恢复
const REVIEW_ZONE_ENTRY_ENABLED: boolean = false;

@Component
export struct FocusedZoneView {
  @Prop zone: string = BodyZone.Misc;
  @Prop items: ChecklistItem[] = [];
  @Prop zoneColor: string = TEXT_SECONDARY;

  // 是否处于激活（聚焦）态：由父传入 focusedZone != null。
  // false→true 时触发列表错落入场（review V2；FocusedZoneView 常驻树，不能用 aboutToAppear）
  @Prop @Watch('onActiveChange') active: boolean = false;

  // callbacks
  onClose: () => void = () => {};
  onTapEmpty: (zone: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  onReviewZone: (zone: string) => void = () => {};

  // 列表错落入场控制（0 = 未入场，1 = 已就位）
  @State private listAppeared: boolean = false;

  // active false→true：重置后下一帧验入场；true→false：重置供下次重放
  onActiveChange(): void {
    if (this.active) {
      this.listAppeared = false;
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.listAppeared = true;
      });
    } else {
      this.listAppeared = false;
    }
  }

  // 顶部关闭键按压
  @State private closePressed: boolean = false;
  // 底部添加行按压
  @State private addPressed: boolean = false;
  // 逐项核查入口按压
  @State private reviewPressed: boolean = false;

  build() {
    Column() {
      // ---- 顶栏 ----
      this.buildTopBar()

      // ---- 全量装备列表 ----
      List({ space: 0 }) {
        ForEach(this.items, (item: ChecklistItem, index: number) => {
          ListItem() {
            ChecklistRow({
              item: item,
              rowHeight: 52,
              checkSize: 28,
              fontSize: FONT_SIZE_BODY_LARGE,
              onToggleCheck: this.onToggleCheck
            })
          }
          // 错落入场：淡入 + translateY，按 index 递延（review V2）
          .opacity(this.listAppeared ? 1 : 0)
          .translate({ y: this.listAppeared ? 0 : STAGGER_OFFSET_Y })
          .animation({ curve: SPRING_GENERAL(), delay: staggerDelay(index) })
        }, (item: ChecklistItem) => item.id + '_' + (item.checked ? '1' : '0'))

        // 底部虚线「+ 添加到{Zone}」行
        ListItem() {
          this.buildAddRow()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16, top: 8, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
  }

  // ---- 顶栏：× 关闭 + Zone 名 + 进度 + 逐项核查入口 ----
  @Builder
  private buildTopBar() {
    Column() {
      Row({ space: 12 }) {
        // 关闭键
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([TEXT_MAIN])
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(CARD_BG)
        .scale({ x: this.closePressed ? PRESS_SCALE_DOWN : 1.0, y: this.closePressed ? PRESS_SCALE_DOWN : 1.0 })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.closePressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.closePressed = false;
          }
        })
        .onClick(() => {
          this.onClose();
        })

        // Zone 色条 + 名称
        Row({ space: 8 }) {
          Row()
            .width(4)
            .height(20)
            .borderRadius(2)
            .backgroundColor(this.zoneColor)

          SymbolGlyph($r(zoneIconName(this.zone)))
            .fontSize(18)
            .fontColor([this.zoneColor])

          Text(zoneDisplayName(this.zone))
            .fontSize(FONT_SIZE_TITLE_MEDIUM)
            .fontWeight(FONT_WEIGHT_BOLD)
            .fontColor(TEXT_MAIN)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        // 该区进度
        Text(this.progress().checked.toString() + ' / ' + this.progress().total.toString())
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontWeight(FONT_WEIGHT_MEDIUM)
          .fontColor(TEXT_SECONDARY)
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)

      // 逐项核查本区入口（D-2），仅有内容时展示（Phase 4 接入前隐藏，见 REVIEW_ZONE_ENTRY_ENABLED）
      if (REVIEW_ZONE_ENTRY_ENABLED && this.items.length > 0) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(16)
            .fontColor([PRIMARY_COLOR])

          Text('逐项核查本区')
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontWeight(FONT_WEIGHT_MEDIUM)
            .fontColor(PRIMARY_COLOR)
        }
        .height(36)
        .padding({ left: 14, right: 14 })
        .borderRadius(18)
        .backgroundColor(CARD_BG)
        .alignItems(VerticalAlign.Center)
        .scale({ x: this.reviewPressed ? PRESS_SCALE_DOWN : 1.0, y: this.reviewPressed ? PRESS_SCALE_DOWN : 1.0 })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.reviewPressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.reviewPressed = false;
          }
        })
        .onClick(() => {
          this.onReviewZone(this.zone);
        })
        .margin({ top: 4, bottom: 4 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  // ---- 底部虚线添加行 ----
  @Builder
  private buildAddRow() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(18)
        .fontColor([TEXT_TERTIARY])

      Text('添加到' + zoneDisplayName(this.zone))
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_TERTIARY)
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(CARD_RADIUS)
    .border({
      width: 1.5,
      color: DIVIDER_COLOR,
      style: BorderStyle.Dashed,
      radius: CARD_RADIUS
    })
    .margin({ top: 8 })
    .scale({ x: this.addPressed ? PRESS_SCALE_DOWN : 1.0, y: this.addPressed ? PRESS_SCALE_DOWN : 1.0 })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.addPressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.addPressed = false;
      }
    })
    .onClick(() => {
      this.onTapEmpty(this.zone);
    })
  }

  private progress(): LoadoutProgress {
    return calcProgress(this.items);
  }
}
