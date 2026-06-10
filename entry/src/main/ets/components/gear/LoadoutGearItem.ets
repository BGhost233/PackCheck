// 配装视图 - 单个装备项组件
// 职责：渲染一行装备（层级badge + 名称 + 重量 + 临时标记 + 勾选），tap勾选，long-press操作菜单

import {
  PRIMARY_COLOR,
  LIGHT_PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  CARD_BG,
  LAYER_BASE_BG,
  LAYER_MID_BG,
  LAYER_SHELL_BG,
  LAYER_INSULATION_BG,
  LAYER_ACCESSORY_BG
} from '../../constants/Colors';
import { LayerOrder } from '../../constants/GearLoadout';
import { SPRING_PRESS, SPRING_GENERAL } from '../../constants/AnimationTokens';
import { layerDisplayName } from '../../services/LoadoutService';
import { ChecklistItem } from '../../models/PackModels';
import { pressHandler } from '../../utils/AnimationUtils';

@Component
export struct LoadoutGearItem {
  @Prop item: ChecklistItem = {
    id: '', name: '', group: '', checked: false
  };
  @Prop layer: number = LayerOrder.Accessory;
  @Prop showLayerBadge: boolean = false;

  // 回调
  onToggleCheck: (itemId: string) => void = () => {};
  onLongPress: (item: ChecklistItem) => void = () => {};
  onTapLayerBadge: (item: ChecklistItem) => void = () => {};

  // 内部状态
  @State private pressed: boolean = false;
  @State private checkScale: number = 0;

  aboutToAppear(): void {
    this.checkScale = this.item.checked ? 1.0 : 0;
  }

  build() {
    Row({ space: 8 }) {
      // 层级 Badge（仅衣物 Zone 显示）
      if (this.showLayerBadge) {
        Text(layerDisplayName(this.layer))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_SECONDARY)
          .backgroundColor(this.layerBadgeBg())
          .borderRadius(6)
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .onClick(() => {
            this.onTapLayerBadge(this.item);
          })
          .hitTestBehavior(HitTestMode.Block)
      }

      // 装备名称
      Text(this.item.name)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
        .opacity(this.item.checked ? 0.5 : 1.0)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 重量
      if (this.item.weight !== undefined && this.item.weight > 0) {
        Text(this.item.weight.toString() + 'g')
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
          .opacity(this.item.checked ? 0.5 : 1.0)
      }

      // 临时标记
      if (this.item.fromGearId === undefined || this.item.fromGearId.length === 0) {
        Text('临时')
          .fontSize(10)
          .fontColor(TEXT_TERTIARY)
          .backgroundColor(LAYER_ACCESSORY_BG)
          .borderRadius(4)
          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
      }

      // 勾选 icon
      if (this.item.checked) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(14)
          .fontColor([PRIMARY_COLOR])
          .scale({ x: this.checkScale, y: this.checkScale })
          .animation({ curve: SPRING_PRESS() })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(10)
    .backgroundColor(this.item.checked ? LIGHT_PRIMARY_COLOR : CARD_BG)
    .animation({ curve: SPRING_GENERAL() })
    .scale({ x: this.pressed ? 0.97 : 1.0, y: this.pressed ? 0.97 : 1.0 })
    .animation({ curve: SPRING_PRESS() })
    .onTouch(pressHandler((v: boolean) => {
      this.pressed = v;
    }))
    .onClick(() => {
      this.onToggleCheck(this.item.id);
      // 勾选动画
      this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
        this.checkScale = this.item.checked ? 0 : 1.0;
      });
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          this.onLongPress(this.item);
        })
    )
  }

  private layerBadgeBg(): string {
    if (this.layer === LayerOrder.Base) {
      return LAYER_BASE_BG;
    }
    if (this.layer === LayerOrder.Mid) {
      return LAYER_MID_BG;
    }
    if (this.layer === LayerOrder.Shell) {
      return LAYER_SHELL_BG;
    }
    if (this.layer === LayerOrder.Insulation) {
      return LAYER_INSULATION_BG;
    }
    return LAYER_ACCESSORY_BG;
  }
}
