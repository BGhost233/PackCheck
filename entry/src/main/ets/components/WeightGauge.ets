import { curves } from '@kit.ArkUI';
import {
  CARD_BG,
  DANGER_COLOR,
  DIVIDER_COLOR,
  LIGHT_PRIMARY_COLOR,
  PRICE_COLOR,
  PRIMARY_COLOR,
  SMALL_CARD_RADIUS,
  TEXT_MAIN,
  TEXT_TERTIARY
} from '../constants/DesignTokens';
import {
  SPRING_PRESS,
  SPRING_GENERAL,
  DURATION_FAST,
  DURATION_NORMAL,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  STAGGER_OFFSET_Y
} from '../constants/AnimationTokens';

enum GaugeMode {
  WEIGHT,
  PRICE
}

@Component
export struct WeightGauge {
  @Prop currentWeight: number = 0;
  @Prop targetWeight: number = 10000;
  @Prop gearCount: number = 0;
  @Prop totalPrice: number = 0;
  @Prop budget: number = 0;

  @State private gaugeMode: GaugeMode = GaugeMode.WEIGHT;
  @State private displayWeight: number = 0;
  @State private displayGearCount: number = 0;
  @State private displayTotalPrice: number = 0;
  @State private counterAnimated: boolean = false;
  @State private ringBounceScale: number = 1.0;
  @State private gearCountPopScale: number = 1.0;
  @State private ringEntranceScale: number = 0;
  @State private pillEntranceIndices: boolean[] = [false, false, false];

  aboutToAppear(): void {
    this.displayWeight = 0;
    this.displayGearCount = 0;
    this.displayTotalPrice = 0;
    this.counterAnimated = false;
    this.ringEntranceScale = 0;
    this.pillEntranceIndices = [false, false, false];
  }

  private getDisplayWeight(): number {
    return this.counterAnimated ? this.currentWeight : this.displayWeight;
  }

  private getDisplayGearCount(): number {
    return this.counterAnimated ? this.gearCount : this.displayGearCount;
  }

  private getDisplayTotalPrice(): number {
    return this.counterAnimated ? this.totalPrice : this.displayTotalPrice;
  }

  private startCounterAnimation(): void {
    this.getUIContext().animateTo({
      duration: 800,
      curve: Curve.EaseOut,
      onFinish: (): void => {
        this.counterAnimated = true;
      }
    }, (): void => {
      this.displayWeight = this.currentWeight;
      this.displayGearCount = this.gearCount;
      this.displayTotalPrice = this.totalPrice;
    });
  }

  private gaugeColor(): string {
    return this.gaugeMode === GaugeMode.WEIGHT ? PRIMARY_COLOR : PRICE_COLOR;
  }

  private ratioValue(): number {
    if (this.gaugeMode === GaugeMode.PRICE) {
      if (this.budget <= 0) {
        return 0;
      }
      return Math.min(this.totalPrice, this.budget);
    }
    if (this.targetWeight <= 0) {
      return 0;
    }
    return Math.min(this.currentWeight, this.targetWeight);
  }

  private ratioTotal(): number {
    if (this.gaugeMode === GaugeMode.PRICE) {
      return this.budget <= 0 ? 1 : Math.max(this.budget, this.totalPrice);
    }
    return this.targetWeight <= 0 ? 1 : Math.max(this.targetWeight, this.currentWeight);
  }

  private isOverTarget(): boolean {
    if (this.gaugeMode === GaugeMode.PRICE) {
      return this.budget > 0 && this.totalPrice > this.budget;
    }
    return this.currentWeight > this.targetWeight;
  }

  private formatKg(weight: number): string {
    if (weight <= 0) {
      return '0kg';
    }
    return (Math.round(weight / 100) / 10).toString() + 'kg';
  }

  private toggleGaugeMode(): void {
    this.ringBounceScale = 0.92;
    this.getUIContext().animateTo({
      duration: 50,
      curve: SPRING_PRESS()
    }, () => {
      this.ringBounceScale = 1.08;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 400,
        curve: SPRING_GENERAL()
      }, () => {
        this.ringBounceScale = 1.0;
      });
    }, 50);

    this.gaugeMode = this.gaugeMode === GaugeMode.WEIGHT ? GaugeMode.PRICE : GaugeMode.WEIGHT;
    this.counterAnimated = false;
    this.startCounterAnimation();
  }

  private onStatPillClick(label: string): void {
    if (label === '总价') {
      if (this.gaugeMode !== GaugeMode.PRICE) {
        this.toggleGaugeMode();
      }
    } else if (label === '重量') {
      if (this.gaugeMode !== GaugeMode.WEIGHT) {
        this.toggleGaugeMode();
      }
    } else if (label === '件数') {
      this.gearCountPopScale = 1.25;
      this.getUIContext().animateTo({
        duration: 400,
        curve: SPRING_GENERAL()
      }, () => {
        this.gearCountPopScale = 1.0;
      });
    }
  }

  build() {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 132, height: 132 })
          .fill('#00000000')
          .stroke(DIVIDER_COLOR)
          .strokeWidth(10)
        Progress({
          value: this.ratioValue(),
          total: this.ratioTotal(),
          type: ProgressType.Ring
        })
          .width(132)
          .height(132)
          .color(this.isOverTarget() ? DANGER_COLOR : this.gaugeColor())
          .style({ strokeWidth: 10, enableSmoothEffect: true })
          .animation({ duration: 600, curve: SPRING_GENERAL() })
        Column({ space: 2 }) {
          if (this.gaugeMode === GaugeMode.WEIGHT) {
            Text(this.formatKg(this.getDisplayWeight()))
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isOverTarget() ? DANGER_COLOR : this.gaugeColor())
            Text(this.isOverTarget() ? '超出目标' : '当前总重')
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          } else {
            Text('¥' + this.getDisplayTotalPrice().toString())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isOverTarget() ? DANGER_COLOR : this.gaugeColor())
            Text(this.isOverTarget() ? '超出预算' : '当前总价')
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(148)
      .height(148)
      .scale({
        x: this.ringBounceScale * this.ringEntranceScale,
        y: this.ringBounceScale * this.ringEntranceScale
      })
      .animation({ duration: DURATION_FAST, curve: SPRING_PRESS() })
      .onClick(() => {
        this.toggleGaugeMode();
      })

      Row() {
        this.StatPill('件数', this.getDisplayGearCount().toString(), this.gearCountPopScale, 0);
        this.StatPill('总价', '¥' + this.getDisplayTotalPrice().toString(), 1.0, 1);
        this.StatPill('重量', this.formatKg(this.currentWeight), 1.0, 2);
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .backgroundColor(CARD_BG)
    .borderRadius(20)
    .shadow({ radius: 12, color: '#0A000000', offsetX: 0, offsetY: 2 })
    .onAppear((): void => {
      this.startCounterAnimation();
      this.getUIContext().animateTo({
        duration: 600,
        curve: SPRING_GENERAL()
      }, () => {
        this.ringEntranceScale = 1.0;
      });
      setTimeout(() => {
        const indices = this.pillEntranceIndices;
        indices[0] = true;
        this.pillEntranceIndices = indices;
      }, 50);
      setTimeout(() => {
        const indices = this.pillEntranceIndices;
        indices[1] = true;
        this.pillEntranceIndices = indices;
      }, 130);
      setTimeout(() => {
        const indices = this.pillEntranceIndices;
        indices[2] = true;
        this.pillEntranceIndices = indices;
      }, 210);
    })
  }

  @Builder
  private StatPill(label: string, value: string, popScale: number, staggerIndex: number) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(11)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .scale({ x: label === '件数' ? popScale : 1.0, y: label === '件数' ? popScale : 1.0 })
        .animation({ duration: 400, curve: SPRING_GENERAL() })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(LIGHT_PRIMARY_COLOR)
    .borderRadius(SMALL_CARD_RADIUS)
    .margin({ left: 4, right: 4 })
    .opacity(this.pillEntranceIndices[staggerIndex] ? 1 : 0)
    .translate({ y: this.pillEntranceIndices[staggerIndex] ? 0 : STAGGER_OFFSET_Y })
    .animation({ duration: DURATION_NORMAL, curve: SPRING_GENERAL() })
    .scale({ x: PRESS_SCALE_REST, y: PRESS_SCALE_REST })
    .onClick(() => {
      this.onStatPillClick(label);
    })
  }
}
