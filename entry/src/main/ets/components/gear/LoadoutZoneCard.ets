// 配装视图 - Zone 卡片组件
// 职责：展示单个 BodyZone 的所有装备，按 LayerOrder 排序
// Misc 卡片内部按品类做子分区

import {
  CARD_BG,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  SHADOW_SUBTLE,
  DIVIDER_COLOR
} from '../../constants/Colors';
import { BodyZone } from '../../constants/GearLoadout';
import { SPRING_GENERAL } from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem } from '../../models/PackModels';
import {
  sortItemsByLayer,
  groupMiscByCategory,
  getLayerForItem,
  zoneDisplayName,
  zoneIconName
} from '../../services/LoadoutService';
import { LoadoutGearItem } from './LoadoutGearItem';

@Component
export struct LoadoutZoneCard {
  @Prop zone: string = BodyZone.Misc;
  @Prop @Watch('onItemsChange') items: ChecklistItem[] = [];
  @Prop gears: GearItem[] = [];
  @Prop zoneColor: string = '#78909C';

  // Misc 子分区缓存
  private miscMapCache: Map<string, ChecklistItem[]> = new Map();

  // 回调
  onToggleCheck: (itemId: string) => void = () => {};
  onLongPress: (item: ChecklistItem) => void = () => {};
  onTapLayerBadge: (item: ChecklistItem) => void = () => {};

  aboutToAppear(): void {
    this.refreshMiscCache();
  }

  onItemsChange(): void {
    this.refreshMiscCache();
  }

  private refreshMiscCache(): void {
    if (this.zone === BodyZone.Misc) {
      this.miscMapCache = groupMiscByCategory(this.items, this.gears);
    }
  }

  build() {
    Column({ space: 4 }) {
      // 标题行
      Row({ space: 6 }) {
        SymbolGlyph($r(zoneIconName(this.zone)))
          .fontSize(16)
          .fontColor([this.zoneColor])
        Text(zoneDisplayName(this.zone))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.zoneColor)
        Text(this.items.length.toString())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 4 })

      // 内容区
      if (this.zone === BodyZone.Misc) {
        this.buildMiscContent()
      } else {
        this.buildNormalContent()
      }
    }
    .width('100%')
    .backgroundColor(CARD_BG)
    .borderRadius(16)
    .shadow({ radius: 8, color: SHADOW_SUBTLE, offsetY: 2 })
    .clip(true)
  }

  @Builder
  private buildNormalContent() {
    // 按层级排序后渲染
    Column({ space: 0 }) {
      ForEach(sortItemsByLayer(this.items, this.gears), (item: ChecklistItem) => {
        LoadoutGearItem({
          item: item,
          layer: getLayerForItem(item, this.gears),
          showLayerBadge: this.zone === BodyZone.UpperBody || this.zone === BodyZone.LowerBody,
          onToggleCheck: this.onToggleCheck,
          onLongPress: this.onLongPress,
          onTapLayerBadge: this.onTapLayerBadge
        })
      }, (item: ChecklistItem) => item.id)
    }
    .width('100%')
    .padding({ bottom: 4 })
  }

  @Builder
  private buildMiscContent() {
    // Misc 内按品类分子区
    Column({ space: 0 }) {
      ForEach(this.getMiscCategories(), (category: string) => {
        // 品类子标题
        Row() {
          Text(category)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_SECONDARY)
            .layoutWeight(1)
          Text(this.getItemsForMiscCategory(category).length.toString())
            .fontSize(11)
            .fontColor(TEXT_TERTIARY)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 2 })

        // 该品类下的装备
        ForEach(this.getItemsForMiscCategory(category), (item: ChecklistItem) => {
          LoadoutGearItem({
            item: item,
            layer: getLayerForItem(item, this.gears),
            showLayerBadge: false,
            onToggleCheck: this.onToggleCheck,
            onLongPress: this.onLongPress,
            onTapLayerBadge: this.onTapLayerBadge
          })
        }, (item: ChecklistItem) => item.id)
      }, (category: string) => category)
    }
    .width('100%')
    .padding({ bottom: 4 })
  }

  // 获取 Misc 下的品类列表（从缓存读取）
  private getMiscCategories(): string[] {
    const categories: string[] = [];
    this.miscMapCache.forEach((_items, key) => {
      categories.push(key);
    });
    return categories;
  }

  // 获取 Misc 某品类下的装备列表（从缓存读取）
  private getItemsForMiscCategory(category: string): ChecklistItem[] {
    return this.miscMapCache.get(category) || [];
  }
}
