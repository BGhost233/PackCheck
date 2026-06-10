// 移动装备到目标分组 — Sheet 内容组件
import {
  PAGE_BG,
  TEXT_MAIN
} from '../../constants/DesignTokens';
import { getGroupColor } from '../../utils/ColorUtils';

@Component
export struct MoveGroupSheet {
  @Prop categories: string[] = [];
  @Prop selectedCount: number = 0;
  onSelectGroup: (group: string) => void = (group: string): void => {};

  build() {
    Column({ space: 8 }) {
      if (this.selectedCount > 0) {
        Text(`已选择 ${this.selectedCount} 件装备`)
          .fontSize(13)
          .fontColor(TEXT_MAIN)
          .padding({ left: 4, bottom: 4 })
      }
      ForEach(this.categories, (group: string) => {
        Row() {
          Row()
            .width(3)
            .height(14)
            .backgroundColor(getGroupColor(group))
            .borderRadius(1.5)
            .margin({ right: 10 })
          Text(group)
            .fontSize(15)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16 })
        .borderRadius(12)
        .backgroundColor(PAGE_BG)
        .onClick(() => {
          this.onSelectGroup(group);
        })
      }, (group: string) => group)
    }
    .width('100%')
  }
}
