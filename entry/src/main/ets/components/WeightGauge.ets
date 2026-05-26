import { curves } from '@kit.ArkUI';
import {
  CARD_BG,
  DANGER_COLOR,
  DIVIDER_COLOR,
  LIGHT_PRIMARY_COLOR,
  PRIMARY_COLOR,
  SMALL_CARD_RADIUS,
  TEXT_MAIN,
  TEXT_TERTIARY
} from '../constants/DesignTokens';

@Component
export struct WeightGauge {
  @Prop currentWeight: number = 0;
  @Prop targetWeight: number = 10000;
  @Prop gearCount: number = 0;
  @Prop totalPrice: number = 0;

  onEditTargetWeight: () => void = (): void => {};

  @State private displayWeight: number = 0;
  @State private displayGearCount: number = 0;
  @State private displayTotalPrice: number = 0;
  @State private counterAnimated: boolean = false;

  aboutToAppear(): void {
    this.displayWeight = 0;
    this.displayGearCount = 0;
    this.displayTotalPrice = 0;
    this.counterAnimated = false;
  }

  private getDisplayWeight(): number {
    return this.counterAnimated ? this.currentWeight : this.displayWeight;
  }

  private getDisplayGearCount(): string {
    return (this.counterAnimated ? this.gearCount : this.displayGearCount).toString();
  }

  private getDisplayTotalPrice(): string {
    return '¥' + (this.counterAnimated ? this.totalPrice : this.displayTotalPrice).toString();
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

  private ratioValue(): number {
    if (this.targetWeight <= 0) {
      return 0;
    }
    return Math.min(this.currentWeight, this.targetWeight);
  }

  private isOverTarget(): boolean {
    return this.currentWeight > this.targetWeight;
  }

  private formatKg(weight: number): string {
    if (weight <= 0) {
      return '0kg';
    }
    return (Math.round(weight / 100) / 10).toString() + 'kg';
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
          total: this.targetWeight,
          type: ProgressType.Ring
        })
          .width(132)
          .height(132)
          .color(this.isOverTarget() ? DANGER_COLOR : PRIMARY_COLOR)
          .style({ strokeWidth: 10, enableSmoothEffect: true })
        Column({ space: 2 }) {
          Text(this.formatKg(this.getDisplayWeight()))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isOverTarget() ? DANGER_COLOR : PRIMARY_COLOR)
          Text(this.isOverTarget() ? '超出目标' : '当前总重')
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(148)
      .height(148)

      Text(this.isOverTarget()
        ? '目标 ' + this.formatKg(this.targetWeight) + ' · 超出 ' + this.formatKg(this.currentWeight - this.targetWeight)
        : '目标 ' + this.formatKg(this.targetWeight))
        .fontSize(12)
        .fontColor(this.isOverTarget() ? DANGER_COLOR : TEXT_TERTIARY)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(12)
        .onClick(() => {
          this.onEditTargetWeight();
        })

      Row() {
        this.StatPill('件数', this.getDisplayGearCount());
        this.StatPill('总价', this.getDisplayTotalPrice());
        this.StatPill('重量', this.formatKg(this.currentWeight));
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
    })
  }

  @Builder
  private StatPill(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(11)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(LIGHT_PRIMARY_COLOR)
    .borderRadius(SMALL_CARD_RADIUS)
    .margin({ left: 4, right: 4 })
  }
}
