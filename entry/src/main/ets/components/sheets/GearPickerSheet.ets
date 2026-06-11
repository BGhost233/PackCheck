// 配装系统 - 装备选择 Sheet
// 职责：展示装备库列表，按品类分组可折叠展开，连续多选，内联临时添加覆盖层
// P5：去顶部品类 tab，改为装备按品类分组按行展示；默认全折叠，
//   预选 Zone 命中的品类 / 搜索命中的品类自动展开

import { LengthMetrics } from '@kit.ArkUI';
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
  TRANSPARENT,
  ZONE_HEAD_COLOR,
  ZONE_UPPER_COLOR,
  ZONE_LOWER_COLOR,
  ZONE_FEET_COLOR,
  ZONE_CARRY_COLOR,
  ZONE_SLEEP_COLOR,
  ZONE_MISC_COLOR,
  ZONE_HEAD_TINT,
  ZONE_UPPER_TINT,
  ZONE_LOWER_TINT,
  ZONE_FEET_TINT,
  ZONE_CARRY_TINT,
  ZONE_SLEEP_TINT,
  ZONE_MISC_TINT
} from '../../constants/Colors';
import { BodyZone } from '../../constants/GearLoadout';
import { SPRING_PRESS, SPRING_GENERAL, SPRING_CHEVRON, PANEL_SCALE_START } from '../../constants/AnimationTokens';
import { GearItem, CATEGORY_FALLBACK, DEFAULT_CATEGORIES } from '../../models/PackModels';
import { assignSlot, zoneDisplayName, allZones } from '../../services/LoadoutService';

// P5：品类分组结果（仅含有装备的品类）
interface CategoryGroup {
  category: string;
  gears: GearItem[];
}

@Component
export struct GearPickerSheet {
  // 数据
  @Prop gears: GearItem[] = [];
  @Prop categories: string[] = [];
  @Prop selectedItemIds: string[] = []; // 已在行程中的装备 fromGearId 列表
  // 从空格子进入时的预选 Zone（空串 = 无预选，向后兼容）：列表排序高亮 + 临时新建默认分区，review I4
  @Prop preselectZone: string = '';

  // 回调
  onToggleGear: (gear: GearItem) => void = () => {};
  onTempAdd: (name: string, zone: string, weight: number | undefined) => void = () => {};
  onClose: () => void = () => {};

  // 内部状态
  @State private searchText: string = '';
  // P5：手动展开的品类集合（用数组而非 Set，便于 @State 变更检测；toggle 时整体新数组赋值）
  @State private expandedCategories: string[] = [];
  @State private showTempOverlay: boolean = false;
  @State private tempName: string = '';
  @State private tempZone: string = BodyZone.Misc;
  @State private tempWeight: string = '';
  @State private overlayScale: number = PANEL_SCALE_START;
  @State private overlayOpacity: number = 0;
  @State private tempRowScale: number = 1.0;

  aboutToAppear(): void {
    // 从空格子进入时，临时新建装备默认落到该 Zone（review I4）
    if (this.preselectZone.length > 0) {
      this.tempZone = this.preselectZone;
    }
  }

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

        // 装备列表（可滚动）：P5 按品类分组折叠展开
        if (this.filteredGears().length === 0 && this.gears.length === 0) {
          // 装备库为空态
          this.buildEmptyState()
        } else if (this.filteredGears().length === 0 && this.searchText.length > 0) {
          // 搜索无结果
          this.buildSearchEmpty()
        } else {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.groupedGears(), (group: CategoryGroup) => {
                this.buildCategorySection(group)
              }, (group: CategoryGroup) => group.category + '_' + group.gears.length.toString())

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
              .scale({ x: this.tempRowScale, y: this.tempRowScale })
              .animation({ curve: SPRING_PRESS() })
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.tempRowScale = 0.97;
                } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  this.tempRowScale = 1.0;
                }
              })
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
                const parsed = Number(this.tempWeight);
                const weight = (this.tempWeight.trim().length > 0 && !Number.isNaN(parsed)) ? parsed : undefined;
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

  // P5：单个品类分组——折叠头（品类名 + 计数 + chevron）+ 展开时的装备行列表
  @Builder
  private buildCategorySection(group: CategoryGroup) {
    Column({ space: 0 }) {
      // 分组头（可点击折叠/展开）
      Row({ space: 8 }) {
        Text(group.category)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
        Text(group.gears.length.toString())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(13)
          .fontColor([TEXT_TERTIARY])
          // 展开时箭头旋转 90° 朝下；SPRING_CHEVRON 弹性
          .rotate({ angle: this.isCategoryExpanded(group.category) ? 90 : 0 })
          .animation({ curve: SPRING_CHEVRON() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.toggleCategory(group.category);
      })

      // 展开态：该品类下装备行
      if (this.isCategoryExpanded(group.category)) {
        ForEach(group.gears, (gear: GearItem) => {
          this.buildGearRow(gear)
        }, (gear: GearItem) => gear.id)
      }
    }
    .width('100%')
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
      .backgroundColor(this.isSelected(gear.id) ? PRIMARY_COLOR : this.getZoneTintColor(assignSlot(gear).zone))
      // 预选 Zone 装备：未选中时描一圈主题色边框做轻量提示（review I4）
      .border(this.isPreselectZone(gear) && !this.isSelected(gear.id)
        ? { width: 1, color: PRIMARY_COLOR }
        : { width: 0, color: TRANSPARENT })
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
      SymbolGlyph($r('sys.symbol.bag'))
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

  @Builder
  private buildSearchEmpty() {
    Column({ space: 8 }) {
      Text('没有找到匹配的装备')
        .fontSize(14)
        .fontColor(TEXT_SECONDARY)
      Text('试试换个关键词，或临时添加一件')
        .fontSize(12)
        .fontColor(TEXT_TERTIARY)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // ===== 辅助方法 =====

  // 搜索过滤后的装备（品类分组前的全量集合）。P5：去掉品类筛选，仅按搜索关键词过滤。
  private filteredGears(): GearItem[] {
    let result = this.gears;
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

  // P5：把 filteredGears 按 category 聚合成分组（仅含有装备的品类）。
  // 顺序：先按 DEFAULT_CATEGORIES 预设顺序，自定义品类按首次出现顺序追加在后。
  private groupedGears(): CategoryGroup[] {
    const buckets = new Map<string, GearItem[]>();
    const customOrder: string[] = [];
    for (const g of this.filteredGears()) {
      const cat = (g.category !== undefined && g.category.length > 0) ? g.category : CATEGORY_FALLBACK;
      if (!buckets.has(cat)) {
        buckets.set(cat, []);
        if (DEFAULT_CATEGORIES.indexOf(cat) < 0) {
          customOrder.push(cat);
        }
      }
      buckets.get(cat)!.push(g);
    }
    const ordered: string[] = DEFAULT_CATEGORIES.concat(customOrder);
    const result: CategoryGroup[] = [];
    for (const cat of ordered) {
      const list = buckets.get(cat);
      if (list !== undefined && list.length > 0) {
        result.push({ category: cat, gears: list });
      }
    }
    return result;
  }

  // P5：预选 Zone 对应的品类集合（数据驱动反查：遍历装备收集该 Zone 的 category，无硬编码映射）
  private preselectCategories(): string[] {
    if (this.preselectZone.length === 0) {
      return [];
    }
    const cats: string[] = [];
    for (const g of this.gears) {
      if (assignSlot(g).zone === this.preselectZone) {
        const cat = (g.category !== undefined && g.category.length > 0) ? g.category : CATEGORY_FALLBACK;
        if (cats.indexOf(cat) < 0) {
          cats.push(cat);
        }
      }
    }
    return cats;
  }

  // P5：品类是否展开 = 手动展开 OR 搜索命中（搜索态全展开方便看到结果）OR 预选 Zone 命中该品类
  private isCategoryExpanded(category: string): boolean {
    if (this.searchText.trim().length > 0) {
      return true;
    }
    if (this.expandedCategories.indexOf(category) >= 0) {
      return true;
    }
    return this.preselectCategories().indexOf(category) >= 0;
  }

  // P5：手动切换品类折叠态（整体新数组赋值触发 @State 刷新）
  private toggleCategory(category: string): void {
    const idx = this.expandedCategories.indexOf(category);
    if (idx >= 0) {
      const next = this.expandedCategories.slice();
      next.splice(idx, 1);
      this.expandedCategories = next;
    } else {
      this.expandedCategories = this.expandedCategories.concat([category]);
    }
  }

  // 是否为预选 Zone 的装备（用于列表轻量高亮提示）
  private isPreselectZone(gear: GearItem): boolean {
    return this.preselectZone.length > 0 && assignSlot(gear).zone === this.preselectZone;
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

  private getZoneTintColor(zone: string): string {
    if (zone === BodyZone.Head) return ZONE_HEAD_TINT;
    if (zone === BodyZone.UpperBody) return ZONE_UPPER_TINT;
    if (zone === BodyZone.LowerBody) return ZONE_LOWER_TINT;
    if (zone === BodyZone.Feet) return ZONE_FEET_TINT;
    if (zone === BodyZone.Carry) return ZONE_CARRY_TINT;
    if (zone === BodyZone.Sleep) return ZONE_SLEEP_TINT;
    return ZONE_MISC_TINT;
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
    this.getUIContext().animateTo({
      curve: SPRING_PRESS(),
      onFinish: () => {
        this.showTempOverlay = false;
      }
    }, () => {
      this.overlayScale = PANEL_SCALE_START;
      this.overlayOpacity = 0;
    });
  }
}
