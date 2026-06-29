import { ChecklistItem, clampNumber, DayItinerary, GearItem, makeId, TripChecklist, CATEGORY_FALLBACK } from '../../models/PackModels';

/**
 * Checklist CRUD + Mutation 纯函数
 * 职责：创建、克隆、更新、删除、排序、移动
 */

// ─── 防腐 Helper：不可变克隆 ────────────────────────────────────────────
// ArkTS 禁止 {...obj} 展开，所有字段逐一拷贝。
// 未来 TripChecklist / ChecklistItem 新增 optional 字段，只需在此处补一行。
// 所有调用方通过 overrides 只指定要改的字段，默认从 source 原样保留。

/** TripChecklist 可覆盖字段（仅限不涉及"清空为 undefined"的场景） */
export interface ChecklistOverrides {
  title?: string;
  items?: ChecklistItem[];
  itinerary?: DayItinerary[];
}

/**
 * 克隆一个 TripChecklist，用 overrides 覆盖指定字段，其余原样保留。
 * ⚠️ 唯一事实源：所有 TripChecklist 不可变更新必须走此函数或 cloneChecklistFull。
 * 新增 TripChecklist 字段时只需在此处 + cloneChecklistFull 各补一行。
 */
export function cloneChecklist(source: TripChecklist, overrides?: ChecklistOverrides): TripChecklist {
  return {
    id: source.id,
    title: overrides?.title !== undefined ? overrides.title : source.title,
    date: source.date,
    dateAt: source.dateAt,
    items: overrides?.items !== undefined ? overrides.items : source.items,
    createdAt: source.createdAt,
    destination: source.destination,
    distanceKm: source.distanceKm,
    maxAltitude: source.maxAltitude,
    ascentM: source.ascentM,
    durationHours: source.durationHours,
    itinerary: overrides?.itinerary !== undefined ? overrides.itinerary : source.itinerary
  };
}

/**
 * 全字段克隆：显式传入每个可选字段的新值（含 undefined = 清空）。
 * 用于 updateChecklistMeta 等需要"清空"可选字段的场景。
 */
export function cloneChecklistFull(source: TripChecklist, title: string,
  date: string | undefined, dateAt: number | undefined,
  destination: string | undefined, distanceKm: number | undefined,
  maxAltitude: number | undefined, ascentM: number | undefined,
  durationHours: number | undefined): TripChecklist {
  return {
    id: source.id,
    title: title,
    date: date,
    dateAt: dateAt,
    items: source.items,
    createdAt: source.createdAt,
    destination: destination,
    distanceKm: distanceKm,
    maxAltitude: maxAltitude,
    ascentM: ascentM,
    durationHours: durationHours,
    itinerary: source.itinerary
  };
}

/** 向后兼容别名：克隆并替换 items */
export function cloneChecklistWithItems(source: TripChecklist, items: ChecklistItem[]): TripChecklist {
  return cloneChecklist(source, { items: items });
}

/**
 * 工厂函数：创建新的 TripChecklist。
 * ⚠️ 唯一入口：所有新建 checklist 必须走此函数，禁止手写字面量。
 * 新增 TripChecklist 字段时只需在此处补一行。
 */
export function createChecklist(title: string, date: string, dateAt: number | undefined,
  destination: string | undefined, distanceKm: number | undefined,
  maxAltitude: number | undefined, ascentM: number | undefined,
  durationHours: number | undefined): TripChecklist {
  return {
    id: makeId('trip'),
    title: title,
    date: date,
    dateAt: dateAt,
    items: [],
    createdAt: Date.now(),
    destination: destination,
    distanceKm: distanceKm,
    maxAltitude: maxAltitude,
    ascentM: ascentM,
    durationHours: durationHours
  };
}

/**
 * 工厂函数：创建空白 ChecklistItem。
 * 用于 actionSheetItem 等初始化场景，禁止手写字面量。
 */
export function createEmptyChecklistItem(): ChecklistItem {
  return {
    id: '',
    name: '',
    group: '',
    checked: false,
    weight: undefined,
    price: undefined,
    fromGearId: undefined
  };
}

/** ChecklistItem 可覆盖字段（仅限不涉及"清空为 undefined"的场景） */
export interface ChecklistItemOverrides {
  name?: string;
  group?: string;
  checked?: boolean;
}

/**
 * 克隆一个 ChecklistItem，用 overrides 覆盖指定字段，其余原样保留。
 * ⚠️ 唯一事实源：所有 ChecklistItem 不可变更新必须走此函数或 cloneChecklistItemFull。
 * 新增 ChecklistItem 字段时只需在此处 + cloneChecklistItemFull 各补一行。
 */
export function cloneChecklistItem(source: ChecklistItem, overrides?: ChecklistItemOverrides): ChecklistItem {
  return {
    id: source.id,
    name: overrides?.name !== undefined ? overrides.name : source.name,
    group: overrides?.group !== undefined ? overrides.group : source.group,
    checked: overrides?.checked !== undefined ? overrides.checked : source.checked,
    weight: source.weight,
    price: source.price,
    fromGearId: source.fromGearId
  };
}

/**
 * 全字段克隆 ChecklistItem：显式传入每个可选字段的新值（含 undefined = 清空）。
 * 用于 updateItemFields 等需要覆盖 weight/price/fromGearId 的场景。
 */
export function cloneChecklistItemFull(source: ChecklistItem, name: string, group: string,
  checked: boolean, weight: number | undefined, price: number | undefined,
  fromGearId: string | undefined): ChecklistItem {
  return {
    id: source.id,
    name: name,
    group: group,
    checked: checked,
    weight: weight,
    price: price,
    fromGearId: fromGearId
  };
}

// ─── Checklist Mutation 纯函数 ─────────────────────────────────────────

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
      nextChecklists.push(cloneChecklist(checklist, { items: nextItems }));
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
      const base = createEmptyChecklistItem();
      base.id = makeId('item');
      const item = cloneChecklistItemFull(base,
        gear.name,
        (zone !== undefined && zone.length > 0) ? zone : gear.category,
        false,
        gear.weight,
        gear.price,
        gear.id);
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
          nextItems.push(cloneChecklistItem(item, { checked: !item.checked }));
        } else {
          nextItems.push(item);
        }
      }
      result.push(cloneChecklist(source, { items: nextItems }));
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

export interface TripProfileUpdate {
  destination?: string;
  distanceKm?: number;
  maxAltitude?: number;
  ascentM?: number;
  durationHours?: number;
}

/**
 * 从字符串输入构建 TripProfileUpdate（DRY：saveTripInfo / saveProfileInfo 共用）。
 */
export function buildTripProfile(destinationStr: string, distanceKmStr: string,
  maxAltitudeStr: string, ascentMStr: string, durationHoursStr: string): TripProfileUpdate {
  return {
    destination: destinationStr.trim().length > 0 ? destinationStr.trim() : undefined,
    distanceKm: clampNumber(distanceKmStr, 0, 100000),
    maxAltitude: clampNumber(maxAltitudeStr, -500, 9000),
    ascentM: clampNumber(ascentMStr, 0, 50000),
    durationHours: clampNumber(durationHoursStr, 0, 8760)
  };
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
      result.push(cloneChecklistFull(source, title, date, dateAt,
        profile !== undefined ? profile.destination : source.destination,
        profile !== undefined ? profile.distanceKm : source.distanceKm,
        profile !== undefined ? profile.maxAltitude : source.maxAltitude,
        profile !== undefined ? profile.ascentM : source.ascentM,
        profile !== undefined ? profile.durationHours : source.durationHours));
    } else {
      result.push(source);
    }
  }
  return result;
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
          nextItems.push(cloneChecklistItemFull(item,
            name, group, item.checked,
            updateMetrics ? weight : item.weight,
            updateMetrics ? price : item.price,
            updateGearId ? fromGearId : item.fromGearId));
        } else {
          nextItems.push(item);
        }
      }
      result.push(cloneChecklist(source, { items: nextItems }));
    } else {
      result.push(source);
    }
  }
  return result;
}

// ─── Wave 2A：移动/重排/批量操作 ────────────────────────────────────────

/**
 * 将指定 item 移动到目标 zone（插入到该 zone 第一个 item 之前），返回新数组。
 * F-1：落点对齐目标格顶部。若目标 zone 为空，插到末尾。
 */
export function moveChecklistItemToZone(checklists: TripChecklist[], checklistId: string,
  itemId: string, zone: string): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const cl = checklists[index];
    if (cl.id !== checklistId) {
      result.push(cl);
      continue;
    }
    const targetItem = cl.items.find(item => item.id === itemId);
    if (targetItem === undefined) {
      result.push(cl);
      continue;
    }
    const movedItem = cloneChecklistItem(targetItem, { group: zone });
    const withoutMoved = cl.items.filter(item => item.id !== itemId);
    let insertAt = withoutMoved.length;
    for (let i = 0; i < withoutMoved.length; i++) {
      if (withoutMoved[i].group === zone) {
        insertAt = i;
        break;
      }
    }
    const updatedItems = withoutMoved.slice();
    updatedItems.splice(insertAt, 0, movedItem);
    result.push(cloneChecklist(cl, { items: updatedItems }));
  }
  return result;
}

/**
 * 按 orderedIds 重排指定 zone 的 items，其他 zone 位置不变，返回新数组。
 */
export function reorderItemsInZone(checklists: TripChecklist[], checklistId: string,
  zone: string, orderedIds: string[]): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const cl = checklists[index];
    if (cl.id !== checklistId) {
      result.push(cl);
      continue;
    }
    const zoneItems = cl.items.filter(item => item.group === zone);
    const reordered: ChecklistItem[] = [];
    for (const id of orderedIds) {
      const found = zoneItems.find(item => item.id === id);
      if (found !== undefined) {
        reordered.push(found);
      }
    }
    const merged: ChecklistItem[] = [];
    let zoneInserted = false;
    for (const item of cl.items) {
      if (item.group === zone) {
        if (!zoneInserted) {
          merged.push(...reordered);
          zoneInserted = true;
        }
      } else {
        merged.push(item);
      }
    }
    if (!zoneInserted) {
      merged.push(...reordered);
    }
    result.push(cloneChecklist(cl, { items: merged }));
  }
  return result;
}

/**
 * 批量移动多个 items 到目标 zone（就地变更 group，保持数组顺序），返回新数组。
 */
export function batchMoveItems(checklists: TripChecklist[], checklistId: string,
  itemIds: string[], zone: string): TripChecklist[] {
  const result: TripChecklist[] = [];
  for (let index = 0; index < checklists.length; index++) {
    const cl = checklists[index];
    if (cl.id !== checklistId) {
      result.push(cl);
      continue;
    }
    const updatedItems: ChecklistItem[] = [];
    for (let i = 0; i < cl.items.length; i++) {
      const item = cl.items[i];
      if (itemIds.indexOf(item.id) >= 0) {
        updatedItems.push(cloneChecklistItem(item, { group: zone }));
      } else {
        updatedItems.push(item);
      }
    }
    result.push(cloneChecklist(cl, { items: updatedItems }));
  }
  return result;
}

/**
 * setItemChecked 返回结果：新的 checklists 数组 + 被更新的目标 checklist（用于完成检测）。
 */
export interface SetItemCheckedResult {
  checklists: TripChecklist[];
  updatedChecklist: TripChecklist | undefined;
}

/**
 * 将指定 item 的 checked 状态设为目标值，返回新数组和更新后的目标 checklist。
 * 不含任何 UI 副作用（动画/成就弹窗），副作用由调用方处理。
 */
export function setItemChecked(checklists: TripChecklist[], checklistId: string,
  itemId: string, checked: boolean): SetItemCheckedResult {
  const nextChecklists: TripChecklist[] = [];
  let updatedChecklist: TripChecklist | undefined = undefined;
  for (let index = 0; index < checklists.length; index++) {
    const source = checklists[index];
    if (source.id === checklistId) {
      const nextItems: ChecklistItem[] = [];
      for (let itemIndex = 0; itemIndex < source.items.length; itemIndex++) {
        const item = source.items[itemIndex];
        if (item.id === itemId) {
          nextItems.push(cloneChecklistItem(item, { checked: checked }));
        } else {
          nextItems.push(item);
        }
      }
      const updated = cloneChecklist(source, { items: nextItems });
      updatedChecklist = updated;
      nextChecklists.push(updated);
    } else {
      nextChecklists.push(source);
    }
  }
  return { checklists: nextChecklists, updatedChecklist: updatedChecklist };
}
