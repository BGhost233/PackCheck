import { ChecklistItem, GearItem, TripChecklist } from '../../models/PackModels';
import { formatKg, gearById } from '../GearService';
import {
  AMBER_ACCENT, PRIMARY_COLOR, TEXT_SECONDARY, TEXT_TERTIARY
} from '../../constants/DesignTokens';

/**
 * Checklist 统计/展示/日期 纯函数
 * 职责：progress 计算、日期解析、倒计时、首页展示文案、行程排序
 */

// ─── 基础统计 ────────────────────────────────────────────────────────────

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

/**
 * 判断 checklist 是否在本次勾选后刚好全部完成（最后一个 item 被勾选）。
 */
export function isJustCompleted(beforeCheckedCount: number, beforeTotal: number,
  updatedChecklist: TripChecklist | undefined): boolean {
  if (updatedChecklist === undefined || beforeTotal === 0) {
    return false;
  }
  return beforeCheckedCount === beforeTotal - 1 && checkedCount(updatedChecklist) === beforeTotal;
}

// ─── 日期解析 ────────────────────────────────────────────────────────────

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

// ─── 格式化 ──────────────────────────────────────────────────────────────

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

// ─── 装备解析 ────────────────────────────────────────────────────────────

function isChecklistItemInGear(item: ChecklistItem): boolean {
  return item.fromGearId !== undefined && item.fromGearId.length > 0;
}

export function hasGearMarker(item: ChecklistItem): boolean {
  return isChecklistItemInGear(item);
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

// ─── 行程排序/查找 ───────────────────────────────────────────────────────

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

// ─── Wave 2C：天数/行程列表 ──────────────────────────────────────────────

/**
 * 距出发还有多少天（正数=未来，0=今天，负数=已过）。
 */
export function daysLeftCount(checklist: TripChecklist): number | undefined {
  const dateAt = checklistDateAt(checklist);
  if (dateAt === undefined) {
    return undefined;
  }
  return Math.floor((dateAt - startOfDay(new Date())) / 86400000);
}

/**
 * 未来行程列表（dateAt >= 今天），按 dateAt 升序。
 */
export function futureTrips(checklists: TripChecklist[]): TripChecklist[] {
  const today = startOfDay(new Date());
  const result: TripChecklist[] = [];
  for (let i = 0; i < checklists.length; i++) {
    const dateAt = checklistDateAt(checklists[i]);
    if (dateAt !== undefined && dateAt >= today) {
      result.push(checklists[i]);
    }
  }
  result.sort((a: TripChecklist, b: TripChecklist) => {
    const da = checklistDateAt(a);
    const db = checklistDateAt(b);
    if (da === undefined || db === undefined) { return 0; }
    return da - db;
  });
  return result;
}

/**
 * 过去行程 + 无日期行程（有日期的按 dateAt 降序，无日期的按 createdAt 降序排后面）。
 */
export function pastTrips(checklists: TripChecklist[]): TripChecklist[] {
  const today = startOfDay(new Date());
  const withDate: TripChecklist[] = [];
  const noDate: TripChecklist[] = [];
  for (let i = 0; i < checklists.length; i++) {
    const dateAt = checklistDateAt(checklists[i]);
    if (dateAt === undefined) {
      noDate.push(checklists[i]);
    } else if (dateAt < today) {
      withDate.push(checklists[i]);
    }
  }
  withDate.sort((a: TripChecklist, b: TripChecklist) => {
    const da = checklistDateAt(a);
    const db = checklistDateAt(b);
    if (da === undefined || db === undefined) { return 0; }
    return db - da;
  });
  noDate.sort((a: TripChecklist, b: TripChecklist) => b.createdAt - a.createdAt);
  const combined: TripChecklist[] = [];
  for (let i = 0; i < withDate.length; i++) {
    combined.push(withDate[i]);
  }
  for (let i = 0; i < noDate.length; i++) {
    combined.push(noDate[i]);
  }
  return combined;
}

// ─── 倒计时/展示文案 ────────────────────────────────────────────────────

/**
 * 倒计时主数字（用于 HeroCard 大字展示）。
 */
export function countdownLead(checklist: TripChecklist): string {
  const days = daysLeftCount(checklist);
  if (days === undefined) {
    return '待定';
  }
  if (days > 0) {
    return days.toString();
  }
  if (days === 0) {
    return '今天';
  }
  return Math.abs(days).toString();
}

/**
 * 倒计时后缀文本。
 */
export function countdownSuffix(checklist: TripChecklist): string {
  const days = daysLeftCount(checklist);
  if (days === undefined) {
    return '';
  }
  if (days > 0) {
    return ' 天后出发';
  }
  if (days === 0) {
    return ' 出发！';
  }
  return ' 天前出发';
}

/**
 * 行程行日期文本（用于行程列表行展示）。
 */
export function rowDateText(checklist: TripChecklist): string {
  const dateAt = checklistDateAt(checklist);
  if (dateAt === undefined) {
    return '日期待定';
  }
  const dayDiff = Math.floor((dateAt - startOfDay(new Date())) / 86400000);
  if (dayDiff > 0) {
    return '还有 ' + dayDiff.toString() + ' 天';
  }
  if (dayDiff === 0) {
    return '今天出发';
  }
  return Math.abs(dayDiff).toString() + ' 天前';
}

// ─── Wave 7.4：首页展示 ──────────────────────────────────────────────────

/**
 * 首页状态文案（如 "2 个行程待出发" / "已完成 3 个行程"）。
 */
export function homeStatusText(checklists: TripChecklist[]): string {
  if (checklists.length === 0) {
    return '还没有行程，创建一个吧';
  }
  const futureCount = futureTrips(checklists).length;
  if (futureCount > 0) {
    return futureCount.toString() + ' 个行程待出发';
  }
  return '已完成 ' + pastTrips(checklists).length.toString() + ' 个行程';
}

/**
 * HeroCard 副标题：目的地 · 日期 · 总重。
 */
export function heroSubtitleText(checklist: TripChecklist | undefined, gears: GearItem[]): string {
  if (checklist === undefined) {
    return '';
  }
  const parts: string[] = [];
  if (checklist.destination !== undefined && checklist.destination.trim().length > 0) {
    parts.push(checklist.destination.trim());
  }
  if (checklist.date !== undefined && checklist.date.length > 0) {
    parts.push(checklist.date);
  } else {
    parts.push('未设置日期');
  }
  parts.push(formatKg(checklistTotalWeight(checklist, gears)));
  return parts.join(' · ');
}

/**
 * Hero 状态标签文本。
 */
export function heroStatusLabel(daysLeft: number | undefined): string {
  if (daysLeft !== undefined && daysLeft >= 0) {
    return '准备中';
  }
  return '已完成';
}

/**
 * Hero 状态标签颜色。
 */
export function heroStatusColor(daysLeft: number | undefined): string {
  if (daysLeft !== undefined && daysLeft >= 0) {
    return PRIMARY_COLOR;
  }
  return TEXT_TERTIARY;
}

/**
 * Hero 大字颜色（紧急=琥珀色，正常=主色，无日期=弱色）。
 */
export function heroLeadColor(daysLeft: number | undefined): string {
  if (daysLeft === undefined) {
    return TEXT_TERTIARY;
  }
  if (daysLeft <= 3 && daysLeft > 0) {
    return AMBER_ACCENT;
  }
  return PRIMARY_COLOR;
}

/**
 * 行程行日期颜色。
 */
export function rowDateColor(item: TripChecklist): string {
  const dateAt = checklistDateAt(item);
  if (dateAt === undefined) {
    return TEXT_TERTIARY;
  }
  const dayDiff = Math.floor((dateAt - startOfDay(new Date())) / 86400000);
  if (dayDiff === 0) {
    return PRIMARY_COLOR;
  }
  if (dayDiff >= 1 && dayDiff <= 3) {
    return AMBER_ACCENT;
  }
  if (dayDiff > 3) {
    return TEXT_SECONDARY;
  }
  return TEXT_TERTIARY;
}

/**
 * 行程行日期字重。
 */
export function rowDateBold(item: TripChecklist): FontWeight {
  const dateAt = checklistDateAt(item);
  if (dateAt === undefined) {
    return FontWeight.Normal;
  }
  const dayDiff = Math.floor((dateAt - startOfDay(new Date())) / 86400000);
  return dayDiff === 0 ? FontWeight.Bold : FontWeight.Normal;
}

/**
 * 折叠头紧凑文本（latest 行程标题 + 天数信息）。
 */
export function compactHeaderText(latestChecklist: TripChecklist | undefined): string {
  if (latestChecklist === undefined) {
    return '';
  }
  const days = daysLeftCount(latestChecklist);
  if (days === undefined) {
    return '· ' + latestChecklist.title;
  }
  if (days > 0) {
    return '· ' + latestChecklist.title + ' · ' + days.toString() + '天后';
  }
  if (days === 0) {
    return '· ' + latestChecklist.title + ' · 今天出发';
  }
  return '· ' + latestChecklist.title;
}

/**
 * 只取未来行程中最近的一个（dateAt >= 今天）。
 */
export function nearestFutureChecklist(checklists: TripChecklist[]): TripChecklist | undefined {
  const today = startOfDay(new Date());
  let nearest: TripChecklist | undefined = undefined;
  for (let i = 0; i < checklists.length; i++) {
    const dateAt = checklistDateAt(checklists[i]);
    if (dateAt !== undefined && dateAt >= today) {
      const nearestDateAt = nearest !== undefined ? checklistDateAt(nearest) : undefined;
      if (nearest === undefined || (nearestDateAt !== undefined && dateAt < nearestDateAt)) {
        nearest = checklists[i];
      }
    }
  }
  return nearest;
}

/**
 * 快速核查按钮文案。
 */
export function quickReviewLabel(checklists: TripChecklist[]): string {
  const target = nearestFutureChecklist(checklists);
  if (target === undefined) {
    return '';
  }
  if (target.items.length > 0 && checkedCount(target) === target.items.length) {
    return '再检查一遍';
  }
  return '快速核查';
}

// ─── Wave 7.6：从 Index.ets 提取的纯计算 ────────────────────────────────

/**
 * 从行程清单中提取所有已绑定装备的 gearId 列表。
 */
export function tripGearIds(checklist: TripChecklist | undefined): string[] {
  if (checklist === undefined) {
    return [];
  }
  const ids: string[] = [];
  for (let i = 0; i < checklist.items.length; i++) {
    const gid = checklist.items[i].fromGearId;
    if (gid !== undefined && gid !== '') {
      ids.push(gid);
    }
  }
  return ids;
}

/**
 * 核查摘要文本：「已带 X 件，未带 Y 件」。
 */
export function reviewSummaryText(checklist: TripChecklist | undefined): string {
  if (checklist === undefined) {
    return '';
  }
  const checked = checkedCount(checklist);
  return '已带 ' + checked.toString() + ' 件，未带 ' +
    (checklist.items.length - checked).toString() + ' 件';
}

/**
 * Tab 栏滑动视觉权重（0=未选中，1=完全选中，中间值=滑动过渡）。
 */
export function tabVisualWeight(index: number, currentTabIndex: number, swipeProgress: number): number {
  const isCurrent = currentTabIndex === index;
  if (isCurrent) {
    return 1.0 - Math.min(1.0, Math.abs(swipeProgress));
  }
  const isSwipeTarget = (swipeProgress < 0 && index === currentTabIndex + 1) ||
    (swipeProgress > 0 && index === currentTabIndex - 1);
  if (isSwipeTarget) {
    return Math.min(1.0, Math.abs(swipeProgress));
  }
  return 0.0;
}
