// 配装系统业务逻辑（纯函数，无 UI）
// 职责：槽位分配、分组、排序、进度计算、旧数据推断

import { BodyZone, LayerOrder, SlotHint, CATEGORY_SLOT_MAP, slotHintForCategory } from '../constants/GearLoadout';
import { ChecklistItem, GearItem } from '../models/PackModels';

// ============================================================
// 槽位分配
// ============================================================

/** 给定装备，返回应落入的 Zone + Layer */
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

/** 按 LayerOrder 升序排序（同层保持原序） */
export function sortItemsByLayer(items: ChecklistItem[], gears: GearItem[]): ChecklistItem[] {
  return items.slice().sort((a, b) => {
    const layerA = getLayerForItem(a, gears);
    const layerB = getLayerForItem(b, gears);
    return layerA - layerB;
  });
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
