// 配装系统业务逻辑（纯函数，无 UI）
// 职责：分组、进度计算、Zone推断、色彩映射、拖拽命中检测

import { BodyZone, CATEGORY_SLOT_MAP } from '../constants/GearLoadout';
import { ChecklistItem } from '../models/PackModels';
import {
  TEXT_SECONDARY,
  ZONE_HEAD_COLOR, ZONE_UPPER_COLOR, ZONE_LOWER_COLOR, ZONE_FEET_COLOR, ZONE_CARRY_COLOR, ZONE_SLEEP_COLOR, ZONE_MISC_COLOR,
  ZONE_HEAD_TINT, ZONE_UPPER_TINT, ZONE_LOWER_TINT, ZONE_FEET_TINT, ZONE_CARRY_TINT, ZONE_SLEEP_TINT, ZONE_MISC_TINT,
  ZONE_HEAD_FILL, ZONE_UPPER_FILL, ZONE_LOWER_FILL, ZONE_FEET_FILL, ZONE_CARRY_FILL, ZONE_SLEEP_FILL, ZONE_MISC_FILL,
  ZONE_HEAD_FOCUS_BG, ZONE_UPPER_FOCUS_BG, ZONE_LOWER_FOCUS_BG, ZONE_FEET_FOCUS_BG, ZONE_CARRY_FOCUS_BG, ZONE_SLEEP_FOCUS_BG, ZONE_MISC_FOCUS_BG,
  ZONE_HEAD_STROKE, ZONE_UPPER_STROKE, ZONE_LOWER_STROKE, ZONE_FEET_STROKE, ZONE_CARRY_STROKE, ZONE_SLEEP_STROKE, ZONE_MISC_STROKE
} from '../constants/Colors';

// ============================================================
// 分组
// ============================================================

const ZONE_ORDER: string[] = [
  BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
  BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
];

/**
 * 按 Zone 分组，始终返回全部 7 个 Zone（含空数组）。
 * 统一清单视图（网格态）用：7 格子始终可见，空 Zone 渲染空态虚线格。
 * 顺序固定为人体从上到下（杂项末尾）。spec §4.4。
 * 性能优化：单次遍历 O(N) 代替原 7×filter O(7N)。
 */
export function groupByZoneAll(items: ChecklistItem[]): Map<string, ChecklistItem[]> {
  const map = new Map<string, ChecklistItem[]>();
  // 预初始化全部 zone 为空数组（保证遍历顺序 = 插入顺序）
  for (const zone of ZONE_ORDER) {
    map.set(zone, []);
  }
  // 单次遍历分桶
  for (let i = 0; i < items.length; i++) {
    const zone = inferZoneFromGroup(items[i].group);
    const bucket = map.get(zone);
    if (bucket !== undefined) {
      bucket.push(items[i]);
    } else {
      // 未知 zone 归入 Misc
      map.get(BodyZone.Misc)!.push(items[i]);
    }
  }
  return map;
}

// ============================================================
// 进度
// ============================================================

export interface LoadoutProgress {
  checked: number;
  total: number;
}

/** 计算勾选进度 */
export function calcProgress(items: ChecklistItem[]): LoadoutProgress {
  const total = items.length;
  let checked = 0;
  for (const item of items) {
    if (item.checked) {
      checked++;
    }
  }
  return { checked, total };
}

// ============================================================
// 旧数据推断
// ============================================================

/** 将 group 字段推断为 BodyZone（旧数据兼容） */
function inferZoneFromGroup(group: string): string {
  // 如果 group 已经是 BodyZone 枚举值，直接返回
  const validZones: string[] = [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
  if (validZones.indexOf(group) >= 0) {
    return group;
  }
  // 优先精确匹配 CATEGORY_SLOT_MAP（品类名 → Zone）
  const hint = CATEGORY_SLOT_MAP[group];
  if (hint !== undefined) {
    return hint.zone;
  }
  // 旧数据模糊推断：根据分组文本猜测 Zone
  if (group.indexOf('上身') >= 0 || group.indexOf('上装') >= 0) {
    return BodyZone.UpperBody;
  }
  if (group.indexOf('下身') >= 0 || group.indexOf('下装') >= 0 || group.indexOf('裤') >= 0) {
    return BodyZone.LowerBody;
  }
  if (group.indexOf('头') >= 0 || group.indexOf('帽') >= 0 || group.indexOf('配件') >= 0) {
    return BodyZone.Head;
  }
  if (group.indexOf('脚') >= 0 || group.indexOf('鞋') >= 0 || group.indexOf('行走') >= 0) {
    return BodyZone.Feet;
  }
  if (group.indexOf('背') >= 0 || group.indexOf('包') >= 0 || group.indexOf('背负') >= 0) {
    return BodyZone.Carry;
  }
  if (group.indexOf('睡') >= 0 || group.indexOf('帐') >= 0) {
    return BodyZone.Sleep;
  }
  // 兜底
  return BodyZone.Misc;
}

/** Zone 枚举值 → 中文显示名 */
export function zoneDisplayName(zone: string): string {
  if (zone === BodyZone.Head) {
    return '头部';
  }
  if (zone === BodyZone.UpperBody) {
    return '上身';
  }
  if (zone === BodyZone.LowerBody) {
    return '下身';
  }
  if (zone === BodyZone.Feet) {
    return '脚部';
  }
  if (zone === BodyZone.Carry) {
    return '背负';
  }
  if (zone === BodyZone.Sleep) {
    return '睡眠';
  }
  if (zone === BodyZone.Misc) {
    return '杂项';
  }
  return zone;
}

// ============================================================
// Zone 色彩映射（权威实现，UI 层统一调用，禁止在组件内重写 switch）
// ============================================================

/** Zone → 主题彩色（标题文字 / 强调色）。未知 zone 兜底 TEXT_SECONDARY。 */
export function zoneColor(zone: string): string {
  if (zone === BodyZone.Head) { return ZONE_HEAD_COLOR; }
  if (zone === BodyZone.UpperBody) { return ZONE_UPPER_COLOR; }
  if (zone === BodyZone.LowerBody) { return ZONE_LOWER_COLOR; }
  if (zone === BodyZone.Feet) { return ZONE_FEET_COLOR; }
  if (zone === BodyZone.Carry) { return ZONE_CARRY_COLOR; }
  if (zone === BodyZone.Sleep) { return ZONE_SLEEP_COLOR; }
  if (zone === BodyZone.Misc) { return ZONE_MISC_COLOR; }
  return TEXT_SECONDARY;
}

/** Zone → 整块淡色填充底（便单式色块）。未知 zone 兜底 MISC。 */
export function zoneFill(zone: string): string {
  if (zone === BodyZone.Head) { return ZONE_HEAD_FILL; }
  if (zone === BodyZone.UpperBody) { return ZONE_UPPER_FILL; }
  if (zone === BodyZone.LowerBody) { return ZONE_LOWER_FILL; }
  if (zone === BodyZone.Feet) { return ZONE_FEET_FILL; }
  if (zone === BodyZone.Carry) { return ZONE_CARRY_FILL; }
  if (zone === BodyZone.Sleep) { return ZONE_SLEEP_FILL; }
  if (zone === BodyZone.Misc) { return ZONE_MISC_FILL; }
  return ZONE_MISC_FILL;
}

/** Zone → 聚焦态不透明实心淡色底（白底掺彩）。未知 zone 兜底 MISC。 */
export function zoneFocusBg(zone: string): string {
  if (zone === BodyZone.Head) { return ZONE_HEAD_FOCUS_BG; }
  if (zone === BodyZone.UpperBody) { return ZONE_UPPER_FOCUS_BG; }
  if (zone === BodyZone.LowerBody) { return ZONE_LOWER_FOCUS_BG; }
  if (zone === BodyZone.Feet) { return ZONE_FEET_FOCUS_BG; }
  if (zone === BodyZone.Carry) { return ZONE_CARRY_FOCUS_BG; }
  if (zone === BodyZone.Sleep) { return ZONE_SLEEP_FOCUS_BG; }
  if (zone === BodyZone.Misc) { return ZONE_MISC_FOCUS_BG; }
  return ZONE_MISC_FOCUS_BG;
}

/** Zone → 容器描边色（饱和度分档）。未知 zone 兜底 MISC。 */
export function zoneStroke(zone: string): string {
  if (zone === BodyZone.Head) { return ZONE_HEAD_STROKE; }
  if (zone === BodyZone.UpperBody) { return ZONE_UPPER_STROKE; }
  if (zone === BodyZone.LowerBody) { return ZONE_LOWER_STROKE; }
  if (zone === BodyZone.Feet) { return ZONE_FEET_STROKE; }
  if (zone === BodyZone.Carry) { return ZONE_CARRY_STROKE; }
  if (zone === BodyZone.Sleep) { return ZONE_SLEEP_STROKE; }
  if (zone === BodyZone.Misc) { return ZONE_MISC_STROKE; }
  return ZONE_MISC_STROKE;
}

/** 所有 BodyZone 枚举值列表（固定顺序） */
export function allZones(): string[] {
  return [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
}

/**
 * 拖拽命中检测：给定手指全局坐标，返回命中的 zone，无命中返回 null。
 *   纯几何计算，坐标系无关。
 */
export function hitTestZoneRect(
  zoneRects: Map<string, number[]>,
  candidateZones: string[],
  globalX: number,
  globalY: number,
  overlayOriginX: number,
  overlayOriginY: number
): string | null {
  const localX = globalX - overlayOriginX;
  const localY = globalY - overlayOriginY;
  for (let i = 0; i < candidateZones.length; i++) {
    const zone = candidateZones[i];
    const rect = zoneRects.get(zone);
    if (rect === undefined) {
      continue;
    }
    const rx = rect[0] - overlayOriginX;
    const ry = rect[1] - overlayOriginY;
    const rw = rect[2];
    const rh = rect[3];
    if (localX >= rx && localX <= rx + rw && localY >= ry && localY <= ry + rh) {
      return zone;
    }
  }
  return null;
}
