// 配装系统 - 装备操作 ActionSheet
// 职责：移动到其他区域 / 查看装备详情 / 从行程移除

import {
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  DANGER_COLOR,
  CARD_BG,
  INPUT_BG,
  DIVIDER_COLOR,
  ZONE_HEAD_COLOR,
  ZONE_UPPER_COLOR,
  ZONE_LOWER_COLOR,
  ZONE_FEET_COLOR,
  ZONE_CARRY_COLOR,
  ZONE_SLEEP_COLOR,
  ZONE_MISC_COLOR
} from '../../constants/Colors';
import { BodyZone } from '../../constants/GearLoadout';
import { SPRING_PRESS } from '../../constants/AnimationTokens';
import { ChecklistItem } from '../../models/PackModels';
import { zoneDisplayName, allZones } from '../../services/LoadoutService';
import { LengthMetrics } from '@kit.ArkUI';

@Component
export struct GearItemActionSheet {
  @Prop item: ChecklistItem = { id: '', name: '', group: '', checked: false };

  // 回调
  onMoveToZone: (itemId: string, zone: string) => void = () => {};
  onViewDetail: (item: ChecklistItem) => void = () => {};
  onRemove: (itemId: string) => void = () => {};
  onClose: () => void = () => {};

  // 内部状态
  @State private showZoneSelector: boolean = false;

  build() {
    Column({ space: 0 }) {
      if (!this.showZoneSelector) {
        // 标题
        Text(this.item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 4, bottom: 12 })

        Divider().color(DIVIDER_COLOR).width('100%')

        // 移动到其他区域
        Row() {
          Text('移动到其他区域')
            .fontSize(15)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron.right'))
            .fontSize(14)
            .fontColor([TEXT_TERTIARY])
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .onClick(() => {
          this.showZoneSelector = true;
        })

        Divider().color(DIVIDER_COLOR).width('100%')

        // 查看装备详情
        Row() {
          Text('查看装备详情')
            .fontSize(15)
            .fontColor(TEXT_MAIN)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .onClick(() => {
          this.onViewDetail(this.item);
        })

        Divider().color(DIVIDER_COLOR).width('100%')

        // 从行程移除（红色）
        Row() {
          Text('从行程移除')
            .fontSize(15)
            .fontColor(DANGER_COLOR)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .onClick(() => {
          this.onRemove(this.item.id);
        })

        Divider().color(DIVIDER_COLOR).width('100%')

        // 取消
        Row() {
          Text('取消')
            .fontSize(15)
            .fontColor(TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onClose();
        })
      } else {
        // Zone 选择器
        Text('移动到')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 4, bottom: 12 })

        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
          ForEach(allZones(), (zone: string) => {
            Text(zoneDisplayName(zone))
              .fontSize(14)
              .fontColor(this.item.group === zone ? CARD_BG : TEXT_MAIN)
              .backgroundColor(this.item.group === zone ? this.getZoneColor(zone) : INPUT_BG)
              .borderRadius(16)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .onClick(() => {
                this.onMoveToZone(this.item.id, zone);
              })
              .animation({ curve: SPRING_PRESS() })
          }, (zone: string) => zone)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })

        Divider().color(DIVIDER_COLOR).width('100%')

        // 返回
        Row() {
          Text('取消')
            .fontSize(15)
            .fontColor(TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showZoneSelector = false;
        })
      }
    }
    .width('100%')
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
}
