import { PRIMARY_COLOR, LIGHT_PRIMARY_COLOR, PRIMARY_TINT_COLOR, AMBER_TINT, DIVIDER_COLOR } from '../constants/Colors';
import { CATEGORY_FALLBACK } from '../models/PackModels';

export function getGroupColor(group: string): string {
  if (group === '证件') {
    return '#5C6BC0';
  }
  if (group === '穿着·上身') {
    return '#AB47BC';
  }
  if (group === '穿着·下身') {
    return '#7E57C2';
  }
  if (group === '穿着·配件') {
    return '#EC407A';
  }
  if (group === '背负系统') {
    return '#FF7043';
  }
  if (group === '行走系统') {
    return PRIMARY_COLOR;
  }
  if (group === '睡眠系统') {
    return '#26A69A';
  }
  if (group === '饮食系统') {
    return '#FFA726';
  }
  if (group === '电力系统') {
    return '#FFEE58';
  }
  if (group === '摄影系统') {
    return '#42A5F5';
  }
  if (group === '安全急救') {
    return '#EF5350';
  }
  if (group === '清洁洗护') {
    return '#66BB6A';
  }
  if (group === CATEGORY_FALLBACK) {
    return '#BDBDBD';
  }

  let hash = 0;
  for (let index = 0; index < group.length; index++) {
    hash = group.charCodeAt(index) + ((hash << 5) - hash);
  }
  const hue = Math.abs(hash) % 360;
  return hslToHex(hue, 45, 55);
}

/**
 * 将 HSL 颜色值转换为 HEX 格式（ArkUI 仅支持 HEX/RGB，不支持 hsl() 字符串）
 */
function hslToHex(h: number, s: number, l: number): string {
  const sFrac = s / 100;
  const lFrac = l / 100;
  const a = sFrac * Math.min(lFrac, 1 - lFrac);
  const f = (n: number): number => {
    const k = (n + h / 30) % 12;
    return lFrac - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
  };
  const toHex = (x: number): string => {
    const hex = Math.round(x * 255).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  };
  return '#' + toHex(f(0)) + toHex(f(4)) + toHex(f(8));
}

/**
 * 折叠 Header 底部分隔线颜色：alpha 随 progress 0→1 浮现（对齐 iOS Large Title hairline）。
 * progress 在 [0, 0.5) 时全透明，在 [0.5, 1] 线性浮现至 DIVIDER_COLOR 全色。
 */
export function headerBorderColor(progress: number): string {
  const t = progress < 0.5 ? 0 : Math.min(1, (progress - 0.5) * 2);
  const alpha = Math.round(t * 0xFF);
  const hex = alpha < 16 ? '0' + alpha.toString(16).toUpperCase() : alpha.toString(16).toUpperCase();
  return '#' + hex + DIVIDER_COLOR.substring(1);
}

export function heroGradientStart(daysLeft: number | undefined): string {
  if (daysLeft === undefined) {
    return PRIMARY_TINT_COLOR;
  }
  if (daysLeft > 14) {
    return PRIMARY_TINT_COLOR;
  }
  if (daysLeft > 7) {
    return LIGHT_PRIMARY_COLOR;
  }
  if (daysLeft > 3) {
    return '#DCF1E3';
  }
  if (daysLeft >= 0) {
    return AMBER_TINT;
  }
  return LIGHT_PRIMARY_COLOR;
}
