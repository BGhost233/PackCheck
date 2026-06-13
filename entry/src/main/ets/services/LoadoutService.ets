// 配装系统业务逻辑（纯函数，无 UI）
// 职责：槽位分配、分组、排序、进度计算、旧数据推断

import { BodyZone, LayerOrder, SlotHint, CATEGORY_SLOT_MAP, slotHintForCategory } from '../constants/GearLoadout';
import { ChecklistItem, GearItem } from '../models/PackModels';
import {
  TEXT_SECONDARY,
  ZONE_HEAD_COLOR, ZONE_UPPER_COLOR, ZONE_LOWER_COLOR, ZONE_FEET_COLOR, ZONE_CARRY_COLOR, ZONE_SLEEP_COLOR, ZONE_MISC_COLOR,
  ZONE_HEAD_TINT, ZONE_UPPER_TINT, ZONE_LOWER_TINT, ZONE_FEET_TINT, ZONE_CARRY_TINT, ZONE_SLEEP_TINT, ZONE_MISC_TINT,
  ZONE_HEAD_FILL, ZONE_UPPER_FILL, ZONE_LOWER_FILL, ZONE_FEET_FILL, ZONE_CARRY_FILL, ZONE_SLEEP_FILL, ZONE_MISC_FILL,
  ZONE_HEAD_FOCUS_BG, ZONE_UPPER_FOCUS_BG, ZONE_LOWER_FOCUS_BG, ZONE_FEET_FOCUS_BG, ZONE_CARRY_FOCUS_BG, ZONE_SLEEP_FOCUS_BG, ZONE_MISC_FOCUS_BG,
  ZONE_HEAD_STROKE, ZONE_UPPER_STROKE, ZONE_LOWER_STROKE, ZONE_FEET_STROKE, ZONE_CARRY_STROKE, ZONE_SLEEP_STROKE, ZONE_MISC_STROKE
} from '../constants/Colors';

// ============================================================
// 槽位分配
// ============================================================

/**
 * @deprecated 新流程已不再使用品类→Zone自动映射。
 * 用户通过点击格子选择装备，Zone 由 buildItemsFromGears 的 zone 参数直接指定。
 * 保留仅为旧数据兼容（旧版本创建的 item 可能依赖此推断）。
 */
export function assignSlot(gear: GearItem): SlotHint {
  return slotHintForCategory(gear.category);
}

// ============================================================
// 分组
// ============================================================

/** 按 Zone 分组（跳过空 Zone），返回有序 Map */
export function groupByZone(items: ChecklistItem[]): Map<string, ChecklistItem[]> {
  const map = new Map<string, ChecklistItem[]>();
  // 按固定顺序初始化（保证遍历顺序）
  const zoneOrder: string[] = [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
  for (const zone of zoneOrder) {
    const zoneItems = items.filter((item) => inferZoneFromGroup(item.group) === zone);
    if (zoneItems.length > 0) {
      map.set(zone, zoneItems);
    }
  }
  return map;
}

/**
 * 按 Zone 分组，始终返回全部 7 个 Zone（含空数组）。
 * 统一清单视图（网格态）用：7 格子始终可见，空 Zone 渲染空态虚线格。
 * 顺序固定为人体从上到下（杂项末尾）。spec §4.4。
 */
export function groupByZoneAll(items: ChecklistItem[]): Map<string, ChecklistItem[]> {
  const map = new Map<string, ChecklistItem[]>();
  const zoneOrder: string[] = [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
  for (const zone of zoneOrder) {
    const zoneItems = items.filter((item) => inferZoneFromGroup(item.group) === zone);
    map.set(zone, zoneItems);
  }
  return map;
}

/** Misc Zone 内部按品类分子组 */
export function groupMiscByCategory(items: ChecklistItem[], gears: GearItem[]): Map<string, ChecklistItem[]> {
  const map = new Map<string, ChecklistItem[]>();
  for (const item of items) {
    const categoryName = getCategoryForItem(item, gears);
    const existing = map.get(categoryName);
    if (existing !== undefined) {
      existing.push(item);
    } else {
      map.set(categoryName, [item]);
    }
  }
  return map;
}

// ============================================================
// 排序
// ============================================================

/**
 * @deprecated D-1（spec §3.1）：一期取消「层级」概念。保留签名向后兼容，
 * 内部不再做分层排序，按 items 数组原始顺序（= 添加顺序）恒等返回。
 * 后续积累实际使用数据后再决定是否加回。
 */
export function sortItemsByLayer(items: ChecklistItem[], gears: GearItem[]): ChecklistItem[] {
  return items;
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
export function inferZoneFromGroup(group: string): string {
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

/** 清单视图分组名回译：BodyZone 枚举 → 有意义的中文名 */
export function inferDisplayGroup(item: ChecklistItem, gears: GearItem[]): string {
  const validZones: string[] = [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
  // 如果 group 不是 BodyZone 枚举值（旧格式），直接返回原值
  if (validZones.indexOf(item.group) < 0) {
    return item.group;
  }
  // 有 fromGearId → 查品类名作为显示分组
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gears.find((g) => g.id === item.fromGearId);
    if (gear !== undefined) {
      return gear.category;
    }
  }
  // 临时装备 → Zone 中文名 + (临时)
  return zoneDisplayName(item.group) + '(临时)';
}

// ============================================================
// 层级推导
// ============================================================

/** 获取 item 的 LayerOrder（运行时推导，不持久化） */
export function getLayerForItem(item: ChecklistItem, gears: GearItem[]): number {
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gears.find((g) => g.id === item.fromGearId);
    if (gear !== undefined) {
      const hint = slotHintForCategory(gear.category);
      return hint.layer;
    }
  }
  // 无关联装备 / 装备已删除 → Accessory
  return LayerOrder.Accessory;
}

// ============================================================
// 辅助函数
// ============================================================

/** 获取 item 对应的品类名 */
function getCategoryForItem(item: ChecklistItem, gears: GearItem[]): string {
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gears.find((g) => g.id === item.fromGearId);
    if (gear !== undefined) {
      return gear.category;
    }
  }
  return '其他';
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

/** Zone 枚举值 → 对应 icon 资源名 */
export function zoneIconName(zone: string): string {
  if (zone === BodyZone.Head) {
    return 'sys.symbol.face.smiling';
  }
  if (zone === BodyZone.UpperBody) {
    return 'sys.symbol.tshirt';
  }
  if (zone === BodyZone.LowerBody) {
    return 'sys.symbol.figure.walk';
  }
  if (zone === BodyZone.Feet) {
    return 'sys.symbol.shoeprints.fill';
  }
  if (zone === BodyZone.Carry) {
    return 'sys.symbol.backpack';
  }
  if (zone === BodyZone.Sleep) {
    return 'sys.symbol.tent';
  }
  if (zone === BodyZone.Misc) {
    return 'sys.symbol.square.grid.2x2';
  }
  return 'sys.symbol.questionmark';
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

/** Zone → 中等透明染色（chip / tint 背景）。未知 zone 兜底 MISC。 */
export function zoneTint(zone: string): string {
  if (zone === BodyZone.Head) { return ZONE_HEAD_TINT; }
  if (zone === BodyZone.UpperBody) { return ZONE_UPPER_TINT; }
  if (zone === BodyZone.LowerBody) { return ZONE_LOWER_TINT; }
  if (zone === BodyZone.Feet) { return ZONE_FEET_TINT; }
  if (zone === BodyZone.Carry) { return ZONE_CARRY_TINT; }
  if (zone === BodyZone.Sleep) { return ZONE_SLEEP_TINT; }
  if (zone === BodyZone.Misc) { return ZONE_MISC_TINT; }
  return ZONE_MISC_TINT;
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

/** Layer 枚举值 → 中文显示名 */
export function layerDisplayName(layer: number): string {
  if (layer === LayerOrder.Base) {
    return '贴身';
  }
  if (layer === LayerOrder.Mid) {
    return '保暖';
  }
  if (layer === LayerOrder.Shell) {
    return '防护';
  }
  if (layer === LayerOrder.Insulation) {
    return '隔绝';
  }
  return '配件';
}

/** 所有 BodyZone 枚举值列表（固定顺序） */
export function allZones(): string[] {
  return [
    BodyZone.Head, BodyZone.UpperBody, BodyZone.LowerBody,
    BodyZone.Feet, BodyZone.Carry, BodyZone.Sleep, BodyZone.Misc
  ];
}

/** 所有 LayerOrder 值列表（升序） */
export function allLayers(): number[] {
  return [LayerOrder.Base, LayerOrder.Mid, LayerOrder.Shell, LayerOrder.Insulation, LayerOrder.Accessory];
}

/**
 * 拖拽命中检测：给定手指全局坐标，返回命中的 zone（命中矩形列表中第一个），无命中返回 null。
 *   纯几何计算，与坐标系无关：globalXY 与 zoneRects（全局坐标 [x,y,w,h]）同时减去 overlayOrigin 转局部后比较，
 *   等价于直接在全局坐标系比较，此处保留原 UnifiedChecklistView 的局部坐标语义以确保零行为变更。
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
