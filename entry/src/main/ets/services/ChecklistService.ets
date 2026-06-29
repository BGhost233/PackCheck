/**
 * ChecklistService — 统一 re-export 入口
 *
 * 职责：聚合 checklist/ 子模块的全部 export，对外保持单一 import 路径。
 * 调用方无需关心内部拆分，只需 import { xxx } from '../services/ChecklistService'。
 */

// ─── CRUD + Mutation ─────────────────────────────────────────────────────
export {
  ChecklistOverrides,
  cloneChecklist,
  cloneChecklistFull,
  cloneChecklistWithItems,
  createChecklist,
  createEmptyChecklistItem,
  ChecklistItemOverrides,
  cloneChecklistItem,
  cloneChecklistItemFull,
  addItemsToChecklist,
  buildItemsFromGears,
  prependChecklist,
  matchingGearForChecklistItem,
  toggleItemInChecklists,
  removeItemFromChecklists,
  TripProfileUpdate,
  buildTripProfile,
  updateChecklistMeta,
  updateItemFields,
  moveChecklistItemToZone,
  reorderItemsInZone,
  batchMoveItems,
  SetItemCheckedResult,
  setItemChecked
} from './checklist/ChecklistCrudService';

// ─── Stats + Display ─────────────────────────────────────────────────────
export {
  checkedCount,
  progressPercent,
  progressValue,
  progressTotal,
  progressText,
  checklistMetaText,
  isChecklistDone,
  isJustCompleted,
  parseTripDateAt,
  startOfDay,
  checklistDateAt,
  countdownText,
  formatTripDate,
  formatDateText,
  numberInputText,
  hasGearMarker,
  resolveItemName,
  resolveItemNameByIndex,
  checklistItemWeight,
  checklistItemPrice,
  checklistTotalWeight,
  findLatestChecklist,
  daysLeftCount,
  futureTrips,
  pastTrips,
  countdownLead,
  countdownSuffix,
  rowDateText,
  homeStatusText,
  heroSubtitleText,
  heroStatusLabel,
  heroStatusColor,
  heroLeadColor,
  rowDateColor,
  rowDateBold,
  compactHeaderText,
  nearestFutureChecklist,
  quickReviewLabel,
  tripGearIds,
  reviewSummaryText,
  tabVisualWeight
} from './checklist/ChecklistStatsService';
