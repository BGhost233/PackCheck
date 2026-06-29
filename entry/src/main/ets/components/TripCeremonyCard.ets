import {
  SPRING_CEREMONY_FLIP, SPRING_CEREMONY_DISMISS, SPRING_PRESS,
  SPRING_COUNTER, SPRING_GENERAL, SPRING_FAB_SNAP, SPRING_SCROLL,
  DURATION_CEREMONY_SHINE, DURATION_CEREMONY_SHIMMER,
  DURATION_TITLE_BREATH,
  CURVE_STANDARD, CURVE_BREATH
} from '../constants/AnimationTokens';
import { hapticPreset } from '../utils/HapticUtils';
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
  TEXT_MAIN,
  TEXT_SECONDARY,
  TRANSPARENT,
  WHITE,
  WHITE_TRANSPARENT
} from '../constants/Colors';
import { CHIP_RADIUS } from '../constants/Layout';
import {
  FONT_SIZE_MINI, FONT_SIZE_CAPTION, FONT_SIZE_BODY_SMALL, FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_TITLE_MEDIUM
} from '../constants/Typography';

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
  

  // === 标题光泽呼吸（深色文字表面流过主题绿光泽的明暗脉动，无位移色块）===
  @State private titleGlow: number = 0;
  private titleGlowTimer: number = -1;

  // === 输入框抖动 ===
  @State private titleShakeX: number = 0;
  @State private titleBorderHighlight: boolean = false;

  // === 渐进式 chip 状态 ===
  @State private activeChips: boolean[] = [false, false, false, false, false];
  @State private chipAreaHeight: number = 0;

  // === 卡片动态高度 ===
  @State private cardContentHeight: number = 0;

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
  // 所有匿名 setTimeout ID 数组，aboutToDisappear 遍历清理
  private timerIds: number[] = [];
  // 防止组件卸载后 timer 回调访问已销毁的 UI 上下文
  private isAlive: boolean = true;

  aboutToAppear(): void {
    this.startEntrance();
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    // 清理 shimmer 递归 timer
    if (this.shimmerTimer !== -1) {
      clearTimeout(this.shimmerTimer);
      this.shimmerTimer = -1;
    }
    this.stopTitleShimmer();
    // 清理所有匿名 setTimeout（入场链/仪式序列/抖动/弹跳等）
    for (let i = 0; i < this.timerIds.length; i++) {
      clearTimeout(this.timerIds[i]);
    }
    this.timerIds = [];
    // 防御性重置：确保所有弹性 scale 回到中性值 1.0，防止组件销毁中途残留非中性值
    // （避坑 #17 静止态中性值：rest state 不得停留在弹性中间值）
    this.sliderBounceScale = 1.0;
    this.ceremonyCardScale = 1.0;
    this.targetGlowScale = 1.0;
    this.launchScale = 1.0;
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
      curve: SPRING_GENERAL()
    }, () => {
      this.overlayOpacity = 0.6;
    });

    let id: number;
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({
        curve: SPRING_CEREMONY_FLIP()
      }, () => {
        this.cardScale = 1.0;
        this.cardRotateY = 0;
        this.cardRotateZ = 0;
        this.cardTranslateY = 0;
        this.cardOpacity = 1;

      });
    }, 50) as number;
    this.timerIds.push(id);

    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({
        duration: DURATION_CEREMONY_SHINE, curve: CURVE_STANDARD
      }, () => {
        this.shineX = 350;
      });
    }, 350) as number;
    this.timerIds.push(id);

    // 内容错落入场：紧跟翻转，不等完全 settle
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.contentStep = 1;
      });
      // 标题入场完成后 300ms 启动标题 shimmer
      let innerId = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.startTitleShimmer();
      }, 300) as number;
      this.timerIds.push(innerId);
    }, 300) as number;
    this.timerIds.push(id);

    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.contentStep = 2;
      });
    }, 360) as number;
    this.timerIds.push(id);

    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.contentStep = 3;
      });
    }, 420) as number;
    this.timerIds.push(id);

    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.contentStep = 4;
      });
      // 入场完毕后启动 shimmer
      let innerId = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.startShimmer();
      }, 200) as number;
      this.timerIds.push(innerId);
    }, 480) as number;
    this.timerIds.push(id);
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
    // 半程：暗(0) → 亮(0.55)，到顶后回落，形成对称呼吸
    const goingUp = this.titleGlow < 0.275;
    this.getUIContext().animateTo({
      duration: DURATION_TITLE_BREATH,
      curve: CURVE_BREATH
    }, () => {
      this.titleGlow = goingUp ? 0.55 : 0;
    });
    this.titleGlowTimer = setTimeout(() => {
      this.startTitleShimmer();
    }, DURATION_TITLE_BREATH) as number;
  }

  private stopTitleShimmer(): void {
    if (this.titleGlowTimer !== -1) {
      clearTimeout(this.titleGlowTimer);
      this.titleGlowTimer = -1;
    }
    // 收场归零，避免静止态停在高亮（避坑 #17 静止态中性值）
    this.getUIContext().animateTo({ duration: DURATION_TITLE_BREATH, curve: CURVE_BREATH }, () => {
      this.titleGlow = 0;
    });
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
        curve: SPRING_CEREMONY_FLIP(),
        onFinish: () => {
          this.startShimmer();
        }
      }, () => {
        this.slideX = 0;
        this.targetGlowScale = 1.0;
        this.targetGlowOpacity = 0.05;
      });
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
      curve: SPRING_FAB_SNAP()
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
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.ripple1Scale = 1.8;
      this.ripple1Opacity = 0;
    }, 10) as number;
    this.timerIds.push(id);

    // 波纹2 延迟 60ms 展开
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.ripple2Opacity = 0.35;
      let innerId = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.ripple2Scale = 1.5;
        this.ripple2Opacity = 0;
      }, 10) as number;
      this.timerIds.push(innerId);
    }, 60) as number;
    this.timerIds.push(id);

    // 150ms 后进入 Phase 2
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.startCeremonyPhase2();
    }, 150) as number;
    this.timerIds.push(id);
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
      curve: SPRING_GENERAL()
    }, () => {
      this.glowLayerOpacity = 0.10;
    });

    // 滑块从 1.15 恢复到 1.0
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({
        curve: SPRING_COUNTER()
      }, () => {
        this.sliderBounceScale = 1.0;
      });
    }, 100) as number;
    this.timerIds.push(id);

    // 400ms 后进入 Phase 3
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.startCeremonyPhase3();
    }, 400) as number;
    this.timerIds.push(id)
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
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.flyAway();
    }, 100) as number;
    this.timerIds.push(id);
  }

  // ============================================================
  // 卡片飘走（改进版）
  // ============================================================
  private flyAway(): void {
    this.onExitStart();
    this.stopTitleShimmer();

    // 光晕消散
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.glowLayerOpacity = 0;
    });

    // 卡片飘走
    this.getUIContext().animateTo({
      curve: SPRING_CEREMONY_FLIP(),
      onFinish: () => {
        this.onDismiss();
      }
    }, () => {
      this.launchTranslateY = -800;
      this.launchScale = 0.85;
      this.launchOpacity = 0;
      this.launchRotate = -3;
    });

    // 遮罩消散
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.overlayOpacity = 0;
    });
  }

  // ============================================================
  // 输入框抖动提示
  // ============================================================
  private shakeTitle(): void {
    // 水平抖动序列
    const sequence: number[] = [-8, 8, -5, 5, 0];
    let delay = 0;
    sequence.forEach((x: number) => {
      let id = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
          this.titleShakeX = x;
        });
      }, delay) as number;
      this.timerIds.push(id);
      delay += 80;
    });

    // 边框闪红
    this.titleBorderHighlight = true;
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.titleBorderHighlight = false;
      });
    }, 600) as number;
    this.timerIds.push(id);

    // 触觉反馈
    this.vibratePreset('haptic.tick');
  }

  // ============================================================
  // 触觉
  // ============================================================
  private vibratePreset(effectId: string): void {
    hapticPreset(effectId, 1);
  }

  private vibratePresetWithCount(effectId: string, count: number): void {
    hapticPreset(effectId, count);
  }

  // ============================================================
  // 退出
  // ============================================================
  private handleDismiss(): void {
    if (this.isSliding || this.isSlideComplete) return;

    this.onExitStart();
    this.stopShimmer();
    this.getUIContext().animateTo({
      curve: SPRING_CEREMONY_DISMISS(),
      onFinish: () => {
        this.onDismiss();
      }
    }, () => {
      this.cardScale = 0.8;
      this.cardOpacity = 0;
      this.cardTranslateY = 100;
      this.cardRotateZ = 5;
    });
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL()
    }, () => {
      this.overlayOpacity = 0;
    });
  }

  // ============================================================
  // Build
  // ============================================================
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ===== 遮罩层（纯视觉，不参与事件分发）=====
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(`rgba(0, 0, 0, ${this.overlayOpacity})`)
        .backdropBlur(this.overlayOpacity > 0 ? 25 : 0)
        .hitTestBehavior(HitTestMode.None)

      // ===== 光晕层（卡片之下）=====
      if (this.glowLayerOpacity > 0) {
        Column()
          .width('87%')
          .height(this.cardContentHeight + 8)
          .constraintSize({ maxWidth: 348 })
          .borderRadius(28)
          .backgroundColor(PRIMARY_COLOR)
          .opacity(this.glowLayerOpacity)
          .hitTestBehavior(HitTestMode.None)
          .animation({ curve: SPRING_GENERAL() })
          .scale({
            x: this.cardScale * this.launchScale * this.ceremonyCardScale,
            y: this.cardScale * this.launchScale * this.ceremonyCardScale
          })
          .translate({
            x: 0,
            y: this.cardTranslateY + this.launchTranslateY + this.ceremonyCardSinkY
          })
      }

      // ===== 主卡片 =====
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

        // 卡面（内容驱动高度）
        this.CeremonyCardFront()
      }
      .width('85%')
      .constraintSize({ maxHeight: 540, maxWidth: 340 })
      .borderRadius(24)
      .clip(true)
      .animation({ curve: SPRING_GENERAL() })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const h = newArea.height as number;
        if (h > 0 && Math.abs(h - this.cardContentHeight) > 1) {
          this.cardContentHeight = h;
        }
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
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Up) {
        inputMethod.getController().stopInputSession();
        this.handleDismiss();
      }
    })
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
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(this.activeChips[index] || this.isChipFilled(index) ? PRIMARY_COLOR : TEXT_SECONDARY)
        .fontWeight(this.activeChips[index] ? FontWeight.Medium : FontWeight.Normal)
      if (this.isChipFilled(index) && this.chipUnits[index].length > 0) {
        Text(this.getChipValue(index) + this.chipUnits[index])
          .fontSize(FONT_SIZE_MINI)
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

  // chip 行滑动状态
  @State private chipScrollAtEnd: boolean = false;
  @State private chipScrollAtStart: boolean = true;

  @Builder
  private ProgressiveChips() {
    Column({ space: 8 }) {
      // chip 行：Scroll 包裹 + 右侧渐变遮罩
      Stack() {
        Scroll() {
          Row({ space: 6 }) {
            ForEach([0, 1, 2, 3, 4], (index: number) => {
              this.ChipTag(this.chipLabels[index], index)
            })
          }
          .padding({ right: 24 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .onScroll((_xOffset: number, _yOffset: number) => {})
        .onScrollEdge((side: Edge) => {
          if (side === Edge.End) {
            this.chipScrollAtEnd = true;
          } else if (side === Edge.Start) {
            this.chipScrollAtStart = true;
          }
        })
        .onScrollStart(() => {
          this.chipScrollAtEnd = false;
          this.chipScrollAtStart = false;
        })

        // 右侧渐变遮罩（暗示可继续滑动）
        Row()
          .width(32)
          .height('100%')
          .linearGradient({
            angle: 0,
            colors: [[WHITE_TRANSPARENT, 0.0], [WHITE, 1.0]]
          })
          .hitTestBehavior(HitTestMode.Transparent)
          .position({ right: 0, top: 0 })
          .opacity(this.chipScrollAtEnd ? 0 : 1)
          .animation({ curve: SPRING_GENERAL() })
      }
      .width('100%')
      .height(28)
      .opacity(this.contentStep >= 3 ? 1 : 0)
      .translate({ y: this.contentStep >= 3 ? 0 : 8 })

      // 展开的输入框（仅激活的 chip 显示）
      if (this.activeChips[0]) {
        TextInput({ placeholder: '目的地', text: this.tripDestination })
          .width('100%')
          .height(40)
          .maxLength(100)
          .fontSize(FONT_SIZE_BODY_SMALL)
          .fontColor(TEXT_MAIN)
          .placeholderColor(PLACEHOLDER_COLOR)
          .backgroundColor(INPUT_BG)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })))
          .onChange((value: string) => { this.onDestinationChange(value); })
      }
      if (this.activeChips[1]) {
        TextInput({ placeholder: '预计里程 km', text: this.tripDistanceKm })
          .width('100%')
          .height(40)
          .maxLength(20)
          .fontSize(FONT_SIZE_BODY_SMALL)
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
        TextInput({ placeholder: '最高海拔 m', text: this.tripMaxAltitude })
          .width('100%')
          .height(40)
          .maxLength(20)
          .fontSize(FONT_SIZE_BODY_SMALL)
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
        TextInput({ placeholder: '累计爬升 m', text: this.tripAscentM })
          .width('100%')
          .height(40)
          .maxLength(20)
          .fontSize(FONT_SIZE_BODY_SMALL)
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
        TextInput({ placeholder: '预计时长 h', text: this.tripDurationHours })
          .width('100%')
          .height(40)
          .maxLength(20)
          .fontSize(FONT_SIZE_BODY_SMALL)
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
        .maxLength(50)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
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
          .fontSize(FONT_SIZE_BODY_MEDIUM)
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
        .fontSize(FONT_SIZE_TITLE_MEDIUM)
        .fontWeight(FontWeight.Bold)
        .fontColor(WHITE)
        .opacity(0.9)
      Text('装备就绪 · 轻装出发')
        .fontSize(FONT_SIZE_CAPTION)
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
      // 情绪化标题（圆点 + 文字）：底层常驻深色，叠加层主题绿光泽随 titleGlow 呼吸
      Stack() {
        // 底层：常驻深色文字
        Row({ space: 0 }) {
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
          Circle({ width: 4, height: 4 })
            .fill(PRIMARY_FILL_SUBTLE)
            .margin({ left: 4 })
          Text('新的冒险即将开始')
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .margin({ left: 10, right: 10 })
          Circle({ width: 4, height: 4 })
            .fill(PRIMARY_FILL_SUBTLE)
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
            .margin({ left: 4 })
        }
        .alignItems(VerticalAlign.Center)

        // 叠加层：主题绿光泽，opacity 随 titleGlow 呼吸（深色文字表面流过一层绿光泽）
        Row({ space: 0 }) {
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
          Circle({ width: 4, height: 4 })
            .fill(PRIMARY_COLOR)
            .margin({ left: 4 })
          Text('新的冒险即将开始')
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_COLOR)
            .margin({ left: 10, right: 10 })
          Circle({ width: 4, height: 4 })
            .fill(PRIMARY_COLOR)
          Circle({ width: 6, height: 6 })
            .fill(PRIMARY_COLOR)
            .margin({ left: 4 })
        }
        .alignItems(VerticalAlign.Center)
        .opacity(this.titleGlow)
      }
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
      .animation({ curve: SPRING_GENERAL() })

      // 间距 16vp（同组内）
      Column().height(16)

      // 日期选择 — 直接内联避免 @Builder 回调 this 丢失
      Row() {
        Text(this.tripDate.length > 0 ? this.tripDate : '什么时候出发？')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
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
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_HALF)
            .opacity(this.trackTextOpacity)
            .animation({ curve: SPRING_GENERAL() })
          Text('准备出发！')
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_COLOR)
            .opacity(this.readyTextOpacity)
            .animation({ curve: SPRING_GENERAL() })
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
          .animation({ curve: SPRING_CEREMONY_FLIP() })
        Circle({ width: 48, height: 48 })
          .fill(PRIMARY_COLOR)
          .position({ x: this.getMaxSlide(), y: 0 })
          .scale({ x: this.ripple2Scale, y: this.ripple2Scale })
          .opacity(this.ripple2Opacity)
          .animation({ curve: SPRING_CEREMONY_FLIP() })

        // ⑤ 滑块：纯色正圆 + 白色飞机
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.SLIDER_WIDTH)
            .height(this.SLIDER_HEIGHT)
            .borderRadius(this.SLIDER_HEIGHT / 2)
            .backgroundColor(this.sliderBgColor)
            .animation({ curve: SPRING_GENERAL() })

          SymbolGlyph($r('sys.symbol.airplane'))
            .fontSize(FONT_SIZE_TITLE_MEDIUM)
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
      .animation({ curve: SPRING_SCROLL() })
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
      event.stopPropagation();
    })
    .opacity(this.cardRotateY <= 90 ? 1 : 0)
    .hitTestBehavior(this.cardRotateY <= 90 ? HitTestMode.Default : HitTestMode.None)
  }
}
