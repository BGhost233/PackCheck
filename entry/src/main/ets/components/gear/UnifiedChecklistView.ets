// 统一清单视图 - 主视图（网格态）
// 职责：2 列网格展示全部 7 个 Zone 格子（有内容态 / 空态），首屏精确 2×2.5 密度
// 替代旧的 LoadoutView + ChecklistDetail 双 Tab。spec §2.1 / §4
// P1：空态不再切引导页，统一走网格态——0 件时所有 Zone 走虚线空格子，点对应部位空格子加装备

import { display } from '@kit.ArkUI';
import {
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  CARD_BG,
  PAGE_BG,
  OVERLAY_DIM,
  SHADOW_MEDIUM,
  ZONE_HEAD_COLOR,
  ZONE_UPPER_COLOR,
  ZONE_LOWER_COLOR,
  ZONE_FEET_COLOR,
  ZONE_CARRY_COLOR,
  ZONE_SLEEP_COLOR,
  ZONE_MISC_COLOR,
  ZONE_HEAD_STROKE,
  ZONE_UPPER_STROKE,
  ZONE_LOWER_STROKE,
  ZONE_FEET_STROKE,
  ZONE_CARRY_STROKE,
  ZONE_SLEEP_STROKE,
  ZONE_MISC_STROKE,
  ZONE_HEAD_TINT,
  ZONE_UPPER_TINT,
  ZONE_LOWER_TINT,
  ZONE_FEET_TINT,
  ZONE_CARRY_TINT,
  ZONE_SLEEP_TINT,
  ZONE_MISC_TINT
} from '../../constants/Colors';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  SPRING_HERO_EXPAND,
  SPRING_HERO_COLLAPSE,
  STAGGER_OFFSET_Y,
  staggerDelay,
  SHARP_SNAP,
  EASE_FADE,
  DURATION_OVERLAY_ENTER,
  DURATION_OVERLAY_FADE,
  DURATION_OVERLAY_DISMISS
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { BodyZone } from '../../constants/GearLoadout';
import { vibrator } from '@kit.SensorServiceKit';
import { groupByZoneAll, calcProgress, LoadoutProgress } from '../../services/LoadoutService';
import { ZoneGridCell } from './ZoneGridCell';
import { FocusedZoneView } from './FocusedZoneView';
import { LoadoutProgressBar } from './LoadoutProgressBar';
import { GearItemContextMenu, ContextMenuItem } from './GearItemContextMenu';

// 双列网格中走常规单列的 zone（杂项单独跨列渲染在末尾）。spec §2.1.2 F-5
const GRID_SINGLE_ZONES: string[] = [
  BodyZone.Head,
  BodyZone.UpperBody,
  BodyZone.LowerBody,
  BodyZone.Feet,
  BodyZone.Carry,
  BodyZone.Sleep
];

// 网格布局常量
const GRID_PADDING: number = 16;   // 左右页边距
const GRID_GUTTER: number = 12;    // 行/列间距
// P4：首屏暗示密度提高到 2.8 行（2 行完整 + 0.8 行露头），单格更矮、底部留出下滑暗示
const FIRST_SCREEN_ROWS: number = 2.8;
// 反算兜底（无法取得屏高时）。P4：随密度提高同步下调
const CELL_HEIGHT_FALLBACK: number = 148;
// P4：底部渐隐遮罩高度，暗示下方还有格子可滑
// 问题2：去掉 backgroundBlurStyle（纯背景上的模糊会变脏灰矩形），改为纯渐变遮罩，高度提到 72 让底部格子自然沉入背景
const BOTTOM_FADE_HEIGHT: number = 72;

@Component
export struct UnifiedChecklistView {
  @Prop @Watch('onTripChange') trip: TripChecklist = { id: '', title: '', items: [], createdAt: 0 };
  @Prop gears: GearItem[] = [];
// 顶部已占高度（NavBar + SharedInfo + ProgressBar），用于首屏 cell 高度反算
// @Watch：aboutToAppear 时父层 build 可能尚未传入实算值，prop 后续更新需重算 cell 高度（review B3）
@Prop @Watch('onReservedTopChange') reservedTopHeight: number = 180;

  // callbacks
  // zone 可选：从空格子进入时透传对应 Zone，picker 据此排序高亮并预选临时新建分区（review I4）
  onOpenPicker: (zone?: string) => void = () => {};
  onToggleCheck: (itemId: string) => void = () => {};
  // 问题4：装备移动到目标 Zone（聚焦态长按转拖拽落点 → 改 group），透传到 Index 持久化
  onMoveItemToZone: (itemId: string, zone: string) => void = () => {};
  // 问题4：聚焦态长按菜单「编辑」，透传到 Index 打开编辑态
  onEditItem: (item: ChecklistItem) => void = () => {};
  // 问题4：聚焦态长按菜单「从本次行程移除」，透传到 Index
  onRemoveItem: (itemId: string) => void = () => {};
  // Phase 4：长按菜单「移动到…」→ 由 Index 弹出 zone 选择面板
  onRequestMoveSheet: (item: ChecklistItem) => void = () => {};

  // FAB 按压状态
  @State private fabScale: number = 1.0;
  // 入场动画控制
  @State private appeared: boolean = false;
  // 反算得到的单格高度
  @State private cellHeight: number = CELL_HEIGHT_FALLBACK;

  // Phase 4：长按浮层 + 拖拽状态
  @State private overlayItem: ChecklistItem | null = null;
  @State private overlayVisible: boolean = false;
  @State private overlayPhase: string = 'idle'; // 'idle' | 'menu' | 'dragging'
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;
  // 胶囊当前位置（浮层 Stack 局部坐标），position() 直接消费
  @State private dragCurrentX: number = 0;
  @State private dragCurrentY: number = 0;
  // 长按时手指全局坐标（Pan offset 累加到此处得到实时全局坐标，再转局部）
  private longPressGlobalX: number = 0;
  private longPressGlobalY: number = 0;
  // 浮层 Stack 的全局原点（onAreaChange 收集），用于全局→局部坐标转换
  @State private overlayOriginX: number = 0;
  @State private overlayOriginY: number = 0;
  // 目标 zone 高亮
  @State private dropTargetZone: string | null = null;
  // 各 zone 格子的全局 Rect（由 onAreaChange 收集）
  private zoneRects: Map<string, number[]> = new Map();
  // 全屏聚焦的 Zone（null = 网格态）。spec §2.2 / §4.5.6
  // 问题4a：改 @Link 由 Index 持有 @State 源，使 onBackPressed 能读判断「是否聚焦」做分层拦截。
  //   注意：Index 不直接改此值（会丢收起动画），而是递增 closeFocusSignal 让本组件走带动画的 closeFocus()。
  @Link focusedZone: string | null;
  // 问题4a：Index 命中聚焦态时递增此信号，本组件 @Watch 后走带动画的 closeFocus()。
  @Prop @Watch('onCloseFocusSignal') closeFocusSignal: number;
  // 当前/上次聚焦渲染的 Zone（F-3：FocusedZoneView 常驻树用 visibility 切换，退场时仍需有 zone 可渲染）
  @State private focusedZoneRender: string = BodyZone.Misc;

  // 分组缓存：仅在 @Watch('trip') 时刷新。
  // 隐含前提（review C2）：Zone 分组只依赖 trip.items 自身字段，不依赖 gears。
  // 因此「gears 数据变化但 trip 引用不变」（如装备库重命名 gear）不会、也无需刷新本缓存。
  private zoneMapCache: Map<string, ChecklistItem[]> = new Map();

  aboutToAppear() {
    this.refreshCache();
    this.computeCellHeight();
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.appeared = true;
    });
  }

  // C1 守卫：组件卸载后 timer 回调不再操作 state
  private isAlive: boolean = true;

  aboutToDisappear() {
    this.appeared = false;
    this.isAlive = false;
  }

onTripChange(): void {
this.refreshCache();
}

onReservedTopChange(): void {
this.computeCellHeight();
}

  build() {
    Column() {
      // 顶部全局进度条（sticky 吸顶，仅有内容时显示）。spec §2.1 / §3.3
      if (this.trip.items.length > 0) {
        LoadoutProgressBar({
          checked: this.progress().checked,
          total: this.progress().total
        })
      }

      Stack() {
        // P1：空态不再切引导页，统一走网格态——0 件时所有 Zone 走虚线空格子，
        // 用户直接点对应部位空格子加装备（「带格子的核查清单」纲领）。
        this.buildGridState()

        // P4：底部渐隐高斯模糊遮罩，暗示下方还有格子可滑（聚焦态隐藏）。
        this.buildBottomFade()

        // FAB 始终显示（空态也可从右下角全局新增）。
        this.buildFAB()

        // 全屏聚焦态（F-3：常驻树，用 visibility 切换，position 叠加在网格之上）
        this.buildFocusedLayer()

        // Phase 4：长按自绘浮层（蓙层 + 详情卡 + 菜单），条件渲染
        if (this.overlayItem !== null) {
          this.buildLongPressOverlay()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .onAreaChange((_o: Area, n: Area) => {
        // 记录浮层容器的全局原点，用于拖拽胶囊/高亮框的全局→局部坐标转换。
        // globalPosition 可能为 undefined（首次布局或特定 ArkUI 版本），加空守卫防止坐标归零。
        if (n.globalPosition !== undefined) {
          this.overlayOriginX = n.globalPosition.x as number;
          this.overlayOriginY = n.globalPosition.y as number;
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  // ---- 全屏聚焦层（常驻树，geometryTransition 共享元素配对端）----
  @Builder
  private buildFocusedLayer() {
    // D-2：聚焦态 = 卡片浮层（不再铺满整屏）。
    //   外层定位容器留边距（左右 20vp）+ 垂直居中，卡片宽度撑满边距内空间、
    //   高度自适应并封顶（maxHeight 80%，卡内 List 滚动）。
    //   geometryTransition 仍挂外层节点、id 不变 → 与网格态 ZoneGridCell 配对端连续放大。
    Column() {
      FocusedZoneView({
        zone: this.focusedZoneRender,
        items: this.itemsForZone(this.focusedZoneRender),
        gears: this.gears,
        zoneColor: this.zoneColor(this.focusedZoneRender),
        zoneStroke: this.zoneStroke(this.focusedZoneRender),
        zoneTint: this.zoneTint(this.focusedZoneRender),
        active: this.focusedZone != null,
        onClose: () => { this.closeFocus(); },
        onTapEmpty: (z: string) => { this.onOpenPicker(z); },
        onToggleCheck: this.onToggleCheck,
        onEditItem: this.onEditItem,
        onRemoveItem: this.onRemoveItem,
        onMoveItemToZone: this.onMoveItemToZone,
        onLongPressItem: (item: ChecklistItem) => { this.showOverlay(item); },
        // D-2「逐项核查本区」携带 Zone 进入 Review，后续 Phase 接入；此处先占位不误触
        onReviewZone: (z: string) => {}
      })
        .width('100%')
        .constraintSize({ maxHeight: '80%' })
    }
    .geometryTransition('zone_' + this.focusedZoneRender)
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .visibility(this.focusedZone != null ? Visibility.Visible : Visibility.Hidden)
    .hitTestBehavior(this.focusedZone != null ? HitTestMode.Default : HitTestMode.None)
  }

  // 问题4a：Index onBackPressed 命中聚焦态时递增 closeFocusSignal，此处响应走带动画的收起。
  //   首帧 closeFocusSignal=0 不触发；仅当外部递增（>0 且无聚焦时也无害）才收起。
  private lastCloseSignal: number = 0;
  onCloseFocusSignal(): void {
    if (this.closeFocusSignal === this.lastCloseSignal) {
      return;
    }
    this.lastCloseSignal = this.closeFocusSignal;
    if (this.focusedZone != null) {
      this.closeFocus();
    }
  }

  // 进入聚焦：zone 赋值与 visible 切换必须在同一个 animateTo 帧内，
  // 让 geometryTransition 在同一帧同时拿到「id 匹配 + 源 Hidden / 目标 Visible」完成共享元素转场。
  // focusedZoneRender 提前设会导致 id 先变、转场系统丢失配对端，退化为普通淡入淡出。
  private openFocus(zone: string): void {
    this.getUIContext().animateTo({ curve: SPRING_HERO_EXPAND() }, () => {
      this.focusedZoneRender = zone;
      this.focusedZone = zone;
    });
  }

  // 退出聚焦：Spring 缩回原格
  private closeFocus(): void {
    this.getUIContext().animateTo({ curve: SPRING_HERO_COLLAPSE() }, () => {
      this.focusedZone = null;
    });
  }

  // ---- Phase 4：长按浮层控制 ----
  private showOverlay(item: ChecklistItem): void {
    this.overlayItem = item;
    this.overlayPhase = 'menu';
    // 延迟一帧触发入场动画（确保条件渲染挂载后再 animate）
    setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({
        curve: SHARP_SNAP,
        duration: DURATION_OVERLAY_ENTER
      }, () => {
        this.overlayVisible = true;
      });
    }, 16);
  }

  private dismissOverlay(fast: boolean = false): void {
    const duration = fast ? 80 : DURATION_OVERLAY_DISMISS;
    this.getUIContext().animateTo({
      curve: EASE_FADE,
      duration: duration,
      onFinish: () => {
        this.overlayItem = null;
        this.overlayVisible = false;
        this.overlayPhase = 'idle';
      }
    }, () => {
      this.overlayVisible = false;
    });
  }

  private buildOverlayMenuItems(): ContextMenuItem[] {
    const item = this.overlayItem!;
    return [
      {
        icon: $r('sys.symbol.square_and_pencil'),
        label: '编辑',
        action: () => {
          this.dismissOverlay(true);
          this.onEditItem(item);
        }
      },
      {
        icon: $r('sys.symbol.arrow_up_and_down_square_portrait'),
        label: '移动到…',
        action: () => {
          this.dismissOverlay(true);
          this.onRequestMoveSheet(item);
        }
      },
      {
        icon: $r('sys.symbol.trash'),
        label: '移除',
        destructive: true,
        action: () => {
          this.dismissOverlay(true);
          this.onRemoveItem(item.id);
        }
      }
    ];
  }

  // ---- Phase 4 阶段2：网格态拖拽逻辑 ----

  // 网格态长按触发（来自 ZoneGridCell）
  private handleGridLongPress(item: ChecklistItem, globalX: number, globalY: number): void {
    this.overlayItem = item;
    this.overlayPhase = 'menu';
    // 保存全局坐标，供 handleDragUpdate 用 Pan offset 累加推出手指实时全局坐标
    this.longPressGlobalX = globalX;
    this.longPressGlobalY = globalY;
    // 初始胶囊位置 = 手指局部坐标（用于菜单阶段的居中展示）
    this.dragCurrentX = globalX - this.overlayOriginX;
    this.dragCurrentY = globalY - this.overlayOriginY;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    this.dropTargetZone = null;
    // 入场动画
    setTimeout(() => {
      if (!this.isAlive) { return; }
      this.getUIContext().animateTo({
        curve: SHARP_SNAP,
        duration: DURATION_OVERLAY_ENTER
      }, () => {
        this.overlayVisible = true;
      });
    }, 16);
  }

  // Pan 更新：offsetX/Y 是 PanGesture 相对起点的累积位移(vp)
  // 手指实时全局坐标 = longPressGlobal + offset，转局部后更新胶囊位置。
  private handleDragUpdate(offsetX: number, offsetY: number): void {
    if (this.overlayItem === null) {
      return;
    }
    if (this.overlayPhase === 'menu') {
      this.overlayPhase = 'dragging';
    }
    this.dragOffsetX = offsetX;
    this.dragOffsetY = offsetY;
    const fingerGlobalX = this.longPressGlobalX + offsetX;
    const fingerGlobalY = this.longPressGlobalY + offsetY;
    // 胶囊跟手：position() 消费局部坐标
    this.dragCurrentX = fingerGlobalX - this.overlayOriginX;
    this.dragCurrentY = fingerGlobalY - this.overlayOriginY;
    // 命中判定
    const prevTarget = this.dropTargetZone;
    this.dropTargetZone = this.hitTestZone(fingerGlobalX, fingerGlobalY);
    // 进入新 Zone 时触觉反馈
    if (this.dropTargetZone !== null && this.dropTargetZone !== prevTarget) {
      this.triggerDropHaptic();
    }
  }

  // Pan 结束（松手）
  private handleDragEnd(offsetX: number, offsetY: number): void {
    if (this.overlayItem === null) {
      return;
    }
    const fingerGlobalX = this.longPressGlobalX + offsetX;
    const fingerGlobalY = this.longPressGlobalY + offsetY;
    const target = this.hitTestZone(fingerGlobalX, fingerGlobalY);
    if (target !== null && target !== this.overlayItem!.group) {
      this.onMoveItemToZone(this.overlayItem!.id, target);
    }
    this.getUIContext().animateTo({
      curve: SPRING_GENERAL(),
      onFinish: () => {
        this.resetDragState();
      }
    }, () => {
      this.dragOffsetX = 0;
      this.dragOffsetY = 0;
      this.dropTargetZone = null;
      this.overlayPhase = 'idle';
      this.overlayVisible = false;
    });
  }

  private resetDragState(): void {
    this.overlayItem = null;
    this.overlayPhase = 'idle';
    this.overlayVisible = false;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    this.dragCurrentX = 0;
    this.dragCurrentY = 0;
    this.dropTargetZone = null;
  }

  private triggerDropHaptic(): void {
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: 'haptic.effect.tick', count: 1 },
        { usage: 'touch' }
      );
    } catch (_e) {
      // 静默降级
    }
  }

  // 坐标命中判定：当前全局坐标落在哪个 zone 格子内
  // zoneRects 存全局坐标，需转局部后与手指局部坐标比较
  private hitTestZone(globalX: number, globalY: number): string | null {
    const localX = globalX - this.overlayOriginX;
    const localY = globalY - this.overlayOriginY;
    const allZones: string[] = [...GRID_SINGLE_ZONES, BodyZone.Misc];
    for (let i = 0; i < allZones.length; i++) {
      const zone = allZones[i];
      const rect = this.zoneRects.get(zone);
      if (rect === undefined) {
        continue;
      }
      // zoneRects 存全局坐标，转为局部与手指比较
      const rx = rect[0] - this.overlayOriginX;
      const ry = rect[1] - this.overlayOriginY;
      const rw = rect[2];
      const rh = rect[3];
      if (localX >= rx && localX <= rx + rw && localY >= ry && localY <= ry + rh) {
        return zone;
      }
    }
    return null;
  }

  private progress(): LoadoutProgress {
    return calcProgress(this.trip.items);
  }

  private refreshCache(): void {
    this.zoneMapCache = groupByZoneAll(this.trip.items);
  }

  // 首屏 2×2.5 密度反算单格高度：(可视高 - 半行gutter冗余) / 2.5 行，扣去行间距
  // spec §2.1.2：用 2.5 行 ≈ 可视高度 反算，保证各机型一致暗示效果
  private computeCellHeight(): void {
    try {
      const di = display.getDefaultDisplaySync();
      const screenHeightVp = this.getUIContext().px2vp(di.height);
      const visibleHeight = screenHeightVp - this.reservedTopHeight;
      // 2.5 行 + 2 个完整 gutter（首屏可见 2 整行需 2 段间距）
      const usable = visibleHeight - GRID_GUTTER * FIRST_SCREEN_ROWS;
      const h = usable / FIRST_SCREEN_ROWS;
      if (h > 80 && h < 400) {
        this.cellHeight = h;
      }
    } catch (e) {
      // 取屏失败 → 用兜底高度
      this.cellHeight = CELL_HEIGHT_FALLBACK;
    }
  }

  @Builder
  private buildGridState() {
    Grid() {
      // 前 6 个 zone 走双列自动布局
      ForEach(GRID_SINGLE_ZONES, (zone: string, index: number) => {
        GridItem() {
          ZoneGridCell({
            zone: zone,
            items: this.itemsForZone(zone),
            zoneColor: this.zoneColor(zone),
            zoneStroke: this.zoneStroke(zone),
            zoneTint: this.zoneTint(zone),
            cellHeight: this.cellHeight,
            isDropTarget: this.overlayPhase === 'dragging' && this.dropTargetZone === zone,
            draggingItemId: this.overlayPhase === 'dragging' ? (this.overlayItem?.id ?? '') : '',
            onTapTitle: (z: string) => { this.openFocus(z); },
            onTapEmpty: (z: string) => { this.onOpenPicker(z); },
            onToggleCheck: this.onToggleCheck,
            onLongPressItem: (item: ChecklistItem, gx: number, gy: number) => {
              this.handleGridLongPress(item, gx, gy);
            },
            onPanUpdate: (ox: number, oy: number) => { this.handleDragUpdate(ox, oy); },
            onPanFinish: (ox: number, oy: number) => { this.handleDragEnd(ox, oy); }
          })
        }
        // B-4：显式等高，强制同行基线齐平，消除两列参差
        .height(this.cellHeight)
        .geometryTransition('zone_' + zone)
        .opacity(this.focusedZone == zone ? 0 : (this.appeared ? 1 : 0))
        .hitTestBehavior(this.focusedZone == zone ? HitTestMode.None : HitTestMode.Default)
        .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
        .animation({
          curve: SPRING_GENERAL(),
          delay: staggerDelay(index)
        })
        .onAreaChange((_o: Area, n: Area) => {
          const pos = n.globalPosition as Record<string, number>;
          this.zoneRects.set(zone, [pos.x ?? 0, pos.y ?? 0, n.width as number, n.height as number]);
        })
      }, (zone: string) => zone + '_' + this.itemsForZone(zone).length.toString())

      // 杂项格跨 2 列（spec §2.1.2 F-5），单独渲染在末尾
      GridItem() {
        ZoneGridCell({
          zone: BodyZone.Misc,
          items: this.itemsForZone(BodyZone.Misc),
          zoneColor: this.zoneColor(BodyZone.Misc),
          zoneStroke: this.zoneStroke(BodyZone.Misc),
          zoneTint: this.zoneTint(BodyZone.Misc),
          cellHeight: this.cellHeight,
          isDropTarget: this.overlayPhase === 'dragging' && this.dropTargetZone === BodyZone.Misc,
          draggingItemId: this.overlayPhase === 'dragging' ? (this.overlayItem?.id ?? '') : '',
          onTapTitle: (z: string) => { this.openFocus(z); },
          onTapEmpty: (z: string) => { this.onOpenPicker(z); },
          onToggleCheck: this.onToggleCheck,
          onLongPressItem: (item: ChecklistItem, gx: number, gy: number) => {
            this.handleGridLongPress(item, gx, gy);
          },
          onPanUpdate: (ox: number, oy: number) => { this.handleDragUpdate(ox, oy); },
          onPanFinish: (ox: number, oy: number) => { this.handleDragEnd(ox, oy); }
        })
      }
      .columnStart(0)
      .columnEnd(1)
      // B-4：显式等高（杂项跨列）
      .height(this.cellHeight)
      .geometryTransition('zone_' + BodyZone.Misc)
      .opacity(this.focusedZone == BodyZone.Misc ? 0 : (this.appeared ? 1 : 0))
      .hitTestBehavior(this.focusedZone == BodyZone.Misc ? HitTestMode.None : HitTestMode.Default)
      .translate({ y: this.appeared ? 0 : STAGGER_OFFSET_Y })
      .animation({
        curve: SPRING_GENERAL(),
        delay: staggerDelay(GRID_SINGLE_ZONES.length)
      })
      .onAreaChange((_o: Area, n: Area) => {
        const pos = n.globalPosition as Record<string, number>;
        this.zoneRects.set(BodyZone.Misc, [pos.x ?? 0, pos.y ?? 0, n.width as number, n.height as number]);
      })
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(GRID_GUTTER)
    .rowsGap(GRID_GUTTER)
    .width('100%')
    .height('100%')
    .padding({ left: GRID_PADDING, right: GRID_PADDING, top: 8, bottom: 100 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    // B2：拖拽期间锁定 Grid 滚动，防止边拖边滚导致落点偏移
    .enableScrollInteraction(this.overlayPhase !== 'dragging')
  }

  @Builder
  private buildFAB() {
    Row() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(24)
        .fontColor([CARD_BG])
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor(PRIMARY_COLOR)
    .justifyContent(FlexAlign.Center)
    .shadow({
      radius: 12,
      color: OVERLAY_DIM,
      offsetX: 0,
      offsetY: 4
    })
    .position({ right: GRID_PADDING, bottom: 32 })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: SPRING_PRESS() }, () => {
          this.fabScale = 0.9;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
          this.fabScale = 1.0;
        });
      }
    })
    .onClick(() => {
      this.onOpenPicker();
    })
    .opacity(this.appeared ? 1 : 0)
    .scale({
      x: (this.appeared ? 1 : 0.8) * this.fabScale,
      y: (this.appeared ? 1 : 0.8) * this.fabScale
    })
    .animation({ curve: SPRING_GENERAL(), delay: 200 })
  }

  // ---- 底部渐隐遮罩（P4 / 问题2）----
  // 贴底渐隐：上透明 → 下 PAGE_BG，让底部格子自然 fade 进背景（Apple/Things 标准）。
  // 问题2：原用 backgroundBlurStyle 在纯色背景上产生脏灰矩形，已移除，只留纯渐变。
  // hitTestBehavior(None)：不拦截滚动/点击，纯视觉层。聚焦态隐藏。
  @Builder
  private buildBottomFade() {
    Column()
      .width('100%')
      .height(BOTTOM_FADE_HEIGHT)
      .linearGradient({
        angle: 180,
        // 渐变起始必须用 PAGE_BG 的 0-alpha 版本而非 TRANSPARENT(#00000000)：
        // 透明黑 → 羽白的中段会混合出灰色，表现为页面底部一块灰色矩形。
        // 用透明羽白 → 羽白保证渐变全程都在 PAGE_BG 色系内，纯净无杂色。
        colors: [['#00F8F9FA', 0.0], [PAGE_BG, 1.0]]
      })
      .position({ left: 0, bottom: 0 })
      .hitTestBehavior(HitTestMode.None)
      .visibility(this.focusedZone == null ? Visibility.Visible : Visibility.Hidden)
      .opacity(this.appeared ? 1 : 0)
      .animation({ curve: SPRING_GENERAL(), delay: 150 })
  }

  // ---- Phase 4：自绘浮层 Builder（双阶段：menu / dragging，用 opacity 过渡而非 if 销毁）----
  @Builder
  private buildLongPressOverlay() {
    Stack() {
      // 蒙层（menu 阶段压暗可点击关闭；dragging 阶段淡出，消除全页压灰中间态）
      // A-1：仅在 menu 阶段显示灰底，进入 dragging 后随胶囊淡入同步淡出
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#33000000')
        .opacity(this.overlayPhase === 'menu' && this.overlayVisible ? 1 : 0)
        .animation({ curve: EASE_FADE, duration: DURATION_OVERLAY_FADE })
        .onClick(() => {
          if (this.overlayPhase !== 'dragging') {
            this.dismissOverlay();
          }
        })

      // 阶段1：详情卡 + 菜单（居中偏上）——常驻渲染，opacity 控制可见性
      // B1 修正：不用 if 条件销毁（硬消失），改为 opacity + animation 交叉淡入淡出
      Column() {
        GearItemContextMenu({
          item: this.overlayItem!,
          gear: this.findGearForItem(this.overlayItem!),
          menuItems: this.buildOverlayMenuItems()
        })
      }
      .width('80%')
      .constraintSize({ maxWidth: 320 })
      .opacity(this.overlayPhase === 'menu' && this.overlayVisible ? 1 : 0)
      .scale({
        x: this.overlayPhase === 'menu' && this.overlayVisible ? 1 : 0.9,
        y: this.overlayPhase === 'menu' && this.overlayVisible ? 1 : 0.9
      })
      .offset({ y: -40 })
      .animation({ curve: EASE_FADE, duration: DURATION_OVERLAY_FADE })
      .hitTestBehavior(this.overlayPhase === 'menu' ? HitTestMode.Default : HitTestMode.None)

      // 阶段2：拖拽跟手胶囊——常驻渲染，opacity 控制可见性
      // position(x,y) 消费局部坐标 dragCurrentX/Y（已在 handleDragUpdate 中由全局→局部转换），
      // -60/-40 偏移让胶囊居中于手指上方。不再使用 translate()+anchor 双坐标系组合。
      Row({ space: 8 }) {
        Text(this.overlayItem!.name)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 160 })
      }
      .height(40)
      .padding({ left: 16, right: 16 })
      .backgroundColor(CARD_BG)
      .borderRadius(20)
      .shadow({ radius: 20, color: SHADOW_MEDIUM, offsetY: 8 })
      .position({ x: this.dragCurrentX - 60, y: this.dragCurrentY - 40 })
      // A-2：进入 dragging 时浮起放大 + 微倾斜，弹性曲线属性级承接（不与 opacity 的 EASE 共用 .animation）
      .scale({
        x: this.overlayPhase === 'dragging' ? 1.05 : 0.9,
        y: this.overlayPhase === 'dragging' ? 1.05 : 0.9
      })
      .animation({ curve: SPRING_PRESS() })
      .rotate({ angle: this.overlayPhase === 'dragging' ? 2.5 : 0 })
      .animation({ curve: SPRING_PRESS() })
      .opacity(this.overlayPhase === 'dragging' ? 1 : 0)
      .animation({ curve: EASE_FADE, duration: DURATION_OVERLAY_FADE })
      .hitTestBehavior(HitTestMode.None)

    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.overlayPhase === 'dragging' ? HitTestMode.None : HitTestMode.Default)
  }

  // 通过 ChecklistItem 的 fromGearId 反查 GearItem
  private findGearForItem(item: ChecklistItem): GearItem | undefined {
    if (!item.fromGearId) {
      return undefined;
    }
    return this.gears.find((g: GearItem) => g.id === item.fromGearId);
  }

  // ---- Helpers ----

  private itemsForZone(zone: string): ChecklistItem[] {
    return this.zoneMapCache.get(zone) ?? [];
  }

  private zoneColor(zone: string): string {
    switch (zone) {
      case BodyZone.Head: return ZONE_HEAD_COLOR;
      case BodyZone.UpperBody: return ZONE_UPPER_COLOR;
      case BodyZone.LowerBody: return ZONE_LOWER_COLOR;
      case BodyZone.Feet: return ZONE_FEET_COLOR;
      case BodyZone.Carry: return ZONE_CARRY_COLOR;
      case BodyZone.Sleep: return ZONE_SLEEP_COLOR;
      case BodyZone.Misc: return ZONE_MISC_COLOR;
      default: return TEXT_SECONDARY;
    }
  }

  // B-1：zone → 容器描边色（饱和度分档），透传给 ZoneGridCell / ZoneShell
  private zoneStroke(zone: string): string {
    switch (zone) {
      case BodyZone.Head: return ZONE_HEAD_STROKE;
      case BodyZone.UpperBody: return ZONE_UPPER_STROKE;
      case BodyZone.LowerBody: return ZONE_LOWER_STROKE;
      case BodyZone.Feet: return ZONE_FEET_STROKE;
      case BodyZone.Carry: return ZONE_CARRY_STROKE;
      case BodyZone.Sleep: return ZONE_SLEEP_STROKE;
      case BodyZone.Misc: return ZONE_MISC_STROKE;
      default: return ZONE_MISC_STROKE;
    }
  }

  // B-1：zone → 浅染底色（复用 ZONE_*_TINT），用于标题行浅彩底
  private zoneTint(zone: string): string {
    switch (zone) {
      case BodyZone.Head: return ZONE_HEAD_TINT;
      case BodyZone.UpperBody: return ZONE_UPPER_TINT;
      case BodyZone.LowerBody: return ZONE_LOWER_TINT;
      case BodyZone.Feet: return ZONE_FEET_TINT;
      case BodyZone.Carry: return ZONE_CARRY_TINT;
      case BodyZone.Sleep: return ZONE_SLEEP_TINT;
      case BodyZone.Misc: return ZONE_MISC_TINT;
      default: return ZONE_MISC_TINT;
    }
  }
}
