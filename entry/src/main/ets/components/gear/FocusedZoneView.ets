// 统一清单视图 - 全屏聚焦单格子视图
// 职责：点击网格格子标题后，该 Zone 从网格位置 geometryTransition 放大铺满全屏
// 顶栏（× 关闭 + Zone 名 + 该区进度 + 逐项核查入口）+ 全量装备列表（ChecklistRow 52vp）+ 底部虚线添加行
// 与网格态格子共用 geometryTransition('zone_' + zone) id 完成共享元素转场（F-3：两端节点全程存在）
// spec §2.2 / §4.5.6
// Phase 3：聚焦布局 + 共享元素转场 + 核查复用
// 问题4b：点空白处 / 左右划收起聚焦回网格（无返回按钮）
// 问题4c：单击装备名手风琴原地展开详情（品类/重量/品牌/备注，经 fromGearId 反查）
// 长按菜单 + 长按转拖拽跨 Zone（问题4d）留 Phase 4，回调已预埋透传到位

import {
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  ZONE_MISC_STROKE,
  ZONE_MISC_FILL
} from '../../constants/Colors';
import {
  FONT_SIZE_TITLE_MEDIUM,
  FONT_SIZE_BODY_LARGE,
  FONT_SIZE_BODY_MEDIUM,
  FONT_WEIGHT_MEDIUM
} from '../../constants/Typography';
import { CARD_RADIUS } from '../../constants/Layout';
import {
  SPRING_PRESS,
  PRESS_SCALE_DOWN,
  SPRING_GENERAL,
  STAGGER_OFFSET_Y,
  staggerDelay
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { hapticSoft } from '../../utils/HapticUtils';
import { zoneDisplayName } from '../../services/LoadoutService';
import { ChecklistRow } from './ChecklistRow';
import { ZoneShell } from './ZoneShell';
import { resolveItemNameByIndex } from '../../services/ChecklistService';

@Component
export struct FocusedZoneView {
  @Prop zone: string = BodyZone.Misc;
  @Prop items: ChecklistItem[] = [];
  // 问题4c：装备库全量，用于 fromGearId 反查品类/备注/品牌等详情
  @Prop @Watch('onGearsChange') gears: GearItem[] = [];
  // 性能：父层预构建的 gearId → GearItem 索引，渲染热路径 O(1) 反查
  @Prop gearIndex: Map<string, GearItem> = new Map();
  @Prop zoneColor: string = TEXT_SECONDARY;
  // ZoneShell 外壳需要的描边色 + 整块淡色填充底，由父层透传（与网格态用同一 helper）
  @Prop zoneStroke: string = ZONE_MISC_STROKE;
  @Prop zoneFill: string = ZONE_MISC_FILL;

  // 是否处于激活（聚焦）态：由父传入 focusedZone != null。
  // false→true 时触发列表错落入场（review V2；FocusedZoneView 常驻树，不能用 aboutToAppear）
  @Prop @Watch('onActiveChange') active: boolean = false;
  // #1：父层递增此信号触发进入多选模式（携带初始选中 item id）
  @Prop @Watch('onMultiSelectSignal') multiSelectSignal: number = 0;
  @Prop multiSelectInitialId: string = '';

  // callbacks
  onClose: () => void = () => {};
  onTapEmpty: (zone: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  onReviewZone: (zone: string) => void = () => {};
  // Phase 4：长按菜单回调
  onEditItem: (item: ChecklistItem) => void = () => {};
  onRemoveItem: (itemId: string) => void = () => {};
  // 长按转拖拽落点：移动装备到目标 Zone（改 group）
  onMoveItemToZone: (itemId: string, zone: string) => void = () => {};
  // Phase 4：长按 item 触发浮层（通知父层弹自绘浮层）
  onLongPressItem: (item: ChecklistItem) => void = () => {};
  // Phase 4：拖拽开始时通知父层 dismiss 菜单（长按弹菜单后继续拖动）
  onDismissMenu: () => void = () => {};
  // Phase 4：拖到边缘触发收缩 + 跨 zone 拖拽（传递 item + Pan 累积偏移）
  onEdgeDragOut: (item: ChecklistItem, offsetX: number, offsetY: number) => void = () => {};
  // Phase 4：边缘拖出后，后续 Pan 事件转发给父层（跟手 + 命中判定）
  onEdgePanUpdate: (offsetX: number, offsetY: number) => void = () => {};
  onEdgePanEnd: (offsetX: number, offsetY: number) => void = () => {};
  // Phase 5：多选批量拖拽 — 长按已选中项触发批量拖出
  onBatchDragOut: (itemIds: string[], offsetX: number, offsetY: number) => void = () => {};
  // #3：点击装备行弹出详情 Sheet（替代手风琴展开）
  onTapItem: (item: ChecklistItem) => void = () => {};

  // #10：格子内排序回调（重排后的 item id 数组）
  onReorderItems: (zone: string, orderedIds: string[]) => void = () => {};
  // #1：多选后请求弹出 Zone 选择面板
  onRequestBatchMoveSheet: (itemIds: string[]) => void = () => {};

  // 列表错落入场控制（0 = 未入场，1 = 已就位）
  @State private listAppeared: boolean = false;

  // #1：多选模式
  @State private isMultiSelectMode: boolean = false;
  @State private selectedIds: Set<string> = new Set();

  // #10：排序模式状态
  @State private reorderingItemId: string = ''; // 当前被拖拽排序的 item id（空 = 非排序态）
  @State private reorderInsertIndex: number = -1; // 拖拽项应插入的目标位置
  @State private reorderDragY: number = 0; // 拖拽项的 Y 偏移量
  // Bug2 同类修复：长按触发后抑制紧随的 onClick（弹详情 Sheet / toggleSelection）
  @State private longPressTriggered: boolean = false;
  // Bug3a/4/5 修复：子元素交互（check/add/longpress/tapRow/checkbox）时抑制 ZoneShell onTouch 触发的 onClose。
  //   ArkUI onTouch 不被子 onClick 消费，onTouch Up 先于子 onClick 触发。
  //   方案：onTapContent 用 setTimeout(0) 延迟执行，子 onClick 同帧内设置此标记阻止关闭。
  //   统一用 armSuppressClose() 设置 + 100ms 兜底重置，防止 onTapContent 未触发时标记泄漏。
  private suppressClose: boolean = false;

  // 统一设置 suppressClose 并注册兜底重置（100ms 足够覆盖同帧事件分发，又不会泄漏）
  private armSuppressClose(): void {
    this.suppressClose = true;
    setTimeout(() => { this.suppressClose = false; }, 100);
  }

  // gearVersion 递增驱动 ForEach key 变化，确保 gear 改名/编辑后列表刷新显示名
  @State private gearVersion: number = 0;
  onGearsChange(): void {
    this.gearVersion++;
  }

  // active false→true：重置后下一帧验入场；true→false：重置供下次重放
  onActiveChange(): void {
    if (this.active) {
      this.listAppeared = false;
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.listAppeared = true;
      });
    } else {
      this.listAppeared = false;
      // 退出聚焦时自动退出多选模式
      if (this.isMultiSelectMode) {
        this.isMultiSelectMode = false;
        this.selectedIds = new Set();
      }
    }
  }

  // #1：父层递增 multiSelectSignal 时进入多选模式
  private lastMultiSelectSignal: number = 0;
  onMultiSelectSignal(): void {
    if (this.multiSelectSignal === this.lastMultiSelectSignal) {
      return;
    }
    this.lastMultiSelectSignal = this.multiSelectSignal;
    this.enterMultiSelectMode(this.multiSelectInitialId);
  }

  // #3：点击装备行弹出详情 Sheet（替代原手风琴展开）
  private handleTapItem(item: ChecklistItem): void {
    this.onTapItem(item);
  }


  // 底部添加行按压
  @State private addPressed: boolean = false;
  // D-2：核查按钮按压
  @State private reviewBtnPressed: boolean = false;

  build() {
    // D-2：聚焦态 = 卡片浮层（不再铺满）。外壳用 ZoneShell（与网格态共用），
    //   保证 geometryTransition 两端外壳结构 100% 一致，转场是「同一边框连续放大」。
    //   宽度由父层 buildFocusedLayer 留边距约束，高度自适应封顶（卡内 List 滚动）。
    ZoneShell({
      zone: this.zone,
      zoneColor: this.zoneColor,
      zoneStroke: this.zoneStroke,
      zoneFill: this.zoneFill,
      // 聚焦态标题区宽松尺寸（区别于网格态紧凑）
      titleBarHeight: 44,
      titleFontSize: FONT_SIZE_TITLE_MEDIUM,
      // 聚焦态边框加粗：2vp + 主题色实色，明确卡片轮廓 + 实体感（问题1）
      focusBorder: true,
      // 顶栏整条不响应点击（内容各自处理）
      titleClickable: false,
      // 诉求3 修复：点卡片空白返回。复用网格态同款 contentClickable→onTapContent 内部链路，
      //   而非在 ZoneShell{} 外部挂 .onClick——外部 onClick 会被 ZoneShell 根节点自身的 onClick 抢占失效（旧 bug 根因）。
      //   不传 contentPressed（默认 false）→ scale 恒 1.0，大卡不缩放，无按压副作用。
      contentClickable: true,
      // 问题6：聚焦态走「原地静止」判定——上下滑动列表空白区不再误触发收起，仅原地轻点才返回。
      tapNeedsStationary: true,
      onTapContent: (_z: string) => {
        // Bug3a/4/5：延迟到下一微任务执行，让同帧内子组件 onClick 有机会设置 suppressClose
        setTimeout(() => {
          if (this.suppressClose) {
            this.suppressClose = false;
            return;
          }
          this.onClose();
        }, 0);
      },
      // D-2：逐项核查本区按钮在 titleTrailing 插槽中
      titleTrailing: () => { this.buildTrailing(); },
      content: () => { this.buildContent() }
    })
    // 问题4b：左右划任一方向收起聚焦回网格（无需返回按钮）。
    //   水平 PanGesture，划动超阈值即触发；fingers=1 避免与列表纵向滚动冲突。
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd(() => {
          this.onClose();
        })
    )
  }

  // ---- 卡片内容：全量装备列表 + 底部添加行 ----
  @Builder
  private buildContent() {
    Column() {
      // #1：多选模式工具栏
      if (this.isMultiSelectMode) {
        this.buildMultiSelectToolbar()
      }

      List({ space: 0 }) {
        ForEach(this.items, (item: ChecklistItem, index: number) => {
          ListItem() {
            Column({ space: 0 }) {
              Row({ space: 0 }) {
                // #1：多选模式 checkbox
                if (this.isMultiSelectMode) {
                  Checkbox()
                    .select(this.selectedIds.has(item.id))
                    .selectedColor(this.zoneColor)
                    .shape(CheckBoxShape.ROUNDED_SQUARE)
                    .width(22)
                    .height(22)
                    .margin({ right: 12 })
                    .onChange((checked: boolean) => {
                      // Bug3a 补全：多选 checkbox 点击也需抑制 ZoneShell onTouch 触发的 onClose
                      this.armSuppressClose();
                      if (checked) {
                        const next = new Set<string>(this.selectedIds);
                        next.add(item.id);
                        this.selectedIds = next;
                      } else {
                        const next = new Set<string>(this.selectedIds);
                        next.delete(item.id);
                        this.selectedIds = next;
                      }
                    })
                    .transition(
                      TransitionEffect.translate({ x: -24 })
                        .combine(TransitionEffect.opacity(0))
                        .animation({ curve: SPRING_GENERAL() })
                    )
                }

                Column() {
                  ChecklistRow({
                    item: item,
                    displayName: resolveItemNameByIndex(item, this.gearIndex),
                    rowHeight: 52,
                    checkSize: 28,
                    fontSize: FONT_SIZE_BODY_LARGE,
                    checkOnlyHotzone: true,
                    onToggleCheck: (id: string) => {
                      // Bug3a：check 圆圈点击时抑制 ZoneShell onTouch 触发的 onClose
                      this.armSuppressClose();
                      if (this.isMultiSelectMode) {
                        this.toggleSelection(id);
                      } else {
                        this.onToggleCheck(id);
                      }
                    },
                    onTapRow: () => {
                      // Bug2 同类修复：长按刚触发后抑制紧随的 tap
                      if (this.longPressTriggered) {
                        this.longPressTriggered = false;
                        return;
                      }
                      // Bug3a 补全：点装备名/整行也需抑制 ZoneShell onTouch 触发的 onClose
                      this.armSuppressClose();
                      if (this.isMultiSelectMode) {
                        this.toggleSelection(item.id);
                      } else {
                        this.handleTapItem(item);
                      }
                    }
                  })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .height(52)
              .alignItems(VerticalAlign.Center)
              .gesture(
                GestureGroup(
                  GestureMode.Sequence,
                  LongPressGesture({ repeat: false, duration: 400 })
                    .onAction(() => {
                      this.handleLongPress(item);
                    }),
                  PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                    .onActionStart(() => {
                      if (this.isMultiSelectMode && this.batchDragPending) {
                        // Phase 5：多选批量拖拽 — 立即触发边缘拖出（不做格子内排序）
                        this.edgeDragFired = true;
                        const ids: string[] = Array.from(this.selectedIds);
                        this.onBatchDragOut(ids, 0, 0);
                      } else if (!this.isMultiSelectMode) {
                        // 长按弹菜单后继续拖动 → dismiss 菜单 + 进入排序
                        this.onDismissMenu();
                        this.startReorder(item, index);
                      }
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.edgeDragFired) {
                        // 边缘拖出 / 批量拖拽：转发给父层
                        this.onEdgePanUpdate(event.offsetX, event.offsetY);
                      } else if (!this.isMultiSelectMode) {
                        this.updateReorder(event.offsetX, event.offsetY, index);
                      }
                    })
                    .onActionEnd((event: GestureEvent) => {
                      if (this.edgeDragFired) {
                        this.onEdgePanEnd(event.offsetX, event.offsetY);
                        this.edgeDragFired = false;
                        this.batchDragPending = false;
                        // 边缘拖出已由父层处理落点，不再走排序持久化
                        if (!this.isMultiSelectMode) {
                          this.finishReorder();
                        }
                        return;
                      }
                      if (!this.isMultiSelectMode) {
                        this.finishReorder();
                      } else {
                        this.batchDragPending = false;
                      }
                    })
                )
              )

              // #3：手风琴展开已移除，点击装备行现在弹出底部 Sheet
            }
            .width('100%')
          }
          // 错落入场：淡入 + translateY，按 index 递延（review V2）
          .opacity(this.listAppeared ? 1 : 0)
          .translate({
            y: this.reorderTranslateY(item.id, index)
          })
          .animation({ curve: SPRING_GENERAL(), delay: this.reorderingItemId.length > 0 ? 0 : staggerDelay(index) })
          // #10：排序中被拖项浮起
          .scale({
            x: this.reorderingItemId === item.id ? 1.03 : 1.0,
            y: this.reorderingItemId === item.id ? 1.03 : 1.0
          })
          .shadow(this.reorderingItemId === item.id
            ? { radius: 24, color: '#1A000000', offsetY: 8 }
            : undefined)
          .zIndex(this.reorderingItemId === item.id ? 100 : 0)
          // 修复 #7：删除时退场动画（向左滑出 + 缩小 + 淡出）
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.IDENTITY,
            TransitionEffect.translate({ x: -40 }).animation({ curve: SPRING_GENERAL() })
              .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 }).animation({ curve: SPRING_GENERAL() }))
              .combine(TransitionEffect.opacity(0).animation({ curve: SPRING_GENERAL() }))
          ))
        // key 拼入 checked：勾选后 key 变 → ForEach 重建该行 → ChecklistRow @Prop 拿到新 checked 值
        }, (item: ChecklistItem) => item.id + '_' + (item.checked ? '1' : '0') + '_' + this.gearVersion.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // 问题5b：「添加到此部位」从列表顶部移到卡片底部吸附。
      //   第一性原理：添加是该 Zone 的主操作，应长在拇指随手可达的底部且常驻可见，
      //   而非藏在列表顶部需滚回去找（交互入口原则）。List layoutWeight(1) 吃掉中间空白——
      //   内容少时列表在上、添加行吸底、中间留白成为自然呼吸区（而非"内容截断后的空荡"）；
      //   内容多时添加行常驻底部不随列表滚走，随手可加。多选模式下隐藏。
      if (!this.isMultiSelectMode) {
        Column() {
          this.buildAddRow()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }


  // ---- 顶部虚线添加行 ----
  // 问题3a：添加区是该部位的主操作，必须比分隔线权重高。
  //   原 DIVIDER_COLOR 虚线 + TEXT_TERTIARY 文字 = 分隔线级弱色，几乎看不见。
  //   改为用 zoneColor（该部位主题色）描虚线 + 图标 + 文字——既拉起视觉权重，
  //   又把「添加到此部位」与该格语义色绑定（第一性原理：可操作 > 装饰）。
  @Builder
  private buildAddRow() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(18)
        .fontColor([this.zoneColor])
        .fontWeight(FontWeight.Medium)

      Text('添加到' + zoneDisplayName(this.zone))
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(this.zoneColor)
        .fontWeight(FONT_WEIGHT_MEDIUM)
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(CARD_RADIUS)
    .border({
      width: 1.5,
      color: this.zoneColor,
      style: BorderStyle.Dashed,
      radius: CARD_RADIUS
    })
    .scale({ x: this.addPressed ? PRESS_SCALE_DOWN : 1.0, y: this.addPressed ? PRESS_SCALE_DOWN : 1.0 })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.addPressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.addPressed = false;
      }
    })
    .onClick(() => {
      // Bug4：添加按钮点击时抑制 ZoneShell onTouch 触发的 onClose
      this.armSuppressClose();
      this.onTapEmpty(this.zone);
    })
  }

  // Phase 4：长按触发 —— 触觉反馈 + 通知父层弹浮层（如果不继续拖动则弹菜单）
  // Phase 5：多选模式下长按已选中项 → 准备批量拖拽（Pan 开始时触发）
  private batchDragPending: boolean = false;

  private handleLongPress(item: ChecklistItem): void {
    // 触觉反馈（轻档）
    hapticSoft();
    // Bug5：长按触发时抑制松手后 ZoneShell onTouch Up 触发的 onClose
    this.armSuppressClose();
    // Bug2 同类修复：标记长按已触发，抑制松手后的 onClick（多选/非多选均需）
    this.longPressTriggered = true;
    setTimeout(() => { this.longPressTriggered = false; }, 500);
    // Phase 5：多选模式下长按已选中项 → 准备批量拖拽
    if (this.isMultiSelectMode) {
      if (this.selectedIds.has(item.id)) {
        // 已选中项：标记待批量拖拽（Pan 开始时触发）
        this.batchDragPending = true;
      } else {
        // 未选中项：切换选中态
        this.toggleSelection(item.id);
      }
      return;
    }
    // 通知父层弹出自绘浮层（如果后续 Pan 开始则会被排序模式覆盖）
    this.onLongPressItem(item);
  }

  // ---- #1：多选模式控制 ----
  enterMultiSelectMode(initialItemId?: string): void {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.isMultiSelectMode = true;
      this.selectedIds = new Set();
      if (initialItemId !== undefined && initialItemId.length > 0) {
        this.selectedIds.add(initialItemId);
      }
    });
  }

  exitMultiSelectMode(): void {
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.isMultiSelectMode = false;
      this.selectedIds = new Set();
    });
  }

  private toggleSelection(itemId: string): void {
    const next = new Set<string>(this.selectedIds);
    if (next.has(itemId)) {
      next.delete(itemId);
    } else {
      next.add(itemId);
    }
    this.selectedIds = next;
  }

  private selectAll(): void {
    const all = new Set<string>();
    for (const item of this.items) {
      all.add(item.id);
    }
    this.selectedIds = all;
  }

  // ---- #10：格子内排序 ----
  private static readonly ITEM_HEIGHT: number = 52;

  private startReorder(item: ChecklistItem, _index: number): void {
    this.reorderingItemId = item.id;
    this.reorderDragY = 0;
    this.reorderInsertIndex = this.items.findIndex((i: ChecklistItem) => i.id === item.id);
    this.edgeDragFired = false;
  }

  // 边缘检测阈值：手指 X 偏移超出此值时触发收缩 + 跨 zone 拖拽
  private static readonly EDGE_THRESHOLD_X: number = 80;
  // 防止重复触发边缘回调
  private edgeDragFired: boolean = false;

  private updateReorder(offsetX: number, offsetY: number, originalIndex: number): void {
    this.reorderDragY = offsetY;
    // 边缘检测：横向偏移超阈值 → 触发收缩 + 跨 zone 拖拽
    if (!this.edgeDragFired && Math.abs(offsetX) > FocusedZoneView.EDGE_THRESHOLD_X) {
      this.edgeDragFired = true;
      const item = this.items.find((i: ChecklistItem) => i.id === this.reorderingItemId);
      if (item !== undefined) {
        // 用 Pan 累积偏移 + 组件区域估算全局坐标（精确值由父层修正）
        this.onEdgeDragOut(item, offsetX, offsetY);
      }
      return;
    }
    if (this.edgeDragFired) {
      // 已触发边缘回调，后续 Pan 事件转发给父层做跨 zone 跟手
      this.onEdgePanUpdate(offsetX, offsetY);
      return;
    }
    // 根据拖拽偏移计算目标插入位置
    const itemH = FocusedZoneView.ITEM_HEIGHT;
    const movedSlots = Math.round(offsetY / itemH);
    let targetIndex = originalIndex + movedSlots;
    targetIndex = Math.max(0, Math.min(this.items.length - 1, targetIndex));
    if (targetIndex !== this.reorderInsertIndex) {
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.reorderInsertIndex = targetIndex;
      });
    }
  }

  private finishReorder(): void {
    if (this.reorderingItemId.length === 0) {
      return;
    }
    // 如果已触发边缘拖出，不做排序持久化（item 已交给跨 zone 流程）
    if (this.edgeDragFired) {
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.reorderingItemId = '';
        this.reorderInsertIndex = -1;
        this.reorderDragY = 0;
      });
      this.edgeDragFired = false;
      return;
    }
    const fromIndex = this.items.findIndex((i: ChecklistItem) => i.id === this.reorderingItemId);
    const toIndex = this.reorderInsertIndex;
    // 重置排序状态
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.reorderingItemId = '';
      this.reorderInsertIndex = -1;
      this.reorderDragY = 0;
    });
    this.edgeDragFired = false;
    // 如果位置变了，通知父层持久化
    if (fromIndex !== toIndex && fromIndex >= 0 && toIndex >= 0) {
      const orderedIds = this.items.map((i: ChecklistItem) => i.id);
      // 执行移动（ArkTS 不支持解构赋值）
      const spliced = orderedIds.splice(fromIndex, 1);
      const moved = spliced[0];
      orderedIds.splice(toIndex, 0, moved);
      this.onReorderItems(this.zone, orderedIds);
    }
  }

  // 计算每个 item 的 translateY（排序让位 + 入场动画）
  private reorderTranslateY(itemId: string, index: number): number {
    // 入场动画
    if (!this.listAppeared) {
      return STAGGER_OFFSET_Y;
    }
    // 非排序态
    if (this.reorderingItemId.length === 0) {
      return 0;
    }
    // 被拖拽项：跟手
    if (itemId === this.reorderingItemId) {
      return this.reorderDragY;
    }
    // 其他项：根据 insertIndex 让位
    const dragFromIndex = this.items.findIndex((i: ChecklistItem) => i.id === this.reorderingItemId);
    const itemH = FocusedZoneView.ITEM_HEIGHT;
    if (dragFromIndex < this.reorderInsertIndex) {
      // 拖拽项向下移动：dragFromIndex+1 ~ reorderInsertIndex 的项向上让位
      if (index > dragFromIndex && index <= this.reorderInsertIndex) {
        return -itemH;
      }
    } else if (dragFromIndex > this.reorderInsertIndex) {
      // 拖拽项向上移动：reorderInsertIndex ~ dragFromIndex-1 的项向下让位
      if (index >= this.reorderInsertIndex && index < dragFromIndex) {
        return itemH;
      }
    }
    return 0;
  }

  // D-2：聚焦态顶栏 trailing — 「逐项核查本区」按钮
  // 问题3a：原 12px TEXT_TERTIARY 纯文字几乎不可见、不像可点。
  //   升级为 zoneColor 淡填充小药丸 + 勾选图标 + 文字——明确「这是可点的核查入口」，
  //   用部位主题色与该格语义统一（第一性原理：主操作必须自解释、视觉权重足）。
  @Builder
  private buildTrailing() {
    Row({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(14)
        .fontColor([this.zoneColor])
      Text('核查')
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(this.zoneColor)
    }
    .height(30)
    .padding({ left: 10, right: 12 })
    .borderRadius(15)
    .backgroundColor(this.zoneFill)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .scale({ x: this.reviewBtnPressed ? PRESS_SCALE_DOWN : 1.0, y: this.reviewBtnPressed ? PRESS_SCALE_DOWN : 1.0 })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.reviewBtnPressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.reviewBtnPressed = false;
      }
    })
    .onClick(() => {
      this.armSuppressClose();
      this.onReviewZone(this.zone);
    })
  }

  // ---- #1：多选模式工具栏 ----
  @State private moveBtnPressed: boolean = false;
  @State private cancelBtnPressed: boolean = false;
  @State private selectAllBtnPressed: boolean = false;

  @Builder
  private buildMultiSelectToolbar() {
    Row() {
      // 已选计数
      Text(`已选 ${this.selectedIds.size} 件`)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontWeight(FONT_WEIGHT_MEDIUM)
        .fontColor(TEXT_MAIN)

      Blank()

      // 全选按钮
      Text(this.selectedIds.size === this.items.length ? '取消全选' : '全选')
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(this.zoneColor)
        .scale({ x: this.selectAllBtnPressed ? PRESS_SCALE_DOWN : 1.0, y: this.selectAllBtnPressed ? PRESS_SCALE_DOWN : 1.0 })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) { this.selectAllBtnPressed = true; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.selectAllBtnPressed = false; }
        })
        .onClick(() => {
          this.armSuppressClose();
          if (this.selectedIds.size === this.items.length) {
            this.selectedIds = new Set();
          } else {
            this.selectAll();
          }
        })
        .margin({ right: 16 })

      // 移动到…按钮
      Text('移动到…')
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(this.selectedIds.size > 0 ? this.zoneColor : TEXT_TERTIARY)
        .scale({ x: this.moveBtnPressed ? PRESS_SCALE_DOWN : 1.0, y: this.moveBtnPressed ? PRESS_SCALE_DOWN : 1.0 })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) { this.moveBtnPressed = true; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.moveBtnPressed = false; }
        })
        .onClick(() => {
          this.armSuppressClose();
          if (this.selectedIds.size > 0) {
            const ids: string[] = Array.from(this.selectedIds);
            this.onRequestBatchMoveSheet(ids);
          }
        })
        .margin({ right: 16 })

      // 取消按钮
      Text('取消')
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_SECONDARY)
        .scale({ x: this.cancelBtnPressed ? PRESS_SCALE_DOWN : 1.0, y: this.cancelBtnPressed ? PRESS_SCALE_DOWN : 1.0 })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) { this.cancelBtnPressed = true; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.cancelBtnPressed = false; }
        })
        .onClick(() => {
          this.armSuppressClose();
          this.exitMultiSelectMode();
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .transition(
      TransitionEffect.translate({ y: -20 })
        .combine(TransitionEffect.opacity(0))
        .animation({ curve: SPRING_GENERAL() })
    )
  }
}
