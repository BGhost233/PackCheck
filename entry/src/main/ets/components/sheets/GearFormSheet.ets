import {
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION
} from '../../constants/Typography';
import {
  WHITE,
  DISABLED_COLOR
} from '../../constants/Colors';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../../constants/AnimationTokens';
import { CategoryTagGroup } from '../CategoryTagGroup';

/**
 * 装备表单 Sheet — 新建/编辑装备。
 *
 * §4.6 内化模式：外部通过 initialXxx 传入初始值，内部 @State 持有编辑态，
 * 提交时通过 onSave 回调将最终数据回传给父组件。
 */
@Component
export struct GearFormSheet {
  // 编辑模式标识（非空 = 编辑已有装备）
  @Prop editingGearId: string = '';

  // 初始值 props（外部传入，仅用于 aboutToAppear 初始化）
  initialName: string = '';
  initialCategory: string = '其他';
  initialWeight: string = '';
  initialPrice: string = '';
  initialNote: string = '';
  @Prop categories: string[] = [];

  // 表单字段 — 内部状态
  @State private gearName: string = '';
  @State private gearCategory: string = '其他';
  @State private gearWeight: string = '';
  @State private gearPrice: string = '';
  @State private gearNote: string = '';

  // 回调：提交表单数据
  onSave: (name: string, category: string, weight: string, price: string, note: string) => void = () => {};
  // 分组管理回调（操作全局分类，非表单本地状态）
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAddCategory: (name: string) => void = () => {};

  @State private buttonPressed: boolean = false;

  aboutToAppear(): void {
    this.gearName = this.initialName;
    this.gearCategory = this.initialCategory;
    this.gearWeight = this.initialWeight;
    this.gearPrice = this.initialPrice;
    this.gearNote = this.initialNote;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ placeholder: '装备名称（必填）', text: this.gearName })
          .type(InputType.Normal)
          .maxLength(100)
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.gearName = value;
          })
        Text('选择分组')
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        CategoryTagGroup({
          categories: this.categories,
          selectedCategory: this.gearCategory,
          mode: 'single',
          editable: true,
          onSelect: (category: string) => {
            this.gearCategory = category;
          },
          onRename: (oldName: string, newName: string) => {
            this.onRename(oldName, newName);
          },
          onDelete: (category: string) => {
            this.onDelete(category);
          },
          onReorder: (categories: string[]) => {
            this.onReorder(categories);
          },
          onAdd: (name: string) => {
            this.onAddCategory(name);
          }
        })
        Row({ space: 12 }) {
          TextInput({ placeholder: '重量(g)', text: this.gearWeight })
            .type(InputType.Number)
            .maxLength(20)
            .height(48)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.gearWeight = value;
            })
          TextInput({ placeholder: '价格(¥)', text: this.gearPrice })
            .type(InputType.Number)
            .maxLength(20)
            .height(48)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.gearPrice = value;
            })
        }
        TextInput({ placeholder: '备注（一行，可选）', text: this.gearNote })
          .type(InputType.Normal)
          .maxLength(500)
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.gearNote = value;
          })
        Button(this.editingGearId.length === 0 ? '确认添加' : '确认保存')
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(WHITE)
          .backgroundColor(this.gearName.trim().length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.gearName.trim().length > 0)
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
            this.onSave(this.gearName, this.gearCategory, this.gearWeight, this.gearPrice, this.gearNote);
          })
      }
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }
}
