import {
  GEAR_SORT_GROUP,
  GEAR_SORT_PRICE,
  GEAR_SORT_TIME,
  GEAR_SORT_TRIP_COUNT,
  GEAR_SORT_VALUE,
  GEAR_SORT_WEIGHT
} from '../constants/DesignTokens';
import { DEFAULT_CATEGORIES, GearItem } from '../models/PackModels';

/**
 * 装备相关纯业务逻辑 — 不依赖 UI 上下文
 */

export function numberOrZero(value: number | undefined): number {
  return value === undefined ? 0 : value;
}

export function gearTripCount(item: GearItem): number {
  return item.tripCount === undefined ? 0 : item.tripCount;
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
      return gearTripCount(right) - gearTripCount(left);
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
  const showAllCategories = activeCategories.indexOf('全部') >= 0;
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
  if (categories.length === 0 || categories.indexOf('全部') >= 0) {
    return ['全部'];
  }
  const normalized: string[] = [];
  for (let index = 0; index < categories.length; index++) {
    const category = categories[index];
    if (category.length > 0 && normalized.indexOf(category) < 0) {
      normalized.push(category);
    }
  }
  if (normalized.length === 0) {
    return ['全部'];
  }
  return normalized;
}

export function allGearFilterCategories(userCategories: string[]): string[] {
  const result: string[] = ['全部'];
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
  if (category === '全部') {
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

export function mostFrequentGearText(gears: GearItem[]): string {
  let item: GearItem | undefined = undefined;
  for (let index = 0; index < gears.length; index++) {
    if (gearTripCount(gears[index]) > 0 &&
      (item === undefined || gearTripCount(gears[index]) > gearTripCount(item))) {
      item = gears[index];
    }
  }
  return item === undefined ? '暂无' : item.name + ' (×' + gearTripCount(item).toString() + '次)';
}

export function formatKg(weightGram: number): string {
  if (weightGram <= 0) {
    return '0kg';
  }
  return (Math.round(weightGram / 100) / 10).toString() + 'kg';
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
  const tabs: string[] = ['全部'];
  const categories = presetCategories(userCategories);
  for (let index = 0; index < categories.length; index++) {
    tabs.push(categories[index]);
  }
  return tabs;
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
  if (category === '全部') {
    return gears;
  }
  return gears.filter((item: GearItem) => item.category === category);
}

export function tempGearFilterText(categories: string[]): string {
  const normalized = normalizeGearCategories(categories);
  if (normalized.indexOf('全部') >= 0) {
    return '全部';
  }
  if (normalized.length === 1) {
    return normalized[0];
  }
  if (normalized.length === 2) {
    return normalized[0] + ' +1';
  }
  return normalized.length.toString() + '个分组';
}
