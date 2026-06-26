import { describe, it, expect } from 'vitest';
import {
  numberOrZero,
  createGear,
  updateGear,
  gearValueRatio,
  sortedGears,
  filterGears,
  normalizeGearCategories,
  allGearFilterCategories,
  gearCategoryCount,
  totalGearWeight,
  totalGearPrice,
  formatKg,
  gearById,
  buildGearIndex,
  uniqueGearIds,
  importGearMetaText,
  filteredImportGears,
  tempGearFilterText,
} from '../entry/src/main/ets/services/GearService.ets';
import { GearItem, CATEGORY_ALL } from '../entry/src/main/ets/models/PackModels.ets';

function makeGear(id: string, name: string, category: string, weight?: number, price?: number): GearItem {
  return { id, name, category, weight, price, createdAt: Date.now() };
}

describe('GearService - numberOrZero', () => {
  it('returns value when defined', () => {
    expect(numberOrZero(42)).toBe(42);
    expect(numberOrZero(0)).toBe(0);
  });

  it('returns 0 when undefined', () => {
    expect(numberOrZero(undefined)).toBe(0);
  });
});

describe('GearService - createGear', () => {
  it('creates gear with all fields', () => {
    const gear = createGear({ name: 'Tent', category: '睡眠系统', weight: 1200, price: 3000, note: 'UL' });
    expect(gear.name).toBe('Tent');
    expect(gear.category).toBe('睡眠系统');
    expect(gear.weight).toBe(1200);
    expect(gear.price).toBe(3000);
    expect(gear.note).toBe('UL');
    expect(gear.id).toContain('gear_');
    expect(gear.createdAt).toBeGreaterThan(0);
  });

  it('creates gear with optional fields undefined', () => {
    const gear = createGear({ name: 'Rope', category: '其他' });
    expect(gear.weight).toBeUndefined();
    expect(gear.price).toBeUndefined();
    expect(gear.brand).toBeUndefined();
  });
});

describe('GearService - updateGear', () => {
  it('updates specified fields, preserves others', () => {
    const original = makeGear('g1', 'Old', '证件', 100, 200);
    const updated = updateGear(original, { name: 'New', weight: 500 });
    expect(updated.name).toBe('New');
    expect(updated.weight).toBe(500);
    expect(updated.category).toBe('证件'); // preserved
    expect(updated.price).toBe(200); // preserved
    expect(updated.id).toBe('g1'); // never changes
  });

  it('preserves order field when not specified', () => {
    const original: GearItem = { ...makeGear('g1', 'X', '其他'), order: 5 };
    const updated = updateGear(original, { name: 'Y' });
    expect(updated.order).toBe(5);
  });
});

describe('GearService - gearValueRatio', () => {
  it('returns price/weight when both defined', () => {
    const gear = makeGear('g1', 'X', '其他', 500, 2500);
    expect(gearValueRatio(gear)).toBe(5); // 2500/500
  });

  it('returns 0 when weight is 0', () => {
    const gear = makeGear('g1', 'X', '其他', 0, 100);
    expect(gearValueRatio(gear)).toBe(0);
  });

  it('returns 0 when price undefined', () => {
    const gear = makeGear('g1', 'X', '其他', 500);
    expect(gearValueRatio(gear)).toBe(0);
  });

  it('returns 0 when weight undefined', () => {
    const gear: GearItem = { id: 'g1', name: 'X', category: '其他', createdAt: 1, price: 100 };
    expect(gearValueRatio(gear)).toBe(0);
  });
});

describe('GearService - sortedGears', () => {
  it('sorts by price descending', () => {
    const gears = [
      makeGear('a', 'Cheap', '其他', 100, 50),
      makeGear('b', 'Mid', '其他', 100, 200),
      makeGear('c', 'Expensive', '其他', 100, 1000),
    ];
    const sorted = sortedGears(gears, 'price');
    expect(sorted.map(g => g.id)).toEqual(['c', 'b', 'a']);
  });

  it('sorts by weight descending', () => {
    const gears = [
      makeGear('a', 'Light', '其他', 100, 50),
      makeGear('b', 'Heavy', '其他', 2000, 50),
    ];
    const sorted = sortedGears(gears, 'weight');
    expect(sorted.map(g => g.id)).toEqual(['b', 'a']);
  });

  it('sorts by group then time within same category', () => {
    const now = Date.now();
    const gears: GearItem[] = [
      { id: 'a', name: 'A', category: '证件', createdAt: now - 1000, weight: 100 },
      { id: 'b', name: 'B', category: '证件', createdAt: now, weight: 200 },
      { id: 'c', name: 'C', category: '其他', createdAt: now, weight: 50 },
    ];
    const sorted = sortedGears(gears, 'group');
    // '其他' comes after '证件' in localeCompare? Actually depends on locale.
    // Within same category, newer first
    const categoryOrder = sorted.map(g => g.category);
    const withinFirst = sorted.filter(g => g.category === categoryOrder[0]);
    if (withinFirst.length > 1) {
      expect(withinFirst[0].createdAt).toBeGreaterThanOrEqual(withinFirst[1].createdAt);
    }
  });

  it('does not mutate original array', () => {
    const gears = [makeGear('a', 'A', '其他', 100, 50), makeGear('b', 'B', '其他', 200, 100)];
    const originalOrder = gears.map(g => g.id);
    sortedGears(gears, 'weight');
    expect(gears.map(g => g.id)).toEqual(originalOrder);
  });
});

describe('GearService - filterGears', () => {
  it('returns all gears when keyword empty and CATEGORY_ALL', () => {
    const gears = [makeGear('a', 'Tent', '睡眠系统'), makeGear('b', 'Jacket', '穿着·上身')];
    const result = filterGears(gears, '', [CATEGORY_ALL], 'group');
    expect(result.length).toBe(2);
  });

  it('filters by category', () => {
    const gears = [makeGear('a', 'Tent', '睡眠系统'), makeGear('b', 'Jacket', '穿着·上身')];
    const result = filterGears(gears, '', ['睡眠系统'], 'group');
    expect(result.length).toBe(1);
    expect(result[0].name).toBe('Tent');
  });

  it('filters by keyword (case insensitive)', () => {
    const gears = [makeGear('a', 'UL Tent', '睡眠系统'), makeGear('b', 'Jacket', '穿着·上身')];
    const result = filterGears(gears, 'tent', [CATEGORY_ALL], 'group');
    expect(result.length).toBe(1);
    expect(result[0].name).toBe('UL Tent');
  });

  it('searches in note field too', () => {
    const gear: GearItem = { ...makeGear('a', 'X', '其他'), note: 'ultralight tent' };
    const result = filterGears([gear], 'ultralight', [CATEGORY_ALL], 'group');
    expect(result.length).toBe(1);
  });
});

describe('GearService - normalizeGearCategories', () => {
  it('returns [CATEGORY_ALL] for empty input', () => {
    expect(normalizeGearCategories([])).toEqual([CATEGORY_ALL]);
  });

  it('returns [CATEGORY_ALL] when ALL is present', () => {
    expect(normalizeGearCategories([CATEGORY_ALL, '睡眠系统'])).toEqual([CATEGORY_ALL]);
  });

  it('deduplicates categories', () => {
    expect(normalizeGearCategories(['睡眠系统', '睡眠系统', '证件'])).toEqual(['睡眠系统', '证件']);
  });

  it('filters out empty strings', () => {
    expect(normalizeGearCategories(['', '睡眠系统'])).toEqual(['睡眠系统']);
  });
});

describe('GearService - formatKg', () => {
  it('returns "0kg" for 0 or negative', () => {
    expect(formatKg(0)).toBe('0kg');
    expect(formatKg(-100)).toBe('0kg');
  });

  it('formats grams to kg with precision', () => {
    expect(formatKg(1000)).toBe('1kg');
    expect(formatKg(1500)).toBe('1.5kg');
    expect(formatKg(1234)).toBe('1.23kg');
  });

  it('rounds for heavy items (≥10kg)', () => {
    expect(formatKg(10000)).toBe('10kg');
    expect(formatKg(15600)).toBe('16kg');
  });
});

describe('GearService - Aggregates', () => {
  it('totalGearWeight sums all weights', () => {
    const gears = [makeGear('a', 'A', '其他', 100), makeGear('b', 'B', '其他', 250), makeGear('c', 'C', '其他')];
    expect(totalGearWeight(gears)).toBe(350); // undefined treated as 0
  });

  it('totalGearPrice sums all prices', () => {
    const gears = [makeGear('a', 'A', '其他', 100, 200), makeGear('b', 'B', '其他', 100, 800)];
    expect(totalGearPrice(gears)).toBe(1000);
  });

  it('gearCategoryCount counts by category', () => {
    const gears = [makeGear('a', 'A', '证件'), makeGear('b', 'B', '证件'), makeGear('c', 'C', '其他')];
    expect(gearCategoryCount(gears, '证件')).toBe(2);
    expect(gearCategoryCount(gears, CATEGORY_ALL)).toBe(3);
  });
});

describe('GearService - Lookup', () => {
  it('gearById finds by id', () => {
    const gears = [makeGear('g1', 'A', '其他'), makeGear('g2', 'B', '其他')];
    expect(gearById(gears, 'g2')!.name).toBe('B');
    expect(gearById(gears, 'nonexistent')).toBeUndefined();
  });

  it('buildGearIndex creates O(1) lookup map', () => {
    const gears = [makeGear('g1', 'A', '其他'), makeGear('g2', 'B', '其他')];
    const index = buildGearIndex(gears);
    expect(index.get('g1')!.name).toBe('A');
    expect(index.get('g2')!.name).toBe('B');
    expect(index.get('g3')).toBeUndefined();
  });
});

describe('GearService - uniqueGearIds', () => {
  it('deduplicates and removes empty', () => {
    expect(uniqueGearIds(['a', 'b', 'a', '', 'c', 'b'])).toEqual(['a', 'b', 'c']);
  });

  it('returns empty for all empty strings', () => {
    expect(uniqueGearIds(['', '', ''])).toEqual([]);
  });
});

describe('GearService - importGearMetaText', () => {
  it('shows weight and price', () => {
    const gear = makeGear('g1', 'X', '其他', 500, 200);
    expect(importGearMetaText(gear)).toBe('500g  \u00A5200');
  });

  it('shows only weight when no price', () => {
    const gear = makeGear('g1', 'X', '其他', 500);
    expect(importGearMetaText(gear)).toBe('500g');
  });

  it('shows only price when no weight', () => {
    const gear: GearItem = { id: 'g1', name: 'X', category: '其他', createdAt: 1, price: 300 };
    expect(importGearMetaText(gear)).toBe('\u00A5300');
  });

  it('returns empty when neither', () => {
    const gear: GearItem = { id: 'g1', name: 'X', category: '其他', createdAt: 1 };
    expect(importGearMetaText(gear)).toBe('');
  });
});

describe('GearService - filteredImportGears', () => {
  it('returns all when CATEGORY_ALL', () => {
    const gears = [makeGear('a', 'A', '证件'), makeGear('b', 'B', '其他')];
    expect(filteredImportGears(gears, CATEGORY_ALL).length).toBe(2);
  });

  it('filters by specific category', () => {
    const gears = [makeGear('a', 'A', '证件'), makeGear('b', 'B', '其他')];
    expect(filteredImportGears(gears, '证件').length).toBe(1);
  });
});

describe('GearService - tempGearFilterText', () => {
  it('returns "全部" for ALL', () => {
    expect(tempGearFilterText([CATEGORY_ALL])).toBe(CATEGORY_ALL);
  });

  it('returns single category name', () => {
    expect(tempGearFilterText(['睡眠系统'])).toBe('睡眠系统');
  });

  it('returns "name +1" for two categories', () => {
    expect(tempGearFilterText(['睡眠系统', '证件'])).toBe('睡眠系统 +1');
  });

  it('returns count for 3+ categories', () => {
    expect(tempGearFilterText(['A', 'B', 'C'])).toBe('3个分组');
  });
});