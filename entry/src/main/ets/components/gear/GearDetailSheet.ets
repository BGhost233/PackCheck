// 装备详情底部半屏 Sheet
// 职责：点击聚焦态装备行后弹出，展示装备详情（品类/重量/品牌/备注）+ 编辑入口
// 替代原 FocusedZoneView 中的手风琴展开，提供更大展示空间和编辑能力
// 动效：Spring 升起/收回 + 蒙层淡入淡出 + 内部错落入场 + 下拉手势关闭
// spec: task_plan §2.2

import {
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  DIVIDER_COLOR,
  INPUT_BG,
  PRIMARY_COLOR,
  OVERLAY_MASK_LIGHT
} from '../../constants/Colors';
import {
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION,
  FONT_WEIGHT_MEDIUM
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  SPRING_GENERAL,
  SPRING_PANEL_ENTER,
  SPRING_PANEL_EXIT,
  STAGGER_OFFSET_Y
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem } from '../../models/PackModels';
import { vibrator } from '@kit.SensorServiceKit';
import { resolveItemName } from '../../services/ChecklistService';

// Sheet 高度占屏幕比例
const SHEET_HEIGHT_RATIO: number = 0.55;
// 下拉关闭阈值
const DISMISS_VELOCITY: number = 800;
const DISMISS_OFFSET: number = 120;

@Component
export struct GearDetailSheet {
  // 要展示的 checklist item
  @Prop item: ChecklistItem | null = null;
  // 装备库全量（用于 fromGearId 反查详情）
  @Prop gears: GearItem[] = [];
  // 是否显示
  @Prop @Watch('onVisibleChange') visible: boolean = false;

  // 回调
  onClose: () => void = () => {};
  onEditGear: (gearId: string) => void = () => {};
  onRemoveItem: (itemId: string) => void = () => {};

  // 内部状态
  @State private sheetTranslateY: number = 1000; // 初始在屏幕外
  @State private maskOpacity: number = 0;
  @State private contentAppeared: boolean = false;
  // 下拉手势
  @State private panOffsetY: number = 0;
  // 编辑按钮按压
  @State private editBtnPressed: boolean = false;
  @State private removeBtnPressed: boolean = false;

  onVisibleChange(): void {
    if (this.visible) {
      this.show();
    } else {
      this.hide();
    }
  }

  private show(): void {
    this.contentAppeared = false;
    this.panOffsetY = 0;
    // 升起动画
    this.getUIContext().animateTo({ curve: SPRING_PANEL_ENTER() }, () => {
      this.sheetTranslateY = 0;
      this.maskOpacity = 1;
    });
    // 内容错落入场（延迟 150ms）
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.contentAppeared = true;
      });
    }, 150);
  }

  private hide(): void {
    this.getUIContext().animateTo({ curve: SPRING_PANEL_EXIT() }, () => {
      this.sheetTranslateY = 1000;
      this.maskOpacity = 0;
      this.contentAppeared = false;
    });
  }

  private dismiss(): void {
    this.onClose();
  }

  private resolveGear(): GearItem | undefined {
    if (this.item === null) {
      return undefined;
    }
    const fromId = this.item.fromGearId;
    if (fromId === undefined || fromId.length === 0) {
      return undefined;
    }
    return this.gears.find((g: GearItem) => g.id === fromId);
  }

  private getDisplayName(): string {
    if (this.item === null) {
      return '';
    }
    return resolveItemName(this.item, this.gears);
  }

  private getCategory(): string {
    const gear = this.resolveGear();
    if (gear !== undefined && gear.category.length > 0) {
      return gear.category;
    }
    return '';
  }

  private getWeight(): string {
    if (this.item === null) {
      return '';
    }
    let w: number | undefined = this.item.weight;
    if (w === undefined) {
      const gear = this.resolveGear();
      w = gear !== undefined ? gear.weight : undefined;
    }
    return (w !== undefined && w > 0) ? (w.toString() + 'g') : '';
  }

  private getBrand(): string {
    const gear = this.resolveGear();
    if (gear !== undefined && gear.brand !== undefined && gear.brand.length > 0) {
      return gear.brand;
    }
    return '';
  }

  private getNote(): string {
    const gear = this.resolveGear();
    if (gear !== undefined && gear.note !== undefined && gear.note.length > 0) {
      return gear.note;
    }
    return '';
  }

  build() {
    Stack() {
      // 蒙层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OVERLAY_MASK_LIGHT)
        .opacity(this.maskOpacity)
        .onClick(() => {
          this.dismiss();
        })

      // Sheet 主体
      Column({ space: 0 }) {
        // 拖拽条
        Row() {
          Row()
            .width(36)
            .height(4)
            .borderRadius(2)
            .backgroundColor(DIVIDER_COLOR)
        }
        .width('100%')
        .height(20)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        // 内容区
        Column({ space: 16 }) {
          // 装备名称
          Text(this.getDisplayName())
            .fontSize(FONT_SIZE_TITLE_MEDIUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .width('100%')
            .opacity(this.contentAppeared ? 1 : 0)
            .translate({ y: this.contentAppeared ? 0 : STAGGER_OFFSET_Y })
            .animation({ curve: SPRING_GENERAL(), delay: 0 })

          // 属性 chips 行
          if (this.getCategory().length > 0 || this.getWeight().length > 0 || this.getBrand().length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              if (this.getCategory().length > 0) {
                this.buildChip('品类', this.getCategory())
              }
              if (this.getWeight().length > 0) {
                this.buildChip('重量', this.getWeight())
              }
              if (this.getBrand().length > 0) {
                this.buildChip('品牌', this.getBrand())
              }
            }
            .width('100%')
            .opacity(this.contentAppeared ? 1 : 0)
            .translate({ y: this.contentAppeared ? 0 : STAGGER_OFFSET_Y })
            .animation({ curve: SPRING_GENERAL(), delay: 50 })
          }

          // 备注区
          if (this.getNote().length > 0) {
            Column({ space: 4 }) {
              Text('备注')
                .fontSize(FONT_SIZE_CAPTION)
                .fontColor(TEXT_TERTIARY)
              Text(this.getNote())
                .fontSize(FONT_SIZE_BODY_MEDIUM)
                .fontColor(TEXT_SECONDARY)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .opacity(this.contentAppeared ? 1 : 0)
            .translate({ y: this.contentAppeared ? 0 : STAGGER_OFFSET_Y })
            .animation({ curve: SPRING_GENERAL(), delay: 100 })
          }

          // 无详情占位
          if (this.getCategory().length === 0 && this.getWeight().length === 0
            && this.getBrand().length === 0 && this.getNote().length === 0) {
            Text('暂无更多信息')
              .fontSize(FONT_SIZE_BODY_MEDIUM)
              .fontColor(TEXT_TERTIARY)
              .width('100%')
              .opacity(this.contentAppeared ? 1 : 0)
              .translate({ y: this.contentAppeared ? 0 : STAGGER_OFFSET_Y })
              .animation({ curve: SPRING_GENERAL(), delay: 50 })
          }

          // 分隔线
          Divider()
            .width('100%')
            .color(DIVIDER_COLOR)
            .opacity(this.contentAppeared ? 1 : 0)
            .animation({ curve: SPRING_GENERAL(), delay: 120 })

          // 操作按钮行
          Row({ space: 12 }) {
            // 编辑按钮
            Button('编辑装备')
              .type(ButtonType.Normal)
              .fontSize(FONT_SIZE_BODY_MEDIUM)
              .fontWeight(FONT_WEIGHT_MEDIUM)
              .fontColor(Color.White)
              .backgroundColor(PRIMARY_COLOR)
              .borderRadius(CARD_RADIUS)
              .height(44)
              .layoutWeight(1)
              .scale({
                x: this.editBtnPressed ? PRESS_SCALE_DOWN : 1.0,
                y: this.editBtnPressed ? PRESS_SCALE_DOWN : 1.0
              })
              .animation({ curve: SPRING_PRESS() })
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.editBtnPressed = true;
                } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  this.editBtnPressed = false;
                }
              })
              .onClick(() => {
                const gear = this.resolveGear();
                if (gear !== undefined) {
                  this.onEditGear(gear.id);
                }
              })

            // 移除按钮
            Button('移除')
              .type(ButtonType.Normal)
              .fontSize(FONT_SIZE_BODY_MEDIUM)
              .fontWeight(FONT_WEIGHT_MEDIUM)
              .fontColor(TEXT_SECONDARY)
              .backgroundColor(INPUT_BG)
              .borderRadius(CARD_RADIUS)
              .height(44)
              .width(80)
              .scale({
                x: this.removeBtnPressed ? PRESS_SCALE_DOWN : 1.0,
                y: this.removeBtnPressed ? PRESS_SCALE_DOWN : 1.0
              })
              .animation({ curve: SPRING_PRESS() })
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.removeBtnPressed = true;
                } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  this.removeBtnPressed = false;
                }
              })
              .onClick(() => {
                if (this.item !== null) {
                  this.triggerHaptic();
                  this.onRemoveItem(this.item.id);
                  this.dismiss();
                }
              })
          }
          .width('100%')
          .opacity(this.contentAppeared ? 1 : 0)
          .translate({ y: this.contentAppeared ? 0 : STAGGER_OFFSET_Y })
          .animation({ curve: SPRING_GENERAL(), delay: 150 })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 8, bottom: 34 })
      }
      .width('100%')
      .height(SHEET_HEIGHT_RATIO * 100 + '%')
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .translate({ y: this.sheetTranslateY + this.panOffsetY })
      .gesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 5 })
          .onActionUpdate((event: GestureEvent) => {
            // 只允许下拉（正值），上拉时阻尼
            if (event.offsetY > 0) {
              this.panOffsetY = event.offsetY;
            } else {
              this.panOffsetY = event.offsetY * 0.2; // 上拉阻尼
            }
          })
          .onActionEnd((event: GestureEvent) => {
            const velocity = event.velocity;
            if (velocity > DISMISS_VELOCITY || this.panOffsetY > DISMISS_OFFSET) {
              // 达到关闭阈值
              this.panOffsetY = 0;
              this.dismiss();
            } else {
              // 弹回
              this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
                this.panOffsetY = 0;
              });
            }
          })
      )
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
    .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.None)
    .opacity(this.visible ? 1 : 0)
  }

  @Builder
  private buildChip(label: string, value: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_MAIN)
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .borderRadius(8)
    .backgroundColor(INPUT_BG)
    .margin({ right: 8, bottom: 8 })
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: 'haptic.effect.soft', count: 1 },
        { usage: 'touch' }
      );
    } catch (_e) {
      // 振动不可用时静默降级
    }
  }
}
