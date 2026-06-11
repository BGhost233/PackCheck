// 统一清单视图 - 全屏聚焦单格子视图
// 职责：点击网格格子标题后，该 Zone 从网格位置 geometryTransition 放大铺满全屏
// 顶栏（× 关闭 + Zone 名 + 该区进度 + 逐项核查入口）+ 全量装备列表（ChecklistRow 52vp）+ 底部虚线添加行
// 与网格态格子共用 geometryTransition('zone_' + zone) id 完成共享元素转场（F-3：两端节点全程存在）
// spec §2.2 / §4.5.6
// Phase 3：聚焦布局 + 共享元素转场 + 核查复用
// 问题4b：点空白处 / 左右划收起聚焦回网格（无返回按钮）
// 问题4c：单击装备名手风琴原地展开详情（品类/重量/品牌/备注，经 fromGearId 反查）
// 长按菜单 + 长按转拖拽跨 Zone（问题4d）留 Phase 4，回调已预埋透传到位

import {
  CARD_BG,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  DIVIDER_COLOR,
  INPUT_BG,
  ZONE_MISC_STROKE,
  ZONE_MISC_TINT
} from '../../constants/Colors';
import {
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_MEDIUM
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
import { vibrator } from '@kit.SensorServiceKit';
import { zoneDisplayName, calcProgress, LoadoutProgress } from '../../services/LoadoutService';
import { ChecklistRow } from './ChecklistRow';
import { ZoneShell } from './ZoneShell';

@Component
export struct FocusedZoneView {
  @Prop zone: string = BodyZone.Misc;
  @Prop items: ChecklistItem[] = [];
  // 问题4c：装备库全量，用于 fromGearId 反查品类/备注/品牌等详情
  @Prop gears: GearItem[] = [];
  @Prop zoneColor: string = TEXT_SECONDARY;
  // D-2：ZoneShell 外壳需要的描边色 + 标题行浅染底，由父层透传（与网格态用同一 helper）
  @Prop zoneStroke: string = ZONE_MISC_STROKE;
  @Prop zoneTint: string = ZONE_MISC_TINT;

  // 是否处于激活（聚焦）态：由父传入 focusedZone != null。
  // false→true 时触发列表错落入场（review V2；FocusedZoneView 常驻树，不能用 aboutToAppear）
  @Prop @Watch('onActiveChange') active: boolean = false;

  // callbacks
  onClose: () => void = () => {};
  onTapEmpty: (zone: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  onReviewZone: (zone: string) => void = () => {};
  // Phase 4：长按菜单回调
  onEditItem: (item: ChecklistItem) => void = () => {};
  onRemoveItem: (itemId: string) => void = () => {};
  // 长按转拖拽落点：移动装备到目标 Zone（改 group）
  onMoveItemToZone: (itemId: string, zone: string) => void = () => {};
  // Phase 4：长按 item 触发浮层（通知父层弹自绘浮层）
  onLongPressItem: (item: ChecklistItem) => void = () => {};

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

  build() {
    // D-2：聚焦态 = 卡片浮层（不再铺满）。外壳用 ZoneShell（与网格态共用），
    //   保证 geometryTransition 两端外壳结构 100% 一致，转场是「同一边框连续放大」。
    //   宽度由父层 buildFocusedLayer 留边距约束，高度自适应封顶（卡内 List 滚动）。
    ZoneShell({
      zone: this.zone,
      zoneColor: this.zoneColor,
      zoneStroke: this.zoneStroke,
      zoneTint: this.zoneTint,
      // 聚焦态标题行宽松尺寸（区别于网格态紧凑）
      titleBarHeight: 44,
      iconSize: 18,
      barHeight: 20,
      titleFontSize: FONT_SIZE_TITLE_MEDIUM,
      // 顶栏整条不响应点击（关闭键 / 内容各自处理）
      titleClickable: false,
      contentClickable: false,
      titleTrailing: () => { this.buildTopTrailing() },
      content: () => { this.buildContent() }
    })
    // 问题4b：点卡片空白处（非装备行/非 check）收起聚焦。
    //   ChecklistRow / check / 添加行 / 关闭键各自 onClick 消费事件不冒泡，
    //   只有点到行间隙 / 列表底部留白 / 顶栏空白才冒泡到此触发收起。
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

  // ---- 卡片内容：全量装备列表 + 底部添加行 ----
  @Builder
  private buildContent() {
    List({ space: 0 }) {
      ForEach(this.items, (item: ChecklistItem, index: number) => {
        ListItem() {
          Column({ space: 0 }) {
            // Phase 4：Stack 手势层（底层）+ 内容行（顶层）
            // 手势层在下接收长按，内容行在上保证 CheckMark onClick 不被拦截
            Stack() {
              // ① 透明手势层（底层，接收长按手势）
              Image('')
                .width('100%')
                .height(52)
                .hitTestBehavior(HitTestMode.Block)
                .gesture(
                  LongPressGesture({ repeat: false, duration: 400 })
                    .onAction(() => {
                      this.handleLongPress(item);
                    })
                )

              // ② 内容行（顶层，CheckMark 点击正常触发）
              ChecklistRow({
                item: item,
                rowHeight: 52,
                checkSize: 28,
                fontSize: FONT_SIZE_BODY_LARGE,
                checkOnlyHotzone: true,
                onToggleCheck: this.onToggleCheck,
                onTapRow: () => { this.toggleExpand(item.id); }
              })
            }
            .width('100%')
            .height(52)

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
      }, (item: ChecklistItem) => item.id + '_' + (this.expandedItemId === item.id ? 'e' : 'c'))

      // 底部虚线「+ 添加到{Zone}」行
      ListItem() {
        this.buildAddRow()
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
  }

  // ---- 标题行右侧 trailing：进度 + × 关闭键 ----
  // D-2：聚焦态外壳 = ZoneShell，标题行左侧（色条+图标+名）由 ZoneShell 渲染，
  //   关闭键与进度统一收进 trailing 插槽，与网格态「数量 trailing」结构对位，保证两端外壳一致。
  @Builder
  private buildTopTrailing() {
    Row({ space: 10 }) {
      // 该区进度
      Text(this.progress().checked.toString() + ' / ' + this.progress().total.toString())
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_SECONDARY)

      // 关闭键
      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(16)
          .fontColor([TEXT_SECONDARY])
      }
      .width(28)
      .height(28)
      .borderRadius(14)
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
    }
    .alignItems(VerticalAlign.Center)
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

  // Phase 4：长按触发 —— 触觉反馈 + 通知父层弹浮层
  private handleLongPress(item: ChecklistItem): void {
    // 触觉反馈（轻档）
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: 'haptic.effect.soft', count: 1 },
        { usage: 'touch' }
      );
    } catch (e) {
      // 振动不可用时静默降级
    }
    // 通知父层弹出自绘浮层
    this.onLongPressItem(item);
  }

  private progress(): LoadoutProgress {
    return calcProgress(this.items);
  }
}
