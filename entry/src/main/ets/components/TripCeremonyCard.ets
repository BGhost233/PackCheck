import {
  SPRING_CEREMONY_FLIP, SPRING_CEREMONY_DISMISS, SPRING_PRESS,
  SPRING_COUNTER, SPRING_GENERAL,
  DURATION_CEREMONY_OVERLAY, DURATION_CEREMONY_SHINE,
  DURATION_CEREMONY_STAGGER, DURATION_CEREMONY_SHIMMER, DURATION_SCROLL_SMOOTH,
  DURATION_COUNTER, DURATION_FAST, DURATION_NORMAL,
  DURATION_COLOR_FADE, DURATION_CEREMONY_SHAKE,
  CURVE_DECELERATE, CURVE_STANDARD
} from '../constants/AnimationTokens';
import { vibrator } from '@kit.SensorServiceKit';
import { inputMethod } from '@kit.IMEKit';
import {
  CARD_BG,
  CARD_FOOTER_BG,
  CHIP_BG_DEFAULT,
  ERROR_BORDER,
  INPUT_BG,
  LIGHT_PRIMARY_COLOR,
  PLACEHOLDER_COLOR,
  PRIMARY_COLOR,
  PRIMARY_FILL_SUBTLE,
  PRIMARY_GRADIENT_END,
  PRIMARY_GRADIENT_START,
  PRIMARY_HALF,
  PRIMARY_PRESSED_DEEP,
  SHADOW_DEFAULT,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TRANSPARENT,
  WHITE,
  WHITE_SEMI_TRANSPARENT
} from '../constants/Colors';
import { CHIP_RADIUS } from '../constants/Layout';

@Component
export struct TripCeremonyCard {
  @Prop tripTitle: string = '';
  @Prop tripDate: string = '';
  @Prop tripDestination: string = '';
  @Prop tripDistanceKm: string = '';
  @Prop tripMaxAltitude: string = '';
  @Prop tripAscentM: string = '';
  @Prop tripDurationHours: string = '';

  onTitleChange: (value: string) => void = () => {};
  onDateChange: (value: string) => void = () => {};
  onDestinationChange: (value: string) => void = () => {};
  onDistanceChange: (value: string) => void = () => {};
  onAltitudeChange: (value: string) => void = () => {};
  onAscentChange: (value: string) => void = () => {};
  onDurationChange: (value: string) => void = () => {};
  onFinish: () => void = () => {};
  onDismiss: () => void = () => {};
  onExitStart: () => void = () => {};

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

  // === 标题 shimmer ===
  @State private titleShimmerX: number = -60;
  private titleShimmerTimer: number = -1;
  private titleRowWidth: number = 200;

  // === 输入框抖动 ===
  @State private titleShakeX: number = 0;
  @State private titleBorderHighlight: boolean = false;

  // === 渐进式 chip 状态 ===
  @State private activeChips: boolean[] = [false, false, false, false, false];
  @State private chipAreaHeight: number = 0;

  // === 滑动状态 ===
  @State private slideX: number = 0;
  @State private isSliding: boolean = false;
  @State private isSlideComplete: boolean = false;
  @State private sliderPressed: boolean = false;
  @State private shimmerX: number = -80;

  // === 终点虚影 ===
  @State private targetGlowScale: number = 1.0;
  @State private targetGlowOpacity: number = 0.05;

  // === 发射/飘走 ===
  @State private launchTranslateY: number = 0;
  @State private launchScale: number = 1.0;
  @State private launchOpacity: number = 1.0;
  @State private launchRotate: number = 0;

  // === 滑块到达膨胀 ===
  @State private sliderBounceScale: number = 1.0;

  // === 按压增强 ===
  @State private sliderBgColor: string = PRIMARY_COLOR;
  @State private trackSinkY: number = 0;
  @State private airplaneRotate: number = 0;
  private lastRatchetProgress: number = 0;

  // === 仪式感状态 ===
  @State private ceremonyPhase: number = 0;
  @State private ripple1Scale: number = 0.5;
  @State private ripple1Opacity: number = 0;
  @State private ripple2Scale: number = 0.5;
  @State private ripple2Opacity: number = 0;
  @State private ceremonyCardScale: number = 1.0;
  @State private ceremonyCardSinkY: number = 0;
  @State private trackTextOpacity: number = 1.0;
  @State private readyTextOpacity: number = 0;
  @State private glowLayerOpacity: number = 0;

  // 配置
  private readonly SLIDER_WIDTH: number = 48;
  private readonly SLIDER_HEIGHT: number = 48;
  private readonly TRACK_HEIGHT: number = 36;
  private readonly TRACK_PADDING: number = 0;
  private readonly MAGNET_THRESHOLD: number = 0.85;
  private trackWidth: number = 0;
  private touchStartX: number = 0;
  private slideStartX: number = 0;

  // shimmer 定时器
  private shimmerTimer: number = -1;

  aboutToAppear(): void {
    this.startEntrance();
  }

  aboutToDisappear(): void {
    if (this.shimmerTimer !== -1) {
      clearTimeout(this.shimmerTimer);
      this.shimmerTimer = -1;
    }
    this.stopTitleShimmer();
  }

  // ============================================================
  // 计算属性
  // ============================================================
private getMaxSlide(): number {
// 滑块左缘最大位移 = 轨道宽度 - 滑块直径
return this.trackWidth - this.SLIDER_WIDTH;
}

  private getProgress(): number {
    const max = this.getMaxSlide();
    if (max <= 0) return 0;
    return Math.min(this.slideX / max, 1.0);
  }

  // ============================================================
  // 入场动画
  // ============================================================
  private startEntrance(): void {
    this.getUIContext().animateTo({
      duration: DURATION_CEREMONY_OVERLAY, curve: CURVE_DECELERATE
    }, () => {
      this.overlayOpacity = 0.6;
    });

    setTimeout(() => {
      this.getUIContext().animateTo({
        curve: SPRING_CEREMONY_FLIP()
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
        duration: DURATION_CEREMONY_SHINE, curve: CURVE_STANDARD
      }, () => {
        this.shineX = 350;
      });
    }, 350);

    // 内容错落入场：紧跟翻转，不等完全 settle
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE }, () => {
        this.contentStep = 1;
      });
      // 标题入场完成后 300ms 启动标题 shimmer
      setTimeout(() => {
        this.startTitleShimmer();
      }, 300);
    }, 300);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE }, () => {
        this.contentStep = 2;
      });
    }, 360);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE }, () => {
        this.contentStep = 3;
      });
    }, 420);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE }, () => {
        this.contentStep = 4;
      });
      // 入场完毕后启动 shimmer
      setTimeout(() => {
        this.startShimmer();
      }, 200);
    }, 480);
  }

  // ============================================================
  // Shimmer 高光循环
  // ============================================================
  private startShimmer(): void {
    if (this.isSlideComplete) return;
    const endX = Math.max(280, this.trackWidth + 50);
    this.shimmerX = -80;
    this.getUIContext().animateTo({
      duration: DURATION_CEREMONY_SHIMMER,
      curve: CURVE_STANDARD
    }, () => {
      this.shimmerX = endX;
    });
    this.shimmerTimer = setTimeout(() => {
      this.startShimmer();
    }, 2500) as number;
  }

  private stopShimmer(): void {
    if (this.shimmerTimer !== -1) {
      clearTimeout(this.shimmerTimer);
      this.shimmerTimer = -1;
    }
  }

  // ============================================================
  // 标题 Shimmer
  // ============================================================
  private startTitleShimmer(): void {
    if (this.isSlideComplete) return;
    const endX = this.titleRowWidth + 60;
    this.titleShimmerX = -60;
    this.getUIContext().animateTo({
      duration: DURATION_CEREMONY_SHIMMER,
      curve: CURVE_STANDARD
    }, () => {
      this.titleShimmerX = endX;
    });
    this.titleShimmerTimer = setTimeout(() => {
      this.startTitleShimmer();
    }, 3000) as number;
  }

  private stopTitleShimmer(): void {
    if (this.titleShimmerTimer !== -1) {
      clearTimeout(this.titleShimmerTimer);
      this.titleShimmerTimer = -1;
    }
  }

  // ============================================================
  // 滑动手势
  // ============================================================
  private onSlideStart(x: number): void {
    if (this.isSlideComplete) return;
    if (this.tripTitle.trim().length === 0) {
      this.shakeTitle();
      return;
    }

    this.isSliding = true;
    this.touchStartX = x;
    this.slideStartX = this.slideX;
    this.lastRatchetProgress = 0;

    // 按压态：缩小 + 颜色加深 + 轨道下沉
    this.getUIContext().animateTo({
      curve: SPRING_PRESS()
    }, () => {
      this.sliderPressed = true;
      this.sliderBgColor = PRIMARY_PRESSED_DEEP;
      this.trackSinkY = 1.5;
    });

    // 柔和抓握反馈
    this.vibratePreset('haptic.effect.soft');
    this.stopShimmer();
  }

  private onSlideMove(x: number): void {
    if (!this.isSliding || this.isSlideComplete) return;

    const delta = x - this.touchStartX;
    const maxSlide = this.getMaxSlide();
    let newX = this.slideStartX + delta;
    newX = Math.max(0, Math.min(newX, maxSlide));
    this.slideX = newX;

    // 更新终点虚影
    const progress = this.getProgress();
    if (progress > 0.5) {
      this.targetGlowScale = 1.0 + (progress - 0.5) * 0.6; // 1.0 → 1.3
      this.targetGlowOpacity = 0.05 + (progress - 0.5) * 0.3; // 0.05 → 0.2
    } else {
      this.targetGlowScale = 1.0;
      this.targetGlowOpacity = 0.05;
    }

    // 棘轮振动：每 25% 进度触发一次
    const ratchetThresholds: number[] = [0.25, 0.50, 0.75];
    for (const threshold of ratchetThresholds) {
      if (progress >= threshold && this.lastRatchetProgress < threshold) {
        this.vibratePreset('haptic.clock.timer');
      }
    }
    this.lastRatchetProgress = progress;

    // 磁吸：超过 85% 自动吸附
    if (progress >= this.MAGNET_THRESHOLD) {
      this.completeSlide();
    }
  }

  private onSlideEnd(): void {
    if (!this.isSliding || this.isSlideComplete) return;
    this.isSliding = false;

    // 松开按压态 + 恢复颜色/下沉
    this.getUIContext().animateTo({
      curve: SPRING_PRESS()
    }, () => {
      this.sliderPressed = false;
      this.sliderBgColor = PRIMARY_COLOR;
      this.trackSinkY = 0;
    });
    this.lastRatchetProgress = 0;

    // 未到磁吸点，弹回
    if (this.getProgress() < this.MAGNET_THRESHOLD) {
      this.getUIContext().animateTo({
        curve: SPRING_CEREMONY_FLIP()
      }, () => {
        this.slideX = 0;
        this.targetGlowScale = 1.0;
        this.targetGlowOpacity = 0.05;
      });
      // 恢复 shimmer
      setTimeout(() => {
        this.startShimmer();
      }, 500);
    }
  }

  // ============================================================
  // 滑动完成 → 三阶段仪式序列
  // ============================================================
  private completeSlide(): void {
    if (this.isSlideComplete) return;
    this.isSlideComplete = true;
    this.isSliding = false;
    this.stopShimmer();
    this.stopTitleShimmer();

    // 吸附到终点 + 恢复按压态
    const maxSlide = this.getMaxSlide();
    this.getUIContext().animateTo({
      duration: DURATION_FAST,
      curve: CURVE_DECELERATE
    }, () => {
      this.slideX = maxSlide;
      this.sliderPressed = false;
      this.sliderBgColor = PRIMARY_COLOR;
      this.trackSinkY = 0;
    });

    // 启动仪式 Phase 1
    this.startCeremonyPhase1();
  }

  // ============================================================
  // Phase 1：锁定确认（0~150ms）
  // ============================================================
  private startCeremonyPhase1(): void {
    this.ceremonyPhase = 1;

    // 滑块放大 1.15
    this.getUIContext().animateTo({
      curve: SPRING_PRESS()
    }, () => {
      this.sliderBounceScale = 1.15;
    });

    // 双击锁定振动
    this.vibratePresetWithCount('haptic.effect.sharp', 2);

    // 波纹扩散
    this.ripple1Scale = 0.5;
    this.ripple1Opacity = 0.5;
    this.ripple2Scale = 0.5;
    this.ripple2Opacity = 0;

    // 波纹1 展开
    setTimeout(() => {
      this.ripple1Scale = 1.8;
      this.ripple1Opacity = 0;
    }, 10);

    // 波纹2 延迟 60ms 展开
    setTimeout(() => {
      this.ripple2Opacity = 0.35;
      setTimeout(() => {
        this.ripple2Scale = 1.5;
        this.ripple2Opacity = 0;
      }, 10);
    }, 60);

    // 150ms 后进入 Phase 2
    setTimeout(() => {
      this.startCeremonyPhase2();
    }, 150);
  }

  // ============================================================
  // Phase 2：充能蓄力（150~550ms）
  // ============================================================
  private startCeremonyPhase2(): void {
    this.ceremonyPhase = 2;

    // 卡片收缩蓄力
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.ceremonyCardScale = 0.97;
      this.ceremonyCardSinkY = 3;
    });

    // 文字切换：「滑动出发」→「准备出发！」
    this.trackTextOpacity = 0;
    this.readyTextOpacity = 1;

    // 飞机旋转朝上
    this.airplaneRotate = -45;

    // 光晕显现
    this.getUIContext().animateTo({
      duration: DURATION_NORMAL,
      curve: CURVE_DECELERATE
    }, () => {
      this.glowLayerOpacity = 0.10;
    });

    // 滑块从 1.15 恢复到 1.0
    setTimeout(() => {
      this.getUIContext().animateTo({
        curve: SPRING_COUNTER()
      }, () => {
        this.sliderBounceScale = 1.0;
      });
    }, 100);

    // 400ms 后进入 Phase 3
    setTimeout(() => {
      this.startCeremonyPhase3();
    }, 400);
  }

  // ============================================================
  // Phase 3：弹射升空（550~1050ms）
  // ============================================================
  private startCeremonyPhase3(): void {
    this.ceremonyPhase = 3;

    // 弹射预备：微放大
    this.getUIContext().animateTo({
      curve: SPRING_PRESS()
    }, () => {
      this.ceremonyCardScale = 1.03;
      this.ceremonyCardSinkY = 0;
    });

    // 推力振动
    this.vibratePreset('haptic.effect.hard');

    // 数据创建
    this.onFinish();

    // 100ms 后飞走
    setTimeout(() => {
      this.flyAway();
    }, 100);
  }

  // ============================================================
  // 卡片飘走（改进版）
  // ============================================================
  private flyAway(): void {
    this.onExitStart();
    this.stopTitleShimmer();

    // 光晕消散
    this.getUIContext().animateTo({
      duration: DURATION_NORMAL,
      curve: CURVE_DECELERATE
    }, () => {
      this.glowLayerOpacity = 0;
    });

    // 卡片飘走
    this.getUIContext().animateTo({
      curve: SPRING_CEREMONY_FLIP()
    }, () => {
      this.launchTranslateY = -800;
      this.launchScale = 0.85;
      this.launchOpacity = 0;
      this.launchRotate = -3;
    });

    // 遮罩消散
    this.getUIContext().animateTo({
      duration: DURATION_COLOR_FADE,
      curve: CURVE_DECELERATE
    }, () => {
      this.overlayOpacity = 0;
    });

    // 飘走完成后移除组件
    setTimeout(() => {
      this.onDismiss();
    }, 500);
  }

  // ============================================================
  // 输入框抖动提示
  // ============================================================
  private shakeTitle(): void {
    // 水平抖动序列
    const sequence: number[] = [-8, 8, -5, 5, 0];
    let delay = 0;
    sequence.forEach((x: number) => {
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: DURATION_CEREMONY_SHAKE, curve: CURVE_DECELERATE }, () => {
          this.titleShakeX = x;
        });
      }, delay);
      delay += 80;
    });

    // 边框闪红
    this.titleBorderHighlight = true;
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: DURATION_CEREMONY_OVERLAY, curve: CURVE_DECELERATE }, () => {
        this.titleBorderHighlight = false;
      });
    }, 600);

    // 触觉反馈
    this.vibratePreset('haptic.tick');
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

  private vibratePresetWithCount(effectId: string, count: number): void {
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: effectId, count: count },
        { usage: 'touch' }
      );
    } catch (e) { /* ignore */ }
  }

  // ============================================================
  // 退出
  // ============================================================
  private handleDismiss(): void {
    if (this.isSliding || this.isSlideComplete) return;

    this.onExitStart();
    this.stopShimmer();
    this.getUIContext().animateTo({
      curve: SPRING_CEREMONY_DISMISS()
    }, () => {
      this.cardScale = 0.8;
      this.cardOpacity = 0;
      this.cardTranslateY = 100;
      this.cardRotateZ = 5;
    });
    this.getUIContext().animateTo({
      duration: DURATION_NORMAL, curve: CURVE_DECELERATE
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
        .backdropBlur(this.overlayOpacity > 0 ? 25 : 0)
        .onClick(() => {
          inputMethod.getController().stopInputSession();
          this.handleDismiss();
        })

      // ===== 光晕层（卡片之下）=====
      Column()
        .width('87%')
        .height(308)
        .constraintSize({ maxWidth: 348 })
        .borderRadius(28)
        .backgroundColor(PRIMARY_COLOR)
        .opacity(this.glowLayerOpacity)
        .blur(16)
        .animation({ duration: DURATION_NORMAL, curve: CURVE_DECELERATE })
        .scale({
          x: this.cardScale * this.launchScale * this.ceremonyCardScale,
          y: this.cardScale * this.launchScale * this.ceremonyCardScale
        })
        .translate({
          x: 0,
          y: this.cardTranslateY + this.launchTranslateY + this.ceremonyCardSinkY
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
      .height(300)
      .constraintSize({ maxWidth: 340 })
      .borderRadius(24)
      .clip(true)
      .shadow({
        radius: this.cardElevation,
        color: SHADOW_DEFAULT,
        offsetY: this.cardElevation / 3
      })
      .scale({
        x: this.cardScale * this.launchScale * this.ceremonyCardScale,
        y: this.cardScale * this.launchScale * this.ceremonyCardScale
      })
      .rotate({ x: 0, y: 1, z: 0, angle: this.cardRotateY, perspective: 800 })
      .rotate({ x: 0, y: 0, z: 1, angle: this.cardRotateZ + this.launchRotate })
      .translate({
        x: 0,
        y: this.cardTranslateY + this.launchTranslateY + this.ceremonyCardSinkY
      })
      .opacity(this.cardOpacity * this.launchOpacity)
    }
    .width('100%')
    .height('100%')
  }

  // ============================================================
  // Builders
  // ============================================================
  // ============================================================
  // 渐进式 chip（5 结构化字段按需点亮）
  // ============================================================
  private chipLabels: string[] = ['目的地', '里程', '海拔', '爬升', '时长'];
  private chipUnits: string[] = ['', 'km', 'm', 'm', 'h'];

  private toggleChip(index: number): void {
    const next = [...this.activeChips];
    next[index] = !next[index];
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.activeChips = next;
    });
  }

  private getChipValue(index: number): string {
    const values: string[] = [
      this.tripDestination, this.tripDistanceKm,
      this.tripMaxAltitude, this.tripAscentM, this.tripDurationHours
    ];
    return values[index];
  }

  private isChipFilled(index: number): boolean {
    return this.getChipValue(index).trim().length > 0;
  }

  private onChipValueChange(index: number, value: string): void {
    switch (index) {
      case 0: this.onDestinationChange(value); break;
      case 1: this.onDistanceChange(value); break;
      case 2: this.onAltitudeChange(value); break;
      case 3: this.onAscentChange(value); break;
      case 4: this.onDurationChange(value); break;
      default: break;
    }
  }

  @Builder
  private ChipTag(label: string, index: number) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(12)
        .fontColor(this.activeChips[index] || this.isChipFilled(index) ? PRIMARY_COLOR : TEXT_SECONDARY)
        .fontWeight(this.activeChips[index] ? FontWeight.Medium : FontWeight.Normal)
      if (this.isChipFilled(index) && this.chipUnits[index].length > 0) {
        Text(this.getChipValue(index) + this.chipUnits[index])
          .fontSize(11)
          .fontColor(PRIMARY_COLOR)
          .fontWeight(FontWeight.Medium)
      }
    }
    .height(28)
    .padding({ left: 10, right: 10 })
    .borderRadius(CHIP_RADIUS)
    .backgroundColor(this.activeChips[index] || this.isChipFilled(index) ? LIGHT_PRIMARY_COLOR : CHIP_BG_DEFAULT)
    .onClick(() => {
      this.toggleChip(index);
    })
  }

  @Builder
  private ProgressiveChips() {
    Column({ space: 8 }) {
      // chip 行
      Row({ space: 6 }) {
        ForEach([0, 1, 2, 3, 4], (index: number) => {
          this.ChipTag(this.chipLabels[index], index)
        })
      }
      .opacity(this.contentStep >= 3 ? 1 : 0)
      .translate({ y: this.contentStep >= 3 ? 0 : 8 })

      // 展开的输入框（仅激活的 chip 显示）
      if (this.activeChips[0]) {
        TextInput({ placeholder: '去哪里？', text: this.tripDestination })
          .width('100%')
          .height(40)
          .fontSize(13)
          .fontColor(TEXT_MAIN)
          .placeholderColor(PLACEHOLDER_COLOR)
          .backgroundColor(INPUT_BG)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
          .onChange((value: string) => { this.onDestinationChange(value); })
      }
      if (this.activeChips[1]) {
        TextInput({ placeholder: '里程（km）', text: this.tripDistanceKm })
          .width('100%')
          .height(40)
          .fontSize(13)
          .fontColor(TEXT_MAIN)
          .placeholderColor(PLACEHOLDER_COLOR)
          .backgroundColor(INPUT_BG)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .type(InputType.Number)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
          .onChange((value: string) => { this.onDistanceChange(value); })
      }
      if (this.activeChips[2]) {
        TextInput({ placeholder: '最高海拔（m）', text: this.tripMaxAltitude })
          .width('100%')
          .height(40)
          .fontSize(13)
          .fontColor(TEXT_MAIN)
          .placeholderColor(PLACEHOLDER_COLOR)
          .backgroundColor(INPUT_BG)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .type(InputType.Number)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
          .onChange((value: string) => { this.onAltitudeChange(value); })
      }
      if (this.activeChips[3]) {
        TextInput({ placeholder: '累计爬升（m）', text: this.tripAscentM })
          .width('100%')
          .height(40)
          .fontSize(13)
          .fontColor(TEXT_MAIN)
          .placeholderColor(PLACEHOLDER_COLOR)
          .backgroundColor(INPUT_BG)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .type(InputType.Number)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
          .onChange((value: string) => { this.onAscentChange(value); })
      }
      if (this.activeChips[4]) {
        TextInput({ placeholder: '时长（小时）', text: this.tripDurationHours })
          .width('100%')
          .height(40)
          .fontSize(13)
          .fontColor(TEXT_MAIN)
          .placeholderColor(PLACEHOLDER_COLOR)
          .backgroundColor(INPUT_BG)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .type(InputType.Number)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
          .onChange((value: string) => { this.onDurationChange(value); })
      }
    }
    .width('100%')
  }

  @Builder
  private InsetInput(placeholder: string, text: string, showCalendar: boolean, stepIndex: number,
    onTextChange?: (value: string) => void, onTap?: () => void) {
    // 简洁输入框：浅色背景 + 圆角，无 3D 效果
    if (onTextChange) {
      TextInput({ placeholder: placeholder, text: text })
        .width('100%')
        .height(48)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
        .placeholderColor(PLACEHOLDER_COLOR)
        .backgroundColor(INPUT_BG)
        .borderRadius(12)
        .padding({ left: 16, right: 16 })
        .opacity(this.contentStep >= stepIndex ? 1 : 0)
        .translate({ y: this.contentStep >= stepIndex ? 0 : 8 })
        .onChange((value: string) => {
          onTextChange(value);
        })
    } else {
      Row() {
        Text(text.length > 0 ? text : placeholder)
          .fontSize(14)
          .fontColor(text.length > 0 ? TEXT_MAIN : PLACEHOLDER_COLOR)
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor(INPUT_BG)
      .borderRadius(12)
      .opacity(this.contentStep >= stepIndex ? 1 : 0)
      .translate({ y: this.contentStep >= stepIndex ? 0 : 8 })
      .onClick(() => {
        if (onTap) onTap();
      })
    }
  }

  @Builder
  private CeremonyCardBack() {
    Column({ space: 8 }) {
      Text('PackCheck')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(WHITE)
        .opacity(0.9)
      Text('装备就绪 · 轻装出发')
        .fontSize(12)
        .fontColor(WHITE)
        .opacity(0.6)
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
    Column() {
      // 情绪化标题（圆点 + 文字 + shimmer）
      Stack() {
        Row({ space: 0 }) {
          // 左侧圆点组
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
          Circle({ width: 4, height: 4 })
            .fill(PRIMARY_FILL_SUBTLE)
            .margin({ left: 4 })

          // 标题文字
          Text('新的冒险即将开始')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .margin({ left: 10, right: 10 })

          // 右侧圆点组
          Circle({ width: 4, height: 4 })
            .fill(PRIMARY_FILL_SUBTLE)
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
            .margin({ left: 4 })
        }
        .alignItems(VerticalAlign.Center)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.titleRowWidth = newValue.width as number;
        })

        // shimmer 高光条
        Row()
          .width(40)
          .height('100%')
          .borderRadius(20)
          .linearGradient({
            angle: 90,
            colors: [[TRANSPARENT, 0], [WHITE_SEMI_TRANSPARENT, 0.5], [TRANSPARENT, 1.0]]
          })
          .translate({ x: this.titleShimmerX })
      }
      .height(20)
      .clip(true)
      .opacity(this.contentStep >= 1 ? 1 : 0)
      .translate({ y: this.contentStep >= 1 ? 0 : 6 })
      .margin({ top: 24, bottom: 20 })

      // 行程名称输入
      Column() {
        this.InsetInput('给这次旅途取个名字吧', this.tripTitle, false, 2,
          (value: string) => { this.onTitleChange(value); })
      }
      .translate({ x: this.titleShakeX })
      .border({
        width: this.titleBorderHighlight ? 1.5 : 0,
        color: this.titleBorderHighlight ? ERROR_BORDER : TRANSPARENT,
        radius: 12
      })
      .animation({ duration: DURATION_NORMAL, curve: CURVE_DECELERATE })

      // 间距 16vp（同组内）
      Column().height(16)

      // 日期选择 — 直接内联避免 @Builder 回调 this 丢失
      Row() {
        Text(this.tripDate.length > 0 ? this.tripDate : '什么时候出发？')
          .fontSize(14)
          .fontColor(this.tripDate.length > 0 ? TEXT_MAIN : PLACEHOLDER_COLOR)
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor(INPUT_BG)
      .borderRadius(12)
      .opacity(this.contentStep >= 3 ? 1 : 0)
      .translate({ y: this.contentStep >= 3 ? 0 : 8 })
      .onClick(() => {
        DatePickerDialog.show({
          start: new Date('2020-1-1'),
          end: new Date('2030-12-31'),
          selected: new Date(),
          lunar: false,
          onDateAccept: (value: Date) => {
            const year = value.getFullYear();
            const month = value.getMonth() + 1;
            const day = value.getDate();
            const dateStr = year.toString() + '年' + month.toString() + '月' + day.toString() + '日';
            this.onDateChange(dateStr);
          }
        });
      })

      // 跨组间距 16vp
      Column().height(16)

      // ========== 渐进式 chip（5 结构化字段）==========
      this.ProgressiveChips()

      // 跨组间距 16vp
      Column().height(16)

      // ========== 滑动出发滑轨 ==========
      Stack({ alignContent: Alignment.Center }) {
        // ① 轨道背景（最底层）
        Row()
          .width('100%')
          .height(this.TRACK_HEIGHT)
          .borderRadius(this.TRACK_HEIGHT / 2)
          .backgroundColor(CARD_FOOTER_BG)

        // ①.5 绿色进度填充条
        Row()
          .width(this.slideX + this.SLIDER_WIDTH / 2)
          .height(this.TRACK_HEIGHT)
          .borderRadius({ topLeft: this.TRACK_HEIGHT / 2, bottomLeft: this.TRACK_HEIGHT / 2 })
          .linearGradient({
            angle: 0,
            colors: [[PRIMARY_GRADIENT_START, 0.0], [PRIMARY_GRADIENT_END, 1.0]]
          })
          .position({ x: 0, y: (this.SLIDER_HEIGHT - this.TRACK_HEIGHT) / 2 })

        // ② 文案（双层叠加，支持仪式感文字切换）
        Stack() {
          Text('滑动出发')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_HALF)
            .opacity(this.trackTextOpacity)
            .animation({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE })
          Text('准备出发！')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_COLOR)
            .opacity(this.readyTextOpacity)
            .animation({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE })
        }

        // ③ 白色遮罩（盖住左侧轨道 + 文字）
        Row()
          .width(this.slideX + this.SLIDER_WIDTH / 2)
          .height(this.TRACK_HEIGHT)
          .backgroundColor(WHITE)
          .borderRadius({ topLeft: this.TRACK_HEIGHT / 2, bottomLeft: this.TRACK_HEIGHT / 2 })
          .position({ x: 0, y: (this.SLIDER_HEIGHT - this.TRACK_HEIGHT) / 2 })

        // ④ 波纹层（仪式感 Phase1 用）
        Circle({ width: 48, height: 48 })
          .fill(PRIMARY_COLOR)
          .position({ x: this.getMaxSlide(), y: 0 })
          .scale({ x: this.ripple1Scale, y: this.ripple1Scale })
          .opacity(this.ripple1Opacity)
          .animation({ duration: DURATION_COUNTER, curve: CURVE_DECELERATE })
        Circle({ width: 48, height: 48 })
          .fill(PRIMARY_COLOR)
          .position({ x: this.getMaxSlide(), y: 0 })
          .scale({ x: this.ripple2Scale, y: this.ripple2Scale })
          .opacity(this.ripple2Opacity)
          .animation({ duration: DURATION_COLOR_FADE, curve: CURVE_DECELERATE })

        // ⑤ 滑块：纯色正圆 + 白色飞机
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.SLIDER_WIDTH)
            .height(this.SLIDER_HEIGHT)
            .borderRadius(this.SLIDER_HEIGHT / 2)
            .backgroundColor(this.sliderBgColor)
            .animation({ duration: DURATION_CEREMONY_STAGGER, curve: CURVE_DECELERATE })

          SymbolGlyph($r('sys.symbol.airplane'))
            .fontSize(20)
            .fontColor([WHITE])
            .rotate({ angle: this.airplaneRotate })
            .animation({ curve: SPRING_COUNTER() })
        }
        .width(this.SLIDER_WIDTH)
        .height(this.SLIDER_HEIGHT)
        .position({ x: this.slideX, y: 0 })
        .scale({
          x: this.sliderPressed ? 0.92 : this.sliderBounceScale,
          y: this.sliderPressed ? 0.92 : this.sliderBounceScale
        })

        // ⑥ 触摸热区（56×56，透明扩展）
        Column()
          .width(56)
          .height(56)
          .backgroundColor(TRANSPARENT)
          .position({
            x: this.slideX - (56 - this.SLIDER_WIDTH) / 2,
            y: (this.SLIDER_HEIGHT - 56) / 2
          })
      }
      .width('100%')
      .height(this.SLIDER_HEIGHT)
      .clip(false)
      .translate({ y: (this.contentStep >= 4 ? 0 : 10) + this.trackSinkY })
      .animation({ duration: DURATION_SCROLL_SMOOTH, curve: CURVE_DECELERATE })
      .opacity(this.contentStep >= 4 ? 1 : 0)
      .scale({
        x: this.contentStep >= 4 ? 1.0 : 0.9,
        y: this.contentStep >= 4 ? 1.0 : 0.9
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.trackWidth = newValue.width as number;
      })
      .onTouch((event: TouchEvent) => {
        const touch = event.touches[0];
        if (event.type === TouchType.Down) {
          this.onSlideStart(touch.x);
        } else if (event.type === TouchType.Move) {
          this.onSlideMove(touch.x);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.onSlideEnd();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, bottom: 20 })
    .backgroundColor(CARD_BG)
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(24)
    .clip(true)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        inputMethod.getController().stopInputSession();
      }
    })
    .opacity(this.cardRotateY <= 90 ? 1 : 0)
    .hitTestBehavior(this.cardRotateY <= 90 ? HitTestMode.Default : HitTestMode.None)
  }
}
