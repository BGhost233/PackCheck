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
export struct TempItemSheet {
  @Prop tempItemName: string = '';
  @Prop tempItemGroup: string = '其他';
  @Prop showTempAddNotice: boolean = false;
  @Prop categories: string[] = [];
  onNameChange: (value: string) => void = (value: string): void => {};
  onGroupChange: (value: string) => void = (value: string): void => {};
  onConfirm: () => void = (): void => {};
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAddCategory: (name: string) => void = () => {};

  @State private buttonPressed: boolean = false;

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '输入物品名称', text: this.tempItemName })
        .type(InputType.Normal)
        .maxLength(100)
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
        selectedCategory: this.tempItemGroup,
        mode: 'single',
        editable: true,
        onSelect: (category: string) => {
          this.onGroupChange(category);
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
      if (this.showTempAddNotice) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(12)
            .fontColor([PRIMARY_COLOR])
          Text('已添加')
            .fontSize(12)
            .fontColor(PRIMARY_COLOR)
        }
        .width('100%')
      }
      Button('确认添加')
        .height(48)
        .fontSize(14)
        .fontColor(WHITE)
        .backgroundColor(this.tempItemName.trim().length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.tempItemName.trim().length > 0)
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
          this.onConfirm();
        })
    }
  }
}
