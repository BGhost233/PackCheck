import { ChecklistItem, GearItem, TripChecklist } from '../models/PackModels';
import { gearById, numberOrZero } from './GearService';

/**
 * 清单相关纯业务逻辑 — 不依赖 UI 上下文
 */

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

export function activeChecklistCount(checklists: TripChecklist[]): number {
  let count = 0;
  for (let index = 0; index < checklists.length; index++) {
    if (!isChecklistDone(checklists[index])) {
      count++;
    }
  }
  return count;
}

export function homeStatusText(checklists: TripChecklist[]): string {
  if (checklists.length === 0) {
    return '还没有行程，创建一个吧';
  }
  return activeChecklistCount(checklists).toString() + ' 个行程进行中';
}

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

export function checklistItemWeight(item: ChecklistItem, gears: GearItem[]): number | undefined {
  if (item.weight !== undefined) {
    return item.weight;
  }
  if (item.fromGearId !== undefined) {
    const gear = gearById(gears, item.fromGearId);
    if (gear !== undefined) {
      return gear.weight;
    }
  }
  return undefined;
}

export function checklistItemPrice(item: ChecklistItem, gears: GearItem[]): number | undefined {
  if (item.price !== undefined) {
    return item.price;
  }
  if (item.fromGearId !== undefined) {
    const gear = gearById(gears, item.fromGearId);
    if (gear !== undefined) {
      return gear.price;
    }
  }
  return undefined;
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

export function checklistCheckedWeight(checklist: TripChecklist, gears: GearItem[]): number {
  let total = 0;
  for (let index = 0; index < checklist.items.length; index++) {
    const item = checklist.items[index];
    const weight = checklistItemWeight(item, gears);
    if (item.checked && weight !== undefined) {
      total += weight;
    }
  }
  return total;
}

export function progressStartColor(percent: number): string {
  if (percent < 30) {
    return '#90A4AE';
  }
  return '#2D7D46';
}

export function progressEndColor(percent: number): string {
  if (percent < 30) {
    return '#90A4AE';
  }
  if (percent < 60) {
    return '#4CAF50';
  }
  return '#4CAF50';
}

export function checklistGroups(checklist: TripChecklist | undefined): string[] {
  if (checklist === undefined) {
    return [];
  }
  const groups: string[] = [];
  for (let index = 0; index < checklist.items.length; index++) {
    const group = checklist.items[index].group;
    if (groups.indexOf(group) < 0) {
      groups.push(group);
    }
  }
  return groups;
}

export function checklistItemsByGroup(checklist: TripChecklist | undefined, group: string): ChecklistItem[] {
  if (checklist === undefined) {
    return [];
  }
  return checklist.items.filter((item: ChecklistItem) => item.group === group);
}

export function isGroupDone(checklist: TripChecklist | undefined, group: string): boolean {
  const items = checklistItemsByGroup(checklist, group);
  if (items.length === 0) {
    return false;
  }
  for (let index = 0; index < items.length; index++) {
    if (!items[index].checked) {
      return false;
    }
  }
  return true;
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

export function isChecklistItemInGear(item: ChecklistItem): boolean {
  return item.fromGearId !== undefined && item.fromGearId.length > 0;
}

export function hasGearMarker(item: ChecklistItem): boolean {
  return isChecklistItemInGear(item);
}

export function checklistHasGear(checklist: TripChecklist, gearId: string): boolean {
  for (let index = 0; index < checklist.items.length; index++) {
    if (checklist.items[index].fromGearId === gearId) {
      return true;
    }
  }
  return false;
}

export function countableGearIds(checklist: TripChecklist, gearIds: string[]): string[] {
  const dedupedIds: string[] = [];
  for (let index = 0; index < gearIds.length; index++) {
    if (gearIds[index].length > 0 && dedupedIds.indexOf(gearIds[index]) < 0) {
      dedupedIds.push(gearIds[index]);
    }
  }
  const nextIds: string[] = [];
  for (let index = 0; index < dedupedIds.length; index++) {
    if (!checklistHasGear(checklist, dedupedIds[index])) {
      nextIds.push(dedupedIds[index]);
    }
  }
  return nextIds;
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
        createdAt: checklist.createdAt
      };
      nextChecklists.push(updated);
    } else {
      nextChecklists.push(checklist);
    }
  }
  return nextChecklists;
}

export function latestChecklistHomeSubtitle(checklist: TripChecklist | undefined, gears: GearItem[]): string {
  if (checklist === undefined) {
    return '';
  }
  const countdown = countdownText(checklist);
  const weight = checklistTotalWeight(checklist, gears);
  if (countdown.length > 0 && weight > 0) {
    return countdown + ' · ' + formatKgLocal(weight);
  }
  if (countdown.length > 0) {
    return countdown;
  }
  if (weight > 0) {
    return formatKgLocal(weight);
  }
  return checklistMetaText(checklist);
}

function formatKgLocal(weightGram: number): string {
  if (weightGram <= 0) {
    return '0kg';
  }
  return (Math.round(weightGram / 100) / 10).toString() + 'kg';
}

export function matchingGearForChecklistItem(item: ChecklistItem, gears: GearItem[]): GearItem | undefined {
  const name = item.name.trim();
  const group = item.group.trim().length === 0 ? '其他' : item.group.trim();
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
      const updatedChecklist: TripChecklist = {
        id: source.id,
        title: source.title,
        date: source.date,
        dateAt: source.dateAt,
        items: nextItems,
        createdAt: source.createdAt
      };
      result.push(updatedChecklist);
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
      const updatedChecklist: TripChecklist = {
        id: source.id,
        title: source.title,
        date: source.date,
        dateAt: source.dateAt,
        items: nextItems,
        createdAt: source.createdAt
      };
      result.push(updatedChecklist);
    } else {
      result.push(source);
    }
  }
  return result;
}

/**
 * 更新指定 checklist 的元信息（title/date/dateAt），返回新数组。
 */
export function updateChecklistMeta(checklists: TripChecklist[], checklistId: string,
  title: string, date: string | undefined, dateAt: number | undefined): TripChecklist[] {
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
        createdAt: source.createdAt
      };
      result.push(updated);
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
      const updatedChecklist: TripChecklist = {
        id: source.id,
        title: source.title,
        date: source.date,
        dateAt: source.dateAt,
        items: nextItems,
        createdAt: source.createdAt
      };
      result.push(updatedChecklist);
    } else {
      result.push(source);
    }
  }
  return result;
}

