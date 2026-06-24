// ItineraryView — 每日行程 Tab 容器组件
// 职责：管理 DayCard 列表 + 空态展示 + 手风琴互斥状态

import { DayItinerary } from '../../models/PackModels';
import { DayCard } from './DayCard';
import {
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../../constants/Colors';
import { PRIMARY_COLOR } from '../../constants/Colors';
import { DAY_CARD_GAP, PAGE_PADDING } from '../../constants/Layout';
import {
  SPRING_GENERAL,
  staggerDelay,
  STAGGER_OFFSET_Y
} from '../../constants/AnimationTokens';

@Component
export struct ItineraryView {
  @Prop itinerary: DayItinerary[] = [];
  // 强制刷新 nonce：父组件数据变更时递增，建立 ArkUI 依赖追踪链路
  @Prop renderNonce: number = 0;

  // 编辑回调
  onAddDay: () => void = () => {};
  onEditDay: (dayId: string) => void = () => {};
  onDeleteDay: (dayId: string) => void = () => {};
  onAddSegment: (dayId: string) => void = () => {};
  onEditSegment: (dayId: string, segId: string) => void = () => {};
  onDeleteSegment: (dayId: string, segId: string) => void = () => {};

  // 手风琴互斥：同时只展开一天
  @State private expandedDayId: string = '';
  // 错落入场控制
  @State private appeared: boolean = false;

  aboutToAppear(): void {
    // 直接置位；动画由各元素的 .animation({ delay }) 控制错落时机
    this.appeared = true;
  }

  build() {
    if (this.itinerary.length === 0) {
      this.buildEmptyState()
    } else {
      this.buildDayList()
    }
  }

  // === 空态 ===
  @Builder
  private buildEmptyState() {
    Column({ space: 8 }) {
      // 虚线时间线占位（表达"等你填充"）
      Column() {
        // 三个空心圆点 + 虚线
        ForEach([0, 1, 2], (i: number) => {
          Circle()
            .width(8)
            .height(8)
            .fill('transparent')
            .stroke(TEXT_TERTIARY)
            .strokeWidth(1)
            .margin({ bottom: i < 2 ? 12 : 0 })
        }, (i: number) => i.toString())
      }
      .margin({ bottom: 20 })

      Text('还没有行程安排')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SECONDARY)

      Text('记录每天的路线，出发时不再手忙脚乱')
        .fontSize(13)
        .fontColor(TEXT_TERTIARY)
        .margin({ top: 2 })

      Text('添加第一天')
        .fontSize(14)
        .fontColor(PRIMARY_COLOR)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16 })
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
    Scroll() {
      Column({ space: DAY_CARD_GAP }) {
        ForEach(this.itinerary, (day: DayItinerary, index: number) => {
          DayCard({
            day: day,
            isExpanded: this.expandedDayId === day.id,
            renderNonce: this.renderNonce,
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
        }, (day: DayItinerary) => day.id)

        // 底部添加一天按钮
        Text('+ 添加一天')
          .fontSize(14)
          .fontColor(PRIMARY_COLOR)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 12, bottom: 12 })
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
