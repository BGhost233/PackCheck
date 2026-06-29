import { LengthMetrics } from '@kit.ArkUI';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_BODY_SMALL,
  FONT_SIZE_CAPTION
} from '../../constants/Typography';
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
  CHIP_BG_DEFAULT,
  DANGER_COLOR
} from '../../constants/Colors';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';
import { RouteSegment, TransportMode, TicketInfo, makeId } from '../../models/PackModels';

/**
 * 路段编辑表单 — 新增 / 编辑复用。
 * 内聚模式：外部通过 initial* 传入初始值，组件内部 @State 管理表单状态。
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

  // 初始值（外部传入，仅在 aboutToAppear 时赋给 @State）
  initialFrom: string = '';
  initialTo: string = '';
  initialTransport: TransportMode = 'other';
  initialDepartTime: string = '';
  initialArriveTime: string = '';
  initialNote: string = '';
  initialAccommodation: string = '';
  initialTicketCode: string = '';
  initialTicketSeat: string = '';
  initialTicketPrice: string = '';

  // 表单状态（组件内部管理）
  @State segFrom: string = '';
  @State segTo: string = '';
  @State segTransport: TransportMode = 'other';
  @State segDepartTime: string = '';
  @State segArriveTime: string = '';
  @State segNote: string = '';
  @State segAccommodation: string = '';
  @State ticketCode: string = '';
  @State ticketSeat: string = '';
  @State ticketPrice: string = '';

  // 回调
  onSubmit: (segment: RouteSegment) => void = () => {};
  onDeleteSegment: () => void = () => {};

  @State private buttonPressed: boolean = false;
  @State private deletePressed: boolean = false;
  @State private showTicket: boolean = false;
  @State private focusedField: string = '';

  aboutToAppear(): void {
    this.segFrom = this.initialFrom;
    this.segTo = this.initialTo;
    this.segTransport = this.initialTransport;
    this.segDepartTime = this.initialDepartTime;
    this.segArriveTime = this.initialArriveTime;
    this.segNote = this.initialNote;
    this.segAccommodation = this.initialAccommodation;
    this.ticketCode = this.initialTicketCode;
    this.ticketSeat = this.initialTicketSeat;
    this.ticketPrice = this.initialTicketPrice;
  }

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
          .maxLength(100)
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'from' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'from'; })
          .onBlur(() => { if (this.focusedField === 'from') this.focusedField = ''; })
          .onChange((value: string) => { this.segFrom = value; })

        // 到达地（必填）
        TextInput({ placeholder: '到达地（必填）', text: this.segTo })
          .type(InputType.Normal)
          .maxLength(100)
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'to' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'to'; })
          .onBlur(() => { if (this.focusedField === 'to') this.focusedField = ''; })
          .onChange((value: string) => { this.segTo = value; })

        // 交通方式 Chip 选择器
        Text('交通方式')
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(TRANSPORT_OPTIONS, (mode: TransportMode) => {
            Text(transportLabel(mode))
              .fontSize(FONT_SIZE_CAPTION)
              .fontColor(this.segTransport === mode ? WHITE : TEXT_MAIN)
              .backgroundColor(this.segTransport === mode ? PRIMARY_COLOR : CHIP_BG_DEFAULT)
              .borderRadius(16)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .onClick(() => { this.segTransport = mode; })
          })
        }
        .width('100%')

        // 出发/到达时间
        Row({ space: 12 }) {
          TextInput({ placeholder: '出发 HH:mm', text: this.segDepartTime })
            .type(InputType.Normal)
            .maxLength(5)
            .height(48)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .layoutWeight(1)
            .border({ width: 1, color: this.focusedField === 'depart' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
            .onFocus(() => { this.focusedField = 'depart'; })
            .onBlur(() => { if (this.focusedField === 'depart') this.focusedField = ''; })
            .onChange((value: string) => { this.segDepartTime = value; })
          TextInput({ placeholder: '到达 HH:mm', text: this.segArriveTime })
            .type(InputType.Normal)
            .maxLength(5)
            .height(48)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .layoutWeight(1)
            .border({ width: 1, color: this.focusedField === 'arrive' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
            .onFocus(() => { this.focusedField = 'arrive'; })
            .onBlur(() => { if (this.focusedField === 'arrive') this.focusedField = ''; })
            .onChange((value: string) => { this.segArriveTime = value; })
        }

        // 票务信息（折叠区）
        Row() {
          Text('票务信息')
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_SECONDARY)
          Blank()
          Text(this.showTicket ? '收起' : '展开')
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_TERTIARY)
            .onClick(() => {
              this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
                this.showTicket = !this.showTicket;
              });
            })
        }
        .width('100%')
        .padding({ top: 4 })

        if (this.showTicket) {
          Row({ space: 8 }) {
            TextInput({ placeholder: '车次/航班号', text: this.ticketCode })
              .type(InputType.Normal)
              .maxLength(100)
              .height(44)
              .fontSize(FONT_SIZE_BODY_SMALL)
              .fontColor(TEXT_MAIN)
              .placeholderColor(TEXT_SECONDARY)
              .backgroundColor(PAGE_BG)
              .borderRadius(10)
              .padding({ left: 10, right: 10 })
              .layoutWeight(1)
              .border({ width: 1, color: this.focusedField === 'ticketCode' ? PRIMARY_COLOR : Color.Transparent, radius: 10 })
              .onFocus(() => { this.focusedField = 'ticketCode'; })
              .onBlur(() => { if (this.focusedField === 'ticketCode') this.focusedField = ''; })
              .onChange((v: string) => { this.ticketCode = v; })
            TextInput({ placeholder: '座位', text: this.ticketSeat })
              .type(InputType.Normal)
              .maxLength(100)
              .height(44)
              .fontSize(FONT_SIZE_BODY_SMALL)
              .fontColor(TEXT_MAIN)
              .placeholderColor(TEXT_SECONDARY)
              .backgroundColor(PAGE_BG)
              .borderRadius(10)
              .padding({ left: 10, right: 10 })
              .width(80)
              .border({ width: 1, color: this.focusedField === 'ticketSeat' ? PRIMARY_COLOR : Color.Transparent, radius: 10 })
              .onFocus(() => { this.focusedField = 'ticketSeat'; })
              .onBlur(() => { if (this.focusedField === 'ticketSeat') this.focusedField = ''; })
              .onChange((v: string) => { this.ticketSeat = v; })
            TextInput({ placeholder: '¥', text: this.ticketPrice })
              .type(InputType.Number)
              .maxLength(20)
              .height(44)
              .fontSize(FONT_SIZE_BODY_SMALL)
              .fontColor(TEXT_MAIN)
              .placeholderColor(TEXT_SECONDARY)
              .backgroundColor(PAGE_BG)
              .borderRadius(10)
              .padding({ left: 10, right: 10 })
              .width(70)
              .border({ width: 1, color: this.focusedField === 'ticketPrice' ? PRIMARY_COLOR : Color.Transparent, radius: 10 })
              .onFocus(() => { this.focusedField = 'ticketPrice'; })
              .onBlur(() => { if (this.focusedField === 'ticketPrice') this.focusedField = ''; })
              .onChange((v: string) => { this.ticketPrice = v; })
          }
          .transition(
            TransitionEffect.asymmetric(
              TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 }))
                .animation({ curve: SPRING_GENERAL() }),
              TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 }))
                .animation({ curve: SPRING_GENERAL() })
            )
          )
        }

        // 住宿
        TextInput({ placeholder: '住宿信息（可选）', text: this.segAccommodation })
          .type(InputType.Normal)
          .maxLength(100)
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'accommodation' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'accommodation'; })
          .onBlur(() => { if (this.focusedField === 'accommodation') this.focusedField = ''; })
          .onChange((value: string) => { this.segAccommodation = value; })

        // 备注
        TextInput({ placeholder: '备注（可选）', text: this.segNote })
          .type(InputType.Normal)
          .maxLength(500)
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'note' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'note'; })
          .onBlur(() => { if (this.focusedField === 'note') this.focusedField = ''; })
          .onChange((value: string) => { this.segNote = value; })

        // 提交按钮
        Button(this.editingSegmentId.length === 0 ? '添加路段' : '保存修改')
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
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

        // 编辑模式 — 删除此路段
        if (this.editingSegmentId.length > 0) {
          Button('删除此路段')
            .height(48)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(DANGER_COLOR)
            .backgroundColor(Color.Transparent)
            .width('100%')
            .borderRadius(12)
            .scale({
              x: this.deletePressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
              y: this.deletePressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
            })
            .animation({ curve: SPRING_PRESS() })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.deletePressed = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.deletePressed = false;
              }
            })
            .onClick(() => {
              AlertDialog.show({
                title: '删除路段',
                message: `确定要删除「${this.segFrom} → ${this.segTo}」吗？`,
                primaryButton: { value: '取消', action: () => {} },
                secondaryButton: {
                  value: '删除',
                  fontColor: DANGER_COLOR,
                  action: () => { this.onDeleteSegment(); }
                }
              });
            })
        }
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }
}
