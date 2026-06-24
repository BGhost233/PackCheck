import {
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  WHITE,
  DISABLED_COLOR
} from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';
import { DayPatch } from '../../models/PackModels';

/**
 * 天编辑表单 — 编辑日期和备注（新增/编辑复用）。
 * 轻量表单，2个字段即可。
 */
@Component
export struct DayFormSheet {
  // 编辑模式标识
  @Prop editingDayId: string = '';

  // 表单字段
  @Prop dayDate: string = '';
  @Prop dayNote: string = '';

  // 回调
  onDateChange: (v: string) => void = () => {};
  onNoteChange: (v: string) => void = () => {};
  onSubmit: (patch: DayPatch) => void = () => {};

  @State private buttonPressed: boolean = false;

  build() {
    Column({ space: 12 }) {
      // 日期
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

      // 备注
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
        .backgroundColor(PRIMARY_COLOR)
        .width('100%')
        .borderRadius(12)
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
          const patch: DayPatch = {
            date: this.dayDate.trim().length > 0 ? this.dayDate.trim() : undefined,
            note: this.dayNote.trim().length > 0 ? this.dayNote.trim() : undefined
          };
          this.onSubmit(patch);
        })
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    .width('100%')
  }
}
