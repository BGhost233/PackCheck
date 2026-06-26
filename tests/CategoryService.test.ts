import { describe, it, expect } from 'vitest';
import {
  isProtectedCategory,
  validateCategoryName,
  addCategory,
  deleteCategory,
  migrateGearsOnDelete,
  migrateChecklistsOnDelete,
  renameCategory,
  renameGearsCategory,
  renameChecklistsCategory,
  reorderCategories,
  countGearsInCategory,
  countChecklistItemsInCategory,
} from '../entry/src/main/ets/services/CategoryService.ets';
import { GearItem, ChecklistItem, TripChecklist } from '../entry/src/main/ets/models/PackModels.ets';

function makeGear(id: string, category: string): GearItem {
  return { id, name: `gear-${id}`, category, createdAt: Date.now() };
}

function makeChecklist(id: string, items: ChecklistItem[]): TripChecklist {
  return { id, title: `trip-${id}`, items, createdAt: Date.now() };
}

function makeItem(id: string, group: string): ChecklistItem {
  return { id, name: `item-${id}`, group, checked: false };
}

describe('CategoryService - Protection', () => {
  it('recognizes protected category', () => {
    expect(isProtectedCategory('其他')).toBe(true);
    expect(isProtectedCategory('证件')).toBe(false);
  });
});

describe('CategoryService - validateCategoryName', () => {
  it('rejects empty name', () => {
    expect(validateCategoryName('', [])).toBe('分组名称不能为空');
    expect(validateCategoryName('   ', [])).toBe('分组名称不能为空');
  });

  it('rejects protected name', () => {
    expect(validateCategoryName('其他', [])).toBe('「其他」为系统保留分组');
  });

  it('rejects duplicate', () => {
    expect(validateCategoryName('证件', ['证件', '睡眠系统'])).toBe('该分组已存在');
  });

  it('accepts valid new name', () => {
    expect(validateCategoryName('新分组', ['证件'])).toBe('');
  });
});

describe('CategoryService - addCategory', () => {
  it('inserts before "其他"', () => {
    const cats = ['证件', '睡眠系统', '其他'];
    const result = addCategory(cats, '新分组');
    expect(result).toEqual(['证件', '睡眠系统', '新分组', '其他']);
  });

  it('does not add duplicate', () => {
    const cats = ['证件', '其他'];
    expect(addCategory(cats, '证件')).toEqual(cats);
  });

  it('does not add empty string', () => {
    const cats = ['证件', '其他'];
    expect(addCategory(cats, '')).toEqual(cats);
  });

  it('appends if no "其他" present', () => {
    const cats = ['证件', '睡眠系统'];
    const result = addCategory(cats, '新分组');
    expect(result).toEqual(['证件', '睡眠系统', '新分组']);
  });
});

describe('CategoryService - deleteCategory', () => {
  it('removes target category', () => {
    const cats = ['证件', '睡眠系统', '其他'];
    expect(deleteCategory(cats, '睡眠系统')).toEqual(['证件', '其他']);
  });

  it('refuses to delete protected category', () => {
    const cats = ['证件', '其他'];
    expect(deleteCategory(cats, '其他')).toEqual(cats);
  });
});

describe('CategoryService - migrateGearsOnDelete', () => {
  it('migrates gears in deleted category to "其他"', () => {
    const gears = [makeGear('g1', '睡眠系统'), makeGear('g2', '证件'), makeGear('g3', '睡眠系统')];
    const result = migrateGearsOnDelete(gears, '睡眠系统');
    expect(result[0].category).toBe('其他');
    expect(result[1].category).toBe('证件'); // untouched
    expect(result[2].category).toBe('其他');
  });
});

describe('CategoryService - migrateChecklistsOnDelete', () => {
  it('migrates checklist items in deleted category', () => {
    const items = [makeItem('i1', '睡眠系统'), makeItem('i2', '证件')];
    const checklists = [makeChecklist('c1', items)];
    const result = migrateChecklistsOnDelete(checklists, '睡眠系统');
    expect(result[0].items[0].group).toBe('其他');
    expect(result[0].items[1].group).toBe('证件');
  });

  it('does not create new reference for unchanged checklists', () => {
    const items = [makeItem('i1', '证件')];
    const checklists = [makeChecklist('c1', items)];
    const result = migrateChecklistsOnDelete(checklists, '睡眠系统');
    expect(result[0]).toBe(checklists[0]); // same reference
  });
});

describe('CategoryService - renameCategory', () => {
  it('renames successfully', () => {
    const cats = ['证件', '睡眠系统', '其他'];
    const { categories, renamed } = renameCategory(cats, '睡眠系统', '露营系统');
    expect(renamed).toBe(true);
    expect(categories).toEqual(['证件', '露营系统', '其他']);
  });

  it('refuses to rename protected category', () => {
    const cats = ['证件', '其他'];
    const { renamed } = renameCategory(cats, '其他', '杂项');
    expect(renamed).toBe(false);
  });

  it('refuses empty new name', () => {
    const cats = ['证件', '其他'];
    const { renamed } = renameCategory(cats, '证件', '');
    expect(renamed).toBe(false);
  });

  it('refuses rename to existing name', () => {
    const cats = ['证件', '睡眠系统', '其他'];
    const { renamed } = renameCategory(cats, '证件', '睡眠系统');
    expect(renamed).toBe(false);
  });

  it('allows rename to same name (no-op but valid)', () => {
    const cats = ['证件', '睡眠系统', '其他'];
    const { categories, renamed } = renameCategory(cats, '证件', '证件');
    expect(renamed).toBe(true);
    expect(categories).toEqual(cats);
  });
});

describe('CategoryService - renameGearsCategory', () => {
  it('updates gear categories', () => {
    const gears = [makeGear('g1', '证件'), makeGear('g2', '睡眠系统')];
    const result = renameGearsCategory(gears, '证件', '通行证');
    expect(result[0].category).toBe('通行证');
    expect(result[1].category).toBe('睡眠系统');
  });
});

describe('CategoryService - renameChecklistsCategory', () => {
  it('updates checklist item groups', () => {
    const items = [makeItem('i1', '证件'), makeItem('i2', '睡眠系统')];
    const checklists = [makeChecklist('c1', items)];
    const result = renameChecklistsCategory(checklists, '证件', '通行证');
    expect(result[0].items[0].group).toBe('通行证');
    expect(result[0].items[1].group).toBe('睡眠系统');
  });
});

describe('CategoryService - reorderCategories', () => {
  it('ensures "其他" is always last', () => {
    const result = reorderCategories(['其他', '证件', '睡眠系统']);
    expect(result[result.length - 1]).toBe('其他');
    expect(result).toEqual(['证件', '睡眠系统', '其他']);
  });

  it('preserves user order', () => {
    const result = reorderCategories(['睡眠系统', '证件', '其他']);
    expect(result).toEqual(['睡眠系统', '证件', '其他']);
  });
});

describe('CategoryService - Counting', () => {
  it('countGearsInCategory', () => {
    const gears = [makeGear('a', '证件'), makeGear('b', '证件'), makeGear('c', '其他')];
    expect(countGearsInCategory(gears, '证件')).toBe(2);
    expect(countGearsInCategory(gears, '其他')).toBe(1);
    expect(countGearsInCategory(gears, '不存在')).toBe(0);
  });

  it('countChecklistItemsInCategory across multiple checklists', () => {
    const c1 = makeChecklist('c1', [makeItem('i1', '证件'), makeItem('i2', '其他')]);
    const c2 = makeChecklist('c2', [makeItem('i3', '证件')]);
    expect(countChecklistItemsInCategory([c1, c2], '证件')).toBe(2);
    expect(countChecklistItemsInCategory([c1, c2], '其他')).toBe(1);
  });
});
