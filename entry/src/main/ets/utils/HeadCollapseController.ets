// head 滚动渐进折叠控制器 — 统一项目内所有「顶部区域随内容滚动而折叠」的滚动数学内核。
//
// 设计边界（关键）：本控制器只管「滚动数学 + 就近吸附 + 曲线分流」，不碰任何渲染。
//   页面持有一个实例，把 handleScroll/handleScrollStop 挂到滚动容器上，
//   从 onChange 回调拿到 progress(0~1) 自己去插值各自的 head。
//   inline 塌缩范式（TripDetailPage）与 overlay 定高变形范式（HomePage/GearPage）
//   对控制器完全透明——控制器只吐 progress，两种布局各取所需，避开「两种布局强行统一」的坑。
//
// 体验范式：对齐 iOS Large Title。
//   - 跟手期（手指在屏上，handleScroll 触发）：progress 严格 1:1 实时映射，零吸附、不抢手感。
//   - 松手惯性停下（handleScrollStop）：若停在 (0,1) 中间态，就近吸附到 0 或 1，绝不留半折叠残缺态。
//
// ⚠️ 刷新陷阱：本控制器是普通 class，改内部字段【不会】触发 ArkUI 组件 re-render。
//   故页面必须持有自己的 @State progress 镜像，由 onChange 回调推动更新——
//   控制器内部 _progress 仅作吸附判定的计算源，渲染一律读页面 @State。

import { SPRING_SCROLL, SPRING_HEAD_FOLLOW } from '../constants/AnimationTokens';

// 控制器配置。每个场景的差异都用入参表达，逻辑内核共享。
export interface HeadCollapseConfig {
  // 折叠总位移（vp）。滚动 0→此距离，progress 线性 0→1。
  //   TripDetail=76(日期28+进度48) / Home=200 / Gear=84(140-56)。
  collapseDistance: number;
  // 是否开启松手就近吸附。本项目统一对齐 Large Title → 全部 true。
  enableSnap: boolean;
  // animateTo 依赖的 UIContext。控制器是普通类无 getUIContext()，必须由页面注入。
  getUIContext: () => UIContext;
  // progress 变化回调。页面据此更新自己的 @State 镜像（触发 re-render），并做跨组件透传（如 TripDetail→父层 SharedInfo）。
  onChange: (progress: number, snapping: boolean) => void;
  // 吸附分界，默认 0.5。
  snapThreshold?: number;
}

export class HeadCollapseController {
  private config: HeadCollapseConfig;
  // 当前折叠进度（滚动驱动部分），0~1。仅作内部计算源，渲染读页面 @State 镜像。
  private scrollProgress: number = 0;
  // 外部强制满折叠信号（如 GearPage.searchExpanded / TripDetailPage.focusedZone）。
  private forcedCollapsed: boolean = false;
  // 是否处于吸附动画态。区分曲线：跟手用 SPRING_HEAD_FOLLOW（近 1:1 实时），吸附用 SPRING_SCROLL（沉稳收尾）。
  private snapping: boolean = false;

  constructor(config: HeadCollapseConfig) {
    this.config = config;
  }

  // 有效折叠进度 = max(滚动进度, 强制满折叠)。
  //   强制态吃满 1（如聚焦卡片要顶到 navbar 下沿 / 搜索框展开锁收缩），与滚动取「更折叠」者。
  progress(): number {
    return this.forcedCollapsed ? 1 : this.scrollProgress;
  }

  // 折叠动画曲线：吸附态 / 强制态走 SPRING_SCROLL；跟手态走 SPRING_HEAD_FOLLOW。
  //   （强制态语义上是「开关切换」，用沉稳的 SPRING_SCROLL 收尾，不用跟手曲线。）
  curve(): ICurve {
    return (this.snapping || this.forcedCollapsed) ? SPRING_SCROLL() : SPRING_HEAD_FOLLOW();
  }

  // 跟手：挂到 Grid 的 .onScroll 或 List/Scroll 的 .onDidScroll。
  //   强制态下跳过——head 已由 forcedCollapsed 吃满，避免双驱动打架。
  handleScroll(scroller: Scroller): void {
    if (this.forcedCollapsed) {
      return;
    }
    const yOffset: number = scroller.currentOffset().yOffset;
    const p: number = Math.min(1, Math.max(0, yOffset / this.config.collapseDistance));
    this.snapping = false;
    this.scrollProgress = p;
    this.config.onChange(p, false);
  }

  // 松手 + 惯性结束后的就近吸附：挂到 .onScrollStop。
  //   仅中间态 (0,1) 吸附；已是 0/1 不做多余动画。对齐 iOS Large Title。
  handleScrollStop(scroller: Scroller): void {
    if (!this.config.enableSnap || this.forcedCollapsed) {
      return;
    }
    const p: number = this.scrollProgress;
    if (p <= 0 || p >= 1) {
      return;
    }
    const threshold: number = this.config.snapThreshold ?? 0.5;
    const targetProgress: number = p < threshold ? 0 : 1;
    const targetOffset: number = targetProgress * this.config.collapseDistance;
    this.snapping = true;
    scroller.scrollTo({
      xOffset: 0,
      yOffset: targetOffset,
      animation: { curve: SPRING_SCROLL() }
    });
    this.config.getUIContext().animateTo({ curve: SPRING_SCROLL() }, () => {
      this.scrollProgress = targetProgress;
      this.config.onChange(targetProgress, true);
    });
  }

  // 外部强制满折叠（聚焦态 / 搜索展开 / 多选等旁路）。
  //   forced=true 时 progress 吃满 1；forced=false 时回落到当前滚动进度。
  //   两种切换都标 snapping（走 SPRING_SCROLL 平滑过渡），并回吐让页面刷新。
  setForcedCollapsed(forced: boolean): void {
    if (this.forcedCollapsed === forced) {
      return;
    }
    this.forcedCollapsed = forced;
    this.snapping = true;
    this.config.onChange(this.progress(), true);
  }
}
