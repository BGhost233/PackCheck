// 自绘长按悬浮详情卡 + 浮动菜单
// 职责：长按 item 后展示装备详情缩略图 + 编辑/多选/删除菜单（视觉复用 GearPage 设计语言）
// 渲染在自绘浮层内（不用 bindContextMenu），由 UnifiedChecklistView 的浮层 Stack 条件渲染驱动
// spec §4.5.2 / §0.6 / F-2

import {
  CARD_BG,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  DANGER_COLOR,
  DIVIDER_COLOR,
  INPUT_BG
} from '../../constants/Colors';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_CAPTION,
  FONT_WEIGHT_MEDIUM,
  FONT_WEIGHT_BOLD
} from '../../constants/Typography';
import { SPRING_PRESS, PRESS_SCALE_DOWN } from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem } from '../../models/PackModels';

// 菜单项接口（spec §4.5.2 指南范式）
export interface ContextMenuItem {
  icon: Resource;
  label: string;
  action: () => void;
  disabled?: boolean;
  destructive?: boolean;
}

@Component
export struct GearItemContextMenu {
  // 当前长按的 ChecklistItem
  @Prop item: ChecklistItem = { id: '', name: '', group: '', checked: false };
  // 通过 fromGearId 反查到的装备详情（可为 undefined = 临时装备）
  @Prop gear: GearItem | undefined = undefined;
  // 菜单项（由调用方注入具体 action）
  @Prop menuItems: ContextMenuItem[] = [];

  // 各菜单项按压态
  @State private pressedIndex: number = -1;

  build() {
    Column({ space: 12 }) {
      // ---- 详情缩略图卡 ----
      this.buildPreviewCard()

      // ---- 浮动菜单 ----
      this.buildMenu()
    }
    .alignItems(HorizontalAlign.Center)
  }

  // 装备详情缩略图（复用 GearPage 视觉：名称 + 品类/重量/品牌 chips + 备注）
  @Builder
  private buildPreviewCard() {
    Column({ space: 10 }) {
      // 装备名（大字加粗）
      Text(this.item.name)
        .fontSize(FONT_SIZE_BODY_LARGE)
        .fontWeight(FONT_WEIGHT_BOLD)
        .fontColor(TEXT_MAIN)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      // 属性 chips 行（品类 / 重量 / 品牌）
      if (this.hasAnyChip()) {
        Flex({ wrap: FlexWrap.Wrap }) {
          if (this.categoryText().length > 0) {
            this.buildChip('品类', this.categoryText())
          }
          if (this.weightText().length > 0) {
            this.buildChip('重量', this.weightText())
          }
          if (this.brandText().length > 0) {
            this.buildChip('品牌', this.brandText())
          }
        }
        .width('100%')
      }

      // 备注
      if (this.noteText().length > 0) {
        Text(this.noteText())
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_SECONDARY)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width(240)
    .padding(16)
    .backgroundColor(CARD_BG)
    .borderRadius(16)
    .shadow({ radius: 24, color: '#1A000000', offsetY: 8 })
  }

  // 浮动菜单（复用 GearPage 菜单视觉：圆角白卡 + 分割线 + 图标/文字/红色删除）
  @Builder
  private buildMenu() {
    Column() {
      ForEach(this.menuItems, (menuItem: ContextMenuItem, index: number) => {
        Row({ space: 12 }) {
          SymbolGlyph(menuItem.icon)
            .fontSize(20)
            .fontColor([menuItem.destructive === true ? DANGER_COLOR : TEXT_MAIN])

          Text(menuItem.label)
            .fontSize(FONT_SIZE_BODY_MEDIUM)
            .fontWeight(FONT_WEIGHT_MEDIUM)
            .fontColor(menuItem.destructive === true ? DANGER_COLOR : TEXT_MAIN)

          Blank()
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.pressedIndex === index ? INPUT_BG : CARD_BG)
        .opacity(menuItem.disabled === true ? 0.4 : 1.0)
        .scale({
          x: this.pressedIndex === index ? PRESS_SCALE_DOWN : 1.0,
          y: this.pressedIndex === index ? PRESS_SCALE_DOWN : 1.0
        })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (menuItem.disabled === true) {
            return;
          }
          if (e.type === TouchType.Down) {
            this.pressedIndex = index;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedIndex = -1;
          }
        })
        .onClick(() => {
          if (menuItem.disabled !== true) {
            menuItem.action();
          }
        })

        // 分割线（最后一项不加）
        if (index < this.menuItems.length - 1) {
          Divider()
            .color(DIVIDER_COLOR)
            .width('100%')
            .padding({ left: 16, right: 16 })
        }
      }, (menuItem: ContextMenuItem, index: number) => index.toString())
    }
    .width(200)
    .backgroundColor(CARD_BG)
    .borderRadius(14)
    .shadow({ radius: 16, color: '#14000000', offsetY: 4 })
    .clip(true)
  }

  @Builder
  private buildChip(label: string, value: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_TERTIARY)
      Text(value)
        .fontSize(FONT_SIZE_CAPTION)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_MAIN)
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .borderRadius(6)
    .backgroundColor(INPUT_BG)
    .margin({ right: 6, bottom: 6 })
  }

  // ---- 数据提取 helpers ----

  private categoryText(): string {
    if (this.gear !== undefined && this.gear.category.length > 0) {
      return this.gear.category;
    }
    return '';
  }

  private weightText(): string {
    let w: number | undefined = this.item.weight;
    if (w === undefined && this.gear !== undefined) {
      w = this.gear.weight;
    }
    return (w !== undefined && w > 0) ? (w.toString() + 'g') : '';
  }

  private brandText(): string {
    if (this.gear !== undefined && this.gear.brand !== undefined && this.gear.brand.length > 0) {
      return this.gear.brand;
    }
    return '';
  }

  private noteText(): string {
    if (this.gear !== undefined && this.gear.note !== undefined && this.gear.note.length > 0) {
      return this.gear.note;
    }
    return '';
  }

  private hasAnyChip(): boolean {
    return this.categoryText().length > 0 || this.weightText().length > 0 || this.brandText().length > 0;
  }
}
