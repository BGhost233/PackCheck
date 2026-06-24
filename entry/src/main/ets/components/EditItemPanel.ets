import {
  DANGER_COLOR,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../constants/DesignTokens';
import {
  WHITE,
  DISABLED_COLOR,
  OVERLAY_MASK,
  TRANSPARENT,
  SHADOW_LIGHT
} from '../constants/Colors';
import {
  SPRING_PANEL_ENTER,
  SPRING_PANEL_EXIT,
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST
} from '../constants/AnimationTokens';
import { CategoryTagGroup } from './CategoryTagGroup';

@Component
export struct EditItemPanel {
  @Prop editingItemName: string = '';
  @Prop editingItemGroup: string = '其他';
  @Prop editingItemWeight: string = '';
  @Prop editingItemPrice: string = '';
  @Prop errorText: string = '';
  @Prop categories: string[] = [];

  onNameChange: (value: string) => void = () => {};
  onGroupChange: (value: string) => void = () => {};
  onWeightChange: (value: string) => void = () => {};
  onPriceChange: (value: string) => void = () => {};
  onSave: () => void = () => {};
  onClose: () => void = () => {};
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAddCategory: (name: string) => void = () => {};

  // 内部动画状态
  @State private panelScale: number = 0.85;
  @State private panelOpacity: number = 0;
  @State private buttonPressed: boolean = false;
  @State private closePressed: boolean = false;
  private entryTimerId: number = -1;

  aboutToAppear(): void {
    this.entryTimerId = setTimeout(() => {
      this.entryTimerId = -1;
      this.getUIContext().animateTo({
        curve: SPRING_PANEL_ENTER()
      }, () => {
        this.panelScale = 1;
        this.panelOpacity = 1;
      });
    }, 0);
  }

  aboutToDisappear(): void {
    if (this.entryTimerId !== -1) {
      clearTimeout(this.entryTimerId);
      this.entryTimerId = -1;
    }
  }

  private handleClose(): void {
    this.getUIContext().animateTo({
      curve: SPRING_PANEL_EXIT(),
      onFinish: () => {
        this.onClose();
      }
    }, () => {
      this.panelScale = 0.9;
      this.panelOpacity = 0;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(OVERLAY_MASK)
        .backdropBlur(20)
        .opacity(this.panelOpacity)
        .onClick(() => {
          this.handleClose();
        })

      Column({ space: 16 }) {
        Row() {
          Text('编辑物品')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Blank()
          Row() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([TEXT_SECONDARY])
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .scale({ x: this.closePressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
            y: this.closePressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
          .animation({ curve: SPRING_PRESS() })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.closePressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.closePressed = false;
            }
          })
          .onClick(() => {
            this.handleClose();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 物品名称输入
        TextInput({ placeholder: '物品名称', text: this.editingItemName })
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

        Text('所属分组')
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
          .width('100%')

        // 分组标签
        CategoryTagGroup({
          categories: this.categories,
          selectedCategory: this.editingItemGroup,
          mode: 'single',
          editable: true,
          onSelect: (category: string) => {
            this.onGroupChange(category);
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

        // 重量 + 价格
        Row({ space: 12 }) {
          this.MetricInput('重量', this.editingItemWeight, 'g', (value: string) => {
            this.onWeightChange(value);
          })
          this.MetricInput('价格', this.editingItemPrice, '¥', (value: string) => {
            this.onPriceChange(value);
          })
        }
        .width('100%')

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Button('保存修改')
          .height(48)
          .fontSize(14)
          .fontColor(WHITE)
          .backgroundColor(this.editingItemName.trim().length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.editingItemName.trim().length > 0)
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
            this.onSave();
          })
      }
      .width('85%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .backgroundColor(WHITE)
      .borderRadius(24)
      .shadow({ radius: 24, color: SHADOW_LIGHT, offsetX: 0, offsetY: 8 })
      .scale({ x: this.panelScale, y: this.panelScale })
      .opacity(this.panelOpacity)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private MetricInput(label: string, textValue: string, unit: string, onValueChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      Row({ space: 6 }) {
        TextInput({ placeholder: '可选', text: textValue })
          .type(InputType.Number)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(TRANSPARENT)
          .layoutWeight(1)
          .onChange((value: string) => {
            onValueChange(value);
          })
        Text(unit)
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
      }
      .height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(PAGE_BG)
      .borderRadius(12)
    }
    .layoutWeight(1)
  }
}
