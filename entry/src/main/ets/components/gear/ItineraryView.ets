// ItineraryView — 每日行程 Tab 容器组件
// 职责：管理 DayCard 列表 + 空态展示 + 手风琴互斥状态

import { DayItinerary } from '../../models/PackModels';
import { DayCard } from './DayCard';
import {
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  PRIMARY_COLOR,
  WHITE
} from '../../constants/Colors';
import { DAY_CARD_GAP, PAGE_PADDING } from '../../constants/Layout';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  staggerDelay,
  STAGGER_OFFSET_Y
} from '../../constants/AnimationTokens';
import { HeadCollapseController } from '../../utils/HeadCollapseController';

@Component
export struct ItineraryView {
  @Prop itinerary: DayItinerary[] = [];
  // 强制刷新 nonce：父组件数据变更时递增，建立 ArkUI 依赖追踪链路，拼入 ForEach key
  @Prop renderNonce: number = 0;
  // tabVisibilityNonce：父层每次切至此 tab 时递增，驱动入场动画重播
  // 解决 ArkUI TabContent keep-alive 时 aboutToAppear 不触发的问题
  @Prop @Watch('onTabVisibilityNonceChange') tabVisibilityNonce: number = 0;

  // 编辑回调
  onAddDay: () => void = () => {};
  onEditDay: (dayId: string) => void = () => {};
  onDeleteDay: (dayId: string) => void = () => {};
  onAddSegment: (dayId: string) => void = () => {};
  onEditSegment: (dayId: string, segId: string) => void = () => {};
  onDeleteSegment: (dayId: string, segId: string) => void = () => {};
  // head 折叠进度回调（驱动 TripDetailPage 同帧联动）
  onHeadCollapseChange: (progress: number, snapping: boolean) => void = () => {};

  // 手风琴互斥：同时只展开一天
  @State private expandedDayId: string = '';
  // 错落入场控制
  @State private appeared: boolean = false;
  // 添加一天按钮按压态
  @State private addDayPressed: boolean = false;
  // Scroll 控制器（HeadCollapseController 需要）
  private scrollerCtrl: Scroller = new Scroller();
  // 折叠距离与装备 Tab 保持一致（76vp = SharedInfo 28 + ProgressBar 48）
  private headController: HeadCollapseController = new HeadCollapseController({
    collapseDistance: 76,
    enableSnap: true,
    getUIContext: () => this.getUIContext(),
    onChange: (progress: number, snapping: boolean) => {
      this.onHeadCollapseChange(progress, snapping);
    }
  });

  private isAlive: boolean = true;

  aboutToAppear(): void {
    this.isAlive = true;
    // 直接置位；动画由各元素的 .animation({ delay }) 控制错落时机
    this.appeared = true;
  }

  // tab 可见性变化时重置并重播错落入场
  onTabVisibilityNonceChange(): void {
    // toggle appeared false→true 让 .animation({ delay }) 重新评估错落
    this.appeared = false;
    this.appeared = true;
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    this.appeared = false;
  }

  build() {
    Column() {
      if (this.itinerary.length === 0) {
        this.buildEmptyState()
      } else {
        this.buildDayList()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  // 空态 CTA 按钮按压态
  @State private emptyCtaPressed: boolean = false;

  // === 空态 ===
  @Builder
  private buildEmptyState() {
    Column({ space: 10 }) {
      // 时间线占位图示（加大圆点 + 拉开间距）
      Column() {
        ForEach([0, 1, 2], (i: number) => {
          Circle()
            .width(10)
            .height(10)
            .fill('transparent')
            .stroke(TEXT_TERTIARY)
            .strokeWidth(1.5)
            .margin({ bottom: i < 2 ? 16 : 0 })
        }, (i: number) => i.toString())
      }
      .margin({ bottom: 24 })

      Text('还没有行程安排')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SECONDARY)

      Text('记录每天的路线，出发时不再手忙脚乱')
        .fontSize(14)
        .fontColor(TEXT_TERTIARY)
        .margin({ top: 4 })

      // CTA 填充按钮
      Button('添加第一天')
        .fontSize(14)
        .fontColor(WHITE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(20)
        .height(40)
        .padding({ left: 24, right: 24 })
        .margin({ top: 20 })
        .scale({
          x: this.emptyCtaPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
          y: this.emptyCtaPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
        })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.emptyCtaPressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.emptyCtaPressed = false;
          }
        })
        .onClick(() => { this.onAddDay(); })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 80 })
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 8 })
    .animation({ curve: SPRING_GENERAL(), delay: 100 })
  }

  // === 天列表 ===
  @Builder
  private buildDayList() {
    Scroll(this.scrollerCtrl) {
      Column({ space: DAY_CARD_GAP }) {
        ForEach(this.itinerary, (day: DayItinerary, index: number) => {
          DayCard({
            day: day,
            isExpanded: this.expandedDayId === day.id,
            onToggle: () => { this.toggleDay(day.id); },
            onEditDay: () => { this.onEditDay(day.id); },
            onDeleteDay: () => { this.onDeleteDay(day.id); },
            onAddSegment: () => { this.onAddSegment(day.id); },
            onEditSegment: (segId: string) => { this.onEditSegment(day.id, segId); },
            onDeleteSegment: (segId: string) => { this.onDeleteSegment(day.id, segId); }
          })
            .opacity(this.appeared ? 1 : 0)
            .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
            .animation({
              curve: SPRING_GENERAL(),
              delay: staggerDelay(index)
            })
            // 新增天入场动效：从下方滑入 + 淡入 + Spring
            .transition(
              TransitionEffect.asymmetric(
                TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
                  .combine(TransitionEffect.scale({ x: 0.95, y: 0.95 }))
                  .animation({ curve: SPRING_GENERAL() }),
                TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 }))
                  .animation({ curve: SPRING_GENERAL() })
              )
            )
        }, (day: DayItinerary) => day.id + '_' + (day.from ?? '') + '_' + (day.to ?? '') + '_' + day.segments.length.toString())

        // 底部添加一天按钮
        Text('+ 添加一天')
          .fontSize(14)
          .fontColor(PRIMARY_COLOR)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .scale({
            x: this.addDayPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
            y: this.addDayPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
          })
          .animation({ curve: SPRING_PRESS() })
          .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Down) {
              this.addDayPressed = true;
            } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.addDayPressed = false;
            }
          })
          .onClick(() => { this.onAddDay(); })
          .opacity(this.appeared ? 1 : 0)
          .animation({ curve: SPRING_GENERAL(), delay: staggerDelay(this.itinerary.length) })
      }
      .width('100%')
      .padding({
        left: PAGE_PADDING,
        right: PAGE_PADDING,
        top: 12,
        bottom: 100  // 预留底部 Tab 栏穿透空间
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onDidScroll(() => {
      this.headController.handleScroll(this.scrollerCtrl);
    })
    .onScrollStop(() => {
      this.headController.handleScrollStop(this.scrollerCtrl);
    })
  }

  // 手风琴切换：点击已展开的收起，点击未展开的展开（互斥）
  private toggleDay(dayId: string): void {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      if (this.expandedDayId === dayId) {
        this.expandedDayId = '';
      } else {
        this.expandedDayId = dayId;
      }
    });
  }
}
