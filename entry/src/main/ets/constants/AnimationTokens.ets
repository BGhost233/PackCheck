import { curves } from '@kit.ArkUI';

// ============================================================
// Spring 曲线预设 — 统一使用 springMotion(response, dampingFraction)
// ============================================================

// 通用
export const SPRING_GENERAL = (): ICurve => curves.springMotion(0.35, 0.8);
export const SPRING_PRESS = (): ICurve => curves.springMotion(0.25, 0.7);
export const SPRING_TAB = (): ICurve => curves.springMotion(0.4, 0.75);
export const SPRING_COUNTER = (): ICurve => curves.springMotion(0.3, 0.75);
export const SPRING_SCROLL = (): ICurve => curves.springMotion(0.45, 0.85);

// 共享元素转场
export const SPRING_HERO_EXPAND = (): ICurve => curves.springMotion(0.42, 0.73);
export const SPRING_HERO_COLLAPSE = (): ICurve => curves.springMotion(0.36, 0.78);

// 问题4a：head 随滚动跟手折叠。responsiveSpringMotion 专为连续手势跟随设计——
//   高频赋值时平滑接管而非重启动画，response 极短近 1:1 实时跟手、不抢手感。
export const SPRING_HEAD_FOLLOW = (): ICurve => curves.responsiveSpringMotion(0.15, 1.0);

// 面板弹性升起/收回
export const SPRING_PANEL_ENTER = (): ICurve => curves.springMotion(0.38, 0.72);
export const SPRING_PANEL_EXIT = (): ICurve => curves.springMotion(0.30, 0.88);

// 交互专用
export const SPRING_SWIPE_RESET = (): ICurve => curves.springMotion(0.35, 0.72);
export const SPRING_CHEVRON = (): ICurve => curves.springMotion(0.22, 0.82);
export const SPRING_FAB_SNAP = (): ICurve => curves.springMotion(0.28, 0.76);
export const SPRING_SEARCH = (): ICurve => curves.springMotion(0.35, 0.82);

// 筛选面板
export const SPRING_FILTER_PRESS = (): ICurve => curves.springMotion(0.18, 0.65);
export const SPRING_FILTER_RELEASE = (): ICurve => curves.springMotion(0.22, 0.62);

// 仪式动画
export const SPRING_CEREMONY_FLIP = (): ICurve => curves.springMotion(0.35, 0.78);
export const SPRING_CEREMONY_DISMISS = (): ICurve => curves.springMotion(0.25, 0.8);

// 上下文菜单/托盘卡片
export const SPRING_CONTEXT_EXIT = (): ICurve => curves.springMotion(0.28, 0.85);
export const SPRING_TRAY_CARD = (): ICurve => curves.springMotion(0.28, 0.72);

// Tab 呼吸/图标
export const SPRING_TAB_BREATHE = (): ICurve => curves.springMotion(0.30, 0.82);
export const SPRING_TAB_ICON = (): ICurve => curves.springMotion(0.28, 0.82);

// ============================================================
// Bezier 曲线 token（仅用于不适合 Spring 的特殊场景）
// ============================================================

export const CURVE_DECELERATE: Curve = Curve.EaseOut;
export const CURVE_STANDARD: ICurve = curves.cubicBezierCurve(0.4, 0.0, 0.2, 1.0);
export const CURVE_LINEAR: Curve = Curve.Linear;

// 长按浮层/菜单专用（spec D-3：浮层弹出/菜单快速出现，无弹性诉求）
export const SHARP_SNAP: Curve = Curve.Sharp;
// 浮层/菜单淡出收场（spec D-3：纯透明度动画，无位移/弹性）
export const EASE_FADE: Curve = Curve.EaseOut;
// 浮层弹出时长
export const DURATION_OVERLAY_ENTER: number = 180;
// 菜单/详情卡淡出时长
export const DURATION_OVERLAY_FADE: number = 120;
// 浮层消失时长
export const DURATION_OVERLAY_DISMISS: number = 150;

// ============================================================
// 时长 (ms)
// ============================================================

// 通用时长
export const DURATION_NONE: number = 0;
export const DURATION_TICK: number = 32;
export const DURATION_FAST: number = 100;
export const DURATION_PRESS: number = 150;
export const DURATION_NORMAL: number = 200;
export const DURATION_HEADER: number = 250;
export const DURATION_RECOVER: number = 280;
export const DURATION_SLOW: number = 300;
export const DURATION_COLOR_FADE: number = 350;
export const DURATION_COUNTER: number = 400;
export const DURATION_GAUGE_COUNTER: number = 800;
export const DURATION_SCROLL_SMOOTH: number = 120;

// 仪式动画专用时长
export const DURATION_CEREMONY_SHAKE: number = 80;
export const DURATION_CEREMONY_STAGGER: number = 150;
export const DURATION_CEREMONY_OVERLAY: number = 300;
export const DURATION_CEREMONY_SHINE: number = 400;
export const DURATION_CHART_DRAW: number = 1200;
export const DURATION_CEREMONY_SHIMMER: number = 1200;

// ============================================================
// 错落入场
// ============================================================

// 加速度曲线错落延迟（涟漪感：首项快、末项慢，400ms 封顶）
export function staggerDelay(index: number, base: number = 30, accel: number = 4, cap: number = 400): number {
  return Math.min(cap, index * base + index * index * accel);
}

// ============================================================
// 缩放/偏移常量
// ============================================================

// 按压三段式
export const PRESS_SCALE_DOWN: number = 0.96;
export const PRESS_SCALE_BOUNCE: number = 1.02;
export const PRESS_SCALE_REST: number = 1.0;

// 面板动画
export const PANEL_SCALE_START: number = 0.9;

// 错落入场偏移 (vp)
export const STAGGER_OFFSET_Y: number = 12;

// D-4：聚焦态背景联动——网格虚化量 (px) + 下沉位移 (vp)。
//   下沉用极小位移制造纵深「退到背后」感；不缩放（网格可滚动，下行展开时前几行可能已滚出视口）。
export const GRID_FOCUS_BLUR: number = 8;
export const GRID_FOCUS_SINK_Y: number = 6;
