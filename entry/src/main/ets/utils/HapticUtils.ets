import { vibrator } from '@kit.SensorServiceKit';

/**
 * 统一触觉反馈工具。
 *
 * 全项目所有 vibrator.startVibration 调用都应经由此处，避免散落的
 * try/catch 样板与不一致的参数。所有方法均静默降级（设备不支持/无权限时不抛错）。
 *
 * 两类底层能力：
 *  - time(duration)        自定义时长震动（type: 'time'）
 *  - preset(effectId, n)   系统预设效果（type: 'preset'）
 *
 * 语义快捷方法（推荐优先使用，表达意图而非参数）：
 *  - light / medium / strong  → 时长档位（轻/中/强）
 *  - tick / soft / sharp      → 系统预设效果档位
 */

// ============================================================
// 底层能力
// ============================================================

/** 自定义时长震动。duration 单位 ms。静默降级。 */
export function hapticTime(duration: number): void {
  try {
    vibrator.startVibration({ type: 'time', duration: duration }, { usage: 'touch' });
  } catch (_e) {
    // 设备不支持 / 无权限：静默降级
  }
}

/** 系统预设效果震动。count 默认 1。静默降级。 */
export function hapticPreset(effectId: string, count: number = 1): void {
  try {
    vibrator.startVibration({ type: 'preset', effectId: effectId, count: count }, { usage: 'touch' });
  } catch (_e) {
    // 设备不支持 / 无权限：静默降级
  }
}

// ============================================================
// 语义快捷方法 —— 时长档位（仅保留实际消费项）
// ============================================================

/** 强触觉（~40ms）：成功释放、重要操作落定。 */
export function hapticStrong(): void {
  hapticTime(40);
}

// ============================================================
// 语义快捷方法 —— 系统预设
// ============================================================

/** soft：柔和反馈，长按拾起 / 选中。 */
export function hapticSoft(): void {
  hapticPreset('haptic.effect.soft', 1);
}

/** sharp：锐利反馈，越界 / 边缘拖出。 */
export function hapticSharp(): void {
  hapticPreset('haptic.effect.sharp', 1);
}
