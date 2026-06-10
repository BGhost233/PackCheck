// 配装视图 - 顶部进度条
// 职责：显示 已装包 N/M + 横条进度 + 100% 庆祝动画

import {
  PRIMARY_COLOR,
  LIGHT_PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  PROGRESS_INACTIVE
} from '../../constants/Colors';
import { SPRING_GENERAL, SPRING_PRESS, DURATION_COUNTER } from '../../constants/AnimationTokens';

@Component
export struct LoadoutProgressBar {
  @Prop @Watch('onCheckedChange') checked: number = 0;
  @Prop total: number = 0;

  @State private displayChecked: number = 0;
  @State private celebrateScale: number = 1.0;
  @State private barWidth: number = 0;
  private counterTimerId: number = -1;

  aboutToAppear(): void {
    this.displayChecked = this.checked;
  }

  aboutToDisappear(): void {
    // 组件销毁时清除 setInterval，防止僵尸 timer
    if (this.counterTimerId >= 0) {
      clearInterval(this.counterTimerId);
      this.counterTimerId = -1;
    }
  }

  // 监听 checked 变化驱动 counter 动画
  // 无条件启动新动画（旧动画在 animateCounter 头部 clearInterval 取消）
  // 解决快速双击时 displayChecked 卡在中间值的问题
  onCheckedChange(): void {
    this.animateCounter(this.displayChecked, this.checked);
  }

  build() {
    Column({ space: 6 }) {
      // 文案行
      Row() {
        Text(this.isComplete() ? '准备出发' : '已装包')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isComplete() ? PRIMARY_COLOR : TEXT_MAIN)
        Text(' ' + this.displayChecked.toString() + '/' + this.total.toString())
          .fontSize(13)
          .fontColor(this.isComplete() ? PRIMARY_COLOR : TEXT_SECONDARY)
        Blank()
        if (this.total > 0) {
          Text(Math.round(this.percentage()).toString() + '%')
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
        }
      }
      .width('100%')

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        // 底层（灰色轨道）
        Row()
          .width('100%')
          .height(4)
          .borderRadius(2)
          .backgroundColor(LIGHT_PRIMARY_COLOR)

        // 前景（进度）
        Row()
          .width(this.progressBarWidth())
          .height(4)
          .borderRadius(2)
          .backgroundColor(this.isComplete() ? PRIMARY_COLOR : PROGRESS_INACTIVE)
          .animation({ curve: SPRING_GENERAL() })
      }
      .width('100%')
      .height(4)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .scale({ x: this.celebrateScale, y: this.celebrateScale })
    .animation({ curve: SPRING_PRESS() })
    .onAppear(() => {
      this.onCheckedChange();
    })
  }

  private isComplete(): boolean {
    return this.total > 0 && this.checked >= this.total;
  }

  private percentage(): number {
    if (this.total === 0) {
      return 0;
    }
    return (this.checked / this.total) * 100;
  }

  private progressBarWidth(): string {
    if (this.total === 0) {
      return '0%';
    }
    const pct = Math.min(100, Math.round((this.checked / this.total) * 100));
    return pct.toString() + '%';
  }

  private animateCounter(from: number, to: number): void {
    // 取消上一轮动画（并发防护）
    if (this.counterTimerId >= 0) {
      clearInterval(this.counterTimerId);
      this.counterTimerId = -1;
    }
    const startTime = Date.now();
    const duration = DURATION_COUNTER;
    const diff = to - from;

    this.counterTimerId = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(1.0, elapsed / duration);
      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      this.displayChecked = Math.round(from + diff * eased);

      if (progress >= 1.0) {
        clearInterval(this.counterTimerId);
        this.counterTimerId = -1;
        this.displayChecked = to;
        // 100% 庆祝弹动
        if (this.isComplete()) {
          this.celebrateScale = 1.04;
          setTimeout(() => {
            this.celebrateScale = 1.0;
          }, 200);
        }
      }
    }, 16);
  }
}
