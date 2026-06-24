// 「我」Tab：年报式叙事长页。纯数据沉淀，无功能入口。
// 每个叙事段落独立入场动画，数字 counter 滚动，时间线错落淡入。
import { GearItem, TripChecklist } from '../models/PackModels';
import { computeFootprint, Footprint, LongestCompanion, TripSummary } from '../services/FootprintService';
import {
  PRIMARY_COLOR, PRIMARY_PRESSED, CARD_BG, PAGE_BG, TEXT_MAIN, TEXT_SECONDARY, TEXT_TERTIARY,
  WHITE_SECONDARY, WHITE_SEMI_TRANSPARENT, PRIMARY_TINT_COLOR, LIGHT_PRIMARY_COLOR
} from '../constants/Colors';
import { PAGE_PADDING, CARD_RADIUS, CARD_PADDING, CHIP_RADIUS, FONT_FEATURE_TNUM } from '../constants/Layout';
import { counterAnimate, stopCounterAnimate, CounterTimerHandle } from '../utils/AnimationUtils';
import {
  SPRING_GENERAL, SPRING_PRESS, STAGGER_OFFSET_Y, staggerDelay,
  PRESS_SCALE_DOWN, PRESS_SCALE_REST
} from '../constants/AnimationTokens';

@Component
export struct ProfilePage {
  @Prop @Watch('onDataChange') trips: TripChecklist[] = [];
  @Prop @Watch('onDataChange') gears: GearItem[] = [];
  // tabVisibilityNonce：父层每次切至此 tab 时递增，驱动入场动画重播
  // 解决 ArkUI TabContent keep-alive 时 aboutToAppear 不触发的问题
  @Prop @Watch('onTabVisibilityNonceChange') tabVisibilityNonce: number = 0;

  @State private footprint: Footprint = {
    tripCount: 0, totalDistanceKm: 0, totalAscentM: 0, totalDurationHours: 0,
    maxAltitude: 0, placeCount: 0, gearCount: 0, recentTrips: [],
  };

  // counter 滚动展示值
  @State private animDistance: number = 0;
  @State private animAscent: number = 0;
  @State private animTrips: number = 0;
  @State private animPlaces: number = 0;
  @State private animDays: number = 0;
  @State private animGearCount: number = 0;
  @State private animMaxAlt: number = 0;
  @State private animDuration: number = 0;

  // 段落 staggered 入场
  @State private heroOpacity: number = 0;
  @State private heroTranslateY: number = STAGGER_OFFSET_Y;
  @State private timelineOpacity: number = 0;
  @State private timelineTranslateY: number = STAGGER_OFFSET_Y;
  @State private companionOpacity: number = 0;
  @State private companionTranslateY: number = STAGGER_OFFSET_Y;
  @State private gridOpacity: number = 0;
  @State private gridTranslateY: number = STAGGER_OFFSET_Y;
  @State private outroOpacity: number = 0;

  // 时间线各条目入场
  @State private timelineItemOpacities: number[] = [0, 0, 0, 0, 0];
  @State private timelineItemTranslateY: number[] = [STAGGER_OFFSET_Y, STAGGER_OFFSET_Y, STAGGER_OFFSET_Y, STAGGER_OFFSET_Y, STAGGER_OFFSET_Y];

  // 按压反馈
  @State private companionPressed: boolean = false;
  @State private gridPressedIndex: number = -1;

  private hasAppeared: boolean = false;
  // 在途的数字滚动动画句柄（组件销毁/数据刷新前取消，避免竞争）
  private counterHandles: CounterTimerHandle[] = [];
  // 错落入场 setTimeout handle（组件销毁时清除，避免销毁后调 animateTo）
  private staggerTimerIds: number[] = [];
  private isAlive: boolean = true;

  aboutToAppear(): void {
    this.isAlive = true;
    this.refreshFootprint(true);
    // 段落错落入场
    this.staggerSections();
    this.hasAppeared = true;
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    this.cancelAllCounters();
    this.clearAllStaggerTimers();
  }

  // shared：所有错落入场 @State 回零（被 onTabVisibilityNonceChange 复用）
  // 首次挂载时 @State 初始值已为零，仅 tab 重显时需要手动重置
  private resetStaggerStates(): void {
    this.heroOpacity = 0;
    this.heroTranslateY = STAGGER_OFFSET_Y;
    this.timelineOpacity = 0;
    this.timelineTranslateY = STAGGER_OFFSET_Y;
    this.companionOpacity = 0;
    this.companionTranslateY = STAGGER_OFFSET_Y;
    this.gridOpacity = 0;
    this.gridTranslateY = STAGGER_OFFSET_Y;
    this.outroOpacity = 0;
    this.timelineItemOpacities = [0, 0, 0, 0, 0];
    this.timelineItemTranslateY = [
      STAGGER_OFFSET_Y, STAGGER_OFFSET_Y, STAGGER_OFFSET_Y, STAGGER_OFFSET_Y, STAGGER_OFFSET_Y
    ];
    // counter 展示值归零
    this.animDistance = 0;
    this.animAscent = 0;
    this.animTrips = 0;
    this.animPlaces = 0;
    this.animDays = 0;
    this.animGearCount = 0;
    this.animMaxAlt = 0;
    this.animDuration = 0;
  }

  // tab 可见性变化时重置并重播全部入场动画
  onTabVisibilityNonceChange(): void {
    this.clearAllStaggerTimers();
    this.cancelAllCounters();
    this.resetStaggerStates();
    this.refreshFootprint(true);
    this.staggerSections();
    // hasAppeared 不重置 — 它是功能 guard，hidden tab 期间需继续响应数据变更
  }

  private clearAllStaggerTimers(): void {
    for (const id of this.staggerTimerIds) {
      clearTimeout(id);
    }
    this.staggerTimerIds = [];
  }

  onDataChange(): void {
    if (this.hasAppeared) {
      this.refreshFootprint(false);
    }
  }

  private staggerSections(): void {
    // Hero 区
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.heroOpacity = 1;
        this.heroTranslateY = 0;
      });
    }, 60);
    this.staggerTimerIds.push(id);
    // 时间线段
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.timelineOpacity = 1;
        this.timelineTranslateY = 0;
      });
      // 时间线各条目逐条入场
      for (let i = 0; i < 5; i++) {
        const itemId = setTimeout(() => {
          if (!this.isAlive) { return; }
          this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
            const opacities = this.timelineItemOpacities.slice();
            opacities[i] = 1;
            this.timelineItemOpacities = opacities;
            const translates = this.timelineItemTranslateY.slice();
            translates[i] = 0;
            this.timelineItemTranslateY = translates;
          });
        }, staggerDelay(i, 60));
        this.staggerTimerIds.push(itemId);
      }
    }, staggerDelay(1, 120));
    this.staggerTimerIds.push(id);
    // 伙伴段
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.companionOpacity = 1;
        this.companionTranslateY = 0;
      });
    }, staggerDelay(2, 120));
    this.staggerTimerIds.push(id);
    // 数字群像
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.gridOpacity = 1;
        this.gridTranslateY = 0;
      });
    }, staggerDelay(3, 120));
    this.staggerTimerIds.push(id);
    // 尾声
    id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.outroOpacity = 1;
      });
    }, staggerDelay(4, 120));
    this.staggerTimerIds.push(id);
  }

  private refreshFootprint(animate: boolean): void {
    // 取消在途的数字滚动动画，避免多轮动画竞争同一 @State
    this.cancelAllCounters();

    const prev = this.footprint;
    this.footprint = computeFootprint(this.trips, this.gears);
    if (animate) {
      this.counterHandles.push(counterAnimate(0, this.footprint.totalDistanceKm, (v: number) => {
        this.animDistance = Math.round(v * 10) / 10;
      }));
      this.counterHandles.push(counterAnimate(0, this.footprint.totalAscentM, (v: number) => {
        this.animAscent = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(0, this.footprint.tripCount, (v: number) => {
        this.animTrips = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(0, this.footprint.placeCount, (v: number) => {
        this.animPlaces = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(0, this.footprint.gearCount, (v: number) => {
        this.animGearCount = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(0, this.footprint.maxAltitude, (v: number) => {
        this.animMaxAlt = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(0, this.footprint.totalDurationHours, (v: number) => {
        this.animDuration = Math.round(v * 10) / 10;
      }));
      const companion: LongestCompanion | undefined = this.footprint.longestCompanion;
      if (companion !== undefined) {
        this.counterHandles.push(counterAnimate(0, companion.days, (v: number) => {
          this.animDays = Math.round(v);
        }));
      }
    } else {
      this.counterHandles.push(counterAnimate(prev.totalDistanceKm, this.footprint.totalDistanceKm, (v: number) => {
        this.animDistance = Math.round(v * 10) / 10;
      }));
      this.counterHandles.push(counterAnimate(prev.totalAscentM, this.footprint.totalAscentM, (v: number) => {
        this.animAscent = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(prev.tripCount, this.footprint.tripCount, (v: number) => {
        this.animTrips = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(prev.placeCount, this.footprint.placeCount, (v: number) => {
        this.animPlaces = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(prev.gearCount, this.footprint.gearCount, (v: number) => {
        this.animGearCount = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(prev.maxAltitude, this.footprint.maxAltitude, (v: number) => {
        this.animMaxAlt = Math.round(v);
      }));
      this.counterHandles.push(counterAnimate(prev.totalDurationHours, this.footprint.totalDurationHours, (v: number) => {
        this.animDuration = Math.round(v * 10) / 10;
      }));
      const companion: LongestCompanion | undefined = this.footprint.longestCompanion;
      const prevDays = prev.longestCompanion !== undefined ? prev.longestCompanion.days : 0;
      if (companion !== undefined) {
        this.counterHandles.push(counterAnimate(prevDays, companion.days, (v: number) => {
          this.animDays = Math.round(v);
        }));
      }
    }
  }

  private cancelAllCounters(): void {
    for (const handle of this.counterHandles) {
      stopCounterAnimate(handle);
    }
    this.counterHandles = [];
  }

  build() {
    Scroll() {
      Column() {
        // ═══════════════════════════════════════════════
        // 第一段 · 开篇英雄区 — 总里程
        // ═══════════════════════════════════════════════
        Column() {
          Text('这一路走来')
            .fontSize(14)
            .fontColor(WHITE_SECONDARY)
            .margin({ bottom: 12 })

          if (this.footprint.totalDistanceKm > 0) {
            Row() {
              Text(`${this.animDistance}`)
                .fontSize(56)
                .fontWeight(FontWeight.Bold)
                .fontColor(CARD_BG)
                .fontFeature(FONT_FEATURE_TNUM)
              Text(' 公里')
                .fontSize(16)
                .fontColor(WHITE_SECONDARY)
                .margin({ bottom: 10 })
            }
            .alignItems(VerticalAlign.Bottom)
          } else {
            Text('每一步都算数')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(CARD_BG)
          }

          // 三 chip 行
          Row({ space: 8 }) {
            if (this.footprint.tripCount > 0) {
              this.footprintChip(`同行 ${this.animTrips} 次`)
            }
            if (this.footprint.placeCount > 0) {
              this.footprintChip(`${this.animPlaces} 个地方`)
            }
            if (this.footprint.totalAscentM > 0) {
              this.footprintChip(`爬升 ${this.animAscent} m`)
            }
          }
          .margin({ top: 20 })
        }
        .width('100%')
        .padding({ top: 80, bottom: 48, left: PAGE_PADDING, right: PAGE_PADDING })
        .linearGradient({
          angle: 160,
          colors: [[PRIMARY_COLOR, 0], [PRIMARY_PRESSED, 1]]
        })
        .borderRadius({ bottomLeft: 24, bottomRight: 24 })
        .alignItems(HorizontalAlign.Start)
        .opacity(this.heroOpacity)
        .translate({ y: this.heroTranslateY })

        // ═══════════════════════════════════════════════
        // 第二段 · 时间线叙事 — 最近行程
        // ═══════════════════════════════════════════════
        Column() {
          Text('你的足迹')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
            .margin({ bottom: 20 })

          if (this.footprint.recentTrips.length > 0) {
            Column() {
              ForEach(this.footprint.recentTrips, (trip: TripSummary, index: number) => {
                Row() {
                  // 左侧时间轴
                  Column() {
                    // 圆点
                    Column()
                      .width(8)
                      .height(8)
                      .borderRadius(4)
                      .backgroundColor(index === 0 ? PRIMARY_COLOR : TEXT_TERTIARY)
                    // 竖线（非最后一条）
                    if (index < this.footprint.recentTrips.length - 1) {
                      Column()
                        .width(1.5)
                        .layoutWeight(1)
                        .backgroundColor(LIGHT_PRIMARY_COLOR)
                        .margin({ top: 4 })
                    }
                  }
                  .width(20)
                  .alignItems(HorizontalAlign.Center)
                  .height('100%')

                  // 右侧内容卡片
                  Column() {
                    Row() {
                      Text(trip.dateLabel)
                        .fontSize(12)
                        .fontColor(TEXT_TERTIARY)
                      if (trip.destination.length > 0) {
                        Text(` · ${trip.destination}`)
                          .fontSize(12)
                          .fontColor(TEXT_SECONDARY)
                      }
                    }
                    .margin({ bottom: 4 })

                    Text(trip.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(TEXT_MAIN)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    // 数据标签行
                    Row({ space: 12 }) {
                      if (trip.distanceKm !== undefined && trip.distanceKm > 0) {
                        Text(`${trip.distanceKm}km`)
                          .fontSize(11)
                          .fontColor(TEXT_TERTIARY)
                      }
                      if (trip.ascentM !== undefined && trip.ascentM > 0) {
                        Text(`${trip.ascentM}m↑`)
                          .fontSize(11)
                          .fontColor(TEXT_TERTIARY)
                      }
                      if (trip.gearCount > 0) {
                        Text(`${trip.gearCount}件装备`)
                          .fontSize(11)
                          .fontColor(TEXT_TERTIARY)
                      }
                    }
                    .margin({ top: 6 })
                  }
                  .layoutWeight(1)
                  .padding({ left: 12, top: 0, bottom: 20 })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .opacity(this.timelineItemOpacities[index] !== undefined ? this.timelineItemOpacities[index] : 0)
                .translate({ y: this.timelineItemTranslateY[index] !== undefined ? this.timelineItemTranslateY[index] : STAGGER_OFFSET_Y })
              }, (trip: TripSummary) => trip.id)
            }
          } else {
            // 空数据态
            Column() {
              Text('第一次出发，从这里开始')
                .fontSize(14)
                .fontColor(TEXT_TERTIARY)
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding({ top: 48, left: PAGE_PADDING, right: PAGE_PADDING })
        .alignItems(HorizontalAlign.Start)
        .opacity(this.timelineOpacity)
        .translate({ y: this.timelineTranslateY })

        // ═══════════════════════════════════════════════
        // 第三段 · 最久伙伴
        // ═══════════════════════════════════════════════
        if (this.footprint.longestCompanion !== undefined) {
          Column() {
            Text('相伴最久')
              .fontSize(13)
              .fontColor(TEXT_TERTIARY)
              .margin({ bottom: 12 })

            Text(`「${this.footprint.longestCompanion.name}」`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(TEXT_MAIN)

            Row() {
              Text(`${this.animDays}`)
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
                .fontColor(PRIMARY_COLOR)
                .fontFeature(FONT_FEATURE_TNUM)
              Text(' 天了')
                .fontSize(15)
                .fontColor(TEXT_SECONDARY)
                .margin({ bottom: 6 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ top: 8 })

            Text('它一直在你身边')
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
              .margin({ top: 16 })
              .opacity(0.8)
          }
          .width('100%')
          .padding(CARD_PADDING)
          .backgroundColor(PRIMARY_TINT_COLOR)
          .borderRadius(CARD_RADIUS)
          .margin({ top: 48, left: PAGE_PADDING, right: PAGE_PADDING })
          .alignItems(HorizontalAlign.Start)
          .opacity(this.companionOpacity)
          .translate({ y: this.companionTranslateY })
          .scale({ x: this.companionPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST, y: this.companionPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
          .animation({ curve: SPRING_PRESS() })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.companionPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.companionPressed = false;
            }
          })
        }

        // ═══════════════════════════════════════════════
        // 第四段 · 数字群像 2×2 网格
        // ═══════════════════════════════════════════════
        Column() {
          Grid() {
            // 装备伙伴数
            GridItem() {
              this.StatCell(`${this.animGearCount}`, '件装备陪着你', 0)
            }
            // 到过的最高处
            GridItem() {
              if (this.footprint.maxAltitude > 0) {
                this.StatCell(`${this.animMaxAlt}m`, '到过的最高处', 1)
              } else {
                this.StatCell('—', '等你去探索', 1)
              }
            }
            // 累计爬升
            GridItem() {
              if (this.footprint.totalAscentM > 0) {
                this.StatCell(`${this.animAscent}m`, '累计向上攀登', 2)
              } else {
                this.StatCell('—', '每一步都是向上', 2)
              }
            }
            // 去过的地方
            GridItem() {
              if (this.footprint.placeCount > 0) {
                this.StatCell(`${this.animPlaces}`, '个地方留下足迹', 3)
              } else {
                this.StatCell('—', '世界在等你', 3)
              }
            }
            // 累计在路上
            GridItem() {
              if (this.footprint.totalDurationHours > 0) {
                this.StatCell(`${this.animDuration}h`, '累计在路上', 4)
              } else {
                this.StatCell('—', '出发就是意义', 4)
              }
            }
            // 累计里程
            GridItem() {
              if (this.footprint.totalDistanceKm > 0) {
                this.StatCell(`${this.animDistance}km`, '双脚丈量过', 5)
              } else {
                this.StatCell('—', '每一步都算数', 5)
              }
            }
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr')
          .columnsGap(12)
          .rowsGap(12)
          .width('100%')
          .height(360)
        }
        .width('100%')
        .padding({ top: 48, left: PAGE_PADDING, right: PAGE_PADDING })
        .opacity(this.gridOpacity)
        .translate({ y: this.gridTranslateY })

        // ═══════════════════════════════════════════════
        // 尾声 · 留白签名
        // ═══════════════════════════════════════════════
        Column() {
          Text('故事都在你心里')
            .fontSize(13)
            .fontColor(TEXT_TERTIARY)
            .opacity(0.6)
        }
        .width('100%')
        .padding({ top: 60, bottom: 140 })
        .alignItems(HorizontalAlign.Center)
        .opacity(this.outroOpacity)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(PAGE_BG)
  }

  // ═══════════════════════════════════════════════
  // Builders
  // ═══════════════════════════════════════════════

  @Builder
  footprintChip(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(CARD_BG)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(WHITE_SEMI_TRANSPARENT)
      .borderRadius(CHIP_RADIUS)
  }

  @Builder
  StatCell(value: string, label: string, index: number) {
    Column() {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .fontFeature(FONT_FEATURE_TNUM)
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_TERTIARY)
        .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .padding(CARD_PADDING)
    .backgroundColor(CARD_BG)
    .borderRadius(CARD_RADIUS)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.End)
    .scale({ x: this.gridPressedIndex === index ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
      y: this.gridPressedIndex === index ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.gridPressedIndex = index;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.gridPressedIndex = -1;
      }
    })
  }
}
