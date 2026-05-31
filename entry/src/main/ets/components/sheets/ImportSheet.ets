import { GearItem } from '../../models/PackModels';
import {
  FONT_FEATURE_TNUM,
  PAGE_BG,
  PRIMARY_COLOR,
  CARD_BG,
  TEXT_MAIN,
  TEXT_SECONDARY
} from '../../constants/DesignTokens';
import {
  WHITE,
  DISABLED_COLOR,
  CHIP_BORDER
} from '../../constants/Colors';
import {
  filteredImportGears,
  importGearMetaText,
  categoryTabs
} from '../../services/GearService';

@Component
export struct ImportSheet {
  @Prop gears: GearItem[] = [];
  @Prop importGearIds: string[] = [];
  @Prop importGearCategory: string = '全部';
  @Prop categories: string[] = [];
  onCategoryChange: (value: string) => void = (value: string): void => {};
  onToggleSelection: (id: string, checked: boolean) => void = (id: string, checked: boolean): void => {};
  onImport: () => void = (): void => {};
  onAddGearFromImport: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      if (this.gears.length === 0) {
        Column({ space: 10 }) {
          Text('装备库还是空的')
            .fontSize(14)
            .fontColor(TEXT_MAIN)
          Text('添加你的第一件装备吧')
            .fontSize(12)
            .fontColor(TEXT_SECONDARY)
          Button('添加装备')
            .width(160)
            .height(44)
            .fontSize(14)
            .fontColor(WHITE)
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(12)
            .onClick(() => {
              this.onAddGearFromImport();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(categoryTabs(this.categories), (category: string) => {
            Text(category)
              .fontSize(13)
              .fontColor(this.importGearCategory === category ? WHITE : TEXT_SECONDARY)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor(this.importGearCategory === category ? PRIMARY_COLOR : CARD_BG)
              .border({ width: 1, color: this.importGearCategory === category ? PRIMARY_COLOR : CHIP_BORDER })
              .borderRadius(12)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.onCategoryChange(category);
              })
          }, (category: string) => category)
        }
        .width('100%')

        List({ space: 8 }) {
          ForEach(filteredImportGears(this.gears, this.importGearCategory), (item: GearItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Checkbox()
                  .select(this.importGearIds.indexOf(item.id) >= 0)
                  .onChange((checked: boolean) => {
                    this.onToggleSelection(item.id, checked);
                  })
                Column({ space: 4 }) {
                  Text(item.name)
                    .fontSize(14)
                    .fontColor(TEXT_MAIN)
                  if (importGearMetaText(item).length > 0) {
                    Text(importGearMetaText(item))
                      .fontSize(12)
                      .fontColor(TEXT_SECONDARY)
                      .fontFeature(FONT_FEATURE_TNUM)
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(PAGE_BG)
              .borderRadius(12)
            }
          }, (item: GearItem) => item.id)
        }
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
      }
      Button('导入选中 (' + this.importGearIds.length.toString() + ')')
        .height(48)
        .fontSize(14)
        .fontColor(WHITE)
        .backgroundColor(this.importGearIds.length === 0 ? DISABLED_COLOR : PRIMARY_COLOR)
        .width('100%')
        .enabled(this.importGearIds.length > 0)
        .onClick(() => {
          this.onImport();
        })
    }
    .height('100%')
  }
}
