// DayCard — 单天行程卡片（手风琴组件：收缩/展开两态）
// Phase 6：收缩态 | Phase 7：展开态时间线

import { DayItinerary, RouteSegment } from '../../models/PackModels';
import { getDaySummary, getTransportIcon, DaySummary } from '../../services/ItineraryService';
import {
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  CARD_BG,
  TIMELINE_LINE,
  TIMELINE_NODE,
  CHIP_BG_DEFAULT
} from '../../constants/Colors';
import {
  TIMELINE_LINE_WIDTH,
  TIMELINE_NODE_SIZE,
  TIMELINE_LEFT_MARGIN
} from '../../constants/Layout';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  PRESS_SCALE_DOWN
} from '../../constants/AnimationTokens';

@Component
export struct DayCard {
  @Prop day: DayItinerary = { id: '', dayIndex: 0, segments: [] };
  @Prop isExpanded: boolean = false;
  onToggle: () => void = () => {};

  @State private cardScale: number = 1.0;

  private getSummary(): DaySummary {
    return getDaySummary(this.day);
  }

  build() {
    Column() {
      // === 收缩态（始终显示） ===
      this.buildCollapsedContent()

      // === 展开态（Phase 7 补充时间线 UI） ===
      if (this.isExpanded) {
        this.buildExpandedContent()
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(CARD_BG)
    .borderRadius(16)
    .scale({ x: this.cardScale, y: this.cardScale })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.cardScale = PRESS_SCALE_DOWN;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.cardScale = 1.0;
      }
    })
    .onClick(() => { this.onToggle(); })
  }

  @Builder
  private buildCollapsedContent() {
    Column({ space: 6 }) {
      // 第一行：Day N · 日期
      Row({ space: 6 }) {
        Text(`Day ${this.day.dayIndex + 1}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)

        if (this.day.date !== undefined && this.day.date.length > 0) {
          Text(this.day.date)
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
        }

        Blank()

        // 展开/收起指示器
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(14)
          .fontColor([TEXT_TERTIARY])
          .rotate({ angle: this.isExpanded ? 180 : 0 })
          .animation({ curve: SPRING_GENERAL() })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 第二行：起点 ──icon──→ 终点
      Row({ space: 8 }) {
        Text(this.getSummary().from)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .constraintSize({ maxWidth: '35%' })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 交通图标
        SymbolGlyph(getTransportIcon(this.getSummary().mainTransport))
          .fontSize(16)
          .fontColor([TEXT_SECONDARY])

        // 箭头
        Text('→')
          .fontSize(14)
          .fontColor(TEXT_TERTIARY)

        Text(this.getSummary().to)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .constraintSize({ maxWidth: '35%' })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 第三行：出发时间 / 到达时间（可选）
      if (this.getSummary().departTime !== undefined || this.getSummary().arriveTime !== undefined) {
        Row({ space: 12 }) {
          if (this.getSummary().departTime !== undefined) {
            Text(this.getSummary().departTime)
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
          if (this.getSummary().departTime !== undefined && this.getSummary().arriveTime !== undefined) {
            Text('–')
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
          if (this.getSummary().arriveTime !== undefined) {
            Text(this.getSummary().arriveTime)
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
        }
      }

      // 第四行：当天备注（可选，单行截断）
      if (this.day.note !== undefined && this.day.note.length > 0) {
        Text(this.day.note)
          .fontSize(13)
          .fontColor(TEXT_TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
  }

  // Phase 7 展开态占位（将实现时间线 UI）
  @Builder
  private buildExpandedContent() {
    Column({ space: 8 }) {
      ForEach(this.day.segments, (seg: RouteSegment, index: number) => {
        this.buildSegmentRow(seg, index)
      }, (seg: RouteSegment) => seg.id)
    }
    .width('100%')
    .margin({ top: 12 })
    .transition(TransitionEffect.OPACITY.combine(
      TransitionEffect.translate({ y: -6 })
    ).animation({ curve: SPRING_GENERAL() }))
  }

  @Builder
  private buildSegmentRow(seg: RouteSegment, index: number) {
    Row({ space: 10 }) {
      // 左侧时间线节点
      Column() {
        // 节点圆点
        Circle()
          .width(TIMELINE_NODE_SIZE)
          .height(TIMELINE_NODE_SIZE)
          .fill(TIMELINE_NODE)

        // 节点下竖线（非末段）
        if (index < this.day.segments.length - 1) {
          Line()
            .width(TIMELINE_LINE_WIDTH)
            .height(32)
            .backgroundColor(TIMELINE_LINE)
            .margin({ top: 4 })
        }
      }
      .width(TIMELINE_LEFT_MARGIN)
      .alignItems(HorizontalAlign.Center)

      // 右侧内容
      Column({ space: 2 }) {
        // 起点 → 终点
        Text(`${seg.from} → ${seg.to}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)

        // 交通方式 + 时间
        Row({ space: 6 }) {
          SymbolGlyph(getTransportIcon(seg.transport))
            .fontSize(13)
            .fontColor([TEXT_TERTIARY])

          if (seg.departTime !== undefined) {
            Text(seg.departTime)
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
          if (seg.departTime !== undefined && seg.arriveTime !== undefined) {
            Text('–')
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
          if (seg.arriveTime !== undefined) {
            Text(seg.arriveTime)
              .fontSize(12)
              .fontColor(TEXT_TERTIARY)
          }
        }
        .alignItems(VerticalAlign.Center)

        // 票务信息 Chip（如果有）
        if (seg.ticket !== undefined) {
          Text(this.formatTicket(seg))
            .fontSize(11)
            .fontColor(TEXT_SECONDARY)
            .backgroundColor(CHIP_BG_DEFAULT)
            .borderRadius(8)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .margin({ top: 2 })
        }

        // 住宿（如果有）
        if (seg.accommodation !== undefined && seg.accommodation.length > 0) {
          Text(`🏨 ${seg.accommodation}`)
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
            .margin({ top: 2 })
        }

        // 备注（如果有）
        if (seg.note !== undefined && seg.note.length > 0) {
          Text(seg.note)
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
            .fontStyle(FontStyle.Italic)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ bottom: 6 })
  }

  private formatTicket(seg: RouteSegment): string {
    if (seg.ticket === undefined) {
      return '';
    }
    const parts: string[] = [];
    if (seg.ticket.code !== undefined && seg.ticket.code.length > 0) {
      parts.push(seg.ticket.code);
    }
    if (seg.ticket.seat !== undefined && seg.ticket.seat.length > 0) {
      parts.push(seg.ticket.seat);
    }
    if (seg.ticket.price !== undefined && seg.ticket.price > 0) {
      parts.push(`¥${seg.ticket.price}`);
    }
    return parts.join(' · ');
  }
}
