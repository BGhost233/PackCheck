import { curves } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { inputMethod } from '@kit.IMEKit';
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

  // === 标题 shimmer ===
  @State private titleShimmerX: number = -60;
  private titleShimmerTimer: number = -1;
  private titleRowWidth: number = 200;

  // === 输入框抖动 ===
  @State private titleShakeX: number = 0;
  @State private titleBorderHighlight: boolean = false;

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
    }, 350);

    // 内容错落入场：紧跟翻转，不等完全 settle
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.contentStep = 1;
      });
      // 标题入场完成后 300ms 启动标题 shimmer
      setTimeout(() => {
        this.startTitleShimmer();
      }, 300);
    }, 300);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.contentStep = 2;
      });
    }, 360);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.contentStep = 3;
      });
    }, 420);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
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
      duration: 1200,
      curve: Curve.EaseInOut
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
      duration: 1200,
      curve: Curve.EaseInOut
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

    // 按压态
    this.getUIContext().animateTo({
      duration: 120,
      curve: curves.springMotion(0.25, 0.7)
    }, () => {
      this.sliderPressed = true;
    });

    // 轻触确认
    this.vibratePreset('haptic.tick');
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

    // 磁吸：超过 85% 自动吸附
    if (progress >= this.MAGNET_THRESHOLD) {
      this.completeSlide();
    }
  }

  private onSlideEnd(): void {
    if (!this.isSliding || this.isSlideComplete) return;
    this.isSliding = false;

    // 松开按压态
    this.getUIContext().animateTo({
      duration: 120,
      curve: curves.springMotion(0.25, 0.7)
    }, () => {
      this.sliderPressed = false;
    });

    // 未到磁吸点，弹回
    if (this.getProgress() < this.MAGNET_THRESHOLD) {
      this.getUIContext().animateTo({
        duration: 400,
        curve: curves.springMotion(0.35, 0.78)
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
  // 滑动完成
  // ============================================================
  private completeSlide(): void {
    if (this.isSlideComplete) return;
    this.isSlideComplete = true;
    this.isSliding = false;
    this.stopShimmer();
    this.stopTitleShimmer();

    // 吸附到终点
    const maxSlide = this.getMaxSlide();
    this.getUIContext().animateTo({
      duration: 100,
      curve: Curve.EaseOut
    }, () => {
      this.slideX = maxSlide;
      this.sliderPressed = false;
    });

    // 到达膨胀 + haptic
    this.vibratePreset('haptic.sharp.strong');
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 150,
        curve: curves.springMotion(0.25, 0.7)
      }, () => {
        this.sliderBounceScale = 1.08;
      });
    }, 80);
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: 200,
        curve: curves.springMotion(0.3, 0.75)
      }, () => {
        this.sliderBounceScale = 1.0;
      });
    }, 200);

    // 数据先于动画
    this.onFinish();

    // 卡片飘走（延迟 350ms 让用户看到咬合反馈）
    setTimeout(() => {
      this.flyAway();
    }, 380);
  }

  // ============================================================
  // 卡片飘走
  // ============================================================
  private flyAway(): void {
    this.stopTitleShimmer();
    this.getUIContext().animateTo({
      duration: 400,
      curve: curves.springMotion(0.35, 0.78)
    }, () => {
      this.launchTranslateY = -800;
      this.launchScale = 0.85;
      this.launchOpacity = 0;
      this.launchRotate = -3;
    });

    // 遮罩消散
    this.getUIContext().animateTo({
      duration: 350,
      curve: Curve.EaseOut
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
    sequence.forEach((x) => {
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 80, curve: Curve.EaseOut }, () => {
          this.titleShakeX = x;
        });
      }, delay);
      delay += 80;
    });

    // 边框闪红
    this.titleBorderHighlight = true;
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
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

  // ============================================================
  // 退出
  // ============================================================
  private handleDismiss(): void {
    if (this.isSliding || this.isSlideComplete) return;

    this.stopShimmer();
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
        .backdropBlur(this.overlayOpacity > 0 ? 25 : 0)
        .onClick(() => {
          inputMethod.getController().stopInputSession();
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
      .height(300)
      .constraintSize({ maxWidth: 340 })
      .borderRadius(24)
      .clip(true)
      .shadow({
        radius: this.cardElevation,
        color: '#1A000000',
        offsetY: this.cardElevation / 3
      })
      .scale({
        x: this.cardScale * this.launchScale,
        y: this.cardScale * this.launchScale
      })
      .rotate({ x: 0, y: 1, z: 0, angle: this.cardRotateY, perspective: 800 })
      .rotate({ x: 0, y: 0, z: 1, angle: this.cardRotateZ + this.launchRotate })
      .translate({
        x: 0,
        y: this.cardTranslateY + this.launchTranslateY
      })
      .opacity(this.cardOpacity * this.launchOpacity)
    }
    .width('100%')
    .height('100%')
  }

  // ============================================================
  // Builders
  // ============================================================
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
        .placeholderColor('#BBBBBB')
        .backgroundColor('#F7F8F7')
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
          .fontColor(text.length > 0 ? TEXT_MAIN : '#BBBBBB')
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F7F8F7')
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
        .fontColor('#FFFFFF')
        .opacity(0.9)
      Text('装备清单 · 轻装出发')
        .fontSize(12)
        .fontColor('#FFFFFF')
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
            .fill('#2D7D4660')
            .margin({ left: 4 })

          // 标题文字
          Text('新的冒险即将开始')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ left: 10, right: 10 })

          // 右侧圆点组
          Circle({ width: 4, height: 4 })
            .fill('#2D7D4660')
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
            colors: [['#00FFFFFF', 0], ['#40FFFFFF', 0.5], ['#00FFFFFF', 1.0]]
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
        color: this.titleBorderHighlight ? '#FF4444' : '#00FFFFFF',
        radius: 12
      })
      .animation({ duration: 200, curve: Curve.EaseOut })

      // 间距 16vp（同组内）
      Column().height(16)

      // 日期选择 — 直接内联避免 @Builder 回调 this 丢失
      Row() {
        Text(this.tripDate.length > 0 ? this.tripDate : '什么时候出发？')
          .fontSize(14)
          .fontColor(this.tripDate.length > 0 ? TEXT_MAIN : '#BBBBBB')
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F7F8F7')
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
            const month = value.getMonth() + 1;
            const day = value.getDate();
            const dateStr = month.toString() + '月' + day.toString() + '日';
            this.onDateChange(dateStr);
          }
        });
      })

      // 跨组间距 24vp
      Column().height(24)

      // ========== 滑动出发滑轨 ==========
      Stack({ alignContent: Alignment.Center }) {
        // ① 轨道背景（最底层）
        Row()
          .width('100%')
          .height(this.TRACK_HEIGHT)
          .borderRadius(this.TRACK_HEIGHT / 2)
          .backgroundColor('#F0F4F0')

        // ② 文案（轨道内居中）
        Text('滑动出发')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#802D7D46')

        // ③ 白色遮罩（盖住左侧轨道 + 文字）
        Row()
          .width(this.slideX + this.SLIDER_WIDTH / 2)
          .height(this.TRACK_HEIGHT)
          .backgroundColor('#FFFFFF')
          .borderRadius({ topLeft: this.TRACK_HEIGHT / 2, bottomLeft: this.TRACK_HEIGHT / 2 })
          .position({ x: 0, y: (this.SLIDER_HEIGHT - this.TRACK_HEIGHT) / 2 })

        // ④ 滑块：纯色正圆 + 白色飞机
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.SLIDER_WIDTH)
            .height(this.SLIDER_HEIGHT)
            .borderRadius(this.SLIDER_HEIGHT / 2)
            .backgroundColor('#2D7D46')

          SymbolGlyph($r('sys.symbol.airplane'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .width(this.SLIDER_WIDTH)
        .height(this.SLIDER_HEIGHT)
        .position({ x: this.slideX, y: 0 })
        .scale({
          x: this.sliderPressed ? 0.92 : this.sliderBounceScale,
          y: this.sliderPressed ? 0.92 : this.sliderBounceScale
        })

        // ⑤ 触摸热区（56×56，透明扩展）
        Column()
          .width(56)
          .height(56)
          .backgroundColor('#00FFFFFF')
          .position({
            x: this.slideX - (56 - this.SLIDER_WIDTH) / 2,
            y: (this.SLIDER_HEIGHT - 56) / 2
          })
      }
      .width('100%')
      .height(this.SLIDER_HEIGHT)
      .clip(false)
      .opacity(this.contentStep >= 4 ? 1 : 0)
      .scale({
        x: this.contentStep >= 4 ? 1.0 : 0.9,
        y: this.contentStep >= 4 ? 1.0 : 0.9
      })
      .translate({ y: this.contentStep >= 4 ? 0 : 10 })
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
    .backgroundColor('#FFFFFF')
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
