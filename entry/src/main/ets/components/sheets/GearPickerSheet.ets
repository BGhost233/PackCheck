// 配装系统 - 装备选择 Sheet
// 职责：展示装备库列表，按品类筛选，连续多选，内联临时添加覆盖层

import {
  PRIMARY_COLOR,
  LIGHT_PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  CARD_BG,
  INPUT_BG,
  PAGE_BG,
  OVERLAY_DIM,
  ZONE_HEAD_COLOR,
  ZONE_UPPER_COLOR,
  ZONE_LOWER_COLOR,
  ZONE_FEET_COLOR,
  ZONE_CARRY_COLOR,
  ZONE_SLEEP_COLOR,
  ZONE_MISC_COLOR
} from '../../constants/Colors';
import { BodyZone } from '../../constants/GearLoadout';
import { SPRING_PRESS, SPRING_GENERAL, PANEL_SCALE_START } from '../../constants/AnimationTokens';
import { GearItem, ChecklistItem, CATEGORY_ALL } from '../../models/PackModels';
import { assignSlot, zoneDisplayName, allZones } from '../../services/LoadoutService';
import { CategoryTagGroup } from '../CategoryTagGroup';

@Component
export struct GearPickerSheet {
  // 数据
  @Prop gears: GearItem[] = [];
  @Prop categories: string[] = [];
  @Prop selectedItemIds: string[] = []; // 已在行程中的装备 fromGearId 列表

  // 回调
  onToggleGear: (gear: GearItem) => void = () => {};
  onTempAdd: (name: string, zone: string, weight: number | undefined) => void = () => {};
  onClose: () => void = () => {};

  // 内部状态
  @State private searchText: string = '';
  @State private filterCategory: string = CATEGORY_ALL;
  @State private showTempOverlay: boolean = false;
  @State private tempName: string = '';
  @State private tempZone: string = BodyZone.Misc;
  @State private tempWeight: string = '';
  @State private overlayScale: number = PANEL_SCALE_START;
  @State private overlayOpacity: number = 0;

  build() {
    Stack() {
      // 底层：正常 Sheet 内容
      Column({ space: 0 }) {
        // 搜索栏
        Row() {
          TextInput({ placeholder: '搜索装备...', text: this.searchText })
            .onChange((value: string) => {
              this.searchText = value;
            })
            .width('100%')
            .height(36)
            .fontSize(14)
            .backgroundColor(INPUT_BG)
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })

        // 品类 tab（sticky - 不随列表滚动）
        CategoryTagGroup({
          categories: this.categories,
          selectedCategory: this.filterCategory,
          mode: 'single',
          showAllOption: true,
          editable: false,
          onSelect: (category: string) => {
            this.filterCategory = category;
          }
        })
        .padding({ left: 16, right: 16, bottom: 8 })

        // 已选汇总栏
        if (this.selectedItemIds.length > 0) {
          Row({ space: 4 }) {
            Text('已选 ' + this.selectedItemIds.length.toString() + ' 件')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(PRIMARY_COLOR)
            Text(this.getZoneSummary())
              .fontSize(11)
              .fontColor(TEXT_TERTIARY)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }

        // 装备列表（可滚动）
        if (this.filteredGears().length === 0 && this.gears.length === 0) {
          // 装备库为空态
          this.buildEmptyState()
        } else {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.filteredGears(), (gear: GearItem) => {
                this.buildGearRow(gear)
              }, (gear: GearItem) => gear.id)

              // 底部临时添加入口
              Row({ space: 6 }) {
                Text('+')
                  .fontSize(16)
                  .fontColor(TEXT_SECONDARY)
                Text('临时添加（不入装备库）')
                  .fontSize(13)
                  .fontColor(TEXT_SECONDARY)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                this.openTempOverlay();
              })
            }
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

      // 上层：TempGearMiniSheet 内联覆盖层
      if (this.showTempOverlay) {
        // 遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(OVERLAY_DIM)
          .opacity(this.overlayOpacity)
          .onClick(() => {
            this.closeTempOverlay();
          })

        // 居中卡片
        Column({ space: 14 }) {
          Text('临时添加装备')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)

          // 名称
          Column({ space: 4 }) {
            Text('名称')
              .fontSize(12)
              .fontColor(TEXT_SECONDARY)
            TextInput({ placeholder: '装备名称', text: this.tempName })
              .onChange((value: string) => {
                this.tempName = value;
              })
              .height(36)
              .fontSize(14)
              .backgroundColor(INPUT_BG)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 归属区域
          Column({ space: 6 }) {
            Text('归属区域')
              .fontSize(12)
              .fontColor(TEXT_SECONDARY)
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
              ForEach(allZones(), (zone: string) => {
                Text(zoneDisplayName(zone))
                  .fontSize(12)
                  .fontColor(this.tempZone === zone ? CARD_BG : TEXT_MAIN)
                  .backgroundColor(this.tempZone === zone ? this.getZoneColor(zone) : INPUT_BG)
                  .borderRadius(14)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .onClick(() => {
                    this.tempZone = zone;
                  })
              }, (zone: string) => zone)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 重量
          Column({ space: 4 }) {
            Text('重量（可选）')
              .fontSize(12)
              .fontColor(TEXT_SECONDARY)
            Row({ space: 4 }) {
              TextInput({ placeholder: '0', text: this.tempWeight })
                .onChange((value: string) => {
                  this.tempWeight = value;
                })
                .width(80)
                .height(36)
                .fontSize(14)
                .backgroundColor(INPUT_BG)
                .borderRadius(8)
                .padding({ left: 12, right: 12 })
                .type(InputType.Number)
              Text('g')
                .fontSize(13)
                .fontColor(TEXT_TERTIARY)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 按钮组
          Row({ space: 12 }) {
            Button('取消')
              .fontSize(14)
              .fontColor(TEXT_SECONDARY)
              .backgroundColor(INPUT_BG)
              .borderRadius(8)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.closeTempOverlay();
              })
            Button('添加')
              .fontSize(14)
              .fontColor(CARD_BG)
              .backgroundColor(PRIMARY_COLOR)
              .borderRadius(8)
              .layoutWeight(1)
              .height(40)
              .enabled(this.tempName.trim().length > 0)
              .opacity(this.tempName.trim().length > 0 ? 1.0 : 0.5)
              .onClick(() => {
                const weight = this.tempWeight.trim().length > 0 ? Number(this.tempWeight) : undefined;
                this.onTempAdd(this.tempName.trim(), this.tempZone, weight);
                this.closeTempOverlay();
              })
          }
          .width('100%')
        }
        .width('80%')
        .padding(20)
        .backgroundColor(CARD_BG)
        .borderRadius(16)
        .scale({ x: this.overlayScale, y: this.overlayScale })
        .opacity(this.overlayOpacity)
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  private buildGearRow(gear: GearItem) {
    Row({ space: 8 }) {
      // 装备名称 + 品牌
      Column({ space: 2 }) {
        Text(gear.name)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (gear.brand !== undefined && gear.brand.length > 0) {
          Text(gear.brand)
            .fontSize(11)
            .fontColor(TEXT_TERTIARY)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 目标 Zone chip
      Row({ space: 4 }) {
        if (this.isSelected(gear.id)) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(11)
            .fontColor([CARD_BG])
        }
        Text(zoneDisplayName(assignSlot(gear).zone))
          .fontSize(11)
          .fontColor(this.isSelected(gear.id) ? CARD_BG : TEXT_MAIN)
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(12)
      .backgroundColor(this.isSelected(gear.id) ? PRIMARY_COLOR : this.getZoneColor(assignSlot(gear).zone) + '33')
      .animation({ curve: SPRING_PRESS() })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.onToggleGear(gear);
    })
  }

  @Builder
  private buildEmptyState() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.backpack'))
        .fontSize(48)
        .fontColor([TEXT_TERTIARY])
      Text('装备库还是空的')
        .fontSize(15)
        .fontColor(TEXT_SECONDARY)
      Text('先临时添加一件试试吧')
        .fontSize(13)
        .fontColor(TEXT_TERTIARY)
      Button('+ 临时添加一件')
        .fontSize(14)
        .fontColor(CARD_BG)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(8)
        .height(40)
        .margin({ top: 8 })
        .onClick(() => {
          this.openTempOverlay();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // ===== 辅助方法 =====

  private filteredGears(): GearItem[] {
    let result = this.gears;
    // 品类筛选
    if (this.filterCategory !== CATEGORY_ALL) {
      result = result.filter((g) => g.category === this.filterCategory);
    }
    // 搜索过滤
    if (this.searchText.trim().length > 0) {
      const keyword = this.searchText.trim().toLowerCase();
      result = result.filter((g) => {
        const nameMatch = g.name.toLowerCase().indexOf(keyword) >= 0;
        const brandMatch = g.brand !== undefined && g.brand.toLowerCase().indexOf(keyword) >= 0;
        return nameMatch || brandMatch;
      });
    }
    return result;
  }

  private isSelected(gearId: string): boolean {
    return this.selectedItemIds.indexOf(gearId) >= 0;
  }

  private getZoneSummary(): string {
    // 统计各 Zone 已选数量
    const zoneCounts = new Map<string, number>();
    for (const gearId of this.selectedItemIds) {
      const gear = this.gears.find((g) => g.id === gearId);
      if (gear !== undefined) {
        const zone = assignSlot(gear).zone;
        const existing = zoneCounts.get(zone) || 0;
        zoneCounts.set(zone, existing + 1);
      }
    }
    const parts: string[] = [];
    zoneCounts.forEach((count, zone) => {
      parts.push(zoneDisplayName(zone) + ' ' + count.toString());
    });
    return parts.length > 0 ? '> ' + parts.join(' - ') : '';
  }

  private getZoneColor(zone: string): string {
    if (zone === BodyZone.Head) return ZONE_HEAD_COLOR;
    if (zone === BodyZone.UpperBody) return ZONE_UPPER_COLOR;
    if (zone === BodyZone.LowerBody) return ZONE_LOWER_COLOR;
    if (zone === BodyZone.Feet) return ZONE_FEET_COLOR;
    if (zone === BodyZone.Carry) return ZONE_CARRY_COLOR;
    if (zone === BodyZone.Sleep) return ZONE_SLEEP_COLOR;
    return ZONE_MISC_COLOR;
  }

  private openTempOverlay(): void {
    this.tempName = '';
    this.tempZone = BodyZone.Misc;
    this.tempWeight = '';
    this.showTempOverlay = true;
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.overlayScale = 1.0;
      this.overlayOpacity = 1.0;
    });
  }

  private closeTempOverlay(): void {
    this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
      this.overlayScale = PANEL_SCALE_START;
      this.overlayOpacity = 0;
    });
    setTimeout(() => {
      this.showTempOverlay = false;
    }, 250);
  }
}
