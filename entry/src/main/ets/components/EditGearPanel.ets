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
  ITEM_GAP,
  CARD_PADDING,
  CARD_RADIUS,
  SMALL_CARD_RADIUS
} from '../constants/Layout';
import {
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION,
  FONT_SIZE_BODY_SMALL,
  FONT_SIZE_OVERLINE
} from '../constants/Typography';
import { CategoryTagGroup } from './CategoryTagGroup';

// 问题10：紧凑高密度面板——单行输入框降至 40vp（Apple 表单单行标准），
//   字段竖排间距收紧至 ITEM_GAP，面板内边距收至 CARD_PADDING，消除松散大文本框观感。
const FIELD_HEIGHT: number = 40;
const SUB_GAP: number = 6;

@Component
export struct EditGearPanel {
  @Prop gearName: string = '';
  @Prop gearCategory: string = '其他';
  @Prop gearWeight: string = '';
  @Prop gearPrice: string = '';
  @Prop gearNote: string = '';
  @Prop errorText: string = '';
  @Prop categories: string[] = [];

  onNameChange: (value: string) => void = () => {};
  onCategoryChange: (value: string) => void = () => {};
  onWeightChange: (value: string) => void = () => {};
  onPriceChange: (value: string) => void = () => {};
  onNoteChange: (value: string) => void = () => {};
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

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({
        curve: SPRING_PANEL_ENTER()
      }, () => {
        this.panelScale = 1;
        this.panelOpacity = 1;
      });
    }, 0);
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

      Column({ space: ITEM_GAP }) {
        Row() {
          Text('编辑装备')
            .fontSize(17)
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

        // 装备名称
        TextInput({ placeholder: '装备名称（必填）', text: this.gearName })
          .type(InputType.Normal)
          .height(FIELD_HEIGHT)
          .maxLength(100)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(SMALL_CARD_RADIUS)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onNameChange(value);
          })

        Text('选择分组')
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(TEXT_SECONDARY)
          .width('100%')
          .margin({ top: -SUB_GAP })

        // 分组标签 (可滚动)
        Scroll() {
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
        }
        .constraintSize({ maxHeight: 120 })
        .edgeEffect(EdgeEffect.Spring)

        // 重量 + 价格
        Row({ space: ITEM_GAP }) {
          this.MetricInput('重量', this.gearWeight, 'g', (value: string) => {
            this.onWeightChange(value);
          })
          this.MetricInput('价格', this.gearPrice, '¥', (value: string) => {
            this.onPriceChange(value);
          })
        }
        .width('100%')

        // 备注
        TextInput({ placeholder: '备注（一行，可选）', text: this.gearNote })
          .type(InputType.Normal)
          .height(FIELD_HEIGHT)
          .maxLength(500)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SECONDARY)
          .backgroundColor(PAGE_BG)
          .borderRadius(SMALL_CARD_RADIUS)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onNoteChange(value);
          })

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Button('保存修改')
          .height(44)
          .fontSize(FONT_SIZE_OVERLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(WHITE)
          .backgroundColor(this.gearName.trim().length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.gearName.trim().length > 0)
          .borderRadius(SMALL_CARD_RADIUS)
          .margin({ top: SUB_GAP })
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
      .padding({ left: CARD_PADDING, right: CARD_PADDING, top: CARD_PADDING, bottom: CARD_PADDING })
      .backgroundColor(WHITE)
      .borderRadius(CARD_RADIUS)
      .shadow({ radius: 24, color: SHADOW_LIGHT, offsetX: 0, offsetY: 8 })
      .scale({ x: this.panelScale, y: this.panelScale })
      .opacity(this.panelOpacity)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private MetricInput(label: string, textValue: string, unit: string, onValueChange: (value: string) => void) {
    Column({ space: SUB_GAP }) {
      Text(label)
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
      Row({ space: SUB_GAP }) {
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
      .height(FIELD_HEIGHT)
      .padding({ left: 12, right: 12 })
      .backgroundColor(PAGE_BG)
      .borderRadius(SMALL_CARD_RADIUS)
    }
    .layoutWeight(1)
  }
}
