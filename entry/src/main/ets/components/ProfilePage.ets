// 「我」Tab：人生足迹年报叙事。spec §4.1 / 决策 2。文案温柔拟人，留白为情感让路。
import { GearItem, TripChecklist } from '../models/PackModels';
import { computeFootprint, Footprint, LongestCompanion } from '../services/FootprintService';
import {
  PRIMARY_COLOR, CARD_BG, PAGE_BG, TEXT_MAIN, TEXT_SECONDARY, TEXT_TERTIARY,
  WHITE_SECONDARY, PRIMARY_TINT_COLOR, LIGHT_PRIMARY_COLOR
} from '../constants/Colors';
import { PAGE_PADDING, CARD_RADIUS, CARD_PADDING, CHIP_RADIUS } from '../constants/Layout';
import { counterAnimate } from '../utils/AnimationUtils';
import {
  SPRING_GENERAL, STAGGER_OFFSET_Y, staggerDelay
} from '../constants/AnimationTokens';

@Component
export struct ProfilePage {
  @Prop @Watch('onDataChange') trips: TripChecklist[] = [];
  @Prop @Watch('onDataChange') gears: GearItem[] = [];

  @State private footprint: Footprint = {
    tripCount: 0, totalDistanceKm: 0, totalAscentM: 0,
    maxAltitude: 0, placeCount: 0, gearCount: 0,
  };
  // counter 滚动展示值
  @State private animDistance: number = 0;
  @State private animAscent: number = 0;
  @State private animTrips: number = 0;
  @State private animPlaces: number = 0;
  @State private animDays: number = 0;
  // staggered 入场
  @State private cardOpacity: number = 0;
  @State private cardTranslateY: number = STAGGER_OFFSET_Y;
  // 是否已完成首次入场动画
  private hasAppeared: boolean = false;

  aboutToAppear(): void {
    this.refreshFootprint(true);
    // staggered 入场
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.cardOpacity = 1;
        this.cardTranslateY = 0;
      });
    }, 60);
    this.hasAppeared = true;
  }

  onDataChange(): void {
    if (this.hasAppeared) {
      this.refreshFootprint(false);
    }
  }

  private refreshFootprint(animate: boolean): void {
    const prev = this.footprint;
    this.footprint = computeFootprint(this.trips, this.gears);
    if (animate) {
      // 首次入场：从 0 滚动到真实值
      counterAnimate(0, this.footprint.totalDistanceKm, (v: number) => {
        this.animDistance = Math.round(v * 10) / 10;
      });
      counterAnimate(0, this.footprint.totalAscentM, (v: number) => {
        this.animAscent = Math.round(v);
      });
      counterAnimate(0, this.footprint.tripCount, (v: number) => {
        this.animTrips = Math.round(v);
      });
      counterAnimate(0, this.footprint.placeCount, (v: number) => {
        this.animPlaces = Math.round(v);
      });
      const companion: LongestCompanion | undefined = this.footprint.longestCompanion;
      if (companion !== undefined) {
        counterAnimate(0, companion.days, (v: number) => {
          this.animDays = Math.round(v);
        });
      }
    } else {
      // 数据变化时：从旧值滚动到新值
      counterAnimate(prev.totalDistanceKm, this.footprint.totalDistanceKm, (v: number) => {
        this.animDistance = Math.round(v * 10) / 10;
      });
      counterAnimate(prev.totalAscentM, this.footprint.totalAscentM, (v: number) => {
        this.animAscent = Math.round(v);
      });
      counterAnimate(prev.tripCount, this.footprint.tripCount, (v: number) => {
        this.animTrips = Math.round(v);
      });
      counterAnimate(prev.placeCount, this.footprint.placeCount, (v: number) => {
        this.animPlaces = Math.round(v);
      });
      const companion: LongestCompanion | undefined = this.footprint.longestCompanion;
      const prevDays = prev.longestCompanion !== undefined ? prev.longestCompanion.days : 0;
      if (companion !== undefined) {
        counterAnimate(prevDays, companion.days, (v: number) => {
          this.animDays = Math.round(v);
        });
      }
    }
  }

  build() {
    Scroll() {
      Column() {
        // ——— 顶部沉浸绿幕「人生足迹」黄金区 ———
        Column() {
          Text('这一路走来')
            .fontSize(14)
            .fontColor(WHITE_SECONDARY)
            .margin({ bottom: 8 })

          if (this.footprint.totalDistanceKm > 0) {
            Row() {
              Text(`${this.animDistance}`)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
                .fontColor(CARD_BG)
                .fontFeature("'tnum'")
              Text(' 公里')
                .fontSize(16)
                .fontColor(WHITE_SECONDARY)
                .margin({ bottom: 8 })
            }
            .alignItems(VerticalAlign.Bottom)
          } else {
            Text('每一步都算数')
              .fontSize(20)
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
          .margin({ top: 16 })

          // 相伴最久的伙伴
          if (this.footprint.longestCompanion !== undefined) {
            Column() {
              Text(`相伴最久的是「${this.footprint.longestCompanion.name}」`)
                .fontSize(13)
                .fontColor(WHITE_SECONDARY)
                .margin({ top: 20 })
              Text(`${this.animDays} 天了`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(CARD_BG)
                .fontFeature("'tnum'")
                .margin({ top: 4 })
            }
          }

          // 留白文案——「故事都在你心里」
          Text('故事都在你心里')
            .fontSize(12)
            .fontColor(WHITE_SECONDARY)
            .margin({ top: 32 })
            .opacity(0.7)
        }
        .width('100%')
        .padding({ top: 80, bottom: 40, left: PAGE_PADDING, right: PAGE_PADDING })
        .linearGradient({
          angle: 180,
          colors: [[PRIMARY_COLOR, 0], ['#1B5E20', 1]]
        })
        .borderRadius({ bottomLeft: CARD_RADIUS, bottomRight: CARD_RADIUS })
        .alignItems(HorizontalAlign.Start)

        // ——— 数据卡片区 ———
        Column({ space: 12 }) {
          // 装备概览卡
          Column() {
            Text('装备伙伴')
              .fontSize(13)
              .fontColor(TEXT_TERTIARY)
              .margin({ bottom: 8 })
            Row() {
              Text(`${this.footprint.gearCount}`)
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .fontColor(TEXT_MAIN)
                .fontFeature("'tnum'")
              Text(' 件装备陪着你')
                .fontSize(14)
                .fontColor(TEXT_SECONDARY)
                .margin({ bottom: 4 })
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .width('100%')
          .padding(CARD_PADDING)
          .backgroundColor(CARD_BG)
          .borderRadius(CARD_RADIUS)
          .alignItems(HorizontalAlign.Start)

          // 海拔卡（有数据时显示）
          if (this.footprint.maxAltitude > 0) {
            Column() {
              Text('到过的最高处')
                .fontSize(13)
                .fontColor(TEXT_TERTIARY)
                .margin({ bottom: 8 })
              Row() {
                Text(`${this.footprint.maxAltitude}`)
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(TEXT_MAIN)
                  .fontFeature("'tnum'")
                Text(' m')
                  .fontSize(14)
                  .fontColor(TEXT_SECONDARY)
                  .margin({ bottom: 4 })
              }
              .alignItems(VerticalAlign.Bottom)
            }
            .width('100%')
            .padding(CARD_PADDING)
            .backgroundColor(CARD_BG)
            .borderRadius(CARD_RADIUS)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .padding({ top: 20, left: PAGE_PADDING, right: PAGE_PADDING, bottom: 120 })
        .width('100%')
      }
      .width('100%')
      .opacity(this.cardOpacity)
      .translate({ y: this.cardTranslateY })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(PAGE_BG)
  }

  @Builder
  footprintChip(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(CARD_BG)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor('#33FFFFFF')
      .borderRadius(CHIP_RADIUS)
  }
}
