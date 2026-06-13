import { CATEGORY_FALLBACK, GearItem, ChecklistItem, TripChecklist } from '../models/PackModels';
import { updateGear } from './GearService';

/**
 * 分组标签 CRUD + 全局数据同步逻辑
 * 纯函数，不依赖 UI 上下文
 */

/** 系统保留分组，不可删除/重命名 */
const PROTECTED_CATEGORY: string = CATEGORY_FALLBACK;

/** 判断是否为受保护分组 */
export function isProtectedCategory(category: string): boolean {
  return category === PROTECTED_CATEGORY;
}

/** 校验分组名是否合法（非空、不重复、不是保留名） */
export function validateCategoryName(name: string, existingCategories: string[]): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    return '分组名称不能为空';
  }
  if (trimmed === PROTECTED_CATEGORY) {
    return '「其他」为系统保留分组';
  }
  if (existingCategories.indexOf(trimmed) >= 0) {
    return '该分组已存在';
  }
  return '';
}

/** 新增分组（插入到"其他"之前） */
export function addCategory(categories: string[], newName: string): string[] {
  const trimmed = newName.trim();
  if (trimmed.length === 0 || categories.indexOf(trimmed) >= 0) {
    return categories;
  }
  const result: string[] = [];
  let inserted = false;
  for (let i = 0; i < categories.length; i++) {
    if (categories[i] === PROTECTED_CATEGORY && !inserted) {
      result.push(trimmed);
      inserted = true;
    }
    result.push(categories[i]);
  }
  if (!inserted) {
    result.push(trimmed);
  }
  return result;
}

/** 删除分组，返回新的分组列表 */
export function deleteCategory(categories: string[], target: string): string[] {
  if (isProtectedCategory(target)) {
    return categories;
  }
  const result: string[] = [];
  for (let i = 0; i < categories.length; i++) {
    if (categories[i] !== target) {
      result.push(categories[i]);
    }
  }
  return result;
}

/** 删除分组后，将装备库中该分组的装备归入"其他" */
export function migrateGearsOnDelete(gears: GearItem[], deletedCategory: string): GearItem[] {
  const result: GearItem[] = [];
  for (let i = 0; i < gears.length; i++) {
    if (gears[i].category === deletedCategory) {
      result.push(updateGear(gears[i], { category: PROTECTED_CATEGORY }));
    } else {
      result.push(gears[i]);
    }
  }
  return result;
}

/** 删除分组后，将所有行程中该分组的物品归入"其他" */
export function migrateChecklistsOnDelete(checklists: TripChecklist[], deletedCategory: string): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let i = 0; i < checklists.length; i++) {
    const checklist = checklists[i];
    let hasChange = false;
    const newItems: ChecklistItem[] = [];
    for (let j = 0; j < checklist.items.length; j++) {
      if (checklist.items[j].group === deletedCategory) {
        hasChange = true;
        const updated: ChecklistItem = {
          id: checklist.items[j].id,
          name: checklist.items[j].name,
          group: PROTECTED_CATEGORY,
          checked: checklist.items[j].checked,
          weight: checklist.items[j].weight,
          price: checklist.items[j].price,
          fromGearId: checklist.items[j].fromGearId
        };
        newItems.push(updated);
      } else {
        newItems.push(checklist.items[j]);
      }
    }
    if (hasChange) {
      const updatedChecklist: TripChecklist = {
        id: checklist.id,
        title: checklist.title,
        date: checklist.date,
        dateAt: checklist.dateAt,
        items: newItems,
        createdAt: checklist.createdAt,
        destination: checklist.destination,
        distanceKm: checklist.distanceKm,
        maxAltitude: checklist.maxAltitude,
        ascentM: checklist.ascentM,
        durationHours: checklist.durationHours
      };
      result.push(updatedChecklist);
    } else {
      result.push(checklist);
    }
  }
  return result;
}

/** 重命名分组，返回 { categories, renamed }。renamed=false 表示 oldName 不存在或操作无效。 */
export function renameCategory(categories: string[], oldName: string, newName: string): RenameCategoryResult {
  const trimmed = newName.trim();
  if (isProtectedCategory(oldName) || trimmed.length === 0) {
    return { categories, renamed: false };
  }
  // 检查新名字是否与其他分组（排除 oldName 自身）重复
  for (let i = 0; i < categories.length; i++) {
    if (categories[i] === trimmed && categories[i] !== oldName) {
      return { categories, renamed: false };
    }
  }
  let found = false;
  const result: string[] = [];
  for (let i = 0; i < categories.length; i++) {
    if (categories[i] === oldName) {
      result.push(trimmed);
      found = true;
    } else {
      result.push(categories[i]);
    }
  }
  if (!found) {
    return { categories, renamed: false };
  }
  return { categories: result, renamed: true };
}

export interface RenameCategoryResult {
  categories: string[];
  renamed: boolean;
}

/** 重命名后，同步装备库 */
export function renameGearsCategory(gears: GearItem[], oldName: string, newName: string): GearItem[] {
  const result: GearItem[] = [];
  for (let i = 0; i < gears.length; i++) {
    if (gears[i].category === oldName) {
      result.push(updateGear(gears[i], { category: newName }));
    } else {
      result.push(gears[i]);
    }
  }
  return result;
}

/** 重命名后，同步所有行程 */
export function renameChecklistsCategory(checklists: TripChecklist[], oldName: string, newName: string): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let i = 0; i < checklists.length; i++) {
    const checklist = checklists[i];
    let hasChange = false;
    const newItems: ChecklistItem[] = [];
    for (let j = 0; j < checklist.items.length; j++) {
      if (checklist.items[j].group === oldName) {
        hasChange = true;
        const updated: ChecklistItem = {
          id: checklist.items[j].id,
          name: checklist.items[j].name,
          group: newName,
          checked: checklist.items[j].checked,
          weight: checklist.items[j].weight,
          price: checklist.items[j].price,
          fromGearId: checklist.items[j].fromGearId
        };
        newItems.push(updated);
      } else {
        newItems.push(checklist.items[j]);
      }
    }
    if (hasChange) {
      const updatedChecklist: TripChecklist = {
        id: checklist.id,
        title: checklist.title,
        date: checklist.date,
        dateAt: checklist.dateAt,
        items: newItems,
        createdAt: checklist.createdAt,
        destination: checklist.destination,
        distanceKm: checklist.distanceKm,
        maxAltitude: checklist.maxAltitude,
        ascentM: checklist.ascentM,
        durationHours: checklist.durationHours
      };
      result.push(updatedChecklist);
    } else {
      result.push(checklist);
    }
  }
  return result;
}

/** 重新排序分组（确保"其他"始终在末尾） */
export function reorderCategories(newOrder: string[]): string[] {
  const result: string[] = [];
  for (let i = 0; i < newOrder.length; i++) {
    if (newOrder[i] !== PROTECTED_CATEGORY) {
      result.push(newOrder[i]);
    }
  }
  // "其他"始终在末尾
  result.push(PROTECTED_CATEGORY);
  return result;
}

/** 统计某分组下的装备数量 */
export function countGearsInCategory(gears: GearItem[], category: string): number {
  let count = 0;
  for (let i = 0; i < gears.length; i++) {
    if (gears[i].category === category) {
      count++;
    }
  }
  return count;
}

/** 统计某分组下所有行程物品数量 */
export function countChecklistItemsInCategory(checklists: TripChecklist[], category: string): number {
  let count = 0;
  for (let i = 0; i < checklists.length; i++) {
    for (let j = 0; j < checklists[i].items.length; j++) {
      if (checklists[i].items[j].group === category) {
        count++;
      }
    }
  }
  return count;
}
