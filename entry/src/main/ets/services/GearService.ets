import {
  GEAR_SORT_GROUP,
  GEAR_SORT_PRICE,
  GEAR_SORT_TIME,
  GEAR_SORT_TRIP_COUNT,
  GEAR_SORT_VALUE,
  GEAR_SORT_WEIGHT
} from '../constants/DesignTokens';
import { CATEGORY_ALL, DEFAULT_CATEGORIES, GearItem, makeId } from '../models/PackModels';

/**
 * 装备相关纯业务逻辑 — 不依赖 UI 上下文
 */

export function numberOrZero(value: number | undefined): number {
  return value === undefined ? 0 : value;
}

// ─── GearItem 工厂 ───────────────────────────────────────────

export interface CreateGearParams {
  name: string;
  category: string;
  weight?: number;
  price?: number;
  note?: string;
  brand?: string;
  acquiredAt?: number;
}

/** 新建装备：统一分配 id + createdAt */
export function createGear(params: CreateGearParams): GearItem {
  return {
    id: makeId('gear'),
    name: params.name,
    category: params.category,
    weight: params.weight,
    price: params.price,
    note: params.note,
    createdAt: Date.now(),
    brand: params.brand,
    acquiredAt: params.acquiredAt
  };
}

export interface UpdateGearFields {
  name?: string;
  category?: string;
  weight?: number;
  price?: number;
  note?: string;
  brand?: string;
  acquiredAt?: number;
}

/** 更新装备字段：保留未指定字段 */
export function updateGear(existing: GearItem, fields: UpdateGearFields): GearItem {
  return {
    id: existing.id,
    name: fields.name !== undefined ? fields.name : existing.name,
    category: fields.category !== undefined ? fields.category : existing.category,
    weight: fields.weight !== undefined ? fields.weight : existing.weight,
    price: fields.price !== undefined ? fields.price : existing.price,
    note: fields.note !== undefined ? fields.note : existing.note,
    createdAt: existing.createdAt,
    brand: fields.brand !== undefined ? fields.brand : existing.brand,
    acquiredAt: fields.acquiredAt !== undefined ? fields.acquiredAt : existing.acquiredAt
  };
}

export function gearValueRatio(item: GearItem): number {
  if (item.price === undefined || item.weight === undefined || item.weight <= 0) {
    return 0;
  }
  return item.price / item.weight;
}

export function sortedGears(items: GearItem[], sortMode: string): GearItem[] {
  const sorted: GearItem[] = [];
  for (let index = 0; index < items.length; index++) {
    sorted.push(items[index]);
  }
  sorted.sort((left: GearItem, right: GearItem): number => {
    if (sortMode === GEAR_SORT_PRICE) {
      return numberOrZero(right.price) - numberOrZero(left.price);
    }
    if (sortMode === GEAR_SORT_WEIGHT) {
      return numberOrZero(right.weight) - numberOrZero(left.weight);
    }
    if (sortMode === GEAR_SORT_TIME) {
      return right.createdAt - left.createdAt;
    }
    if (sortMode === GEAR_SORT_VALUE) {
      return gearValueRatio(right) - gearValueRatio(left);
    }
    if (sortMode === GEAR_SORT_TRIP_COUNT) {
      // trip count 排序由 GearPage 自行处理（查 gearTripCountMap），此处 fallback 为按时间
      return right.createdAt - left.createdAt;
    }
    if (left.category === right.category) {
      return right.createdAt - left.createdAt;
    }
    return left.category.localeCompare(right.category);
  });
  return sorted;
}

export function filterGears(gears: GearItem[], keyword: string, activeCategories: string[], sortMode: string): GearItem[] {
  const filtered: GearItem[] = [];
  const lowerKeyword = keyword.trim().toLowerCase();
  const showAllCategories = activeCategories.indexOf(CATEGORY_ALL) >= 0;
  for (let index = 0; index < gears.length; index++) {
    const item = gears[index];
    const categoryMatched = showAllCategories || activeCategories.indexOf(item.category) >= 0;
    const note = item.note === undefined ? '' : item.note;
    const keywordMatched = lowerKeyword.length === 0 ||
      item.name.toLowerCase().indexOf(lowerKeyword) >= 0 ||
      item.category.toLowerCase().indexOf(lowerKeyword) >= 0 ||
      note.toLowerCase().indexOf(lowerKeyword) >= 0;
    if (categoryMatched && keywordMatched) {
      filtered.push(item);
    }
  }
  return sortedGears(filtered, sortMode);
}

export function normalizeGearCategories(categories: string[]): string[] {
  if (categories.length === 0 || categories.indexOf(CATEGORY_ALL) >= 0) {
    return [CATEGORY_ALL];
  }
  const normalized: string[] = [];
  for (let index = 0; index < categories.length; index++) {
    const category = categories[index];
    if (category.length > 0 && normalized.indexOf(category) < 0) {
      normalized.push(category);
    }
  }
  if (normalized.length === 0) {
    return [CATEGORY_ALL];
  }
  return normalized;
}

export function allGearFilterCategories(userCategories: string[]): string[] {
  const result: string[] = [CATEGORY_ALL];
  for (let index = 0; index < DEFAULT_CATEGORIES.length; index++) {
    result.push(DEFAULT_CATEGORIES[index]);
  }
  for (let index = 0; index < userCategories.length; index++) {
    if (result.indexOf(userCategories[index]) < 0) {
      result.push(userCategories[index]);
    }
  }
  return result;
}

export function gearCategoryCount(gears: GearItem[], category: string): number {
  if (category === CATEGORY_ALL) {
    return gears.length;
  }
  let count = 0;
  for (let index = 0; index < gears.length; index++) {
    if (gears[index].category === category) {
      count++;
    }
  }
  return count;
}

export function gearSortLabel(sortMode: string): string {
  if (sortMode === GEAR_SORT_PRICE) {
    return '按价格';
  }
  if (sortMode === GEAR_SORT_WEIGHT) {
    return '按重量';
  }
  if (sortMode === GEAR_SORT_TIME) {
    return '按添加时间';
  }
  if (sortMode === GEAR_SORT_VALUE) {
    return '按克单价';
  }
  if (sortMode === GEAR_SORT_TRIP_COUNT) {
    return '按出行次数';
  }
  return '按分组';
}

export function filteredGearGroups(gears: GearItem[], keyword: string, activeCategories: string[], sortMode: string): string[] {
  const items = filterGears(gears, keyword, activeCategories, sortMode);
  const groups: string[] = [];
  for (let index = 0; index < items.length; index++) {
    const group = sortMode === GEAR_SORT_GROUP ? items[index].category : gearSortLabel(sortMode);
    if (groups.indexOf(group) < 0) {
      groups.push(group);
    }
  }
  return groups;
}

export function filteredGearsByGroup(gears: GearItem[], keyword: string, activeCategories: string[], sortMode: string, group: string): GearItem[] {
  const items = filterGears(gears, keyword, activeCategories, sortMode);
  if (sortMode !== GEAR_SORT_GROUP) {
    return items;
  }
  return items.filter((item: GearItem) => item.category === group);
}

export function totalGearWeight(gears: GearItem[]): number {
  let total = 0;
  for (let index = 0; index < gears.length; index++) {
    total += numberOrZero(gears[index].weight);
  }
  return total;
}

export function totalGearPrice(gears: GearItem[]): number {
  let total = 0;
  for (let index = 0; index < gears.length; index++) {
    total += numberOrZero(gears[index].price);
  }
  return total;
}

export function averageGearValueRatio(gears: GearItem[]): number {
  let totalPrice = 0;
  let totalWeight = 0;
  for (let index = 0; index < gears.length; index++) {
    if (gears[index].price !== undefined && gears[index].weight !== undefined) {
      totalPrice += numberOrZero(gears[index].price);
      totalWeight += numberOrZero(gears[index].weight);
    }
  }
  if (totalWeight <= 0) {
    return 0;
  }
  return Math.round(totalPrice * 100 / totalWeight) / 100;
}

export function heaviestGearText(gears: GearItem[]): string {
  let item: GearItem | undefined = undefined;
  for (let index = 0; index < gears.length; index++) {
    if (gears[index].weight !== undefined &&
      (item === undefined || numberOrZero(gears[index].weight) > numberOrZero(item.weight))) {
      item = gears[index];
    }
  }
  if (item === undefined || item.weight === undefined) {
    return '暂无';
  }
  return item.name + ' (' + item.weight.toString() + 'g)';
}

export function mostExpensiveGearText(gears: GearItem[]): string {
  let item: GearItem | undefined = undefined;
  for (let index = 0; index < gears.length; index++) {
    if (gears[index].price !== undefined &&
      (item === undefined || numberOrZero(gears[index].price) > numberOrZero(item.price))) {
      item = gears[index];
    }
  }
  if (item === undefined || item.price === undefined) {
    return '暂无';
  }
  return item.name + ' (¥' + item.price.toString() + ')';
}

export function mostFrequentGearText(gears: GearItem[], tripCountMap: Map<string, number>): string {
  let item: GearItem | undefined = undefined;
  let maxCount = 0;
  for (let index = 0; index < gears.length; index++) {
    const count = tripCountMap.get(gears[index].id) ?? 0;
    if (count > maxCount) {
      maxCount = count;
      item = gears[index];
    }
  }
  return item === undefined ? '暂无' : item.name + ' (×' + maxCount.toString() + '次)';
}

export function formatKg(weightGram: number): string {
  if (weightGram <= 0) {
    return '0kg';
  }
  const kg = weightGram / 1000;
  if (kg >= 10) {
    return Math.round(kg).toString() + 'kg';
  }
  return (Math.round(kg * 100) / 100).toString() + 'kg';
}

export function gearStatsText(gears: GearItem[]): string {
  return gears.length.toString() + ' 件 · ' + formatKg(totalGearWeight(gears)) +
    ' · ¥' + totalGearPrice(gears).toString();
}

export function gearById(gears: GearItem[], id: string): GearItem | undefined {
  for (let index = 0; index < gears.length; index++) {
    if (gears[index].id === id) {
      return gears[index];
    }
  }
  return undefined;
}

/**
 * 性能：构建 gearId → GearItem 索引，供渲染热路径 O(1) 反查，
 * 替代在 ForEach 每行调用 gearById 的 O(items × gears) 线性扫描。
 * 用法对齐 buildGearTripCountMap：消费组件 @Watch('gears') 时刷新一次缓存。
 */
export function buildGearIndex(gears: GearItem[]): Map<string, GearItem> {
  const map = new Map<string, GearItem>();
  for (let index = 0; index < gears.length; index++) {
    map.set(gears[index].id, gears[index]);
  }
  return map;
}

export function presetCategories(userCategories: string[]): string[] {
  const nextCategories: string[] = [];
  for (let index = 0; index < DEFAULT_CATEGORIES.length; index++) {
    nextCategories.push(DEFAULT_CATEGORIES[index]);
  }
  for (let index = 0; index < userCategories.length; index++) {
    if (nextCategories.indexOf(userCategories[index]) < 0) {
      nextCategories.push(userCategories[index]);
    }
  }
  return nextCategories;
}

export function categoryTabs(userCategories: string[]): string[] {
  return allGearFilterCategories(userCategories);
}

export function uniqueGearIds(ids: string[]): string[] {
  const dedupedIds: string[] = [];
  for (let index = 0; index < ids.length; index++) {
    if (ids[index].length > 0 && dedupedIds.indexOf(ids[index]) < 0) {
      dedupedIds.push(ids[index]);
    }
  }
  return dedupedIds;
}

export function importGearMetaText(item: GearItem): string {
  let text = '';
  if (item.weight !== undefined) {
    text = text + item.weight.toString() + 'g';
  }
  if (item.price !== undefined) {
    if (text.length > 0) {
      text = text + '  ';
    }
    text = text + '¥' + item.price.toString();
  }
  return text;
}

export function filteredImportGears(gears: GearItem[], category: string): GearItem[] {
  if (category === CATEGORY_ALL) {
    return gears;
  }
  return gears.filter((item: GearItem) => item.category === category);
}

export function tempGearFilterText(categories: string[]): string {
  const normalized = normalizeGearCategories(categories);
  if (normalized.indexOf(CATEGORY_ALL) >= 0) {
    return CATEGORY_ALL;
  }
  if (normalized.length === 1) {
    return normalized[0];
  }
  if (normalized.length === 2) {
    return normalized[0] + ' +1';
  }
  return normalized.length.toString() + '个分组';
}

