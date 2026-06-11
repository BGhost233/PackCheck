// 统一清单视图 - 单个装备核查行
// 职责：左侧圆形 CheckMark + 装备名，点击切换 checked，勾选弹跳动画
// 网格态（紧凑）与全屏聚焦态（宽松）共用，通过 rowHeight/checkSize prop 调整尺寸
// spec §2.1.3 / §3.3：勾选 scale 0.8→1.1→1.0(SPRING_PRESS)；已勾文字变灰 + 实心绿勾
// P2 双热区：checkOnlyHotzone=true 时整行不绑 onClick，只 check 圆圈拦截勾选，
//   装备名/空白处的点击冒泡到外层格子触发聚焦；false 时整行点击即勾选（聚焦态用）

import {
  PRIMARY_COLOR,
  CARD_BG,
  TEXT_MAIN,
  PLACEHOLDER_COLOR,
  DIVIDER_COLOR,
  TRANSPARENT
} from '../../constants/Colors';
import {
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_MEDIUM
} from '../../constants/Typography';
import { SPRING_PRESS } from '../../constants/AnimationTokens';
import { ChecklistItem } from '../../models/PackModels';

@Component
export struct ChecklistRow {
  @Prop @Watch('onCheckedChange') item: ChecklistItem = {
    id: '', name: '', group: '', checked: false
  };
  @Prop rowHeight: number = 40;
  @Prop checkSize: number = 24;
  @Prop fontSize: number = FONT_SIZE_BODY_MEDIUM;
  // P2：true 时仅 check 圆圈是勾选热区，整行其余区域点击冒泡给外层（网格态）
  @Prop checkOnlyHotzone: boolean = false;

  // 回调
  onToggleCheck: (itemId: string) => void = () => {};

  // 勾选标记缩放（弹跳动画）
  @State private checkScale: number = 0;
  // 整行按压
  @State private pressed: boolean = false;
  // 上一次的 checked 值：@Watch('item') 会被 item 任意字段变化触发，
  // 用此守卫只在 checked 真正变化时才走动画逻辑（review C1）
  private lastChecked: boolean = false;

  aboutToAppear(): void {
    this.checkScale = this.item.checked ? 1.0 : 0;
    this.lastChecked = this.item.checked;
  }

  // checked 变化时弹跳：0→1（勾上）或 1→0（取消）
  onCheckedChange(): void {
    // item 其他字段变动不应重复调用动画；checkScale 守卫之前先用 lastChecked 早返回
    if (this.lastChecked === this.item.checked) {
      return;
    }
    this.lastChecked = this.item.checked;
    const target: number = this.item.checked ? 1.0 : 0;
    if (this.checkScale !== target) {
      this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
        this.checkScale = target;
      });
    }
  }

  build() {
    Row({ space: 10 }) {
      // 圆形 CheckMark：未勾空心灰圈 / 已勾实心绿圆 + 白勾
      // P2：checkOnlyHotzone 时此 Stack 单独绑 onClick 拦截勾选 + 按压反馈，
      //   不触碰整行 onClick，避免与外层聚焦手势冲突
      Stack() {
        // 外圈（恒在）
        Circle()
          .width(this.checkSize)
          .height(this.checkSize)
          .fill(this.item.checked ? PRIMARY_COLOR : TRANSPARENT)
          .stroke(this.item.checked ? PRIMARY_COLOR : DIVIDER_COLOR)
          .strokeWidth(2)
          .animation({ curve: SPRING_PRESS() })

        // 白勾（scale 控制弹跳出现）
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(this.checkSize * 0.56)
          .fontColor([CARD_BG])
          .fontWeight(FontWeight.Bold)
          .scale({ x: this.checkScale, y: this.checkScale })
          .opacity(this.checkScale)
      }
      .width(this.checkSize)
      .height(this.checkSize)
      .alignContent(Alignment.Center)
      // 热区命中区域略放大，便于点击；按压反馈仅在双热区模式下挂到圆圈上
      .scale({
        x: this.checkOnlyHotzone && this.pressed ? 0.9 : 1.0,
        y: this.checkOnlyHotzone && this.pressed ? 0.9 : 1.0
      })
      .animation({ curve: SPRING_PRESS() })
      .onTouch((e: TouchEvent) => {
        if (!this.checkOnlyHotzone) {
          return;
        }
        if (e.type === TouchType.Down) {
          this.pressed = true;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressed = false;
        }
      })
      .onClick(() => {
        if (this.checkOnlyHotzone) {
          // 拦截：仅圆圈触发勾选，点击不冒泡到外层格子聚焦手势
          this.onToggleCheck(this.item.id);
        }
      })

      // 装备名（已勾变灰）
      Text(this.item.name)
        .fontSize(this.fontSize)
        .fontColor(this.item.checked ? PLACEHOLDER_COLOR : TEXT_MAIN)
        .decoration({ type: this.item.checked ? TextDecorationType.LineThrough : TextDecorationType.None })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ curve: SPRING_PRESS() })
    }
    .width('100%')
    .height(this.rowHeight)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    // 整行按压反馈仅在「整行点击勾选」模式（聚焦态）下生效
    .scale({
      x: !this.checkOnlyHotzone && this.pressed ? 0.96 : 1.0,
      y: !this.checkOnlyHotzone && this.pressed ? 0.96 : 1.0
    })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (this.checkOnlyHotzone) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      // 双热区模式整行不绑勾选，点击冒泡至外层格子触发聚焦
      if (!this.checkOnlyHotzone) {
        this.onToggleCheck(this.item.id);
      }
    })
  }
}
