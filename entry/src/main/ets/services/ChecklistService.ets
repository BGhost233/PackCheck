import { ChecklistItem, GearItem, makeId, TripChecklist, CATEGORY_FALLBACK } from '../models/PackModels';
import { gearById } from './GearService';

/**
 * 清单相关纯业务逻辑 — 不依赖 UI 上下文
 */

/**
 * 克隆一个 TripChecklist，仅替换其 items 列表，其余字段（meta/profile）原样保留。
 * 用于在不可变更新（toggle/remove/updateItem）中复用清单的完整字段拷贝。
 */
export function cloneChecklistWithItems(source: TripChecklist, items: ChecklistItem[]): TripChecklist {
  return {
    id: source.id,
    title: source.title,
    date: source.date,
    dateAt: source.dateAt,
    items: items,
    createdAt: source.createdAt,
    destination: source.destination,
    distanceKm: source.distanceKm,
    maxAltitude: source.maxAltitude,
    ascentM: source.ascentM,
    durationHours: source.durationHours
  };
}

export function checkedCount(checklist: TripChecklist): number {
  let count = 0;
  for (let index = 0; index < checklist.items.length; index++) {
    if (checklist.items[index].checked) {
      count++;
    }
  }
  return count;
}

export function progressPercent(checklist: TripChecklist): number {
  if (checklist.items.length === 0) {
    return 0;
  }
  return Math.floor(checkedCount(checklist) * 100 / checklist.items.length);
}

export function progressValue(checklist: TripChecklist): number {
  if (checklist.items.length === 0) {
    return 0;
  }
  return checkedCount(checklist);
}

export function progressTotal(checklist: TripChecklist): number {
  if (checklist.items.length === 0) {
    return 1;
  }
  return checklist.items.length;
}

export function progressText(checklist: TripChecklist): string {
  return checkedCount(checklist).toString() + '/' + checklist.items.length.toString();
}

export function checklistMetaText(checklist: TripChecklist): string {
  const progress = progressText(checklist);
  if (checklist.date === undefined || checklist.date.length === 0) {
    return progress;
  }
  return checklist.date + ' · ' + progress;
}

export function isChecklistDone(checklist: TripChecklist): boolean {
  return checklist.items.length > 0 && checkedCount(checklist) === checklist.items.length;
}

// 当日期文本不包含"年"时，默认使用当前年份（适用于"6月15日"这类省略年份的输入）
export function parseTripDateAt(text: string): number | undefined {
  const value = text.trim();
  if (value.length === 0) {
    return undefined;
  }
  const yearIndex = value.indexOf('年');
  let year = new Date().getFullYear();
  let parseFrom = value;
  if (yearIndex > 0) {
    const parsedYear = Number(value.substring(0, yearIndex));
    if (!Number.isNaN(parsedYear)) {
      year = parsedYear;
    }
    parseFrom = value.substring(yearIndex + 1);
  }
  const monthIndex = parseFrom.indexOf('月');
  const dayIndex = parseFrom.indexOf('日');
  if (monthIndex > 0 && dayIndex > monthIndex) {
    const month = Number(parseFrom.substring(0, monthIndex));
    const day = Number(parseFrom.substring(monthIndex + 1, dayIndex));
    if (!Number.isNaN(month) && !Number.isNaN(day)) {
      return new Date(year, month - 1, day).getTime();
    }
  }
  return undefined;
}

export function startOfDay(date: Date): number {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

export function checklistDateAt(checklist: TripChecklist): number | undefined {
  if (checklist.dateAt !== undefined) {
    return checklist.dateAt;
  }
  if (checklist.date !== undefined) {
    return parseTripDateAt(checklist.date);
  }
  return undefined;
}

export function countdownText(checklist: TripChecklist): string {
  const dateAt = checklistDateAt(checklist);
  if (dateAt === undefined) {
    return '';
  }
  const today = startOfDay(new Date());
  const dayDiff = Math.floor((dateAt - today) / 86400000);
  if (dayDiff > 0) {
    return '还有 ' + dayDiff.toString() + ' 天出发';
  }
  if (dayDiff === 0) {
    return '今天出发！';
  }
  return '已出发 ' + Math.abs(dayDiff).toString() + ' 天';
}

/**
 * 「实时引用」模型：有 fromGearId 且 gear 在库 → 实时取 gear 数据；
 * gear 已删（orphaned）→ 降级取 item 快照；无 fromGearId（临时项）→ item 自身。
 */
export function resolveItemName(item: ChecklistItem, gears: GearItem[]): string {
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gearById(gears, item.fromGearId);
    if (gear !== undefined) {
      return gear.name;
    }
  }
  return item.name;
}

/**
 * 性能：resolveItemName 的索引版，用预建的 gearIndex O(1) 反查。
 */
export function resolveItemNameByIndex(item: ChecklistItem, gearIndex: Map<string, GearItem>): string {
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gearIndex.get(item.fromGearId);
    if (gear !== undefined) {
      return gear.name;
    }
  }
  return item.name;
}

export function checklistItemWeight(item: ChecklistItem, gears: GearItem[]): number | undefined {
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gearById(gears, item.fromGearId);
    if (gear !== undefined) {
      return gear.weight;
    }
  }
  return item.weight;
}

export function checklistItemPrice(item: ChecklistItem, gears: GearItem[]): number | undefined {
  if (item.fromGearId !== undefined && item.fromGearId.length > 0) {
    const gear = gearById(gears, item.fromGearId);
    if (gear !== undefined) {
      return gear.price;
    }
  }
  return item.price;
}

export function checklistTotalWeight(checklist: TripChecklist, gears: GearItem[]): number {
  let total = 0;
  for (let index = 0; index < checklist.items.length; index++) {
    const weight = checklistItemWeight(checklist.items[index], gears);
    if (weight !== undefined) {
      total += weight;
    }
  }
  return total;
}

export function formatTripDate(date: Date): string {
  return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日';
}

export function formatDateText(timestamp: number): string {
  const date = new Date(timestamp);
  return date.getFullYear().toString() + '-' + (date.getMonth() + 1).toString() + '-' + date.getDate().toString();
}

export function numberInputText(value: number | undefined): string {
  return value === undefined ? '' : value.toString();
}

function isChecklistItemInGear(item: ChecklistItem): boolean {
  return item.fromGearId !== undefined && item.fromGearId.length > 0;
}

export function hasGearMarker(item: ChecklistItem): boolean {
  return isChecklistItemInGear(item);
}

/**
 * 找到最相关的行程：优先最近的未来行程，其次最近的过去行程，最后按创建时间取最新。
 */
export function findLatestChecklist(checklists: TripChecklist[]): TripChecklist | undefined {
  if (checklists.length === 0) {
    return undefined;
  }
  const today = startOfDay(new Date());
  let nearestFuture: TripChecklist | undefined = undefined;
  let nearestFutureDate: number = Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < checklists.length; i++) {
    const dateAt = checklistDateAt(checklists[i]);
    if (dateAt !== undefined && dateAt >= today) {
      if (dateAt < nearestFutureDate) {
        nearestFutureDate = dateAt;
        nearestFuture = checklists[i];
      }
    }
  }
  if (nearestFuture !== undefined) {
    return nearestFuture;
  }
  let latestPast: TripChecklist | undefined = undefined;
  let latestPastDate: number = -1;
  for (let i = 0; i < checklists.length; i++) {
    const dateAt = checklistDateAt(checklists[i]);
    if (dateAt !== undefined && dateAt < today) {
      if (dateAt > latestPastDate) {
        latestPastDate = dateAt;
        latestPast = checklists[i];
      }
    }
  }
  if (latestPast !== undefined) {
    return latestPast;
  }
  return checklists[0];
}

export function addItemsToChecklist(checklists: TripChecklist[], checklistId: string, items: ChecklistItem[]): TripChecklist[] {
  const nextChecklists: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const checklist = checklists[index];
    if (checklist.id === checklistId) {
      const nextItems: ChecklistItem[] = [];
      for (let itemIndex = 0; itemIndex < checklist.items.length; itemIndex++) {
        nextItems.push(checklist.items[itemIndex]);
      }
      for (let newIndex = 0; newIndex < items.length; newIndex++) {
        nextItems.push(items[newIndex]);
      }
      const updated: TripChecklist = {
        id: checklist.id,
        title: checklist.title,
        date: checklist.date,
        dateAt: checklist.dateAt,
        items: nextItems,
        createdAt: checklist.createdAt,
        destination: checklist.destination,
        distanceKm: checklist.distanceKm,
        maxAltitude: checklist.maxAltitude,
        ascentM: checklist.ascentM,
        durationHours: checklist.durationHours
      };
      nextChecklists.push(updated);
    } else {
      nextChecklists.push(checklist);
    }
  }
  return nextChecklists;
}

/**
 * 从装备列表中按 ID 筛选，生成 ChecklistItem 数组。
 * @param zone 可选，指定装备归属的 BodyZone 枚举值。
 */
export function buildItemsFromGears(gears: GearItem[], gearIds: string[], zone?: string): ChecklistItem[] {
  const items: ChecklistItem[] = [];
  for (let gearIndex = 0; gearIndex < gears.length; gearIndex++) {
    const gear = gears[gearIndex];
    if (gearIds.indexOf(gear.id) >= 0) {
      const item: ChecklistItem = {
        id: makeId('item'),
        name: gear.name,
        group: (zone !== undefined && zone.length > 0) ? zone : gear.category,
        checked: false,
        weight: gear.weight,
        price: gear.price,
        fromGearId: gear.id
      };
      items.push(item);
    }
  }
  return items;
}

/**
 * 在 checklists 头部插入新建的 checklist，返回新数组。
 */
export function prependChecklist(checklists: TripChecklist[], created: TripChecklist): TripChecklist[] {
  const result: TripChecklist[] = [created];
  for (let index = 0; index < checklists.length; index++) {
    result.push(checklists[index]);
  }
  return result;
}

export function matchingGearForChecklistItem(item: ChecklistItem, gears: GearItem[]): GearItem | undefined {
  const name = item.name.trim();
  const group = item.group.trim().length === 0 ? CATEGORY_FALLBACK : item.group.trim();
  for (let index = 0; index < gears.length; index++) {
    const gear = gears[index];
    if (gear.name.trim() === name && gear.category.trim() === group) {
      return gear;
    }
  }
  return undefined;
}

// ─── Checklist Mutation 纯函数 ─────────────────────────────────────────

/**
 * 翻转指定 checklist 中指定 item 的 checked 状态，返回新数组。
 */
export function toggleItemInChecklists(checklists: TripChecklist[], checklistId: string, itemId: string): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const source = checklists[index];
    if (source.id === checklistId) {
      const nextItems: ChecklistItem[] = [];
      for (let itemIndex = 0; itemIndex < source.items.length; itemIndex++) {
        const item = source.items[itemIndex];
        if (item.id === itemId) {
          const updated: ChecklistItem = {
            id: item.id,
            name: item.name,
            group: item.group,
            checked: !item.checked,
            weight: item.weight,
            price: item.price,
            fromGearId: item.fromGearId
          };
          nextItems.push(updated);
        } else {
          nextItems.push(item);
        }
      }
      result.push(cloneChecklistWithItems(source, nextItems));
    } else {
      result.push(source);
    }
  }
  return result;
}

/**
 * 从指定 checklist 中删除指定 item，返回新数组。
 */
export function removeItemFromChecklists(checklists: TripChecklist[], checklistId: string, itemId: string): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const source = checklists[index];
    if (source.id === checklistId) {
      const nextItems = source.items.filter((item: ChecklistItem) => item.id !== itemId);
      result.push(cloneChecklistWithItems(source, nextItems));
    } else {
      result.push(source);
    }
  }
  return result;
}

/**
 * 更新指定 checklist 的元信息（title/date/dateAt + 可选 profile 字段），返回新数组。
 */
export function updateChecklistMeta(checklists: TripChecklist[], checklistId: string,
  title: string, date: string | undefined, dateAt: number | undefined,
  profile?: TripProfileUpdate): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const source = checklists[index];
    if (source.id === checklistId) {
      const updated: TripChecklist = {
        id: source.id,
        title: title,
        date: date,
        dateAt: dateAt,
        items: source.items,
        createdAt: source.createdAt,
        destination: profile !== undefined ? profile.destination : source.destination,
        distanceKm: profile !== undefined ? profile.distanceKm : source.distanceKm,
        maxAltitude: profile !== undefined ? profile.maxAltitude : source.maxAltitude,
        ascentM: profile !== undefined ? profile.ascentM : source.ascentM,
        durationHours: profile !== undefined ? profile.durationHours : source.durationHours
      };
      result.push(updated);
    } else {
      result.push(source);
    }
  }
  return result;
}

export interface TripProfileUpdate {
  destination?: string;
  distanceKm?: number;
  maxAltitude?: number;
  ascentM?: number;
  durationHours?: number;
}

/**
 * 更新指定 checklist 中指定 item 的字段，返回新数组。
 */
export function updateItemFields(checklists: TripChecklist[], checklistId: string, itemId: string,
  name: string, group: string, fromGearId: string | undefined, updateGearId: boolean,
  weight: number | undefined, price: number | undefined, updateMetrics: boolean): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const source = checklists[index];
    if (source.id === checklistId) {
      const nextItems: ChecklistItem[] = [];
      for (let itemIndex = 0; itemIndex < source.items.length; itemIndex++) {
        const item = source.items[itemIndex];
        if (item.id === itemId) {
          const updatedItem: ChecklistItem = {
            id: item.id,
            name: name,
            group: group,
            checked: item.checked,
            weight: updateMetrics ? weight : item.weight,
            price: updateMetrics ? price : item.price,
            fromGearId: updateGearId ? fromGearId : item.fromGearId
          };
          nextItems.push(updatedItem);
        } else {
          nextItems.push(item);
        }
      }
      result.push(cloneChecklistWithItems(source, nextItems));
    } else {
      result.push(source);
    }
  }
  return result;
}
