// 配装系统 - 装备选择 Sheet
// 职责：展示装备库全量列表，按品类分组可折叠展开，连续多选（点击即添加）
// 新建装备为同层级内联态切换（列表态 ↔ 新建态），无弹窗/遮罩
// GearPickerSheet 自管 head（标题随态 Spring 切换），SheetOverlay 不为它渲染统一 head

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
import { SPRING_PRESS, SPRING_GENERAL, SPRING_CHEVRON, PRESS_SCALE_DOWN } from '../../constants/AnimationTokens';
import { GearItem, CATEGORY_FALLBACK, DEFAULT_CATEGORIES } from '../../models/PackModels';
import { zoneDisplayName, allZones } from '../../services/LoadoutService';
import { vibrator } from '@kit.SensorServiceKit';

// 品类分组结果
interface CategoryGroup {
  category: string;
  gears: GearItem[];
}

@Component
export struct GearPickerSheet {
  // 数据
  @Prop gears: GearItem[] = [];
  @Prop categories: string[] = [];
  @Prop selectedItemIds: string[] = [];
  @Prop preselectZone: string = '';

  // 回调
  onToggleGear: (gear: GearItem) => void = () => {};
  onAddGear: (name: string, zone: string, weight: number | undefined, category: string, saveToLibrary: boolean) => void = () => {};
  onClose: () => void = () => {};

  // ===== 列表态状态 =====
  @State private searchText: string = '';
  @State private expandedCategories: string[] = [];
  @State private pressedCategory: string = '';
  @State private pressedGearRowId: string = '';
  @State private lastAddedGearId: string = '';
  @State private newEntryScale: number = 1.0;

  // ===== 新建态状态 =====
  @State private isCreateMode: boolean = false;
  @State private tempName: string = '';
  @State private tempZone: string = BodyZone.Misc;
  @State private tempWeight: string = '';
  @State private tempSaveToLibrary: boolean = false;
  @State private tempCategory: string = CATEGORY_FALLBACK;

  // ===== 态切换动画 =====
  @State private listOffsetX: number = 0;
  @State private listOpacity: number = 1;
  @State private createOffsetX: number = 20;
  @State private createOpacity: number = 0;
  // head 标题
  @State private headerTitle: string = '选择装备';
  // 添加按钮按压
  @State private addBtnScale: number = 1.0;

  aboutToAppear(): void {
    if (this.preselectZone.length > 0) {
      this.tempZone = this.preselectZone;
    }
  }

  build() {
    Column({ space: 0 }) {
      // Head：标题 + 关闭（紧凑，高 36vp）
      Row() {
        Text(this.headerTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .layoutWeight(1)
        Button('关闭')
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
          .backgroundColor(TRANSPARENT)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height(36)
      .margin({ bottom: 6 })

      // 内容区：列表态和新建态叠加
      Stack() {
        // 列表态
        Column({ space: 0 }) {
          // 搜索栏 + 新建按钮（一行）
          Row({ space: 8 }) {
            TextInput({ placeholder: '搜索装备...', text: this.searchText })
              .onChange((value: string) => {
                this.searchText = value;
              })
              .layoutWeight(1)
              .height(36)
              .fontSize(14)
              .backgroundColor(INPUT_BG)
              .borderRadius(10)
              .padding({ left: 12, right: 12 })

            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(14)
                .fontColor([CARD_BG])
              Text('新建')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(CARD_BG)
            }
            .height(36)
            .padding({ left: 12, right: 12 })
            .backgroundColor(PRIMARY_COLOR)
            .borderRadius(10)
            .scale({ x: this.newEntryScale, y: this.newEntryScale })
            .animation({ curve: SPRING_PRESS() })
            .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
                this.newEntryScale = PRESS_SCALE_DOWN;
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                this.newEntryScale = 1.0;
              }
            })
            .onClick(() => {
              this.enterCreateMode('');
            })
          }
          .width('100%')

          // 已选汇总（紧凑）
          if (this.selectedItemIds.length > 0) {
            Text('已添加 ' + this.selectedItemIds.length.toString() + ' 件装备')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(PRIMARY_COLOR)
              .margin({ top: 6 })
          }

          // 列表内容（紧贴上方）
          if (this.filteredGears().length === 0 && this.gears.length === 0) {
            this.buildEmptyState()
          } else if (this.filteredGears().length === 0 && this.searchText.length > 0) {
            this.buildSearchEmpty()
          } else {
            Scroll() {
              Column({ space: 0 }) {
                ForEach(this.groupedGears(), (group: CategoryGroup) => {
                  this.buildCategorySection(group)
                }, (group: CategoryGroup) => group.category + '_' + group.gears.length.toString())
              }
              .padding({ bottom: 24 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .margin({ top: 8 })
          }
        }
        .width('100%')
        .height('100%')
        .translate({ x: this.listOffsetX })
        .opacity(this.listOpacity)

        // 新建态
        if (this.isCreateMode) {
          this.buildCreateForm()
        }
      }
      .layoutWeight(1)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    // 右滑手势：新建态返回列表态
    .gesture(
      PanGesture({ direction: PanDirection.Right, distance: 30 })
        .onActionEnd(() => {
          if (this.isCreateMode) {
            this.exitCreateMode();
          }
        })
    )
  }

  // ===== 新建态：全宽内联表单（紧凑布局）=====
  @Builder
  private buildCreateForm() {
    Column({ space: 0 }) {
      Scroll() {
        Column({ space: 14 }) {
          // 「同时存入装备库」Toggle
          Row() {
            Text('同时存入装备库')
              .fontSize(14)
              .fontColor(TEXT_MAIN)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.tempSaveToLibrary })
              .onChange((isOn: boolean) => {
                this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
                  this.tempSaveToLibrary = isOn;
                });
              })
              .selectedColor(PRIMARY_COLOR)
              .width(48)
              .height(28)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 名称输入
          Column({ space: 6 }) {
            Text('名称')
              .fontSize(13)
              .fontColor(TEXT_SECONDARY)
            TextInput({ placeholder: '输入装备名称', text: this.tempName })
              .onChange((value: string) => {
                this.tempName = value;
              })
              .height(42)
              .fontSize(15)
              .backgroundColor(INPUT_BG)
              .borderRadius(10)
              .padding({ left: 14, right: 14 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 入库时品类选择（Spring 展开）
          Column({ space: 8 }) {
            Text('品类')
              .fontSize(13)
              .fontColor(TEXT_SECONDARY)
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
              ForEach(this.categoryOptions(), (cat: string) => {
                Text(cat)
                  .fontSize(13)
                  .fontWeight(this.tempCategory === cat ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.tempCategory === cat ? CARD_BG : TEXT_MAIN)
                  .backgroundColor(this.tempCategory === cat ? PRIMARY_COLOR : INPUT_BG)
                  .borderRadius(14)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .animation({ curve: SPRING_PRESS() })
                  .onClick(() => {
                    this.triggerHaptic();
                    this.tempCategory = cat;
                  })
              }, (cat: string) => cat)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .clip(true)
          .height(this.tempSaveToLibrary ? undefined : 0)
          .opacity(this.tempSaveToLibrary ? 1 : 0)
          .animation({ curve: SPRING_GENERAL() })

          // 归属区域
          Column({ space: 8 }) {
            Text('归属区域')
              .fontSize(13)
              .fontColor(TEXT_SECONDARY)
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
              ForEach(allZones(), (zone: string) => {
                Text(zoneDisplayName(zone))
                  .fontSize(13)
                  .fontWeight(this.tempZone === zone ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.tempZone === zone ? CARD_BG : TEXT_MAIN)
                  .backgroundColor(this.tempZone === zone ? this.getZoneColor(zone) : INPUT_BG)
                  .borderRadius(14)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .animation({ curve: SPRING_PRESS() })
                  .onClick(() => {
                    this.triggerHaptic();
                    this.tempZone = zone;
                  })
              }, (zone: string) => zone)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 重量（可选）
          Column({ space: 6 }) {
            Text('重量（可选）')
              .fontSize(13)
              .fontColor(TEXT_SECONDARY)
            Row({ space: 6 }) {
              TextInput({ placeholder: '0', text: this.tempWeight })
                .onChange((value: string) => {
                  this.tempWeight = value;
                })
                .width(90)
                .height(42)
                .fontSize(15)
                .backgroundColor(INPUT_BG)
                .borderRadius(10)
                .padding({ left: 14, right: 14 })
                .type(InputType.Number)
              Text('g')
                .fontSize(14)
                .fontColor(TEXT_TERTIARY)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ bottom: 80 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部固定按钮
      Button(this.tempSaveToLibrary ? '入库并添加' : '添加到' + zoneDisplayName(this.tempZone))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(CARD_BG)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(22)
        .width('100%')
        .height(44)
        .enabled(this.tempName.trim().length > 0)
        .opacity(this.tempName.trim().length > 0 ? 1.0 : 0.4)
        .scale({ x: this.addBtnScale, y: this.addBtnScale })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.addBtnScale = PRESS_SCALE_DOWN;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.addBtnScale = 1.0;
          }
        })
        .onClick(() => {
          this.handleCreate();
        })
        .margin({ top: 8, bottom: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(CARD_BG)
    .translate({ x: this.createOffsetX })
    .opacity(this.createOpacity)
  }

  // ===== 品类分组区 =====
  @Builder
  private buildCategorySection(group: CategoryGroup) {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Row()
          .width(3)
          .height(14)
          .borderRadius(1.5)
          .backgroundColor(PRIMARY_COLOR)

        Text(group.category)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(group.gears.length.toString())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_TERTIARY)
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(13)
          .fontColor([TEXT_TERTIARY])
          .rotate({ angle: this.isCategoryExpanded(group.category) ? 90 : 0 })
          .animation({ curve: SPRING_CHEVRON() })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor(INPUT_BG)
      .alignItems(VerticalAlign.Center)
      .scale({ x: this.pressedCategory === group.category ? PRESS_SCALE_DOWN : 1.0, y: this.pressedCategory === group.category ? PRESS_SCALE_DOWN : 1.0 })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.pressedCategory = group.category;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressedCategory = '';
        }
      })
      .onClick(() => {
        this.toggleCategoryAnimated(group.category);
      })

      Column({ space: 0 }) {
        ForEach(group.gears, (gear: GearItem) => {
          this.buildGearRow(gear)
        }, (gear: GearItem) => gear.id + '_' + (this.isSelected(gear.id) ? '1' : '0'))
      }
      .width('100%')
      .padding({ top: this.isCategoryExpanded(group.category) ? 4 : 0 })
      .clip(true)
      .height(this.isCategoryExpanded(group.category) ? undefined : 0)
      .opacity(this.isCategoryExpanded(group.category) ? 1 : 0)
      .animation({ curve: SPRING_GENERAL() })
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  private buildGearRow(gear: GearItem) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(gear.name)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          if (gear.brand !== undefined && gear.brand.length > 0) {
            Text(gear.brand)
              .fontSize(11)
              .fontColor(TEXT_TERTIARY)
          }
          if (gear.weight !== undefined && gear.weight > 0) {
            Text(gear.weight.toString() + 'g')
              .fontSize(11)
              .fontColor(TEXT_TERTIARY)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.isSelected(gear.id)) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(11)
            .fontColor([CARD_BG])
          Text('已添加')
            .fontSize(11)
            .fontColor(CARD_BG)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(12)
        .backgroundColor(this.getZoneColor(this.preselectZone.length > 0 ? this.preselectZone : BodyZone.Misc))
        .animation({ curve: SPRING_PRESS() })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 12, top: 10, bottom: 10 })
    .borderRadius(12)
    .scale({ x: this.pressedGearRowId === gear.id ? PRESS_SCALE_DOWN : 1.0,
      y: this.pressedGearRowId === gear.id ? PRESS_SCALE_DOWN : 1.0 })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedGearRowId = gear.id;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedGearRowId = '';
      }
    })
    .onClick(() => {
      this.handleGearTap(gear);
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
      Text('新建一件装备开始吧')
        .fontSize(13)
        .fontColor(TEXT_TERTIARY)
      Button('+ 新建装备')
        .fontSize(14)
        .fontColor(CARD_BG)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(8)
        .height(40)
        .margin({ top: 8 })
        .onClick(() => {
          this.enterCreateMode('');
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildSearchEmpty() {
    Column({ space: 12 }) {
      Text('没有找到匹配的装备')
        .fontSize(14)
        .fontColor(TEXT_SECONDARY)
      Button('+ 创建「' + this.searchText.trim() + '」')
        .fontSize(14)
        .fontColor(CARD_BG)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(8)
        .height(40)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.enterCreateMode(this.searchText.trim());
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // ===== 态切换逻辑 =====

  private enterCreateMode(presetName: string): void {
    this.triggerHaptic();
    this.tempName = presetName;
    this.tempZone = this.preselectZone.length > 0 ? this.preselectZone : BodyZone.Misc;
    this.tempWeight = '';
    this.tempSaveToLibrary = false;
    this.tempCategory = CATEGORY_FALLBACK;
    this.createOffsetX = 20;
    this.createOpacity = 0;
    this.isCreateMode = true;
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.listOffsetX = -20;
      this.listOpacity = 0;
      this.createOffsetX = 0;
      this.createOpacity = 1;
      this.headerTitle = '新建装备';
    });
  }

  private exitCreateMode(): void {
    this.triggerHaptic();
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL(),
      onFinish: () => {
        this.isCreateMode = false;
      }
    }, () => {
      this.createOffsetX = 20;
      this.createOpacity = 0;
      this.listOffsetX = 0;
      this.listOpacity = 1;
      this.headerTitle = '选择装备';
    });
  }

  private handleCreate(): void {
    if (this.tempName.trim().length === 0) return;
    this.triggerHaptic();
    const parsed = Number(this.tempWeight);
    const weight = (this.tempWeight.trim().length > 0 && !Number.isNaN(parsed)) ? parsed : undefined;
    this.onAddGear(this.tempName.trim(), this.tempZone, weight, this.tempCategory, this.tempSaveToLibrary);
    this.exitCreateMode();
  }

  // ===== 通用辅助 =====

  private filteredGears(): GearItem[] {
    let result = this.gears;
    if (this.searchText.trim().length > 0) {
      const keyword = this.searchText.trim().toLowerCase();
      result = result.filter((g: GearItem) => {
        const nameMatch = g.name.toLowerCase().indexOf(keyword) >= 0;
        const brandMatch = g.brand !== undefined && g.brand.toLowerCase().indexOf(keyword) >= 0;
        return nameMatch || brandMatch;
      });
    }
    return result;
  }

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

  private isCategoryExpanded(category: string): boolean {
    if (this.searchText.trim().length > 0) {
      return true;
    }
    return this.expandedCategories.indexOf(category) >= 0;
  }

  private toggleCategoryAnimated(category: string): void {
    this.triggerHaptic();
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      const idx = this.expandedCategories.indexOf(category);
      if (idx >= 0) {
        const next = this.expandedCategories.slice();
        next.splice(idx, 1);
        this.expandedCategories = next;
      } else {
        this.expandedCategories = this.expandedCategories.concat([category]);
      }
    });
  }

  private handleGearTap(gear: GearItem): void {
    this.triggerHaptic();
    if (!this.isSelected(gear.id)) {
      this.lastAddedGearId = gear.id;
    }
    this.onToggleGear(gear);
  }

  private isSelected(gearId: string): boolean {
    return this.selectedItemIds.indexOf(gearId) >= 0;
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

  private categoryOptions(): string[] {
    const result: string[] = DEFAULT_CATEGORIES.slice();
    for (const g of this.gears) {
      const cat = (g.category !== undefined && g.category.length > 0) ? g.category : '';
      if (cat.length > 0 && result.indexOf(cat) < 0) {
        result.push(cat);
      }
    }
    return result;
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.soft',
        count: 1
      }, { usage: 'touch' });
    } catch (_e) {
      // 静默失败
    }
  }
}
