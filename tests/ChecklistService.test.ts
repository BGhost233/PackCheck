import { describe, it, expect } from 'vitest';
import {
  checkedCount,
  progressPercent,
  progressTotal,
  progressText,
  isChecklistDone,
  parseTripDateAt,
  startOfDay,
  countdownText,
  findLatestChecklist,
  toggleItemInChecklists,
  removeItemFromChecklists,
  addItemsToChecklist,
  buildItemsFromGears,
  updateChecklistMeta,
  updateItemFields,
  resolveItemName,
  checklistTotalWeight,
  matchingGearForChecklistItem,
  formatTripDate,
  formatDateText,
  numberInputText,
  hasGearMarker,
  cloneChecklistWithItems,
} from '../entry/src/main/ets/services/ChecklistService.ets';
import { ChecklistItem, TripChecklist, GearItem } from '../entry/src/main/ets/models/PackModels.ets';

// --- Test Helpers ---

function makeItem(id: string, checked: boolean, group = '\u5176\u4ed6', fromGearId?: string): ChecklistItem {
  return { id, name: 'item-' + id, group, checked, weight: 100, price: 50, fromGearId };
}

function makeChecklist(id: string, items: ChecklistItem[], opts?: Partial<TripChecklist>): TripChecklist {
  return {
    id,
    title: 'trip-' + id,
    items,
    createdAt: Date.now(),
    ...opts,
  };
}

function makeGear(id: string, name: string, category = '\u5176\u4ed6', weight = 200): GearItem {
  return { id, name, category, weight, price: 100, createdAt: Date.now() };
}

// --- Tests ---

describe('ChecklistService - Progress', () => {
  it('checkedCount returns 0 for empty items', () => {
    const cl = makeChecklist('c1', []);
    expect(checkedCount(cl)).toBe(0);
  });

  it('checkedCount counts only checked items', () => {
    const cl = makeChecklist('c1', [
      makeItem('a', true),
      makeItem('b', false),
      makeItem('c', true),
    ]);
    expect(checkedCount(cl)).toBe(2);
  });

  it('progressPercent floors the percentage', () => {
    const cl = makeChecklist('c1', [
      makeItem('a', true),
      makeItem('b', false),
      makeItem('c', false),
    ]);
    expect(progressPercent(cl)).toBe(33);
  });

  it('progressPercent returns 0 for empty checklist', () => {
    const cl = makeChecklist('c1', []);
    expect(progressPercent(cl)).toBe(0);
  });

  it('progressPercent returns 100 when all checked', () => {
    const cl = makeChecklist('c1', [makeItem('a', true), makeItem('b', true)]);
    expect(progressPercent(cl)).toBe(100);
  });

  it('progressTotal returns 1 for empty (avoids division by zero in UI)', () => {
    const cl = makeChecklist('c1', []);
    expect(progressTotal(cl)).toBe(1);
  });

  it('progressText formats correctly', () => {
    const cl = makeChecklist('c1', [makeItem('a', true), makeItem('b', false), makeItem('c', true)]);
    expect(progressText(cl)).toBe('2/3');
  });

  it('isChecklistDone true only when all checked and non-empty', () => {
    expect(isChecklistDone(makeChecklist('c1', []))).toBe(false);
    expect(isChecklistDone(makeChecklist('c1', [makeItem('a', true)]))).toBe(true);
    expect(isChecklistDone(makeChecklist('c1', [makeItem('a', true), makeItem('b', false)]))).toBe(false);
  });
});

describe('ChecklistService - parseTripDateAt', () => {
  it('returns undefined for empty string', () => {
    expect(parseTripDateAt('')).toBeUndefined();
    expect(parseTripDateAt('   ')).toBeUndefined();
  });

  it('parses "6\u670815\u65e5" with current year', () => {
    const result = parseTripDateAt('6\u670815\u65e5');
    const year = new Date().getFullYear();
    const expected = new Date(year, 5, 15).getTime();
    expect(result).toBe(expected);
  });

  it('parses "2025\u5e743\u67081\u65e5"', () => {
    const result = parseTripDateAt('2025\u5e743\u67081\u65e5');
    expect(result).toBe(new Date(2025, 2, 1).getTime());
  });

  it('returns undefined for malformed input', () => {
    expect(parseTripDateAt('\u968f\u4fbf\u5199\u70b9\u556a')).toBeUndefined();
    expect(parseTripDateAt('2025\u5e74')).toBeUndefined();
    expect(parseTripDateAt('\u6708\u65e5')).toBeUndefined();
  });

  it('parses "12\u670831\u65e5"', () => {
    const result = parseTripDateAt('12\u670831\u65e5');
    const year = new Date().getFullYear();
    expect(result).toBe(new Date(year, 11, 31).getTime());
  });
});

describe('ChecklistService - countdownText', () => {
  it('returns empty string when no date', () => {
    const cl = makeChecklist('c1', []);
    expect(countdownText(cl)).toBe('');
  });

  it('returns "\u4eca\u5929\u51fa\u53d1\uff01" when dateAt is today', () => {
    const today = startOfDay(new Date());
    const cl = makeChecklist('c1', [], { dateAt: today });
    expect(countdownText(cl)).toBe('\u4eca\u5929\u51fa\u53d1\uff01');
  });

  it('returns "\u8fd8\u6709 X \u5929\u51fa\u53d1" for future dates', () => {
    const future = startOfDay(new Date()) + 86400000 * 3;
    const cl = makeChecklist('c1', [], { dateAt: future });
    expect(countdownText(cl)).toBe('\u8fd8\u6709 3 \u5929\u51fa\u53d1');
  });

  it('returns "\u5df2\u51fa\u53d1 X \u5929" for past dates', () => {
    const past = startOfDay(new Date()) - 86400000 * 5;
    const cl = makeChecklist('c1', [], { dateAt: past });
    expect(countdownText(cl)).toBe('\u5df2\u51fa\u53d1 5 \u5929');
  });
});

describe('ChecklistService - Immutable Mutations', () => {
  it('toggleItemInChecklists flips checked without mutating original', () => {
    const items = [makeItem('a', false), makeItem('b', true)];
    const original = [makeChecklist('c1', items)];
    const result = toggleItemInChecklists(original, 'c1', 'a');

    expect(original[0].items[0].checked).toBe(false);
    expect(result[0].items[0].checked).toBe(true);
    expect(result[0].items[1].checked).toBe(true);
  });

  it('toggleItemInChecklists does nothing for non-existent id', () => {
    const original = [makeChecklist('c1', [makeItem('a', false)])];
    const result = toggleItemInChecklists(original, 'c1', 'nonexistent');
    expect(result[0].items[0].checked).toBe(false);
  });

  it('removeItemFromChecklists removes target item', () => {
    const items = [makeItem('a', false), makeItem('b', true), makeItem('c', false)];
    const original = [makeChecklist('c1', items)];
    const result = removeItemFromChecklists(original, 'c1', 'b');

    expect(result[0].items.length).toBe(2);
    expect(result[0].items.map(i => i.id)).toEqual(['a', 'c']);
    expect(original[0].items.length).toBe(3);
  });

  it('addItemsToChecklist appends items to correct checklist', () => {
    const c1 = makeChecklist('c1', [makeItem('a', false)]);
    const c2 = makeChecklist('c2', [makeItem('x', true)]);
    const newItems = [makeItem('n1', false), makeItem('n2', false)];

    const result = addItemsToChecklist([c1, c2], 'c1', newItems);
    expect(result[0].items.length).toBe(3);
    expect(result[1].items.length).toBe(1);
  });

  it('updateChecklistMeta updates title/date correctly', () => {
    const cl = makeChecklist('c1', [], { title: 'old', date: '6\u67081\u65e5', dateAt: 100 });
    const result = updateChecklistMeta([cl], 'c1', 'new title', '7\u67082\u65e5', 200);
    expect(result[0].title).toBe('new title');
    expect(result[0].date).toBe('7\u67082\u65e5');
    expect(result[0].dateAt).toBe(200);
  });

  it('updateItemFields updates specified fields', () => {
    const items = [makeItem('a', true)];
    const cl = makeChecklist('c1', items);
    const result = updateItemFields([cl], 'c1', 'a', 'newName', 'newGroup', 'gear123', true, 500, 999, true);
    const updated = result[0].items[0];
    expect(updated.name).toBe('newName');
    expect(updated.group).toBe('newGroup');
    expect(updated.fromGearId).toBe('gear123');
    expect(updated.weight).toBe(500);
    expect(updated.price).toBe(999);
    expect(updated.checked).toBe(true);
  });
});

describe('ChecklistService - findLatestChecklist', () => {
  it('returns undefined for empty array', () => {
    expect(findLatestChecklist([])).toBeUndefined();
  });

  it('prefers nearest future trip', () => {
    const today = startOfDay(new Date());
    const c1 = makeChecklist('past', [], { dateAt: today - 86400000 * 10 });
    const c2 = makeChecklist('far', [], { dateAt: today + 86400000 * 30 });
    const c3 = makeChecklist('near', [], { dateAt: today + 86400000 * 2 });
    expect(findLatestChecklist([c1, c2, c3])!.id).toBe('near');
  });

  it('falls back to most recent past trip if no future', () => {
    const today = startOfDay(new Date());
    const c1 = makeChecklist('old', [], { dateAt: today - 86400000 * 30 });
    const c2 = makeChecklist('recent', [], { dateAt: today - 86400000 * 2 });
    expect(findLatestChecklist([c1, c2])!.id).toBe('recent');
  });

  it('falls back to first item if no dateAt at all', () => {
    const c1 = makeChecklist('first', []);
    const c2 = makeChecklist('second', []);
    expect(findLatestChecklist([c1, c2])!.id).toBe('first');
  });
});

describe('ChecklistService - Gear Resolution', () => {
  it('resolveItemName returns gear name when gear exists', () => {
    const gear = makeGear('g1', 'UL\u5e10\u7bae');
    const item = makeItem('i1', false, '\u7761\u7720\u7cfb\u7edf', 'g1');
    expect(resolveItemName(item, [gear])).toBe('UL\u5e10\u7bae');
  });

  it('resolveItemName falls back to item name when gear deleted', () => {
    const item = makeItem('i1', false, '\u7761\u7720\u7cfb\u7edf', 'deleted-gear-id');
    expect(resolveItemName(item, [])).toBe('item-i1');
  });

  it('resolveItemName uses item name when no fromGearId', () => {
    const item = makeItem('i1', false);
    expect(resolveItemName(item, [])).toBe('item-i1');
  });

  it('checklistTotalWeight sums weights from gear or item', () => {
    const gear = makeGear('g1', 'Tent', '\u7761\u7720\u7cfb\u7edf', 800);
    const items: ChecklistItem[] = [
      { id: 'i1', name: 'Tent', group: '\u7761\u7720\u7cfb\u7edf', checked: false, weight: 100, fromGearId: 'g1' },
      { id: 'i2', name: 'Stove', group: '\u996e\u98df\u7cfb\u7edf', checked: false, weight: 300 },
    ];
    const cl = makeChecklist('c1', items);
    expect(checklistTotalWeight(cl, [gear])).toBe(1100);
  });
});

describe('ChecklistService - Utility', () => {
  it('formatTripDate formats correctly', () => {
    const date = new Date(2025, 0, 5);
    expect(formatTripDate(date)).toBe('1\u67085\u65e5');
  });

  it('formatDateText formats timestamp', () => {
    const ts = new Date(2025, 5, 15).getTime();
    expect(formatDateText(ts)).toBe('2025-6-15');
  });

  it('numberInputText returns empty for undefined', () => {
    expect(numberInputText(undefined)).toBe('');
    expect(numberInputText(42)).toBe('42');
    expect(numberInputText(0)).toBe('0');
  });

  it('hasGearMarker reflects fromGearId presence', () => {
    expect(hasGearMarker(makeItem('a', false, '\u5176\u4ed6', 'g1'))).toBe(true);
    expect(hasGearMarker(makeItem('a', false, '\u5176\u4ed6', ''))).toBe(false);
    expect(hasGearMarker(makeItem('a', false))).toBe(false);
  });

  it('matchingGearForChecklistItem finds by name+category', () => {
    const gear = makeGear('g1', 'Headlamp', '\u7a7f\u7740\u00b7\u914d\u4ef6');
    const item: ChecklistItem = { id: 'i1', name: 'Headlamp', group: '\u7a7f\u7740\u00b7\u914d\u4ef6', checked: false };
    expect(matchingGearForChecklistItem(item, [gear])).toEqual(gear);
  });

  it('matchingGearForChecklistItem uses fallback category for empty group', () => {
    const gear = makeGear('g1', 'Stuff', '\u5176\u4ed6');
    const item: ChecklistItem = { id: 'i1', name: 'Stuff', group: '', checked: false };
    expect(matchingGearForChecklistItem(item, [gear])).toEqual(gear);
  });
});

describe('ChecklistService - buildItemsFromGears', () => {
  it('builds items from selected gear ids', () => {
    const gears = [
      makeGear('g1', 'Tent', '\u7761\u7720\u7cfb\u7edf'),
      makeGear('g2', 'Jacket', '\u7a7f\u7740\u00b7\u4e0a\u8eab'),
      makeGear('g3', 'Boots', '\u884c\u8d70\u7cfb\u7edf'),
    ];
    const result = buildItemsFromGears(gears, ['g1', 'g3'], 'carry');
    expect(result.length).toBe(2);
    expect(result[0].name).toBe('Tent');
    expect(result[0].group).toBe('carry');
    expect(result[0].fromGearId).toBe('g1');
    expect(result[1].name).toBe('Boots');
  });

  it('uses gear category when zone not provided', () => {
    const gears = [makeGear('g1', 'Tent', '\u7761\u7720\u7cfb\u7edf')];
    const result = buildItemsFromGears(gears, ['g1']);
    expect(result[0].group).toBe('\u7761\u7720\u7cfb\u7edf');
  });
});

describe('ChecklistService - cloneChecklistWithItems', () => {
  it('preserves all fields except items', () => {
    const original = makeChecklist('c1', [makeItem('a', true)], {
      title: 'Trip',
      date: '6\u67081\u65e5',
      dateAt: 1000,
      destination: '\u9ec4\u5c71',
      distanceKm: 20,
      maxAltitude: 1800,
      ascentM: 900,
      durationHours: 8,
    });
    const newItems = [makeItem('b', false)];
    const cloned = cloneChecklistWithItems(original, newItems);

    expect(cloned.id).toBe('c1');
    expect(cloned.title).toBe('Trip');
    expect(cloned.destination).toBe('\u9ec4\u5c71');
    expect(cloned.items).toBe(newItems);
    expect(cloned.items).not.toBe(original.items);
  });
});
