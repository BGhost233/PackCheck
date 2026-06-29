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

interface CreateGearParams {
  name: string;
  category: string;
  weight?: number;
  price?: number;
  note?: string;
  brand?: string;
  acquiredAt?: number;
}

/** 新建装备：统一分配 id + createdAt（order 留空，由排序回退 createdAt 倒序自然定位） */
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

interface UpdateGearFields {
  name?: string;
  category?: string;
  weight?: number;
  price?: number;
  note?: string;
  brand?: string;
  acquiredAt?: number;
  order?: number; // 问题9：手动拖动排序权重；不传则原样保留
}

/** 更新装备字段：保留未指定字段（含 order——必须透传，否则编辑/改分组会清空手动排序） */
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
    acquiredAt: fields.acquiredAt !== undefined ? fields.acquiredAt : existing.acquiredAt,
    order: fields.order !== undefined ? fields.order : existing.order
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

// ─── Wave 2B：从 GearPage 提取的纯计算 ─────────────────────────────────

/**
 * 按关键字将文本切分为交替的 [普通, 高亮, 普通, ...] 段（大小写不敏感）。
 */
export function splitByKeyword(text: string, keyword: string): string[] {
  if (keyword.length === 0) {
    return [text];
  }
  const parts: string[] = [];
  const lowerText = text.toLowerCase();
  const lowerKey = keyword.toLowerCase();
  let startIndex = 0;
  while (startIndex < text.length) {
    const foundIndex = lowerText.indexOf(lowerKey, startIndex);
    if (foundIndex < 0) {
      parts.push(text.substring(startIndex));
      break;
    }
    if (foundIndex > startIndex) {
      parts.push(text.substring(startIndex, foundIndex));
    }
    parts.push(text.substring(foundIndex, foundIndex + keyword.length));
    startIndex = foundIndex + keyword.length;
  }
  return parts;
}

/**
 * 陪伴天数（从入手日期或创建日期算起）。
 */
export function companionDays(item: GearItem): number {
  const start: number = typeof item.acquiredAt === 'number' ? item.acquiredAt : item.createdAt;
  return Math.max(0, Math.floor((Date.now() - start) / 86400000));
}

/**
 * 陪伴天数后缀：有明确入手日期 → " 天"，否则 → " 天左右"。
 */
export function companionDaysLabel(item: GearItem): string {
  if (typeof item.acquiredAt === 'number') {
    return ' 天';
  }
  return ' 天左右';
}

/**
 * 装备库概要：「N件 · Xkg · ¥Y」。
 */
export function gearSummaryText(gears: GearItem[]): string {
  return gears.length.toString() + '件 · ' + formatKg(totalGearWeight(gears)) +
    ' · ¥' + totalGearPrice(gears).toString();
}

// ─── Wave 7.5：从 GearPage 提取的纯计算 ─────────────────────────────────

/** buildGearGroups 的返回结构。 */
export interface GearGroupsResult {
  filteredGears: GearItem[];
  groups: string[];
  byGroup: Map<string, GearItem[]>;
}

/**
 * 带 categoryOrder + manual order + tripCount 的完整排序。
 * tripCountMap 为 undefined 时 GEAR_SORT_TRIP_COUNT 回退为时间排序。
 */
export function sortGearsWithOrder(items: GearItem[], sortMode: string,
  categoryOrder: string[], tripCountMap: Map<string, number> | undefined): GearItem[] {
  const sorted: GearItem[] = [];
  for (let i = 0; i < items.length; i++) {
    sorted.push(items[i]);
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
      if (tripCountMap !== undefined) {
        const lc = tripCountMap.get(left.id) ?? 0;
        const rc = tripCountMap.get(right.id) ?? 0;
        return rc - lc;
      }
      return right.createdAt - left.createdAt;
    }
    // GEAR_SORT_GROUP: 同分类内按手动 order 升序，不同分类按 categoryOrder
    if (left.category === right.category) {
      const lo = left.order;
      const ro = right.order;
      if (lo !== undefined && ro !== undefined) {
        return lo - ro;
      }
      if (lo !== undefined) {
        return -1;
      }
      if (ro !== undefined) {
        return 1;
      }
      return right.createdAt - left.createdAt;
    }
    const leftIdx = categoryOrder.indexOf(left.category);
    const rightIdx = categoryOrder.indexOf(right.category);
    const li = leftIdx >= 0 ? leftIdx : 9999;
    const ri = rightIdx >= 0 ? rightIdx : 9999;
    if (li !== ri) {
      return li - ri;
    }
    return left.category.localeCompare(right.category);
  });
  return sorted;
}

/**
 * 一次性完成 筛选 → 排序 → 分组，返回结构化结果。
 * 等价于 GearPage.rebuildGearCache() 的纯函数版。
 */
export function buildGearGroups(gears: GearItem[], keyword: string,
  selectedCategories: string[], sortMode: string,
  categoryOrder: string[], tripCountMap: Map<string, number> | undefined): GearGroupsResult {
  // 1. 筛选
  const filtered: GearItem[] = [];
  const lowerKeyword = keyword.trim().toLowerCase();
  const activeCategories = normalizeGearCategories(selectedCategories);
  const showAllCategories = activeCategories.indexOf(CATEGORY_ALL) >= 0;
  for (let i = 0; i < gears.length; i++) {
    const item = gears[i];
    const note = item.note === undefined ? '' : item.note;
    const categoryMatched = showAllCategories || activeCategories.indexOf(item.category) >= 0;
    const keywordMatched = lowerKeyword.length === 0 ||
      item.name.toLowerCase().indexOf(lowerKeyword) >= 0 ||
      item.category.toLowerCase().indexOf(lowerKeyword) >= 0 ||
      note.toLowerCase().indexOf(lowerKeyword) >= 0;
    if (categoryMatched && keywordMatched) {
      filtered.push(item);
    }
  }

  // 2. 排序
  const sortedItems = sortGearsWithOrder(filtered, sortMode, categoryOrder, tripCountMap);

  // 3. 分组列表
  const groups: string[] = [];
  for (let i = 0; i < sortedItems.length; i++) {
    const group = sortMode === GEAR_SORT_GROUP
      ? sortedItems[i].category
      : gearSortLabel(sortMode);
    if (groups.indexOf(group) < 0) {
      groups.push(group);
    }
  }
  if (sortMode === GEAR_SORT_GROUP && categoryOrder.length > 0) {
    groups.sort((a: string, b: string): number => {
      const ai = categoryOrder.indexOf(a);
      const bi = categoryOrder.indexOf(b);
      const aIdx = ai >= 0 ? ai : 9999;
      const bIdx = bi >= 0 ? bi : 9999;
      if (aIdx !== bIdx) {
        return aIdx - bIdx;
      }
      return a.localeCompare(b);
    });
  }

  // 4. 分桶
  const byGroup = new Map<string, GearItem[]>();
  if (sortMode !== GEAR_SORT_GROUP) {
    for (let i = 0; i < groups.length; i++) {
      byGroup.set(groups[i], sortedItems);
    }
  } else {
    for (let i = 0; i < groups.length; i++) {
      byGroup.set(groups[i], []);
    }
    for (let i = 0; i < sortedItems.length; i++) {
      const cat = sortedItems[i].category;
      const bucket = byGroup.get(cat);
      if (bucket !== undefined) {
        bucket.push(sortedItems[i]);
      }
    }
  }

  return { filteredGears: sortedItems, groups: groups, byGroup: byGroup };
}

/**
 * 菜单覆盖层定位计算：以长按锚点为基准，底部空间不足时翻转到上方。
 */
export function overlayMenuTop(anchorGlobalY: number, overlayOriginY: number,
  menuHeight: number, screenHeight: number): number {
  const anchorLocalY = anchorGlobalY - overlayOriginY;
  const tabBarReserve = 84;
  const topSafe = 60;
  const availableBelow = screenHeight - anchorLocalY - tabBarReserve;

  if (availableBelow >= menuHeight) {
    let top = anchorLocalY - 20;
    const maxTop = screenHeight - tabBarReserve - menuHeight;
    if (top > maxTop) {
      top = maxTop;
    }
    if (top < topSafe) {
      top = topSafe;
    }
    return top;
  } else {
    let top = anchorLocalY - menuHeight - 20;
    if (top < topSafe) {
      top = topSafe;
    }
    return top;
  }
}

/**
 * 动态底部 spacer 高度计算。
 */
export function gearBottomSpacerHeight(headerExpanded: number, headerCollapsed: number,
  groups: string[], visibleItemCount: number): number {
  const collapseRange = headerExpanded - headerCollapsed;
  const estimatedContentHeight = visibleItemCount * 52 + groups.length * 44;
  if (estimatedContentHeight > collapseRange) {
    return 80;
  }
  return collapseRange - estimatedContentHeight + 80;
}

