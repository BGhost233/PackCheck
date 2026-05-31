// 通用动画工具 — 封装可复用的动画模式，避免组件重复编写

import { curves } from '@kit.ArkUI';
import {
  SPRING_GENERAL,
  SPRING_PRESS,
  SPRING_HERO_EXPAND,
  SPRING_HERO_COLLAPSE,
  SPRING_PANEL_ENTER,
  SPRING_PANEL_EXIT,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  STAGGER_OFFSET_Y,
  DURATION_NORMAL,
  DURATION_COUNTER,
  DURATION_COLOR_FADE,
  PANEL_SCALE_START
} from '../constants/AnimationTokens';

// ============================================================
// 1. 按压反馈（Press Effect）
// ============================================================

/**
 * 按压态 scale 值计算。
 * 用法：.scale({ x: pressScale(isPressed), y: pressScale(isPressed) })
 */
export function pressScale(isPressed: boolean): number {
  return isPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST;
}

/**
 * 按压态 TouchEvent 处理器工厂。
 * 返回一个 onTouch 回调函数，自动管理 pressed 状态。
 *
 * 用法：
 *   @State pressed: boolean = false;
 *   .onTouch(pressHandler((v: boolean) => { this.pressed = v; }))
 */
export function pressHandler(setter: (pressed: boolean) => void): (event: TouchEvent) => void {
  return (event: TouchEvent) => {
    if (event.type === TouchType.Down) {
      setter(true);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      setter(false);
    }
  };
}

/**
 * 按压动画属性配置。
 * 用法：.animation(pressAnimationOptions())
 */
export function pressAnimationOptions(): AnimateParam {
  return { duration: DURATION_NORMAL, curve: SPRING_PRESS() };
}

// ============================================================
// 2. 列表错落入场（Staggered Entrance）
// ============================================================

/**
 * 错落入场 animation 配置生成。
 * 用法：.animation(staggeredAnimationOptions(index))
 */
export function staggeredAnimationOptions(index: number, base: number = 30, accel: number = 4, cap: number = 400): AnimateParam {
  const delay = Math.min(cap, index * base + index * index * accel);
  return { duration: DURATION_NORMAL + delay, curve: SPRING_GENERAL() };
}

/**
 * 错落入场 translateY 目标值。
 * 用法：.translate({ y: staggeredTranslateY(isReady) })
 */
export function staggeredTranslateY(isEntered: boolean): number {
  return isEntered ? 0 : STAGGER_OFFSET_Y;
}

/**
 * 错落入场 opacity 目标值。
 * 用法：.opacity(staggeredOpacity(isReady))
 */
export function staggeredOpacity(isEntered: boolean): number {
  return isEntered ? 1.0 : 0;
}

// ============================================================
// 3. 数字滚动动画（Counter Animation）
// ============================================================

/**
 * 数字滚动动画驱动。
 * 从 fromValue 平滑过渡到 toValue，每帧调用 onUpdate。
 *
 * 用法：
 *   counterAnimate(0, 1500, (v: number) => { this.displayWeight = v; })
 */
export function counterAnimate(
  fromValue: number,
  toValue: number,
  onUpdate: (current: number) => void,
  duration: number = DURATION_COUNTER
): void {
  const startTime = Date.now();
  const diff = toValue - fromValue;

  const tick = (): void => {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(1.0, elapsed / duration);
    // EaseOut 曲线：1 - (1 - t)^3
    const eased = 1 - Math.pow(1 - progress, 3);
    const current = fromValue + diff * eased;
    onUpdate(current);

    if (progress < 1.0) {
      // 约 60fps
      setTimeout(tick, 16);
    } else {
      onUpdate(toValue);
    }
  };

  tick();
}

// ============================================================
// 4. 面板转场（Panel Transition）
// ============================================================

/**
 * 面板展开动画。
 * 在 animateTo 内调用，驱动面板可见性 + 背景消散。
 *
 * 用法：
 *   panelEnter(() => { this.showPanel = true; })
 */
export function panelEnter(stateUpdater: () => void): void {
  animateTo({ curve: SPRING_PANEL_ENTER() }, stateUpdater);
}

/**
 * 面板收回动画。
 */
export function panelExit(stateUpdater: () => void): void {
  animateTo({ curve: SPRING_PANEL_EXIT() }, stateUpdater);
}

/**
 * 面板背景消散 scale 值。
 * 用法：.scale({ x: panelBgScale(showPanel), y: panelBgScale(showPanel) })
 */
export function panelBgScale(isPanelVisible: boolean): number {
  return isPanelVisible ? PANEL_SCALE_START : PRESS_SCALE_REST;
}

/**
 * 面板背景消散 blur 值。
 * 用法：.blur(panelBgBlur(showPanel))
 */
export function panelBgBlur(isPanelVisible: boolean): number {
  return isPanelVisible ? 12 : 0;
}

// ============================================================
// 5. 共享元素转场（Shared Element Transition）
// ============================================================

/**
 * 共享元素 push 转场。
 * 包装 animateTo + pushPath(animated=false) 的标准模式。
 *
 * 用法：
 *   sharedElementPush(this.navStack, 'DetailPage', { id: item.id })
 */
export function sharedElementPush(
  navStack: NavPathStack,
  name: string,
  param?: object
): void {
  animateTo({ curve: SPRING_HERO_EXPAND() }, () => {
    navStack.pushPath({ name: name, param: param }, false);
  });
}

/**
 * 共享元素 pop 转场。
 *
 * 用法：在 NavDestination 的 .onBackPressed 中调用
 *   sharedElementPop(this.navStack)
 */
export function sharedElementPop(navStack: NavPathStack): void {
  animateTo({ curve: SPRING_HERO_COLLAPSE() }, () => {
    navStack.pop(false);
  });
}

// ============================================================
// 6. 折叠/展开动画（Collapse/Expand）
// ============================================================

/**
 * 通用折叠展开动画包装。
 * 用法：collapseAnimate(() => { this.isExpanded = !this.isExpanded; })
 */
export function collapseAnimate(stateUpdater: () => void): void {
  animateTo({ curve: SPRING_GENERAL() }, stateUpdater);
}

// ============================================================
// 7. 颜色渐变动画配置
// ============================================================

/**
 * 颜色过渡 animation 配置。
 * 用法：.animation(colorFadeOptions())
 */
export function colorFadeOptions(): AnimateParam {
  return { duration: DURATION_COLOR_FADE, curve: Curve.EaseOut };
}

// ============================================================
// 8. 拖拽跟手（Drag Follow）
// ============================================================

/**
 * 拖拽跟手 animation 配置（消除插值延迟）。
 * 用法：浮动拖拽层 .animation(dragFollowOptions())
 */
export function dragFollowOptions(): AnimateParam {
  return { duration: 0 };
}

/**
 * 拖拽松手回弹 animation 配置。
 * 用法：松手归位 animateTo(dragReleaseOptions(), () => { ... })
 */
export function dragReleaseOptions(): AnimateParam {
  return { curve: SPRING_GENERAL() };
}

// ============================================================
// 9. 边缘阻尼（Edge Resistance）
// ============================================================

/**
 * 计算边缘阻尼后的位移值。
 * 当 offset 超出 boundary 时施加 0.3 倍衰减。
 *
 * 用法：
 *   const dampedX = edgeDamping(rawOffset, maxOffset)
 */
export function edgeDamping(offset: number, boundary: number, factor: number = 0.3): number {
  if (Math.abs(offset) <= boundary) {
    return offset;
  }
  const sign = offset > 0 ? 1 : -1;
  const excess = Math.abs(offset) - boundary;
  return sign * (boundary + excess * factor);
}
