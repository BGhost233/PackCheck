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
import { DayItinerary, RouteSegment, TransportMode, makeId } from '../../models/PackModels';

/**
 * 新建/编辑一天 表单。
 * 新建模式：必填出发地+到达地，选填交通方式/时间/日期/备注。提交时组装 DayItinerary（含首段 RouteSegment）。
 * 编辑模式：预填已有数据，提交 patch。
 */

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
export struct DayFormSheet {
  // 编辑模式标识（非空 = 编辑已有天）
  @Prop editingDayId: string = '';

  // 表单字段 — 受控模式，由外部传入
  @Prop dayFrom: string = '';
  @Prop dayTo: string = '';
  @Prop dayTransport: TransportMode = 'other';
  @Prop dayDepartTime: string = '';
  @Prop dayArriveTime: string = '';
  @Prop dayDate: string = '';
  @Prop dayNote: string = '';

  // 回调
  onFromChange: (v: string) => void = () => {};
  onToChange: (v: string) => void = () => {};
  onTransportChange: (v: TransportMode) => void = () => {};
  onDepartTimeChange: (v: string) => void = () => {};
  onArriveTimeChange: (v: string) => void = () => {};
  onDateChange: (v: string) => void = () => {};
  onNoteChange: (v: string) => void = () => {};
  // 新建模式：提交完整 DayItinerary（含首段）
  onSubmitDay: (day: DayItinerary) => void = () => {};
  // 编辑模式：提交 patch（dayId 由外部持有）
  onSubmitEdit: (dayId: string, firstSeg: RouteSegment, date?: string, note?: string) => void = () => {};

  @State private buttonPressed: boolean = false;

  private isFormValid(): boolean {
    return this.dayFrom.trim().length > 0 && this.dayTo.trim().length > 0;
  }

  private buildFirstSegment(): RouteSegment {
    const seg: RouteSegment = {
      id: makeId('seg'),
      from: this.dayFrom.trim(),
      to: this.dayTo.trim(),
      transport: this.dayTransport,
      departTime: this.dayDepartTime.trim().length > 0 ? this.dayDepartTime.trim() : undefined,
      arriveTime: this.dayArriveTime.trim().length > 0 ? this.dayArriveTime.trim() : undefined
    };
    return seg;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 出发地（必填）
        TextInput({ placeholder: '从哪里出发（必填）', text: this.dayFrom })
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
        TextInput({ placeholder: '到达哪里（必填）', text: this.dayTo })
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
              .fontColor(this.dayTransport === mode ? WHITE : TEXT_MAIN)
              .backgroundColor(this.dayTransport === mode ? PRIMARY_COLOR : CHIP_BG_DEFAULT)
              .borderRadius(16)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .onClick(() => { this.onTransportChange(mode); })
          })
        }
        .width('100%')

        // 出发/到达时间
        Row({ space: 12 }) {
          TextInput({ placeholder: '出发 HH:mm', text: this.dayDepartTime })
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
          TextInput({ placeholder: '到达 HH:mm', text: this.dayArriveTime })
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

        // 日期（可选）
        TextInput({ placeholder: '日期 YYYY-MM-DD（可选）', text: this.dayDate })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => { this.onDateChange(value); })

        // 备注（可选）
        TextInput({ placeholder: '当天备注（可选）', text: this.dayNote })
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
        Button(this.editingDayId.length === 0 ? '添加一天' : '保存修改')
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
          .onClick(() => {
            if (this.editingDayId.length === 0) {
              // 新建模式：组装 DayItinerary（含首段 RouteSegment）
              const firstSeg = this.buildFirstSegment();
              const day: DayItinerary = {
                id: makeId('day'),
                dayIndex: 0,
                segments: [firstSeg],
                date: this.dayDate.trim().length > 0 ? this.dayDate.trim() : undefined,
                note: this.dayNote.trim().length > 0 ? this.dayNote.trim() : undefined
              };
              this.onSubmitDay(day);
            } else {
              // 编辑模式：返回更新后的首段 + 天级信息
              const firstSeg = this.buildFirstSegment();
              this.onSubmitEdit(
                this.editingDayId,
                firstSeg,
                this.dayDate.trim().length > 0 ? this.dayDate.trim() : undefined,
                this.dayNote.trim().length > 0 ? this.dayNote.trim() : undefined
              );
            }
          })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }
}
