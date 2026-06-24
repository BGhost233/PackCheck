import { LengthMetrics } from '@kit.ArkUI';
import {
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY
} from '../../constants/DesignTokens';
import {
  WHITE,
  DISABLED_COLOR,
  CHIP_BG_DEFAULT
} from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';
import { RouteSegment, TransportMode, TicketInfo, makeId } from '../../models/PackModels';

/**
 * 路段编辑表单 — 新增 / 编辑复用。
 * 受控模式：外部通过 @Prop 传入各字段，通过回调接收变更。
 * 提交时组装完整 RouteSegment 通过 onSubmit 返回。
 */

// 交通方式选项（顺序即显示顺序）
const TRANSPORT_OPTIONS: TransportMode[] = ['flight', 'train', 'bus', 'drive', 'walk', 'bike', 'boat', 'other'];

function transportLabel(mode: TransportMode): string {
  const labels: Record<string, string> = {
    'flight': '飞机',
    'train': '火车',
    'bus': '大巴',
    'drive': '自驾',
    'walk': '徒步',
    'bike': '骑行',
    'boat': '轮船',
    'other': '其他'
  };
  return labels[mode] ?? '其他';
}

@Component
export struct SegmentFormSheet {
  // 编辑模式：有 editingSegmentId 则为编辑，否则为新增
  @Prop editingSegmentId: string = '';

  // 表单字段
  @Prop segFrom: string = '';
  @Prop segTo: string = '';
  @Prop segTransport: TransportMode = 'other';
  @Prop segDepartTime: string = '';
  @Prop segArriveTime: string = '';
  @Prop segNote: string = '';
  @Prop segAccommodation: string = '';
  // 票务（可选展开）
  @Prop ticketCode: string = '';
  @Prop ticketSeat: string = '';
  @Prop ticketPrice: string = '';

  // 回调
  onFromChange: (v: string) => void = () => {};
  onToChange: (v: string) => void = () => {};
  onTransportChange: (v: TransportMode) => void = () => {};
  onDepartTimeChange: (v: string) => void = () => {};
  onArriveTimeChange: (v: string) => void = () => {};
  onNoteChange: (v: string) => void = () => {};
  onAccommodationChange: (v: string) => void = () => {};
  onTicketCodeChange: (v: string) => void = () => {};
  onTicketSeatChange: (v: string) => void = () => {};
  onTicketPriceChange: (v: string) => void = () => {};
  onSubmit: (segment: RouteSegment) => void = () => {};

  @State private buttonPressed: boolean = false;
  @State private showTicket: boolean = false;

  private isFormValid(): boolean {
    return this.segFrom.trim().length > 0 && this.segTo.trim().length > 0;
  }

  private buildSegment(): RouteSegment {
    let ticket: TicketInfo | undefined = undefined;
    if (this.ticketCode.trim().length > 0 || this.ticketSeat.trim().length > 0 || this.ticketPrice.trim().length > 0) {
      ticket = {
        type: transportLabel(this.segTransport),
        code: this.ticketCode.trim().length > 0 ? this.ticketCode.trim() : undefined,
        seat: this.ticketSeat.trim().length > 0 ? this.ticketSeat.trim() : undefined,
        price: this.ticketPrice.trim().length > 0 ? Number(this.ticketPrice) : undefined
      };
    }
    const seg: RouteSegment = {
      id: this.editingSegmentId.length > 0 ? this.editingSegmentId : makeId('seg'),
      from: this.segFrom.trim(),
      to: this.segTo.trim(),
      transport: this.segTransport,
      departTime: this.segDepartTime.trim().length > 0 ? this.segDepartTime.trim() : undefined,
      arriveTime: this.segArriveTime.trim().length > 0 ? this.segArriveTime.trim() : undefined,
      note: this.segNote.trim().length > 0 ? this.segNote.trim() : undefined,
      ticket: ticket,
      accommodation: this.segAccommodation.trim().length > 0 ? this.segAccommodation.trim() : undefined
    };
    return seg;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 出发地（必填）
        TextInput({ placeholder: '出发地（必填）', text: this.segFrom })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => { this.onFromChange(value); })

        // 到达地（必填）
        TextInput({ placeholder: '到达地（必填）', text: this.segTo })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => { this.onToChange(value); })

        // 交通方式 Chip 选择器
        Text('交通方式')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(TRANSPORT_OPTIONS, (mode: TransportMode) => {
            Text(transportLabel(mode))
              .fontSize(12)
              .fontColor(this.segTransport === mode ? WHITE : TEXT_MAIN)
              .backgroundColor(this.segTransport === mode ? PRIMARY_COLOR : CHIP_BG_DEFAULT)
              .borderRadius(16)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .onClick(() => { this.onTransportChange(mode); })
          })
        }
        .width('100%')

        // 出发/到达时间
        Row({ space: 12 }) {
          TextInput({ placeholder: '出发 HH:mm', text: this.segDepartTime })
            .type(InputType.Normal)
            .height(48)
            .fontSize(14)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .layoutWeight(1)
            .onChange((value: string) => { this.onDepartTimeChange(value); })
          TextInput({ placeholder: '到达 HH:mm', text: this.segArriveTime })
            .type(InputType.Normal)
            .height(48)
            .fontSize(14)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .layoutWeight(1)
            .onChange((value: string) => { this.onArriveTimeChange(value); })
        }

        // 票务信息（折叠区）
        Row() {
          Text('票务信息')
            .fontSize(12)
            .fontColor(TEXT_SECONDARY)
          Blank()
          Text(this.showTicket ? '收起' : '展开')
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
            .onClick(() => { this.showTicket = !this.showTicket; })
        }
        .width('100%')
        .padding({ top: 4 })

        if (this.showTicket) {
          Row({ space: 8 }) {
            TextInput({ placeholder: '车次/航班号', text: this.ticketCode })
              .type(InputType.Normal)
              .height(44)
              .fontSize(13)
              .fontColor(TEXT_MAIN)
              .placeholderColor(TEXT_SECONDARY)
              .backgroundColor(PAGE_BG)
              .borderRadius(10)
              .padding({ left: 10, right: 10 })
              .layoutWeight(1)
              .onChange((v: string) => { this.onTicketCodeChange(v); })
            TextInput({ placeholder: '座位', text: this.ticketSeat })
              .type(InputType.Normal)
              .height(44)
              .fontSize(13)
              .fontColor(TEXT_MAIN)
              .placeholderColor(TEXT_SECONDARY)
              .backgroundColor(PAGE_BG)
              .borderRadius(10)
              .padding({ left: 10, right: 10 })
              .width(80)
              .onChange((v: string) => { this.onTicketSeatChange(v); })
            TextInput({ placeholder: '¥', text: this.ticketPrice })
              .type(InputType.Number)
              .height(44)
              .fontSize(13)
              .fontColor(TEXT_MAIN)
              .placeholderColor(TEXT_SECONDARY)
              .backgroundColor(PAGE_BG)
              .borderRadius(10)
              .padding({ left: 10, right: 10 })
              .width(70)
              .onChange((v: string) => { this.onTicketPriceChange(v); })
          }
        }

        // 住宿
        TextInput({ placeholder: '住宿信息（可选）', text: this.segAccommodation })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => { this.onAccommodationChange(value); })

        // 备注
        TextInput({ placeholder: '备注（可选）', text: this.segNote })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => { this.onNoteChange(value); })

        // 提交按钮
        Button(this.editingSegmentId.length === 0 ? '添加路段' : '保存修改')
          .height(48)
          .fontSize(14)
          .fontColor(WHITE)
          .backgroundColor(this.isFormValid() ? PRIMARY_COLOR : DISABLED_COLOR)
          .width('100%')
          .borderRadius(12)
          .enabled(this.isFormValid())
          .scale({ x: this.buttonPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
            y: this.buttonPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
          .animation({ curve: SPRING_PRESS() })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.buttonPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.buttonPressed = false;
            }
          })
          .onClick(() => { this.onSubmit(this.buildSegment()); })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }
}
