import { curves, LengthMetrics } from '@kit.ArkUI';
import {
  CARD_BG,
  DANGER_COLOR,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../constants/DesignTokens';
import {
  DURATION_SLOW
} from '../constants/AnimationTokens';

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

  // 内部动画状态
  @State private panelScale: number = 0.85;
  @State private panelOpacity: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: DURATION_SLOW,
        curve: curves.springMotion(0.35, 0.8)
      }, () => {
        this.panelScale = 1;
        this.panelOpacity = 1;
      });
    }, 0);
  }

  private handleClose(): void {
    this.getUIContext().animateTo({
      duration: 200,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.onClose();
      }
    }, () => {
      this.panelScale = 0.9;
      this.panelOpacity = 0;
    });
  }

  private presetCategories(): string[] {
    const defaults: string[] = ['帐篷', '睡眠', '炊具', '电子', '衣物', '鞋袜', '配件', '食品', '其他'];
    const result: string[] = [];
    for (let i = 0; i < defaults.length; i++) {
      result.push(defaults[i]);
    }
    for (let i = 0; i < this.categories.length; i++) {
      if (result.indexOf(this.categories[i]) < 0) {
        result.push(this.categories[i]);
      }
    }
    return result;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .backdropBlur(20)
        .opacity(this.panelOpacity)
        .onClick(() => {
          this.handleClose();
        })

      Column({ space: 16 }) {
        Row() {
          Text('编辑装备')
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
          .onClick(() => {
            this.handleClose();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 装备名称
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

        // 分组标签 (可滚动)
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            ForEach(this.presetCategories(), (category: string) => {
              Text(category)
                .fontSize(13)
                .fontColor(this.gearCategory === category ? '#FFFFFF' : '#666666')
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .backgroundColor(this.gearCategory === category ? PRIMARY_COLOR : CARD_BG)
                .border({ width: 1, color: this.gearCategory === category ? PRIMARY_COLOR : '#E0E0E0' })
                .borderRadius(12)
                .onClick(() => {
                  this.onCategoryChange(category);
                })
            }, (category: string) => category)
          }
          .width('100%')
        }
        .height(96)
        .edgeEffect(EdgeEffect.Spring)

        // 重量 + 价格
        Row({ space: 12 }) {
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

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor(DANGER_COLOR)
            .width('100%')
        }

        Button('保存修改')
          .height(48)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.gearName.trim().length === 0 ? '#CCCCCC' : PRIMARY_COLOR)
          .width('100%')
          .enabled(this.gearName.trim().length > 0)
          .borderRadius(12)
          .onClick(() => {
            this.onSave();
          })
      }
      .width('85%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .backgroundColor(CARD_BG)
      .borderRadius(24)
      .shadow({ radius: 24, color: '#14000000', offsetX: 0, offsetY: 8 })
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
          .backgroundColor('#00000000')
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
