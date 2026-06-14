// 统一清单视图 - 主视图（网格态）
// 职责：2 列网格展示全部 7 个 Zone 格子（有内容态 / 空态），首屏精确 2×2.5 密度
// 替代旧的配装/清单双 Tab。spec §2.1 / §4
// P1：空态不再切引导页，统一走网格态——0 件时所有 Zone 走虚线空格子，点对应部位空格子加装备

import { display } from '@kit.ArkUI';
import {
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_SECONDARY,
  CARD_BG,
  PAGE_BG,
  OVERLAY_DIM,
  SHADOW_MEDIUM
} from '../../constants/Colors';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  SPRING_HERO_EXPAND,
  SPRING_HERO_COLLAPSE,
  STAGGER_OFFSET_Y,
  GRID_FOCUS_BLUR,
  GRID_FOCUS_SINK_Y,
  staggerDelay,
  SHARP_SNAP,
  EASE_FADE,
  DURATION_OVERLAY_ENTER,
  DURATION_OVERLAY_FADE
} from '../../constants/AnimationTokens';
import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { resolveItemName } from '../../services/ChecklistService';
import { BodyZone } from '../../constants/GearLoadout';
import { hapticSoft, hapticSharp } from '../../utils/HapticUtils';
import { groupByZoneAll, calcProgress, LoadoutProgress, zoneColor, zoneStroke, zoneFill, zoneFocusBg, hitTestZoneRect } from '../../services/LoadoutService';
import { ZoneGridCell } from './ZoneGridCell';
import { FocusedZoneView } from './FocusedZoneView';
import { LoadoutProgressBar } from './LoadoutProgressBar';
import { GearItemContextMenu, ContextMenuItem } from './GearItemContextMenu';
import { GearDetailSheet } from './GearDetailSheet';
import { HeadCollapseController } from '../../utils/HeadCollapseController';

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
// 反算兜底（无法取得屏高时）。问题5：上调至 196 保证兜底态也能容纳 5 行预览（标题28+5×32=188，留余量）
const CELL_HEIGHT_FALLBACK: number = 196;

// 问题4a：head 随网格滚动渐进折叠的总位移（vp）。
//   = SharedInfo(28，TripDetailPage 日期行) + ProgressBar(48，本组件进度条) = 76。
//   网格滚动 0→此距离，headCollapseProgress 线性 0→1，期间严格 1:1 跟手（无动画）。
//   松手后惯性停在中间态时再做就近吸附（Spring）。对齐 iOS Large Title 范式。
//   折叠数学统一交给 HeadCollapseController，此距离作为其 collapseDistance 配置入参。
const HEAD_COLLAPSE_DISTANCE: number = 76;

@Component
export struct UnifiedChecklistView {
  @Prop @Watch('onTripChange') trip: TripChecklist = { id: '', title: '', items: [], createdAt: 0 };
  @Prop gears: GearItem[] = [];
@Prop checklistRenderNonce: number = 0;
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
  // D-2：聚焦态「逐项核查本区」回调
  onReviewZone: (zone: string) => void = () => {};
  // #10：格子内排序完成回调（重排后的 item id 数组）
  onReorderItems: (zone: string, orderedIds: string[]) => void = () => {};
  // #1：多选后请求弹出 Zone 选择面板（由 Index 处理）
  onRequestBatchMoveSheet: (itemIds: string[]) => void = () => {};
  // 问题4a：head 折叠进度变化回调（0=全展开，1=全折叠）。父层 TripDetailPage 据此插值收起日期行（SharedInfo），
  //   与本组件的 ProgressBar 折叠同帧联动，形成「整条 head 随滚动连续收没」的 iOS Large Title 手感。
  //   snapping：是否吸附动画态（父层据此选曲线——跟手用即时跟随，吸附用 SPRING_SCROLL）。
  onHeadCollapseChange: (progress: number, snapping: boolean) => void = () => {};

  // 入场动画控制
  @State private appeared: boolean = false;
  // 问题4a：head 折叠进度（0=全展开，1=全折叠）。
  //   跟手期间由 Grid.onScroll 实时 1:1 赋值（无动画）；松手惯性停在中间态时由 onScrollStop 走 Spring 吸附就近端。
  @State private headCollapseProgress: number = 0;
  // 问题4a：是否处于吸附动画中——区分曲线：跟手时不挂 animation（靠高频赋值实时跟），吸附时挂 SPRING_SCROLL。
  @State private headSnapping: boolean = false;
  // 反算得到的单格高度
  @State private cellHeight: number = CELL_HEIGHT_FALLBACK;

  // #3：装备详情底部半屏 Sheet
  @State private detailSheetItem: ChecklistItem | null = null;
  @State private detailSheetVisible: boolean = false;

  // #1：多选模式信号（递增触发 FocusedZoneView 进入多选）
  @State private multiSelectSignal: number = 0;
  @State private multiSelectInitialId: string = '';

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
  // #12：拖拽自动滚动
  private gridScroller: Scroller = new Scroller();
  private autoScrollTimer: number = -1;
  private autoScrollSpeed: number = 0;
  // 容器高度（用于计算边缘热区）
  private containerHeight: number = 0;
  // 全屏聚焦的 Zone（null = 网格态）。spec §2.2 / §4.5.6
  // 问题4a：改 @Link 由 Index 持有 @State 源，使 onBackPressed 能读判断「是否聚焦」做分层拦截。
  //   注意：Index 不直接改此值（会丢收起动画），而是递增 closeFocusSignal 让本组件走带动画的 closeFocus()。
//   @Watch：聚焦态变化 → 同步控制器 forcedCollapsed（聚焦时 head 强制吃满折叠）。
  @Link @Watch('onFocusedZoneChange') focusedZone: string | null;
  // 问题4a：Index 命中聚焦态时递增此信号，本组件 @Watch 后走带动画的 closeFocus()。
  @Prop @Watch('onCloseFocusSignal') closeFocusSignal: number;
  // 当前/上次聚焦渲染的 Zone（F-3：FocusedZoneView 常驻树用 visibility 切换，退场时仍需有 zone 可渲染）
  @State private focusedZoneRender: string = BodyZone.Misc;

  // 分组缓存：仅在 @Watch('trip') 时刷新。
  // 隐含前提（review C2）：Zone 分组只依赖 trip.items 自身字段，不依赖 gears。
  // 因此「gears 数据变化但 trip 引用不变」（如装备库重命名 gear）不会、也无需刷新本缓存。
  private zoneMapCache: Map<string, ChecklistItem[]> = new Map();

  // 问题4a：统一折叠控制器。实例放本组件（持有 gridScroller）。
  //   onChange 把 progress 同时写回本组件 @State 镜像（驱动 ProgressBar 折叠）与父层（驱动 SharedInfo 折叠）。
  private headController: HeadCollapseController = new HeadCollapseController({
    collapseDistance: HEAD_COLLAPSE_DISTANCE,
    enableSnap: true,
    getUIContext: () => this.getUIContext(),
    onChange: (progress: number, snapping: boolean) => {
      this.headSnapping = snapping;
      this.headCollapseProgress = progress;
      this.onHeadCollapseChange(progress, snapping);
    }
  });

  // @Watch('focusedZone')：聚焦态切换时把强制满折叠信号同步给控制器。
  onFocusedZoneChange(): void {
    this.headController.setForcedCollapsed(this.focusedZone != null);
  }

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
    this.stopAutoScroll();
  }

onTripChange(): void {
this.refreshCache();
}

onReservedTopChange(): void {
this.computeCellHeight();
}

// 问题4a：有效折叠程度 = 两个来源取「更折叠」者。
//   聚焦态吃满 1（聚焦卡片要顶到 navbar 下沿，head 必须全收）；非聚焦时跟随滚动进度。
  private effectiveHeadCollapse(): number {
    // ⚠️ 刷新陷阱：必须读 @State 镜像（headCollapseProgress），不能直接读 controller.progress()。
    //   ArkUI 依赖收集只订阅 build 中读到的 @State；controller 是普通类，改字段不触发 re-render。
    //   镜像由 controller.onChange 推动更新（含强制态 setForcedCollapsed 回吐的满折叠值）。
    return this.headCollapseProgress;
  }

// 问题4a：head 折叠动画曲线分三态——
//   聚焦态开关切换走 SPRING_HERO（展/收方向不同）；
//   滚动吸附走 SPRING_SCROLL（沉稳收尾）；
//   跟手滚动走 SPRING_HEAD_FOLLOW（responsiveSpringMotion 近 1:1 实时跟随，不抢手感）。
  private headCollapseCurve(): ICurve {
    // 聚焦态走 hero 展开曲线（与共享元素转场同帧），是本页特有动效，不下沉到通用控制器。
    if (this.focusedZone != null) {
      return SPRING_HERO_EXPAND();
    }
    return this.headController.curve();
  }

  build() {
    Column() {
      // 顶部全局进度条（sticky 吸顶，仅有内容时显示）。spec §2.1 / §3.3
      // 诉求1：进入聚焦时进度条随 head 一起向上收没（height→0 + 淡出 + clip），
      //   与日期行（父层 TripDetailPage）协同让出空间给聚焦卡片顶到 navbar 下沿。
      //   外层 collapse 容器：展开高度 48（与 TripDetailPage.reservedTop 的 PROGRESS_BAR 一致，可插值）。
      if (this.trip.items.length > 0) {
        Column() {
          LoadoutProgressBar({
            checked: this.progress().checked,
            total: this.progress().total
          })
        }
        .width('100%')
        // 问题4a：折叠程度融合两个来源——聚焦态吃满 1（走 SPRING_HERO 开关动画），
        //   非聚焦时跟随滚动 headCollapseProgress（跟手 1:1 无动画，吸附走 SPRING_SCROLL）。
        //   展开高度 48，线性插值到 0。
        .height(48 * (1 - this.effectiveHeadCollapse()))
        .clip(true)
        .opacity(1 - this.effectiveHeadCollapse())
        .animation({ curve: this.headCollapseCurve() })
      }

      Stack() {
        // P1：空态不再切引导页，统一走网格态——0 件时所有 Zone 走虚线空格子，
        // 用户直接点对应部位空格子加装备（「带格子的核查清单」纲领）。
        this.buildGridState()

        // D-4：全屏压暗蒙层。层级在网格之上、聚焦卡片之下，点蒙层收起聚焦。
        this.buildFocusedScrim()

        // 全屏聚焦态（F-3：常驻树，用 visibility 切换，position 叠加在网格之上）
        this.buildFocusedLayer()

        // Phase 4：长按自绘浮层（蓙层 + 详情卡 + 菜单），条件渲染
        if (this.overlayItem !== null) {
          this.buildLongPressOverlay()
        }

        // #3：装备详情底部半屏 Sheet
        // 条件渲染：ArkUI 中 hitTestBehavior(None) 不可靠地阻止子元素 onClick（避坑 ZoneGridCell 注释），
        // 常驻树时蒙层 Column 的 onClick 仍拦截全屏点击导致网格态完全无法交互。
        // 用 detailSheetItem !== null 作为条件（closeDetailSheet 延迟 400ms 清空 item 保留退场动画）。
        if (this.detailSheetItem !== null) {
          GearDetailSheet({
            item: this.detailSheetItem,
            gears: this.gears,
            visible: this.detailSheetVisible,
            onClose: () => { this.closeDetailSheet(); },
            onEditGear: (_gearId: string) => {
              this.closeDetailSheet();
              if (this.detailSheetItem !== null) {
                this.onEditItem(this.detailSheetItem);
              }
            },
            onRemoveItem: (itemId: string) => {
              this.onRemoveItem(itemId);
              this.closeDetailSheet();
            }
          })
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
        // #12：记录容器高度用于边缘热区计算
        this.containerHeight = n.height as number;
      })
    }
    .width('100%')
    .height('100%')
  }

  // ---- D-4：全屏聚焦遮罩（常驻树，opacity 切换，焦点驱动）----
  //   诉求2：从半透明压暗黑（OVERLAY_DIM）改为纯羽白实心（PAGE_BG #F8F9FA）。
  //   彻底盖住背后网格虚影 + 满屏水印，聚焦卡片浮在干净羽白底上，可读性拉满（仿便单纯白屏背景）。
  //   半透明黑 + 透出网格 = 三层叠加发灰发脏，是上版「卡片背后透明可读性差」的根因。
  //   与 SPRING_HERO 同帧淡入淡出；层级在网格之上、聚焦卡片之下；点遮罩 → 收起聚焦。
  @Builder
  private buildFocusedScrim() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BG)
      .opacity(this.focusedZone != null ? 1 : 0)
      .animation({ curve: this.focusedZone != null ? SPRING_HERO_EXPAND() : SPRING_HERO_COLLAPSE() })
      // 非聚焦时彻底不拦截点击，避免遮住网格交互
      .hitTestBehavior(this.focusedZone != null ? HitTestMode.Default : HitTestMode.None)
      .onClick(() => {
        if (this.focusedZone != null) {
          this.closeFocus();
        }
      })
  }

  // ---- 全屏聚焦层（常驻树，geometryTransition 共享元素配对端）----
  @Builder
  private buildFocusedLayer() {
// 诉求1：聚焦态 = 卡片铺满 head 收没后让出的空间（顶到 navbar 下沿 ~ 底部安全区上方）。
//   外层定位容器：左右留边 16（与网格 GRID_PADDING 一致，转场更连贯）、顶部 8、底部留 96。
    //   不再垂直居中悬浮 80%——卡片 height('100%') 撑满定位容器。
    //   geometryTransition 下沉到 FocusedZoneView（= ZoneShell 卡片节点）本身——
    //   与网格端 GridItem（那张卡）几何对应，转场是「同一块淡色容器连续放大」，
    //   修复此前挂全屏居中容器导致标题被甩到屏幕中央 / 背景药丸悬空的错位。
    Column() {
      FocusedZoneView({
        zone: this.focusedZoneRender,
        items: this.itemsForZone(this.focusedZoneRender),
        gears: this.gears,
        zoneColor: zoneColor(this.focusedZoneRender),
        zoneStroke: zoneStroke(this.focusedZoneRender),
        zoneFill: zoneFocusBg(this.focusedZoneRender),
        active: this.focusedZone != null,
        multiSelectSignal: this.multiSelectSignal,
        multiSelectInitialId: this.multiSelectInitialId,
        onClose: () => { this.closeFocus(); },
        onTapEmpty: (z: string) => { this.onOpenPicker(z); },
        onToggleCheck: this.onToggleCheck,
        onEditItem: this.onEditItem,
        onRemoveItem: this.onRemoveItem,
        onMoveItemToZone: this.onMoveItemToZone,
        onLongPressItem: (item: ChecklistItem) => { this.showOverlay(item); },
        onDismissMenu: () => { this.dismissOverlay(true); },
        onEdgeDragOut: (item: ChecklistItem, offsetX: number, offsetY: number) => {
          this.handleEdgeDragOut(item, offsetX, offsetY);
        },
        onEdgePanUpdate: (offsetX: number, offsetY: number) => {
          this.handleEdgePanUpdate(offsetX, offsetY);
        },
        onEdgePanEnd: (offsetX: number, offsetY: number) => {
          this.handleEdgePanEnd(offsetX, offsetY);
        },
        onBatchDragOut: (itemIds: string[], offsetX: number, offsetY: number) => {
          this.handleBatchDragOut(itemIds, offsetX, offsetY);
        },
        onTapItem: (item: ChecklistItem) => { this.openDetailSheet(item); },
        onReorderItems: (zone: string, orderedIds: string[]) => { this.onReorderItems(zone, orderedIds); },
        onRequestBatchMoveSheet: (ids: string[]) => { this.onRequestBatchMoveSheet(ids); },
        onReviewZone: this.onReviewZone
      })
        .width('100%')
        .height('100%')
        // D-3：follow:true 让转场期间节点跟随布局插值，从原格几何中心连续长大到聚焦落点（就地放大）。
        //   挂在卡片节点上而非外层全屏容器，保证两端共享元素都是「那张卡」本身。
        .geometryTransition('zone_' + this.focusedZoneRender, { follow: true })
    }
    .width('100%')
    .height('100%')
    // 问题3c 修复：底部 padding 由 96 降到 24。原 96vp 把卡片下边界硬抬高 96vp，
    //   卡片 clip(true) 导致列表滚到卡片下沿即被裁切，视觉上「内容到某条线突然截断消失」。
    //   降到 24vp 后卡片几乎贴到底部安全区上方，列表内容可完整滚动展示，下方留呼吸而非硬切。
    .padding({ left: GRID_PADDING, right: GRID_PADDING, top: 8, bottom: 24 })
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

  // Phase 4/5：展开态拖到边缘 / 多选批量拖拽 → 收缩聚焦态 + 启动跨 zone 拖拽
  // 保存边缘触发时的 Pan 偏移基准，后续 update 用差值计算胶囊位移
  private edgeDragBaseOffsetX: number = 0;
  private edgeDragBaseOffsetY: number = 0;
  // Phase 5：批量拖拽的 item ids（空数组 = 单项拖拽）
  private batchDragIds: string[] = [];

  private handleEdgeDragOut(item: ChecklistItem, offsetX: number, offsetY: number): void {
    // 保存触发时的偏移作为基准
    this.edgeDragBaseOffsetX = offsetX;
    this.edgeDragBaseOffsetY = offsetY;
    // 单项拖出，清空批量 ids
    this.batchDragIds = [];
    // 1. 设置拖拽状态
    this.overlayItem = item;
    this.overlayPhase = 'dragging';
    this.overlayVisible = true;
    this.dropTargetZone = null;
    // 胶囊初始位置：屏幕中央偏上（后续由 Pan 差值跟手修正）
    try {
      const di = display.getDefaultDisplaySync();
      const screenW = this.getUIContext().px2vp(di.width);
      const screenH = this.getUIContext().px2vp(di.height);
      this.dragCurrentX = screenW / 2 - this.overlayOriginX;
      this.dragCurrentY = screenH / 3 - this.overlayOriginY;
    } catch (_e) {
      this.dragCurrentX = 180;
      this.dragCurrentY = 250;
    }
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    // 2. 收缩聚焦态（geometryTransition 动画）
    this.getUIContext().animateTo({ curve: SPRING_HERO_COLLAPSE() }, () => {
      this.focusedZone = null;
    });
    // 3. 触觉反馈
    this.triggerDropHaptic();
  }

  // Phase 5：多选批量拖出（长按已选中项触发）
  private handleBatchDragOut(itemIds: string[], offsetX: number, offsetY: number): void {
    // 保存触发时的偏移作为基准
    this.edgeDragBaseOffsetX = offsetX;
    this.edgeDragBaseOffsetY = offsetY;
    // 记录批量 ids
    this.batchDragIds = itemIds;
    // 用第一个 item 作为 overlayItem（胶囊显示用）
    const firstItem = this.trip.items.find((i: ChecklistItem) => i.id === itemIds[0]);
    if (firstItem === undefined) {
      return;
    }
    this.overlayItem = firstItem;
    this.overlayPhase = 'dragging';
    this.overlayVisible = true;
    this.dropTargetZone = null;
    // 胶囊初始位置：屏幕中央偏上
    try {
      const di = display.getDefaultDisplaySync();
      const screenW = this.getUIContext().px2vp(di.width);
      const screenH = this.getUIContext().px2vp(di.height);
      this.dragCurrentX = screenW / 2 - this.overlayOriginX;
      this.dragCurrentY = screenH / 3 - this.overlayOriginY;
    } catch (_e) {
      this.dragCurrentX = 180;
      this.dragCurrentY = 250;
    }
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
    // 收缩聚焦态
    this.getUIContext().animateTo({ curve: SPRING_HERO_COLLAPSE() }, () => {
      this.focusedZone = null;
    });
    // 触觉反馈
    this.triggerDropHaptic();
  }

  // Phase 4：边缘拖出后 Pan 跟手更新（FocusedZoneView 转发）
  private handleEdgePanUpdate(offsetX: number, offsetY: number): void {
    if (this.overlayItem === null || this.overlayPhase !== 'dragging') {
      return;
    }
    // 用 Pan 偏移差值（相对边缘触发时）更新胶囊位置
    const deltaX = offsetX - this.edgeDragBaseOffsetX;
    const deltaY = offsetY - this.edgeDragBaseOffsetY;
    try {
      const di = display.getDefaultDisplaySync();
      const screenW = this.getUIContext().px2vp(di.width);
      const screenH = this.getUIContext().px2vp(di.height);
      this.dragCurrentX = screenW / 2 - this.overlayOriginX + deltaX;
      this.dragCurrentY = screenH / 3 - this.overlayOriginY + deltaY;
    } catch (_e) {
      this.dragCurrentX = 180 + deltaX;
      this.dragCurrentY = 250 + deltaY;
    }
    // 命中判定（用胶囊中心的全局坐标）
    const fingerGlobalX = this.dragCurrentX + this.overlayOriginX;
    const fingerGlobalY = this.dragCurrentY + this.overlayOriginY;
    const prevTarget = this.dropTargetZone;
    this.dropTargetZone = this.hitTestZone(fingerGlobalX, fingerGlobalY);
    if (this.dropTargetZone !== null && this.dropTargetZone !== prevTarget) {
      this.triggerDropHaptic();
    }
  }

  // Phase 4：边缘拖出后 Pan 结束（松手落点）
  private handleEdgePanEnd(offsetX: number, offsetY: number): void {
    if (this.overlayItem === null) {
      return;
    }
    // 最终命中判定
    const deltaX = offsetX - this.edgeDragBaseOffsetX;
    const deltaY = offsetY - this.edgeDragBaseOffsetY;
    let fingerGlobalX: number;
    let fingerGlobalY: number;
    try {
      const di = display.getDefaultDisplaySync();
      const screenW = this.getUIContext().px2vp(di.width);
      const screenH = this.getUIContext().px2vp(di.height);
      fingerGlobalX = screenW / 2 + deltaX;
      fingerGlobalY = screenH / 3 + deltaY;
    } catch (_e) {
      fingerGlobalX = 180 + this.overlayOriginX + deltaX;
      fingerGlobalY = 250 + this.overlayOriginY + deltaY;
    }
    const target = this.hitTestZone(fingerGlobalX, fingerGlobalY);
    if (target !== null && target !== this.overlayItem!.group) {
      if (this.batchDragIds.length > 0) {
        // 批量移动：所有选中项移到目标 zone
        for (const id of this.batchDragIds) {
          this.onMoveItemToZone(id, target);
        }
      } else {
        // 单项移动
        this.onMoveItemToZone(this.overlayItem!.id, target);
      }
      // 问题1：成功落位回执（批量/单项统一一次）
      this.triggerLandedHaptic();
    }
    // 重置拖拽状态
    this.batchDragIds = [];
    this.overlayPhase = 'idle';
    this.overlayVisible = false;
    this.dropTargetZone = null;
    setTimeout(() => {
      if (!this.isAlive) { return; }
      this.overlayItem = null;
    }, DURATION_OVERLAY_FADE + 80);
  }

  // ---- #3：装备详情 Sheet 控制 ----
  private openDetailSheet(item: ChecklistItem): void {
    this.detailSheetItem = item;
    this.detailSheetVisible = true;
  }

  private closeDetailSheet(): void {
    this.detailSheetVisible = false;
    // 延迟清空 item，让退场动画完成
    setTimeout(() => {
      if (!this.isAlive) return;
      if (!this.detailSheetVisible) {
        this.detailSheetItem = null;
      }
    }, 400);
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
    // 立即重置交互状态——让 hitTestBehavior 瞬间放行，不再阻塞后续触摸
    // 退出动画由 buildLongPressOverlay 内各元素的 .animation() 声明式修饰符自动驱动
    this.overlayPhase = 'idle';
    this.overlayVisible = false;
    // 延迟清理数据引用，等退出动画播完再销毁（避免 if 条件销毁打断退出动画）
    // DURATION_OVERLAY_FADE=120ms 是 .animation() 退出时长，需留足余量
    const cleanupDelay = fast ? 150 : DURATION_OVERLAY_FADE + 80;
    setTimeout(() => {
      if (!this.isAlive) { return; }
      this.overlayItem = null;
    }, cleanupDelay);
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
        icon: $r('sys.symbol.checkmark_circle'),
        label: '选择多个',
        action: () => {
          this.dismissOverlay(true);
          // 进入多选模式，初始选中当前 item
          this.multiSelectInitialId = item.id;
          this.multiSelectSignal++;
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
    const localX = fingerGlobalX - this.overlayOriginX;
    const localY = fingerGlobalY - this.overlayOriginY;
    this.dragCurrentX = localX;
    this.dragCurrentY = localY;
    // #12：边缘热区自动滚动
    this.checkAutoScroll(localY);
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
    // #12：停止自动滚动
    this.stopAutoScroll();
    const fingerGlobalX = this.longPressGlobalX + offsetX;
    const fingerGlobalY = this.longPressGlobalY + offsetY;
    const target = this.hitTestZone(fingerGlobalX, fingerGlobalY);
    if (target !== null && target !== this.overlayItem!.group) {
      this.onMoveItemToZone(this.overlayItem!.id, target);
      // 问题1：成功落位回执
      this.triggerLandedHaptic();
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
    this.stopAutoScroll();
  }

  // ---- #12：拖拽边缘自动滚动 ----
  private static readonly AUTO_SCROLL_EDGE: number = 80; // 热区高度 vp
  private static readonly AUTO_SCROLL_INTERVAL: number = 16; // ~60fps

  private checkAutoScroll(fingerLocalY: number): void {
    const edge = UnifiedChecklistView.AUTO_SCROLL_EDGE;
    if (fingerLocalY < edge) {
      // 顶部热区：向上滚动（负值）
      const ratio = (edge - fingerLocalY) / edge;
      this.autoScrollSpeed = -ratio * 10;
      this.startAutoScroll();
    } else if (fingerLocalY > this.containerHeight - edge) {
      // 底部热区：向下滚动（正值）
      const ratio = (fingerLocalY - (this.containerHeight - edge)) / edge;
      this.autoScrollSpeed = ratio * 10;
      this.startAutoScroll();
    } else {
      this.stopAutoScroll();
    }
  }

  private startAutoScroll(): void {
    if (this.autoScrollTimer >= 0) {
      return; // 已在滚动
    }
    this.autoScrollTimer = setInterval(() => {
      this.gridScroller.scrollBy(0, this.autoScrollSpeed);
    }, UnifiedChecklistView.AUTO_SCROLL_INTERVAL);
  }

  private stopAutoScroll(): void {
    if (this.autoScrollTimer >= 0) {
      clearInterval(this.autoScrollTimer);
      this.autoScrollTimer = -1;
      this.autoScrollSpeed = 0;
    }
  }

  // 问题1：拖拽进入新目标格的触觉反馈。
  //   第一性原理：跨格是拖拽中「有空间吸附意义的离散里程碑」，比勾选(tick)重要——
  //   tick 太轻会淹没在拖拽手势里，用户感知不到「进新格了」。升级为 soft：
  //   明确的实体吸附感，又不刺激（拖拽扫过多格时频繁触发也不烦躁）。
  //   与长按触发拖拽同用 soft，时序不重叠，形成「soft = 与格子发生关系」的一致触觉语义。
  private triggerDropHaptic(): void {
    hapticSoft();
  }

  // 问题1：拖拽成功落位的回执反馈。
  //   第一性原理：松手成功移入新格是整个拖拽操作的「完成时刻」，需要一记比过程(soft)
  //   更明确清脆的「成了」确认——用 sharp 与跨格 soft 分层：soft=途经，sharp=落定。
  //   仅在确实发生移动（target 有效且非原格）时触发，空落/原地放回不响。
  private triggerLandedHaptic(): void {
    hapticSharp();
  }

  // 坐标命中判定：当前全局坐标落在哪个 zone 格子内
  // zoneRects 存全局坐标，需转局部后与手指局部坐标比较
  private hitTestZone(globalX: number, globalY: number): string | null {
    const candidateZones: string[] = [...GRID_SINGLE_ZONES, BodyZone.Misc];
    return hitTestZoneRect(this.zoneRects, candidateZones, globalX, globalY, this.overlayOriginX, this.overlayOriginY);
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
    // 问题4 根因修复：原 Grid 自身滚动 + cachedCount(8) 仍在真机出现「底部格子未完全遮挡就消失」。
    //   根因不是 cachedCount 数量不足，而是 Grid 懒加载对【跨列 GridItem（杂项 columnStart/End）】的
    //   保活不可靠——整行滚到视口外时缓存计数不一定覆盖它，被回收即消失。
    //   彻底根治：外层 Scroll 承载滚动，内层 Grid 设为非滚动（内容自然高度撑开），
    //   Grid 不滚动即不触发任何虚拟化回收 → 全部 GridItem 常驻，零消失。
    //   head 折叠的 onScroll/onScrollStop、拖拽锁滚动、edgeEffect 全部迁到外层 Scroll。
    Scroll(this.gridScroller) {
    Grid() {
      // 前 6 个 zone 走双列自动布局
      ForEach(GRID_SINGLE_ZONES, (zone: string, index: number) => {
        GridItem() {
          ZoneGridCell({
            zone: zone,
            items: this.itemsForZone(zone),
            gears: this.gears,
            zoneColor: zoneColor(zone),
            zoneStroke: zoneStroke(zone),
            zoneFill: zoneFill(zone),
            cellHeight: this.cellHeight,
            isDropTarget: this.overlayPhase === 'dragging' && this.dropTargetZone === zone,
            draggingItemId: this.overlayPhase === 'dragging' ? (this.overlayItem?.id ?? '') : '',
            onTapTitle: (z: string) => { this.openFocus(z); },
            onTapEmpty: (z: string) => { this.onOpenPicker(z); },
            onTapAdd: (z: string) => { this.onOpenPicker(z); },
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
        // D-3：与聚焦端 options 一致（follow:true），保证就地放大锚定原格
        .geometryTransition('zone_' + zone, { follow: true })
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
          gears: this.gears,
          zoneColor: zoneColor(BodyZone.Misc),
          zoneStroke: zoneStroke(BodyZone.Misc),
          zoneFill: zoneFill(BodyZone.Misc),
          cellHeight: this.cellHeight,
          isDropTarget: this.overlayPhase === 'dragging' && this.dropTargetZone === BodyZone.Misc,
          draggingItemId: this.overlayPhase === 'dragging' ? (this.overlayItem?.id ?? '') : '',
          onTapTitle: (z: string) => { this.openFocus(z); },
          onTapEmpty: (z: string) => { this.onOpenPicker(z); },
          onTapAdd: (z: string) => { this.onOpenPicker(z); },
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
      // D-3：与聚焦端 options 一致（follow:true）
      .geometryTransition('zone_' + BodyZone.Misc, { follow: true })
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
    // 问题4：Grid 高度自适应内容（非 '100%'）——作为 Scroll 的子节点按真实内容高度撑开，
    //   全部 GridItem 一次性布局、不进虚拟化，彻底杜绝跨列格子被回收消失。
    .height('auto')
    // D-4：聚焦时网格虚化 + 极小下沉，制造「退到背后」纵深感。随 SPRING_HERO 同帧联动。
    .blur(this.focusedZone != null ? GRID_FOCUS_BLUR : 0)
    .translate({ y: this.focusedZone != null ? GRID_FOCUS_SINK_Y : 0 })
    .animation({ curve: this.focusedZone != null ? SPRING_HERO_EXPAND() : SPRING_HERO_COLLAPSE() })
    }
    .width('100%')
    .height('100%')
    .padding({ left: GRID_PADDING, right: GRID_PADDING, top: 8, bottom: 100 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    // B2：拖拽期间锁定滚动，防止边拖边滚导致落点偏移
    .enableScrollInteraction(this.overlayPhase !== 'dragging')
    // 问题4a：head 随滚动渐进折叠。折叠程度 = 滚动意图的实时映射（连续量，非开关）。
    //   跟手阶段严格 1:1 实时赋值、零动画、绝不抢手感；松手吸附交给 onScrollStop。
    //   聚焦态下 head 已由 focusedZone 开关吃满折叠（走 SPRING_HERO），此处由控制器内部跳过避免双驱动打架。
    .onDidScroll(() => {
      this.headController.handleScroll(this.gridScroller);
    })
    // 问题4a：松手 + 惯性结束后的「就近吸附」。对齐 iOS Large Title——绝不让 head 停在半折叠残缺态。
    .onScrollStop(() => {
      this.headController.handleScrollStop(this.gridScroller);
    })
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
        .backgroundColor(OVERLAY_DIM)
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
          displayName: resolveItemName(this.overlayItem!, this.gears),
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
        Text(this.batchDragIds.length > 1
          ? `${this.batchDragIds.length} 件装备`
          : resolveItemName(this.overlayItem!, this.gears))
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
    // Bug3 fix：仅在 menu 可见阶段拦截触摸（蒙层点击关闭），
    // idle/dragging 阶段一律穿透——消除 dismissOverlay 后 150ms 清理延迟期间 Stack 吞事件的问题
    .hitTestBehavior(this.overlayPhase === 'menu' && this.overlayVisible ? HitTestMode.Default : HitTestMode.None)
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

}
