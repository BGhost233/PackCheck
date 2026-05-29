import { curves } from '@kit.ArkUI';

// Spring 曲线预设 — 统一使用 springMotion(response, dampingFraction)
export const SPRING_GENERAL = (): ICurve => curves.springMotion(0.35, 0.8);
export const SPRING_PRESS = (): ICurve => curves.springMotion(0.25, 0.7);
export const SPRING_TAB = (): ICurve => curves.springMotion(0.4, 0.75);
export const SPRING_COUNTER = (): ICurve => curves.springMotion(0.3, 0.75);
export const SPRING_SCROLL = (): ICurve => curves.springMotion(0.45, 0.85);

// 通用时长 (ms) — 用于非 Spring 的辅助动画 (opacity / color)
export const DURATION_FAST = 100;
export const DURATION_NORMAL = 200;
export const DURATION_SLOW = 300;
export const DURATION_COUNTER = 400;
export const DURATION_SCROLL_SMOOTH = 120;
export const DURATION_COLOR_FADE = 350;

// 错落入场延迟 (ms)
export const STAGGER_DELAY_MENU = 30;
export const STAGGER_DELAY_LIST = 40;
export const STAGGER_DELAY_SWIPE = 50;

// 加速度曲线错落延迟（涟漪感：首项快、末项慢，400ms 封顶）
export function staggerDelay(index: number, base: number = 30, accel: number = 4, cap: number = 400): number {
  return Math.min(cap, index * base + index * index * accel);
}

// 按压三段式缩放值
export const PRESS_SCALE_DOWN = 0.96;
export const PRESS_SCALE_BOUNCE = 1.02;
export const PRESS_SCALE_REST = 1.0;

// 共享元素转场 — 卡片展开/收回
export const SPRING_HERO_EXPAND = (): ICurve => curves.springMotion(0.42, 0.73);
export const SPRING_HERO_COLLAPSE = (): ICurve => curves.springMotion(0.36, 0.78);

// 面板弹性升起/收回
export const SPRING_PANEL_ENTER = (): ICurve => curves.springMotion(0.38, 0.72);
export const SPRING_PANEL_EXIT = (): ICurve => curves.springMotion(0.30, 0.88);

// 面板动画
export const PANEL_SCALE_START = 0.9;
export const PANEL_SCALE_DISMISS = 0.95;

// 错落入场偏移 (vp)
export const STAGGER_OFFSET_Y = 12;
