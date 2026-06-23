// 通用动画工具 — 封装可复用的动画模式，避免组件重复编写
// 当前保留实际消费的导出：pressHandler, counterAnimate, stopCounterAnimate

import { DURATION_COUNTER } from '../constants/AnimationTokens';

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

// ============================================================
// 数字滚动动画（Counter Animation）
// ============================================================

/**
 * 数字滚动动画驱动。
 * 从 fromValue 平滑过渡到 toValue，每帧调用 onUpdate。
 * 返回 { id } 句柄，可传给 stopCounterAnimate() 取消进行中的动画。
 *
 * 用法：
 *   const handle = counterAnimate(0, 1500, (v: number) => { this.displayWeight = v; })
 *   // 需要取消时：
 *   stopCounterAnimate(handle)
 */
export interface CounterTimerHandle {
  id: number;
}

export function counterAnimate(
  fromValue: number,
  toValue: number,
  onUpdate: (current: number) => void,
  duration: number = DURATION_COUNTER
): CounterTimerHandle {
  const handle: CounterTimerHandle = { id: -1 };
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
      handle.id = setTimeout(tick, 16);
    } else {
      onUpdate(toValue);
      handle.id = -1;
    }
  };

  handle.id = setTimeout(tick, 16);
  return handle;
}

/**
 * 取消一个进行中的数字滚动动画。
 * 传入 counterAnimate 返回的句柄；若 handle 为 undefined 或动画已完成则无操作。
 */
export function stopCounterAnimate(handle: CounterTimerHandle | undefined): void {
  if (handle !== undefined && handle.id >= 0) {
    clearTimeout(handle.id);
    handle.id = -1;
  }
}
