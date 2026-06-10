import { CATEGORY_ALL, GearItem } from '../../models/PackModels';
import {
  FONT_FEATURE_TNUM,
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
import {
  filteredImportGears,
  importGearMetaText,
  categoryTabs
} from '../../services/GearService';
import { CategoryTagGroup } from '../CategoryTagGroup';

@Component
export struct ImportSheet {
  @Prop gears: GearItem[] = [];
  @Prop importGearIds: string[] = [];
  @Prop importGearCategory: string = CATEGORY_ALL;
  @Prop categories: string[] = [];
  onCategoryChange: (value: string) => void = (value: string): void => {};
  onToggleSelection: (id: string, checked: boolean) => void = (id: string, checked: boolean): void => {};
  onImport: () => void = (): void => {};
  onAddGearFromImport: () => void = (): void => {};

  @State private buttonPressed: boolean = false;
  @State private addButtonPressed: boolean = false;
  @State private pressedGearId: string = '';

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
            .scale({ x: this.addButtonPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
              y: this.addButtonPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
            .animation({ curve: SPRING_PRESS() })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.addButtonPressed = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.addButtonPressed = false;
              }
            })
            .onClick(() => {
              this.onAddGearFromImport();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        CategoryTagGroup({
          categories: this.categories,
          selectedCategory: this.importGearCategory,
          mode: 'single',
          showAllOption: true,
          editable: false,
          onSelect: (category: string) => {
            this.onCategoryChange(category);
          }
        })

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
              .scale({ x: this.pressedGearId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
                y: this.pressedGearId === item.id ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
              .animation({ curve: SPRING_PRESS() })
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressedGearId = item.id;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.pressedGearId = '';
                }
              })
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
          this.onImport();
        })
    }
    .height('100%')
  }
}
