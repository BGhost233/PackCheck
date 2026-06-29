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
import {
  FONT_SIZE_SUBTITLE_LARGE,
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION,
  FONT_SIZE_BODY_SMALL
} from '../constants/Typography';
import { CategoryTagGroup } from './CategoryTagGroup';

@Component
export struct EditItemPanel {
  // 初始值由 Index 传入，组件内以 @State 自持编辑
  initialName: string = '';
  initialGroup: string = '其他';
  initialWeight: string = '';
  initialPrice: string = '';
  @Prop categories: string[] = [];

  @State editingItemName: string = '';
  @State editingItemGroup: string = '其他';
  @State editingItemWeight: string = '';
  @State editingItemPrice: string = '';
  @State errorText: string = '';

  onSave: (name: string, group: string, weight: string, price: string) => void = () => {};
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
    // 从初始值初始化 @State
    this.editingItemName = this.initialName;
    this.editingItemGroup = this.initialGroup;
    this.editingItemWeight = this.initialWeight;
    this.editingItemPrice = this.initialPrice;
    this.errorText = '';

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
            .fontSize(FONT_SIZE_SUBTITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Blank()
          Row() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(FONT_SIZE_TITLE_MEDIUM)
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
          .maxLength(100)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.editingItemName = value;
          })

        Text('所属分组')
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_SECONDARY)
          .width('100%')

        // 分组标签
        CategoryTagGroup({
          categories: this.categories,
          selectedCategory: this.editingItemGroup,
          mode: 'single',
          editable: true,
          onSelect: (category: string) => {
            this.editingItemGroup = category;
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
            this.editingItemWeight = value;
          })
          this.MetricInput('价格', this.editingItemPrice, '¥', (value: string) => {
            this.editingItemPrice = value;
          })
        }
        .width('100%')

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Button('保存修改')
          .height(48)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
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
            if (this.editingItemName.trim().length === 0) {
              this.errorText = '物品名称不能为空';
              return;
            }
            this.onSave(this.editingItemName, this.editingItemGroup, this.editingItemWeight, this.editingItemPrice);
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
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      Row({ space: 6 }) {
        TextInput({ placeholder: '可选', text: textValue })
          .type(InputType.Number)
          .maxLength(20)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(TRANSPARENT)
          .layoutWeight(1)
          .onChange((value: string) => {
            onValueChange(value);
          })
        Text(unit)
          .fontSize(FONT_SIZE_BODY_SMALL)
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
