import { curves } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import {
  CARD_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../constants/DesignTokens';

@Component
export struct TripCeremonyCard {
  @Prop tripTitle: string = '';
  @Prop tripDate: string = '';

  onTitleChange: (value: string) => void = () => {};
  onDateChange: (value: string) => void = () => {};
  onFinish: () => void = () => {};
  onDismiss: () => void = () => {};

  // === 入场动画状态 ===
  @State private overlayOpacity: number = 0;
  @State private cardScale: number = 0.3;
  @State private cardRotateY: number = 180;
  @State private cardRotateZ: number = -8;
  @State private cardTranslateY: number = 60;
  @State private cardOpacity: number = 0;
  @State private shineX: number = -200;
  @State private contentStep: number = 0;
  @State private cardElevation: number = 0;

  // === 蓄力状态 ===
  @State private holdProgress: number = 0; // 0~1
  @State private isHolding: boolean = false;
  @State private isLaunched: boolean = false;
  @State private chargeScale: number = 1.0;
  @State private shakeX: number = 0;
  @State private btnText: string = '长按开启新旅途';

  // === 发射 ===
  @State private launchTranslateY: number = 0;
  @State private launchScale: number = 1.0;
  @State private launchOpacity: number = 1.0;

  // === 粒子 ===
  @State private showParticles: boolean = false;
  @State private particleProgress: number = 0;

  // === 背景模糊 ===
  @State private overlayBlur: number = 0;

  // 计时器引用
  private holdTimer: number = -1;
  private shakeTimer: number = -1;

  // 配置
  private readonly CHARGE_DURATION: number = 1200; // ms
  private readonly TICK: number = 16;

  aboutToAppear(): void {
    this.startEntrance();
  }

  aboutToDisappear(): void {
    this.cleanup();
  }

  private cleanup(): void {
    if (this.holdTimer !== -1) {
      clearInterval(this.holdTimer);
      this.holdTimer = -1;
    }
    if (this.shakeTimer !== -1) {
      clearInterval(this.shakeTimer);
      this.shakeTimer = -1;
    }
  }

  // ============================================================
  // 入场动画
  // ============================================================
  private startEntrance(): void {
    this.getUIContext().animateTo({
      duration: 300, curve: Curve.EaseOut
    }, () => {
      this.overlayOpacity = 0.6;
    });

    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 600,
        curve: curves.springMotion(0.35, 0.78)
      }, () => {
        this.cardScale = 1.0;
        this.cardRotateY = 0;
        this.cardRotateZ = 0;
        this.cardTranslateY = 0;
        this.cardOpacity = 1;
        this.cardElevation = 24;
      });
    }, 50);

    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 400, curve: Curve.EaseInOut
      }, () => {
        this.shineX = 350;
      });
    }, 550);

    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 1;
      });
    }, 750);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 2;
      });
    }, 830);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 3;
      });
    }, 910);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 4;
      });
    }, 990);
  }

  // ============================================================
  // 长按蓄力系统
  // ============================================================
  private onHoldStart(): void {
    if (this.tripTitle.trim().length === 0) {
      this.shakeEmpty();
      return;
    }
    if (this.isHolding || this.isLaunched) {
      return;
    }

    this.isHolding = true;
    this.vibratePreset('haptic.tick');

    const startTime = Date.now();
    this.holdTimer = setInterval(() => {
      if (!this.isHolding) return;

      const elapsed = Date.now() - startTime;
      this.holdProgress = Math.min(elapsed / this.CHARGE_DURATION, 1.0);

      // 三段递进缩放
      const p = this.holdProgress;
      if (p <= 0.4) {
        this.chargeScale = 1.0 - (p / 0.4) * 0.05; // 1.0 → 0.95
      } else if (p <= 0.75) {
        this.chargeScale = 0.95 - ((p - 0.4) / 0.35) * 0.07; // 0.95 → 0.88
      } else {
        this.chargeScale = 0.88 - ((p - 0.75) / 0.25) * 0.06; // 0.88 → 0.82
      }

      // 文案
      if (p < 0.5) {
        this.btnText = '长按开启新旅途';
      } else {
        this.btnText = '🚀 蓄力中...';
      }

      // 75% 里程碑触觉
      if (p >= 0.75 && p < 0.77) {
        this.vibratePreset('haptic.sharp.medium');
      }

      if (this.holdProgress >= 1.0) {
        this.cleanup();
        this.launch();
      }
    }, this.TICK) as number;

    // 启动抖动
    this.startShake();
  }

  private startShake(): void {
    let tick = 0;
    this.shakeTimer = setInterval(() => {
      if (!this.isHolding || this.isLaunched) return;
      tick++;

      const p = this.holdProgress;
      let amplitude: number;
      if (p < 0.4) {
        amplitude = 1.0;
      } else if (p < 0.75) {
        amplitude = 2.5;
      } else {
        amplitude = 4.5;
      }

      this.shakeX = Math.sin(tick * 0.8) * amplitude;
    }, 30) as number;
  }

  private onHoldEnd(): void {
    if (this.isLaunched) return;
    if (!this.isHolding) return;

    this.isHolding = false;
    this.cleanup();

    // Spring 弹回
    this.getUIContext().animateTo({
      duration: 400,
      curve: curves.springMotion(0.35, 0.78)
    }, () => {
      this.holdProgress = 0;
      this.chargeScale = 1.0;
      this.shakeX = 0;
      this.btnText = '长按开启新旅途';
    });
  }

  // ============================================================
  // 发射！
  // ============================================================
  private launch(): void {
    this.isLaunched = true;
    this.isHolding = false;
    this.shakeX = 0;
    this.btnText = '🚀';

    // 重击触觉
    this.vibratePreset('haptic.sharp.strong');

    // 数据先于动画
    this.onFinish();

    // Step 1: 回拉 (60ms)
    this.getUIContext().animateTo({
      duration: 60,
      curve: Curve.EaseIn
    }, () => {
      this.chargeScale = 0.76;
    });

    // Step 2: 弹射 (300ms)
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 300,
        curve: curves.springMotion(0.28, 0.72)
      }, () => {
        this.launchScale = 0.3;
        this.launchTranslateY = -1200;
        this.launchOpacity = 0;
      });

      // 粒子
      this.emitParticles();

      // 背景模糊加深再消散
      this.getUIContext().animateTo({
        duration: 150, curve: Curve.EaseIn
      }, () => {
        this.overlayBlur = 15;
        this.overlayOpacity = 0.85;
      });

      setTimeout(() => {
        this.getUIContext().animateTo({
          duration: 300, curve: Curve.EaseOut
        }, () => {
          this.overlayBlur = 0;
          this.overlayOpacity = 0;
        });
      }, 200);
    }, 70);
  }

  // ============================================================
  // 粒子
  // ============================================================
  private emitParticles(): void {
    this.showParticles = true;
    this.particleProgress = 0;
    this.getUIContext().animateTo({
      duration: 500,
      curve: Curve.EaseOut
    }, () => {
      this.particleProgress = 1;
    });
    setTimeout(() => {
      this.showParticles = false;
      this.particleProgress = 0;
    }, 600);
  }

  // ============================================================
  // 空输入抖动
  // ============================================================
  private shakeEmpty(): void {
    this.getUIContext().animateTo({ duration: 80, curve: Curve.EaseInOut }, () => {
      this.cardRotateZ = 2.5;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 80, curve: Curve.EaseInOut }, () => {
        this.cardRotateZ = -2.5;
      });
    }, 80);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 80, curve: Curve.EaseInOut }, () => {
        this.cardRotateZ = 1.5;
      });
    }, 160);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 80, curve: Curve.EaseOut }, () => {
        this.cardRotateZ = 0;
      });
    }, 240);
  }

  // ============================================================
  // 触觉
  // ============================================================
  private vibratePreset(effectId: string): void {
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: effectId, count: 1 },
        { usage: 'touch' }
      );
    } catch (e) { /* ignore */ }
  }

  // ============================================================
  // 退出
  // ============================================================
  private handleDismiss(): void {
    if (this.isHolding || this.isLaunched) return;

    this.getUIContext().animateTo({
      duration: 250,
      curve: curves.springMotion(0.25, 0.8)
    }, () => {
      this.cardScale = 0.8;
      this.cardOpacity = 0;
      this.cardTranslateY = 100;
      this.cardRotateZ = 5;
    });
    this.getUIContext().animateTo({
      duration: 200, curve: Curve.EaseOut
    }, () => {
      this.overlayOpacity = 0;
    });

    setTimeout(() => {
      this.onDismiss();
    }, 300);
  }

  // ============================================================
  // Build
  // ============================================================
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ===== 遮罩层 =====
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(`rgba(0, 0, 0, ${this.overlayOpacity})`)
        .backdropBlur(this.overlayOpacity > 0 ? 25 + this.overlayBlur : 0)
        .onClick(() => {
          this.handleDismiss();
        })

      // ===== 主卡片 =====
      Column() {
        Stack() {
          // 卡背
          Column() {
            this.CeremonyCardBack()
          }
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .opacity(this.cardRotateY > 90 ? 1 : 0)
          .hitTestBehavior(this.cardRotateY > 90 ? HitTestMode.Default : HitTestMode.None)

          // 卡面
          this.CeremonyCardFront()
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('85%')
      .height(310)
      .constraintSize({ maxWidth: 340 })
      .borderRadius(24)
      .clip(true)
      .shadow({
        radius: this.cardElevation,
        color: '#1A000000',
        offsetY: this.cardElevation / 3
      })
      .scale({
        x: this.cardScale * this.chargeScale * this.launchScale,
        y: this.cardScale * this.chargeScale * this.launchScale
      })
      .rotate({ x: 0, y: 1, z: 0, angle: this.cardRotateY, perspective: 800 })
      .rotate({ x: 0, y: 0, z: 1, angle: this.cardRotateZ })
      .translate({
        x: this.shakeX,
        y: this.cardTranslateY + this.launchTranslateY
      })
      .opacity(this.cardOpacity * this.launchOpacity)

      // ===== 粒子层 =====
      if (this.showParticles) {
        this.LaunchParticles()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ============================================================
  // Builders
  // ============================================================
  @Builder
  private CeremonyCardBack() {
    Column({ space: 12 }) {
      Text('🏔️')
        .fontSize(48)
        .opacity(0.6)
      Text('PackCheck')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .opacity(0.8)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PRIMARY_COLOR)
    .justifyContent(FlexAlign.Center)
    .borderRadius(24)
    .rotate({ x: 0, y: 1, z: 0, angle: 180 })
  }

  @Builder
  private CeremonyCardFront() {
    Column({ space: 0 }) {
      // 情绪化标题
      Text('🏔️ 新的冒险即将开始')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 16 })
        .opacity(this.contentStep >= 1 ? 1 : 0)

      // 行程名称输入
      TextInput({ placeholder: '给这次旅途取个名字吧', text: this.tripTitle })
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(TEXT_MAIN)
        .placeholderColor(TEXT_SECONDARY)
        .backgroundColor('#F5F5F5')
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.onTitleChange(value);
        })
        .opacity(this.contentStep >= 2 ? 1 : 0)

      // 日期选择
      Row() {
        Text(this.tripDate.length > 0 ? this.tripDate : '什么时候出发？')
          .fontSize(16)
          .fontColor(this.tripDate.length > 0 ? TEXT_MAIN : '#BBBBBB')
          .layoutWeight(1)
        Text('📅')
          .fontSize(20)
      }
      .width('100%')
      .height(48)
      .backgroundColor('#F5F5F5')
      .borderRadius(16)
      .padding({ left: 16, right: 16 })
      .margin({ top: 12 })
      .onClick(() => {
        DatePickerDialog.show({
          start: new Date('2020-1-1'),
          end: new Date('2030-12-31'),
          selected: new Date(),
          lunar: false,
          onDateAccept: (value: Date) => {
            const month = value.getMonth() + 1;
            const day = value.getDate();
            this.onDateChange(month.toString() + '月' + day.toString() + '日');
          }
        });
      })
      .opacity(this.contentStep >= 3 ? 1 : 0)

      Blank()

      // ========== 长按蓄力按钮 ==========
      Stack({ alignContent: Alignment.BottomStart }) {
        // 按钮主体
        Row() {
          Text(this.btnText)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        .height(48)
        .borderRadius(24)
        .backgroundColor(PRIMARY_COLOR)
        .justifyContent(FlexAlign.Center)

        // 底部进度条
        Row()
          .width(`${this.holdProgress * 100}%`)
          .height(3)
          .borderRadius(1.5)
          .backgroundColor('#FFFFFF')
          .opacity(0.6)
          .position({ x: 0, y: 45 })
      }
      .width('100%')
      .height(48)
      .borderRadius(24)
      .clip(true)
      .opacity(this.contentStep >= 4 ? 1 : 0)
      .scale({
        x: this.contentStep >= 4 ? 1.0 : 0.8,
        y: this.contentStep >= 4 ? 1.0 : 0.8
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.onHoldStart();
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.onHoldEnd();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(24)
    .clip(true)
    .opacity(this.cardRotateY <= 90 ? 1 : 0)
    .hitTestBehavior(this.cardRotateY <= 90 ? HitTestMode.Default : HitTestMode.None)
  }

  // ============================================================
  // 粒子
  // ============================================================
  @Builder
  private LaunchParticles() {
    ForEach(this.getParticles(), (p: number[]) => {
      Circle()
        .width(p[2])
        .height(p[2])
        .fill(p[3] === 0 ? PRIMARY_COLOR : '#FFD700')
        .position({ x: '50%', y: '45%' })
        .translate({
          x: p[0] * this.particleProgress - p[2] / 2,
          y: p[1] * this.particleProgress - p[2] / 2
        })
        .opacity(1 - this.particleProgress)
        .scale({
          x: 1 - this.particleProgress * 0.7,
          y: 1 - this.particleProgress * 0.7
        })
    }, (p: number[]) => `particle_${p[0]}_${p[1]}`)
  }

  private getParticles(): number[][] {
    // [dirX, dirY, size, colorIndex]
    const result: number[][] = [];
    const angles: number[] = [0, 40, 80, 120, 160, 200, 240, 280, 320];
    for (let i = 0; i < angles.length; i++) {
      const rad = angles[i] * Math.PI / 180;
      const dist = 45 + (i % 3) * 20;
      const size = i % 2 === 0 ? 8 : 5;
      result.push([
        Math.cos(rad) * dist,
        Math.sin(rad) * dist,
        size,
        i % 2
      ]);
    }
    return result;
  }
}
