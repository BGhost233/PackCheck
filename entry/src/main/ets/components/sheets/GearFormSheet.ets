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
import { CategoryTagGroup } from '../CategoryTagGroup';

@Component
export struct GearFormSheet {
  @Prop gearName: string = '';
  @Prop gearCategory: string = '其他';
  @Prop gearWeight: string = '';
  @Prop gearPrice: string = '';
  @Prop gearNote: string = '';
  @Prop editingGearId: string = '';
  @Prop categories: string[] = [];
  onNameChange: (value: string) => void = (value: string): void => {};
  onCategoryChange: (value: string) => void = (value: string): void => {};
  onWeightChange: (value: string) => void = (value: string): void => {};
  onPriceChange: (value: string) => void = (value: string): void => {};
  onNoteChange: (value: string) => void = (value: string): void => {};
  onSave: () => void = (): void => {};
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAddCategory: (name: string) => void = () => {};

  @State private buttonPressed: boolean = false;

  build() {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ placeholder: '装备名称（必填）', text: this.gearName })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onNameChange(value);
          })
        Text('选择分组')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
        CategoryTagGroup({
          categories: this.categories,
          selectedCategory: this.gearCategory,
          mode: 'single',
          editable: true,
          onSelect: (category: string) => {
            this.onCategoryChange(category);
          },
          onRename: (oldName: string, _newName: string) => {
            this.onRename(oldName, '');
          },
          onDelete: (category: string) => {
            this.onDelete(category);
          },
          onReorder: (categories: string[]) => {
            this.onReorder(categories);
          },
          onAdd: (_name: string) => {
            this.onAddCategory('');
          }
        })
        Row({ space: 12 }) {
          TextInput({ placeholder: '重量(g)', text: this.gearWeight })
            .type(InputType.Number)
            .height(48)
            .fontSize(14)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.onWeightChange(value);
            })
          TextInput({ placeholder: '价格(¥)', text: this.gearPrice })
            .type(InputType.Number)
            .height(48)
            .fontSize(14)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECONDARY)
            .backgroundColor(PAGE_BG)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.onPriceChange(value);
            })
        }
        TextInput({ placeholder: '备注（一行，可选）', text: this.gearNote })
          .type(InputType.Normal)
          .height(48)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onNoteChange(value);
          })
        Button(this.editingGearId.length === 0 ? '确认添加' : '确认保存')
          .height(48)
          .fontSize(14)
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
            this.onSave();
          })
      }
    }
    .edgeEffect(EdgeEffect.Spring)
    .layoutWeight(1)
  }
}
