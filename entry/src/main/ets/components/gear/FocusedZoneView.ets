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
  DIVIDER_COLOR,
  INPUT_BG
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
import { ChecklistItem, GearItem } from '../../models/PackModels';
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
  // 问题4c：装备库全量，用于 fromGearId 反查品类/备注/品牌等详情
  @Prop gears: GearItem[] = [];
  @Prop zoneColor: string = TEXT_SECONDARY;

  // 是否处于激活（聚焦）态：由父传入 focusedZone != null。
  // false→true 时触发列表错落入场（review V2；FocusedZoneView 常驻树，不能用 aboutToAppear）
  @Prop @Watch('onActiveChange') active: boolean = false;

  // callbacks
  onClose: () => void = () => {};
  onTapEmpty: (zone: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  onReviewZone: (zone: string) => void = () => {};
  // 问题4d：长按菜单「编辑」「从本次行程移除」
  onEditItem: (item: ChecklistItem) => void = () => {};
  onRemoveItem: (itemId: string) => void = () => {};
  // 问题4d：长按转拖拽落点移动装备到目标 Zone
  onMoveItemToZone: (itemId: string, zone: string) => void = () => {};

  // 列表错落入场控制（0 = 未入场，1 = 已就位）
  @State private listAppeared: boolean = false;
  // 问题4c：当前手风琴展开详情的装备 id（null = 全部收起）。单击装备名 toggle，点别行自动收起当前行。
  @State private expandedItemId: string | null = null;

  // active false→true：重置后下一帧验入场；true→false：重置供下次重放
  onActiveChange(): void {
    if (this.active) {
      this.listAppeared = false;
      // 问题4c：每次进入聚焦重置展开态，避免残留上次的展开行
      this.expandedItemId = null;
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.listAppeared = true;
      });
    } else {
      this.listAppeared = false;
      this.expandedItemId = null;
    }
  }

  // 问题4c：单击装备名 toggle 该行详情展开（手风琴：点别行自动收起当前行）
  private toggleExpand(itemId: string): void {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.expandedItemId = (this.expandedItemId === itemId) ? null : itemId;
    });
  }

  // 问题4c：按 fromGearId 反查装备库详情（品类/备注/品牌）。临时装备无 fromGearId 则返回 undefined。
  private gearForItem(item: ChecklistItem): GearItem | undefined {
    if (item.fromGearId === undefined || item.fromGearId.length === 0) {
      return undefined;
    }
    return this.gears.find((g: GearItem) => g.id === item.fromGearId);
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
            Column({ space: 0 }) {
              // 问题4c：双热区——点 check 圆圈勾选，点装备名/行其余区 toggle 详情展开
              ChecklistRow({
                item: item,
                rowHeight: 52,
                checkSize: 28,
                fontSize: FONT_SIZE_BODY_LARGE,
                checkOnlyHotzone: true,
                onToggleCheck: this.onToggleCheck,
                onTapRow: () => { this.toggleExpand(item.id); }
              })

              // 问题4c：手风琴详情区（重量/品类/备注/品牌），Spring 高度 + 透明度
              if (this.expandedItemId === item.id) {
                this.buildItemDetail(item)
              }
            }
            .width('100%')
          }
          // 错落入场：淡入 + translateY，按 index 递延（review V2）
          .opacity(this.listAppeared ? 1 : 0)
          .translate({ y: this.listAppeared ? 0 : STAGGER_OFFSET_Y })
          .animation({ curve: SPRING_GENERAL(), delay: staggerDelay(index) })
        }, (item: ChecklistItem) => item.id + '_' + (item.checked ? '1' : '0') + '_' + (this.expandedItemId === item.id ? 'e' : 'c'))

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
    // 问题4b：点任意非装备行/非 check 的空白处收起聚焦。
    //   ArkUI 事件机制：装备行 ChecklistRow、check 圆圈、底部添加行、顶栏关闭键各自绑 onClick 会消费事件不冒泡，
    //   因此只有点到「行之间空隙 / 列表底部留白 / 顶栏空白」才会冒泡到此根 Column 触发收起。
    .onClick(() => {
      this.onClose();
    })
    // 问题4b：左右划任一方向收起聚焦回网格（无需返回按钮）。
    //   水平 PanGesture，划动超阈值即触发；fingers=1 避免与列表纵向滚动冲突。
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd(() => {
          this.onClose();
        })
    )
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

  // ---- 问题4c：装备详情手风琴展开区 ----
  // 数据优先取 ChecklistItem 自身（weight），缺失字段经 fromGearId 反查 GearItem（category/brand/note）。
  // 临时装备（无 fromGearId）只展示已有字段；全空时显示占位「暂无更多信息」。
  @Builder
  private buildItemDetail(item: ChecklistItem) {
    Column({ space: 8 }) {
      // 品类 + 重量 + 品牌：一行 chips
      Flex({ wrap: FlexWrap.Wrap }) {
        if (this.detailCategory(item).length > 0) {
          this.buildDetailChip('品类', this.detailCategory(item))
        }
        if (this.detailWeight(item).length > 0) {
          this.buildDetailChip('重量', this.detailWeight(item))
        }
        if (this.detailBrand(item).length > 0) {
          this.buildDetailChip('品牌', this.detailBrand(item))
        }
      }
      .width('100%')

      // 备注：整段文字
      if (this.detailNote(item).length > 0) {
        Text(this.detailNote(item))
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
      }

      // 全空占位
      if (!this.hasAnyDetail(item)) {
        Text('暂无更多信息')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_TERTIARY)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 50, right: 16, top: 4, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildDetailChip(label: string, value: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_MAIN)
    }
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .borderRadius(8)
    .backgroundColor(INPUT_BG)
    .margin({ right: 8, bottom: 8 })
  }

  private detailCategory(item: ChecklistItem): string {
    const gear = this.gearForItem(item);
    if (gear !== undefined && gear.category.length > 0) {
      return gear.category;
    }
    return '';
  }

  private detailWeight(item: ChecklistItem): string {
    let w: number | undefined = item.weight;
    if (w === undefined) {
      const gear = this.gearForItem(item);
      w = gear !== undefined ? gear.weight : undefined;
    }
    return (w !== undefined && w > 0) ? (w.toString() + 'g') : '';
  }

  private detailBrand(item: ChecklistItem): string {
    const gear = this.gearForItem(item);
    if (gear !== undefined && gear.brand !== undefined && gear.brand.length > 0) {
      return gear.brand;
    }
    return '';
  }

  private detailNote(item: ChecklistItem): string {
    const gear = this.gearForItem(item);
    if (gear !== undefined && gear.note !== undefined && gear.note.length > 0) {
      return gear.note;
    }
    return '';
  }

  private hasAnyDetail(item: ChecklistItem): boolean {
    return this.detailCategory(item).length > 0
      || this.detailWeight(item).length > 0
      || this.detailBrand(item).length > 0
      || this.detailNote(item).length > 0;
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
