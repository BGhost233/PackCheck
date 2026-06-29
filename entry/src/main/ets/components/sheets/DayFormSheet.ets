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
  DANGER_COLOR
} from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';
import { DayItinerary, makeId } from '../../models/PackModels';

/**
 * 新建/编辑一天 表单。
 * 4 个字段：出发地（必填）、目的地（必填）、日期（选填）、备注（选填）。
 * 新建模式：提交完整 DayItinerary（segments 为空）。
 * 编辑模式：提交 (dayId, from, to, date, note)。
 */

@Component
export struct DayFormSheet {
  // 编辑模式标识（非空 = 编辑已有天）
  @Prop editingDayId: string = '';

  // 表单字段 — 受控模式，由外部传入
  @Prop dayFrom: string = '';
  @Prop dayTo: string = '';
  @Prop dayDate: string = '';
  @Prop dayNote: string = '';

  // 回调
  onFromChange: (v: string) => void = () => {};
  onToChange: (v: string) => void = () => {};
  onDateChange: (v: string) => void = () => {};
  onNoteChange: (v: string) => void = () => {};
  // 新建模式：提交完整 DayItinerary（segments 为空，天级 from/to）
  onSubmitDay: (day: DayItinerary) => void = () => {};
  // 编辑模式：提交天级 patch（from/to/date/note 始终传字符串，'' = 清空）
  onSubmitEdit: (dayId: string, from: string, to: string, date: string, note: string) => void = () => {};
  // 编辑模式：删除此天
  onDeleteDay: () => void = () => {};

  @State private buttonPressed: boolean = false;
  @State private deletePressed: boolean = false;
  @State private focusedField: string = '';

  private isFormValid(): boolean {
    return this.dayFrom.trim().length > 0 && this.dayTo.trim().length > 0;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 出发地（必填）
        TextInput({ placeholder: '从哪里出发（必填）', text: this.dayFrom })
          .type(InputType.Normal)
          .maxLength(100)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'from' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'from'; })
          .onBlur(() => { if (this.focusedField === 'from') this.focusedField = ''; })
          .onChange((value: string) => { this.onFromChange(value); })

        // 目的地（必填）
        TextInput({ placeholder: '到达哪里（必填）', text: this.dayTo })
          .type(InputType.Normal)
          .maxLength(100)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'to' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'to'; })
          .onBlur(() => { if (this.focusedField === 'to') this.focusedField = ''; })
          .onChange((value: string) => { this.onToChange(value); })

        // 日期（可选，点击弹出 DatePickerDialog）
        Row() {
          Text(this.dayDate.length > 0 ? this.dayDate : '选择日期（可选）')
            .fontSize(14)
            .fontColor(this.dayDate.length > 0 ? TEXT_MAIN : TEXT_TERTIARY)
        }
        .height(48)
        .width('100%')
        .backgroundColor(PAGE_BG)
        .borderRadius(12)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          // 解析已选日期作为初始值
          let selected: Date = new Date();
          if (this.dayDate.length > 0) {
            const parsed = new Date(this.dayDate);
            if (!isNaN(parsed.getTime())) {
              selected = parsed;
            }
          }
          DatePickerDialog.show({
            start: new Date('2020-01-01'),
            end: new Date('2030-12-31'),
            selected: selected,
            lunar: false,
            onDateAccept: (value: Date) => {
              const y = value.getFullYear();
              const m = (value.getMonth() + 1).toString().padStart(2, '0');
              const d = value.getDate().toString().padStart(2, '0');
              this.onDateChange(`${y}-${m}-${d}`);
            }
          });
        })

        // 备注（可选）
        TextInput({ placeholder: '当天备注（可选）', text: this.dayNote })
          .type(InputType.Normal)
          .maxLength(500)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: this.focusedField === 'note' ? PRIMARY_COLOR : Color.Transparent, radius: 12 })
          .onFocus(() => { this.focusedField = 'note'; })
          .onBlur(() => { if (this.focusedField === 'note') this.focusedField = ''; })
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
              // 新建模式：组装 DayItinerary（天级 from/to，segments 为空）
              const day: DayItinerary = {
                id: makeId('day'),
                dayIndex: 0,
                from: this.dayFrom.trim(),
                to: this.dayTo.trim(),
                segments: [],
                date: this.dayDate.trim().length > 0 ? this.dayDate.trim() : undefined,
                note: this.dayNote.trim().length > 0 ? this.dayNote.trim() : undefined
              };
              this.onSubmitDay(day);
            } else {
              // 编辑模式：返回天级 patch（始终传字符串，'' = 清空）
              this.onSubmitEdit(
                this.editingDayId,
                this.dayFrom.trim(),
                this.dayTo.trim(),
                this.dayDate.trim(),
                this.dayNote.trim()
              );
            }
          })

        // 编辑模式：删除此天按钮（红色文字按钮，确认弹窗后删除）
        if (this.editingDayId.length > 0) {
          Button('删除此天')
            .height(44)
            .fontSize(14)
            .fontColor(DANGER_COLOR)
            .backgroundColor(Color.Transparent)
            .width('100%')
            .borderRadius(12)
            .margin({ top: 4 })
            .scale({ x: this.deletePressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
              y: this.deletePressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
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
                title: '删除行程日',
                message: '删除后无法恢复，确定删除吗？',
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '删除',
                  fontColor: DANGER_COLOR,
                  action: () => { this.onDeleteDay(); }
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
