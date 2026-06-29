// 统一清单视图 - 网格态单格组件
// 职责：渲染单个 BodyZone 的格子（有内容态白卡 / 空态虚线框）
// 标题行 = Zone 色条 + 图标 + 名称 + 数量；点击标题/白卡主体进全屏聚焦
// P2 双热区：白卡内 ChecklistRow 走 checkOnlyHotzone——点 check 圆圈仅勾选，
//   点装备名/空白/标题冒泡到外层触发全屏聚焦。空态点虚线框打开 picker。
// spec §2.1.3 / §2.1.2

import {
  TEXT_TERTIARY,
  DIVIDER_COLOR,
  PLACEHOLDER_COLOR,
  ZONE_MISC_COLOR,
  ZONE_MISC_STROKE,
  ZONE_MISC_FILL
} from '../../constants/Colors';
import {
  FONT_SIZE_CAPTION,
  FONT_SIZE_SUBTITLE_LARGE
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import { SPRING_PRESS, PRESS_SCALE_DOWN, SPRING_GENERAL } from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { zoneDisplayName } from '../../services/LoadoutService';
import { ChecklistRow } from './ChecklistRow';
import { resolveItemNameByIndex } from '../../services/ChecklistService';
import { ZoneShell } from './ZoneShell';
import { hapticSoft } from '../../utils/HapticUtils';

// 网格态单格内最多预览的 item 数（超出折叠为「+N 件」提示）。spec §2.1.3
// 问题5：收缩态露 5 个装备名（cellHeight 内容区 ~174vp 足够容纳 5×32=160vp，提升信息密度）
const MAX_PREVIEW_ITEMS: number = 5;
// P4：网格态核查行压缩一档（聚焦态仍用默认宽松尺寸）
const GRID_ROW_HEIGHT: number = 32;
const GRID_CHECK_SIZE: number = 20;

@Component
export struct ZoneGridCell {
  @Prop zone: string = BodyZone.Misc;
  @Prop items: ChecklistItem[] = [];
  // 「实时引用」模型：传入装备库用于 resolve item 展示名
  @Prop gears: GearItem[] = [];
  // 性能：父层预构建的 gearId → GearItem 索引，渲染热路径 O(1) 反查
  @Prop gearIndex: Map<string, GearItem> = new Map();
  @Prop zoneColor: string = ZONE_MISC_COLOR;
  // 容器描边色 + 整块淡色填充底（由父层 zoneStroke/zoneFill helper 传入）
  @Prop zoneStroke: string = ZONE_MISC_STROKE;
  @Prop zoneFill: string = ZONE_MISC_FILL;
  @Prop cellHeight: number = 160;
  // 问题3 修复：勾选只改某 item 的 checked，items 数组引用变了但本组件 @Prop items 是值拷贝，
  //   父层 ForEach key（zone+数量）不变 → 本组件节点不重建 → @Prop 不重新下发 → 视觉不刷新。
  //   父层每次勾选自增 checklistRenderNonce 透传进来，@Watch 后自增 itemsVersion，
  //   内层 ChecklistRow 的 ForEach key 拼上 itemsVersion → 勾选即重建受影响行，立即刷新。
  @Prop @Watch('onRenderNonceChange') renderNonce: number = 0;
  @State private itemsVersion: number = 0;

  // 回调（Phase 2/3 接入）
  onTapTitle: (zone: string) => void = () => {};
  onTapEmpty: (zone: string) => void = () => {};
  onTapAdd: (zone: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  // Phase 4：网格态长按+拖拽回调（full mode）
  onLongPressItem: (item: ChecklistItem, globalX: number, globalY: number) => void = () => {};
  onPanUpdate: (offsetX: number, offsetY: number) => void = () => {};
  onPanFinish: (offsetX: number, offsetY: number) => void = () => {};

  // 拖拽悬停高亮：拖拽胶囊进入本格子时父层设为 true，格子边框 glow 绿光
  @Prop isDropTarget: boolean = false;

  // C-1：当前被拖拽 item 的 id（空串表示无拖拽）。命中行在源位置渲染虚线空槽，明确"从哪拿的"
  @Prop draggingItemId: string = '';

  // 标题行按压
  @State private titlePressed: boolean = false;
  // P2：白卡主体（装备名/空白）按压——点这里整卡进全屏聚焦，与标题行同语义
  @State private contentPressed: boolean = false;
  // Bug2 fix：长按触发后抑制紧随的 onClick（进聚焦），防止长按松手同时进入展开态
  @State private longPressTriggered: boolean = false;
  // timer 清理：longPressTriggered 安全兜底定时器
  private timerIds: number[] = [];
  private isAlive: boolean = true;

  aboutToDisappear(): void {
    this.isAlive = false;
    for (let i = 0; i < this.timerIds.length; i++) {
      clearTimeout(this.timerIds[i]);
    }
    this.timerIds = [];
  }

  // 问题3：父层勾选信号变化 → 自增 itemsVersion，驱动内层 ChecklistRow ForEach key 变更重建
  private onRenderNonceChange(): void {
    this.itemsVersion++;
  }

  build() {
    // if/else 而非 Stack 双层常驻：空态和有内容态不可同时存在于视图树，
    // 消除 HitTestMode.None 在 ArkUI 中不阻止子元素 onClick 的不可靠性。
    // 外层 Column 承载 cellHeight 约束（v3 中由 Stack 提供）。
    Column() {
      if (this.items.length === 0) {
        this.buildEmptyCell()
      } else {
        this.buildContentCell()
      }
    }
    .width('100%')
    .height(this.cellHeight)
    .borderRadius(CARD_RADIUS)
    // 问题2：拖拽落点高亮用「目标格自身的 zoneColor」而非固定主题绿——
    //   第一性原理：高亮的本质是预告「松手落进这个格子」，颜色即归属。
    //   拖到头部格亮蓝、下身格亮靛蓝……用户拖拽途中即可凭色预判落点。
    //   glow 阴影同用 zoneColor（radius 16 营造发光扩散），无需为每 zone 单造 glow token。
    .border({
      width: this.isDropTarget ? 2.5 : 0,
      color: this.isDropTarget ? this.zoneColor : 'transparent',
      style: BorderStyle.Solid
    })
    .shadow(this.isDropTarget
      ? { radius: 16, color: this.zoneColor, offsetY: 0 }
      : undefined)
    .animation({ curve: SPRING_GENERAL() })
    .clip(true)
  }

  // ---- 有内容态：ZoneShell（标题行 + 白卡）包裹 ----
  // D-1：外壳（标题行浅染 + 白卡描边阴影 + 按压缩放 + 点击进聚焦）全部下放到 ZoneShell，
  //   两端共用同一外壳结构，是 geometryTransition 不闪烁的地基。
  //   本组件只往插槽里塞「数量 Text（titleTrailing）」与「核查行 ForEach（content）」。
  @Builder
  private buildContentCell() {
    ZoneShell({
      zone: this.zone,
      zoneColor: this.zoneColor,
      zoneStroke: this.zoneStroke,
      zoneFill: this.zoneFill,
      // 便单式：整块容器统一承接点击进聚焦（标题不再单独可点）
      contentClickable: true,
      contentPressed: this.contentPressed,
      onContentTouch: (pressed: boolean) => { this.contentPressed = pressed; },
      onTapContent: (zone: string) => {
        // Bug2：长按刚触发后抑制紧随的 tap 进聚焦
        if (this.longPressTriggered) {
          this.longPressTriggered = false;
          return;
        }
        this.onTapTitle(zone);
      },
      titleTrailing: () => { this.buildCountTrailing() },
      content: () => { this.buildPreviewList() }
    })
  }

  // 标题行右侧：仅数量显示（添加入口已移至展开列表顶部虚线框）
  @Builder
  private buildCountTrailing() {
    if (this.items.length > 0) {
      Text(this.items.length.toString())
        .fontSize(FONT_SIZE_CAPTION)
        .fontColor(TEXT_TERTIARY)
    }
  }

  // 内容白卡内容：前 N 条核查行 + 折叠提示
  // P2/问题1：ChecklistRow 走双热区（checkOnlyHotzone），点 check 圆圈仅勾选；
  //   点装备名/行空白由 ChecklistRow 直接调 onTapRow→onTapTitle 进聚焦（ArkUI onClick 消费事件不冒泡）。
  // Phase 4：每行用 Column wrapper 承载 GestureGroup(Sequence, LongPress+Pan)。
  //   手势必须绑在「有点击响应」元素的同层/上层；wrapper 只有 gesture 无 onClick，
  //   tap 由 ChecklistRow 内部 onClick 处理，long press + pan 由 wrapper 处理，两者不互斥。
  @Builder
  private buildPreviewList() {
    Column({ space: 0 }) {
      ForEach(this.previewItems(), (item: ChecklistItem) => {
        if (this.draggingItemId.length > 0 && item.id === this.draggingItemId) {
          // C-1：被拖拽项在源位置留虚线空槽，同高不塌陷，不绑手势
          Row()
            .width('100%')
            .height(GRID_ROW_HEIGHT - 4)
            .margin({ top: 2, bottom: 2 })
            .borderRadius(6)
            .border({ width: 1, color: DIVIDER_COLOR, style: BorderStyle.Dashed })
        } else {
          Column() {
            ChecklistRow({
              item: item,
              displayName: resolveItemNameByIndex(item, this.gearIndex),
              rowHeight: GRID_ROW_HEIGHT,
              checkSize: GRID_CHECK_SIZE,
              checkOnlyHotzone: true,
              onToggleCheck: this.onToggleCheck,
              onTapRow: () => {
                // Bug2：长按刚触发后抑制紧随的 tap 进聚焦
                if (this.longPressTriggered) {
                  this.longPressTriggered = false;
                  return;
                }
                this.onTapTitle(this.zone);
              }
            })
          }
          .width('100%')
          .height(GRID_ROW_HEIGHT)
          .gesture(
            GestureGroup(
              GestureMode.Sequence,
              LongPressGesture({ repeat: false, duration: 400 })
                .onAction((event: GestureEvent) => {
                  // Bug2 fix：标记长按已触发，抑制松手后的 onClick 进聚焦
                  this.longPressTriggered = true;
                  this.triggerHaptic();
                  const finger = event.fingerList[0];
                  this.onLongPressItem(item, finger.globalX, finger.globalY);
                  // 安全兜底：500ms 后自动重置，防止极端情况永久阻塞
                  let id = setTimeout(() => {
                    if (!this.isAlive) { return; }
                    this.longPressTriggered = false;
                  }, 500) as number;
                  this.timerIds.push(id);
                }),
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionUpdate((event: GestureEvent) => {
                  this.onPanUpdate(event.offsetX, event.offsetY);
                })
                .onActionEnd((event: GestureEvent) => {
                  this.onPanFinish(event.offsetX, event.offsetY);
                })
            )
          )
        }
        // 问题3 状态不刷新根因修复：key 必须包含 checked + itemsVersion。
        //   仅 item.id：勾选只改 checked、id 不变 → ForEach diff 认为节点未变不更新。
        //   拼 checked：本组件若重建可即时反映；但父层 grid ForEach key（zone+数量）不变时本组件根本不重建，
        //   @Prop items 值拷贝拿不到新 checked → 拼 checked 也无从生效。
        //   再拼 itemsVersion（由父层 renderNonce @Watch 自增驱动）：父层每次勾选都让本组件内层 key 变更，
        //   强制重建受影响行，彻底闭环——无需退出重进即可实时刷新。
      }, (item: ChecklistItem) => item.id + '_' + (item.checked ? '1' : '0') + '_' + this.itemsVersion.toString())

      // 超过 N 件：折叠提示行
      if (this.items.length > MAX_PREVIEW_ITEMS) {
        Row() {
          Text('+' + (this.items.length - MAX_PREVIEW_ITEMS).toString() + ' 件')
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_TERTIARY)
        }
        .width('100%')
        .height(28)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  // ---- 空态：走 ZoneShell 复用统一标题行（P1/P2），内容区 contentDashed 降级 ----
  // P1/P2：标题行 100% 由 ZoneShell 渲染（浅染底 + 圆角，与满格子并排不割裂），消除 buildTitleRow 平行实现。
  //   contentDashed=true 让 ZoneShell 内容容器透明无装饰，虚线降权框完全由 buildEmptyContent 自绘——
  //   守住 B-3「空轻满重」分层（空态不套实白卡、不进 geometryTransition）。
  //   空态标题行不可点（titleClickable:false），整格点击交给内容虚线框 → onTapEmpty 打开 picker。
  @Builder
  private buildEmptyCell() {
    ZoneShell({
      zone: this.zone,
      zoneColor: this.zoneColor,
      zoneStroke: this.zoneStroke,
      zoneFill: this.zoneFill,
      contentDashed: true,
      titleClickable: false,
      contentClickable: false,
      content: () => { this.buildEmptyContent() }
    })
  }

  // 空态内容：虚线占位框（B-3 降权）。高度封顶 132vp，多出空间框外居中留白（保持同行对齐），
  //   虚线淡化（宽 1）+「+」降权 + 部位名提示，使空格子视觉重量低于满格子。
  @Builder
  private buildEmptyContent() {
    Column() {
      Column({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(FONT_SIZE_SUBTITLE_LARGE)
          .fontColor([PLACEHOLDER_COLOR])

        Text(zoneDisplayName(this.zone))
          .fontSize(FONT_SIZE_CAPTION)
          .fontColor(PLACEHOLDER_COLOR)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxHeight: 132 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(CARD_RADIUS)
      .border({
        width: 1,
        color: DIVIDER_COLOR,
        style: BorderStyle.Dashed,
        radius: CARD_RADIUS
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .scale({ x: this.titlePressed ? PRESS_SCALE_DOWN : 1.0, y: this.titlePressed ? PRESS_SCALE_DOWN : 1.0 })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.titlePressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.titlePressed = false;
      }
    })
    .onClick(() => {
      this.onTapEmpty(this.zone);
    })
  }

  private previewItems(): ChecklistItem[] {
    if (this.items.length <= MAX_PREVIEW_ITEMS) {
      return this.items;
    }
    return this.items.slice(0, MAX_PREVIEW_ITEMS);
  }

  private triggerHaptic(): void {
    hapticSoft();
  }
}
