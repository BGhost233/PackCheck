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
 * 临时物品添加 Sheet。
 *
 * §4.6 内化模式：外部通过 initialXxx 传入初始值，内部 @State 持有编辑态。
 * 提交后不关闭 sheet，而是清空输入+显示"已添加"提示，允许连续添加。
 */
@Component
export struct TempItemSheet {
  // 初始值 props（外部传入，仅用于 aboutToAppear 初始化）
  initialName: string = '';
  initialGroup: string = '其他';
  @Prop categories: string[] = [];

  // 表单字段 — 内部状态
  @State private tempItemName: string = '';
  @State private tempItemGroup: string = '其他';
  @State private showAddNotice: boolean = false;

  // 回调：提交表单数据（连续添加模式，添加后不关闭 sheet）
  onConfirm: (name: string, group: string) => void = () => {};
  // 分组管理回调
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAddCategory: (name: string) => void = () => {};

  @State private buttonPressed: boolean = false;

  aboutToAppear(): void {
    this.tempItemName = this.initialName;
    this.tempItemGroup = this.initialGroup;
    this.showAddNotice = false;
  }

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '输入物品名称', text: this.tempItemName })
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
          this.tempItemName = value;
        })
      Text('选择分组')
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      CategoryTagGroup({
        categories: this.categories,
        selectedCategory: this.tempItemGroup,
        mode: 'single',
        editable: true,
        onSelect: (category: string) => {
          this.tempItemGroup = category;
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
      if (this.showAddNotice) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor([PRIMARY_COLOR])
          Text('已添加')
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(PRIMARY_COLOR)
        }
        .width('100%')
      }
      Button('确认添加')
        .height(48)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
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
          this.onConfirm(this.tempItemName, this.tempItemGroup);
          // 连续添加：清空名称 + 显示"已添加"提示
          this.tempItemName = '';
          this.showAddNotice = true;
        })
    }
  }
}
