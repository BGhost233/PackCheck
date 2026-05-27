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
  private readonly SLIDER_WIDTH: number = 60;
  private readonly SLIDER_HEIGHT: number = 40;
  private readonly TRACK_HEIGHT: number = 52;
  private readonly TRACK_PADDING: number = 6;
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
  }

  // ============================================================
  // 计算属性
  // ============================================================
  private getMaxSlide(): number {
    // 滑轨内部可用宽度 - 滑块宽度
    return this.trackWidth - this.SLIDER_WIDTH - this.TRACK_PADDING * 2;
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
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 1;
      });
    }, 420);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 2;
      });
    }, 490);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 3;
      });
    }, 560);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.contentStep = 4;
      });
      // 入场完毕后启动 shimmer
      setTimeout(() => {
        this.startShimmer();
      }, 200);
    }, 630);
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
  // 滑动手势
  // ============================================================
  private onSlideStart(x: number): void {
    if (this.isSlideComplete) return;
    if (this.tripTitle.trim().length === 0) {
      this.shakeEmpty();
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
      .constraintSize({ maxWidth: 340, maxHeight: 380 })
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
  private InsetInput(placeholder: string, text: string, showCalendar: boolean, stepIndex: number,
    onTextChange?: (value: string) => void, onTap?: () => void) {
    Stack() {
      // 主体背景
      Column()
        .width('100%')
        .height(52)
        .borderRadius(14)
        .backgroundColor('#F5F7F5')
        .border({ width: 1, color: '#06000000' })

      // 顶部内阴影（模拟凹陷）
      Column()
        .width('100%')
        .height(8)
        .linearGradient({
          angle: 180,
          colors: [['#0000000A', 0], ['#00000000', 1]]
        })
        .borderRadius({ topLeft: 14, topRight: 14 })

      // 底部高光线（反光）
      Column()
        .width('85%')
        .height(1)
        .backgroundColor('#FFFFFF')
        .opacity(0.6)
        .borderRadius(1)
        .position({ x: '7.5%', bottom: 7 })

      // 内容层
      if (onTextChange) {
        TextInput({ placeholder: placeholder, text: text })
          .width('100%')
          .height(52)
          .fontSize(15)
          .fontColor(TEXT_MAIN)
          .placeholderColor('#AAAAAA')
          .backgroundColor('#00FFFFFF')
          .borderRadius(14)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            onTextChange(value);
          })
      } else {
        Row() {
          Text(text.length > 0 ? text : placeholder)
            .fontSize(15)
            .fontColor(text.length > 0 ? TEXT_MAIN : '#AAAAAA')
            .layoutWeight(1)
          if (showCalendar) {
            Text('日历')
              .fontSize(12)
              .fontColor('#999999')
          }
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          if (onTap) onTap();
        })
      }
    }
    .width('100%')
    .height(52)
    .opacity(this.contentStep >= stepIndex ? 1 : 0)
    .translate({ y: this.contentStep >= stepIndex ? 0 : 8 })
  }

  @Builder
  private CeremonyCardFront() {
    Column() {
      // 情绪化标题
      Text('新的冒险即将开始')
        .fontSize(14)
        .fontColor('#999999')
        .opacity(this.contentStep >= 1 ? 1 : 0)
        .translate({ y: this.contentStep >= 1 ? 0 : 6 })
        .margin({ top: 32, bottom: 28 })

      // 行程名称输入（3D 内凹）
      this.InsetInput('给这次旅途取个名字吧', this.tripTitle, false, 2,
        (value: string) => { this.onTitleChange(value); })

      // 间距 16vp（同组内）
      Column().height(16)

      // 日期选择（3D 内凹）
      this.InsetInput('什么时候出发？', this.tripDate, true, 3, undefined,
        () => {
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

      // 跨组间距 36vp
      Column().height(36)

      // ========== 滑动出发滑轨 ==========
      Stack({ alignContent: Alignment.Start }) {
        // 轨道背景（内凹层次）
        Stack() {
          // 渐变背景
          Column()
            .width('100%')
            .height('100%')
            .borderRadius(this.TRACK_HEIGHT / 2)
            .linearGradient({
              angle: 180,
              colors: [['#E8F5E9', 0], ['#F1F8F2', 1]]
            })

          // 顶部内阴影
          Column()
            .width('100%')
            .height(4)
            .linearGradient({
              angle: 180,
              colors: [['#00000008', 0], ['#00000000', 1]]
            })
            .borderRadius({ topLeft: this.TRACK_HEIGHT / 2, topRight: this.TRACK_HEIGHT / 2 })

          // 底部内高光
          Column()
            .width('80%')
            .height(1)
            .backgroundColor('#FFFFFF')
            .opacity(0.5)
            .borderRadius(1)
            .position({ x: '10%', bottom: 5 })
        }
        .width('100%')
        .height('100%')
        .borderRadius(this.TRACK_HEIGHT / 2)
        .border({ width: 1, color: '#2D7D4610' })
        .clip(true)

        // 已滑过区域（动态宽度 + clip）
        Column()
          .width(this.slideX + this.SLIDER_WIDTH / 2 + this.TRACK_PADDING)
          .height('100%')
          .borderRadius(this.TRACK_HEIGHT / 2)
          .linearGradient({
            angle: 90,
            colors: [['#2D7D4612', 0], ['#2D7D4628', 1]]
          })
          .clip(true)

        // 终点虚影（右端胶囊）
        Column()
          .width(this.SLIDER_WIDTH)
          .height(this.SLIDER_HEIGHT)
          .borderRadius(this.SLIDER_HEIGHT / 2)
          .backgroundColor('#2D7D46')
          .opacity(this.targetGlowOpacity)
          .scale({ x: this.targetGlowScale, y: this.targetGlowScale })
          .position({
            x: Math.max(0, this.getMaxSlide()) + this.TRACK_PADDING,
            y: (this.TRACK_HEIGHT - this.SLIDER_HEIGHT) / 2
          })
          .animation({ duration: 200, curve: Curve.EaseOut })

        // 文案 + shimmer
        Stack({ alignContent: Alignment.Center }) {
          Text('滑动出发')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#702D7D46')
            .opacity(1 - this.getProgress())

          // shimmer 高光条
          Row()
            .width(50)
            .height(18)
            .borderRadius(9)
            .linearGradient({
              angle: 90,
              colors: [['#00FFFFFF', 0], ['#60FFFFFF', 0.5], ['#00FFFFFF', 1.0]]
            })
            .translate({ x: this.shimmerX })
            .opacity(this.isSliding ? 0 : (1 - this.getProgress()))
        }
        .width('100%')
        .height('100%')
        .clip(true)

        // 液态胶囊滑块（视觉层）
        Stack({ alignContent: Alignment.Center }) {
          // 主体渐变胶囊（含外发光 shadow）
          Column()
            .width(this.SLIDER_WIDTH)
            .height(this.SLIDER_HEIGHT)
            .borderRadius(this.SLIDER_HEIGHT / 2)
            .linearGradient({
              angle: 135,
              colors: [['#3A9D5B', 0], ['#2D7D46', 0.6], ['#236B38', 1.0]]
            })
            .border({ width: 1, color: '#FFFFFF2E' })
            .shadow({
              radius: 14,
              color: '#2D7D4640',
              offsetX: 0,
              offsetY: 2
            })

          // 顶部内高光弧（玻璃质感）
          Column()
            .width('80%')
            .height('40%')
            .borderRadius(16)
            .linearGradient({
              angle: 180,
              colors: [['#38FFFFFF', 0], ['#00FFFFFF', 1]]
            })
            .position({ x: '10%', top: 3 })

          // 简洁箭头
          Text('›')
            .fontSize(22)
            .fontWeight(FontWeight.Normal)
            .fontColor('#FFFFFFDD')
        }
        .width(this.SLIDER_WIDTH)
        .height(this.SLIDER_HEIGHT)
        .translate({
          x: this.slideX + this.TRACK_PADDING,
          y: (this.TRACK_HEIGHT - this.SLIDER_HEIGHT) / 2
        })
        .scale({
          x: this.sliderPressed ? 0.92 : this.sliderBounceScale,
          y: this.sliderPressed ? 0.92 : this.sliderBounceScale
        })

        // 触摸热区（72×52，透明扩展）
        Column()
          .width(72)
          .height(this.TRACK_HEIGHT)
          .backgroundColor('#00FFFFFF')
          .position({
            x: this.slideX + this.TRACK_PADDING - (72 - this.SLIDER_WIDTH) / 2,
            y: 0
          })
      }
      .width('100%')
      .height(this.TRACK_HEIGHT)
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
    .padding({ left: 24, right: 24, bottom: 28 })
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(24)
    .clip(true)
    .opacity(this.cardRotateY <= 90 ? 1 : 0)
    .hitTestBehavior(this.cardRotateY <= 90 ? HitTestMode.Default : HitTestMode.None)
  }
}
