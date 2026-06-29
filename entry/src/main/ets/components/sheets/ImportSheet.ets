import { CATEGORY_ALL, GearItem } from '../../models/PackModels';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_CAPTION
} from '../../constants/Typography';
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
  importGearMetaText
} from '../../services/GearService';
import { CategoryTagGroup } from '../CategoryTagGroup';

/**
 * 装备导入 Sheet — 从装备库选择装备导入到行程清单。
 *
 * §4.6 内化模式：选中状态和筛选分类在组件内部管理，
 * 提交时通过 onImport(ids) 回调将选中 ID 列表回传。
 */
@Component
export struct ImportSheet {
  @Prop gears: GearItem[] = [];
  @Prop categories: string[] = [];

  // 内部状态
  @State private importGearIds: string[] = [];
  @State private importGearCategory: string = CATEGORY_ALL;

  // 回调
  onImport: (ids: string[]) => void = () => {};
  onAddGearFromImport: () => void = (): void => {};

  @State private buttonPressed: boolean = false;
  @State private addButtonPressed: boolean = false;
  @State private pressedGearId: string = '';

  aboutToAppear(): void {
    this.importGearIds = [];
    this.importGearCategory = CATEGORY_ALL;
  }

  private toggleSelection(id: string, checked: boolean): void {
    const nextIds: string[] = [];
    for (let index = 0; index < this.importGearIds.length; index++) {
      if (this.importGearIds[index] !== id) {
        nextIds.push(this.importGearIds[index]);
      }
    }
    if (checked) {
      nextIds.push(id);
    }
    this.importGearIds = nextIds;
  }

  build() {
    Column({ space: 12 }) {
      if (this.gears.length === 0) {
        Column({ space: 10 }) {
          Text('装备库还是空的')
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontColor(TEXT_MAIN)
          Text('添加你的第一件装备吧')
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_SECONDARY)
          Button('添加装备')
            .width(160)
            .height(44)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
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
            this.importGearCategory = category;
          }
        })

        List({ space: 8 }) {
          ForEach(filteredImportGears(this.gears, this.importGearCategory), (item: GearItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Checkbox()
                  .select(this.importGearIds.indexOf(item.id) >= 0)
                  .onChange((checked: boolean) => {
                    this.toggleSelection(item.id, checked);
                  })
                Column({ space: 4 }) {
                  Text(item.name)
                    .fontSize(FONT_SIZE_BODY_MEDIUM)
                    .fontColor(TEXT_MAIN)
                  if (importGearMetaText(item).length > 0) {
                    Text(importGearMetaText(item))
                      .fontSize(FONT_SIZE_CAPTION)
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
        .fontSize(FONT_SIZE_BODY_MEDIUM)
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
          this.onImport(this.importGearIds);
        })
    }
    .height('100%')
  }
}
