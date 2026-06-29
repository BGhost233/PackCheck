import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChecklistItem, DEFAULT_CATEGORIES, DayItinerary, GearItem, RouteSegment, TicketInfo, TripChecklist } from '../models/PackModels';

const STORE_NAME = 'packcheck_store';
const KEY_GEARS = 'packcheck_gears';
const KEY_CHECKLISTS = 'packcheck_checklists';
const KEY_CATEGORIES = 'packcheck_categories';
const KEY_COLLAPSED_GEAR_GROUPS = 'packcheck_collapsed_gear_groups';
const KEY_CATEGORY_ORDER = 'packcheck_category_order';
const KEY_SCHEMA_VERSION = 'packcheck_schema_version';
const CURRENT_SCHEMA_VERSION = 2;
const DEFAULT_ARRAY = '[]';
const LOG_DOMAIN = 0x0001;
const LOG_TAG = 'PackStore';

// Preferences 单 key 警告阈值（字节）
const SIZE_WARN_THRESHOLD = 800 * 1024; // 800KB，预留 200KB 余量

// ─── 运行时数据验证 ─────────────────────────────────────────────────────
// JSON 反序列化后逐条校验，丢弃不合法记录。
// 只校验结构完整性（必填字段+类型），不校验业务逻辑。

function isString(value: Object | null | undefined): boolean {
  return typeof value === 'string';
}

function isNumber(value: Object | null | undefined): boolean {
  return typeof value === 'number';
}

function isBoolean(value: Object | null | undefined): boolean {
  return typeof value === 'boolean';
}

function isArray(value: Object | null | undefined): boolean {
  return value instanceof Array;
}

/** 验证 TicketInfo 基础结构 */
function validateTicketInfo(raw: Object | null | undefined): boolean {
  if (raw === null || raw === undefined) {
    return false;
  }
  const obj = raw as Record<string, Object>;
  return isString(obj['type']);
}

/** 验证 RouteSegment 基础结构 */
function validateRouteSegment(raw: Object | null | undefined): boolean {
  if (raw === null || raw === undefined) {
    return false;
  }
  const obj = raw as Record<string, Object>;
  if (!isString(obj['id']) || !isString(obj['from']) || !isString(obj['to']) || !isString(obj['transport'])) {
    return false;
  }
  // ticket 可选但如果存在必须合法
  if (obj['ticket'] !== undefined && obj['ticket'] !== null && !validateTicketInfo(obj['ticket'])) {
    return false;
  }
  return true;
}

/** 验证 DayItinerary 基础结构 */
function validateDayItinerary(raw: Object | null | undefined): boolean {
  if (raw === null || raw === undefined) {
    return false;
  }
  const obj = raw as Record<string, Object>;
  if (!isString(obj['id']) || !isNumber(obj['dayIndex'])) {
    return false;
  }
  if (!isArray(obj['segments'])) {
    return false;
  }
  return true;
}

/** 验证 ChecklistItem 基础结构 */
function validateChecklistItem(raw: Object | null | undefined): boolean {
  if (raw === null || raw === undefined) {
    return false;
  }
  const obj = raw as Record<string, Object>;
  return isString(obj['id']) && isString(obj['name']) && isString(obj['group']) && isBoolean(obj['checked']);
}

/** 验证 GearItem 基础结构 */
function validateGearItem(raw: Object | null | undefined): boolean {
  if (raw === null || raw === undefined) {
    return false;
  }
  const obj = raw as Record<string, Object>;
  return isString(obj['id']) && isString(obj['name']) && isString(obj['category']) && isNumber(obj['createdAt']);
}

/** 验证 TripChecklist 基础结构 */
function validateTripChecklist(raw: Object | null | undefined): boolean {
  if (raw === null || raw === undefined) {
    return false;
  }
  const obj = raw as Record<string, Object>;
  if (!isString(obj['id']) || !isString(obj['title']) || !isNumber(obj['createdAt'])) {
    return false;
  }
  if (!isArray(obj['items'])) {
    return false;
  }
  return true;
}

/**
 * 安全反序列化 + 运行时验证：解析 JSON → 逐条校验 → 丢弃不合法记录。
 * @param json JSON 字符串
 * @param validator 单条记录验证函数
 * @param label 日志标签（仅用于 warn 输出）
 */
function safeParseAndValidate<T>(json: string, validator: (raw: Object | null | undefined) => boolean, label: string): T[] {
  let parsed: Object[];
  try {
    parsed = JSON.parse(json) as Object[];
  } catch (e) {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'JSON.parse failed for %{public}s, returning empty array. Input: %{public}s', label, json.substring(0, 100));
    return [] as T[];
  }
  if (!isArray(parsed)) {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Parsed result is not array for %{public}s, returning empty array.', label);
    return [] as T[];
  }
  const result: T[] = [];
  let dropped = 0;
  for (let i = 0; i < parsed.length; i++) {
    if (validator(parsed[i])) {
      result.push(parsed[i] as T);
    } else {
      dropped++;
    }
  }
  if (dropped > 0) {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Dropped %{public}d invalid records from %{public}s (kept %{public}d)', dropped, label, result.length);
  }
  return result;
}

/** 旧版兼容：string 数组无需结构校验 */
function safeParseStringArray(json: string, label: string): string[] {
  let parsed: Object[];
  try {
    parsed = JSON.parse(json) as Object[];
  } catch (e) {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'JSON.parse failed for %{public}s', label);
    return [];
  }
  if (!isArray(parsed)) {
    return [];
  }
  const result: string[] = [];
  for (let i = 0; i < parsed.length; i++) {
    if (isString(parsed[i])) {
      result.push(parsed[i] as string);
    }
  }
  return result;
}

// ─── Singleton 模式 ──────────────────────────────────────────────────────
// 全局唯一 PackStore 实例，消灭双实例 flush 竞争。
let _instance: PackStore | undefined = undefined;

export function getPackStore(): PackStore {
  if (_instance === undefined) {
    _instance = new PackStore();
  }
  return _instance;
}

export class PackStore {
  private prefs?: preferences.Preferences;
  private initFailed: boolean = false;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.prefs !== undefined) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, STORE_NAME);
      this.initFailed = false;
    } catch (error) {
      this.initFailed = true;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to init preferences: %{public}s', String(error));
      return;
    }
    await this.migrateSchema();
    const categories = await this.getCategories();
    if (categories.length === 0) {
      await this.saveCategories(DEFAULT_CATEGORIES);
    }
  }

  isInitFailed(): boolean {
    return this.initFailed;
  }

  private async migrateSchema(): Promise<void> {
    const versionStr = await this.readString(KEY_SCHEMA_VERSION, '0');
    const version = Number(versionStr);
    if (version >= CURRENT_SCHEMA_VERSION) {
      return;
    }
    // v0 → v1：无需迁移，仅标记版本
    // v1 → v2：为旧版 TripChecklist 补齐 itinerary 字段（undefined → []）
    if (version < 2) {
      await this.migrateV1ToV2();
    }
    await this.writeString(KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION.toString());
  }

  private async migrateV1ToV2(): Promise<void> {
    const json = await this.readString(KEY_CHECKLISTS, DEFAULT_ARRAY);
    let parsed: Object[];
    try {
      parsed = JSON.parse(json) as Object[];
    } catch (e) {
      return;
    }
    if (!isArray(parsed)) {
      return;
    }
    let migrated = false;
    for (let i = 0; i < parsed.length; i++) {
      const obj = parsed[i] as Record<string, Object>;
      if (obj['itinerary'] === undefined || obj['itinerary'] === null) {
        obj['itinerary'] = [];
        migrated = true;
      }
      // optional 字段（weight/price/fromGearId）缺失时 JSON 反序列化自动为 undefined，
      // 运行时通过 validateChecklistItem 校验必填字段即可，无需额外处理。
    }
    if (migrated) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Schema migration v1→v2: patched itinerary field for %{public}d checklists', parsed.length);
      await this.writeString(KEY_CHECKLISTS, JSON.stringify(parsed));
    }
  }

  async getGears(): Promise<GearItem[]> {
    const value = await this.readString(KEY_GEARS, DEFAULT_ARRAY);
    return safeParseAndValidate<GearItem>(value, validateGearItem, 'gears');
  }

  async saveGears(gears: GearItem[]): Promise<void> {
    const json = JSON.stringify(gears);
    this.warnIfLarge(json, 'gears');
    await this.writeString(KEY_GEARS, json);
  }

  async getChecklists(): Promise<TripChecklist[]> {
    const value = await this.readString(KEY_CHECKLISTS, DEFAULT_ARRAY);
    return safeParseAndValidate<TripChecklist>(value, validateTripChecklist, 'checklists');
  }

  async saveChecklists(checklists: TripChecklist[]): Promise<void> {
    const json = JSON.stringify(checklists);
    this.warnIfLarge(json, 'checklists');
    await this.writeString(KEY_CHECKLISTS, json);
  }

  async getCategories(): Promise<string[]> {
    const value = await this.readString(KEY_CATEGORIES, DEFAULT_ARRAY);
    return safeParseStringArray(value, 'categories');
  }

  async saveCategories(categories: string[]): Promise<void> {
    await this.writeString(KEY_CATEGORIES, JSON.stringify(categories));
  }

  async getCollapsedGearGroups(): Promise<string[]> {
    const value = await this.readString(KEY_COLLAPSED_GEAR_GROUPS, DEFAULT_ARRAY);
    return safeParseStringArray(value, 'collapsedGearGroups');
  }

  async saveCollapsedGearGroups(groups: string[]): Promise<void> {
    await this.writeString(KEY_COLLAPSED_GEAR_GROUPS, JSON.stringify(groups));
  }

  async getCategoryOrder(): Promise<string[]> {
    const value = await this.readString(KEY_CATEGORY_ORDER, DEFAULT_ARRAY);
    return safeParseStringArray(value, 'categoryOrder');
  }

  async saveCategoryOrder(order: string[]): Promise<void> {
    await this.writeString(KEY_CATEGORY_ORDER, JSON.stringify(order));
  }

  private async readString(key: string, fallback: string): Promise<string> {
    if (this.prefs === undefined) {
      return fallback;
    }
    try {
      const value = await this.prefs.get(key, fallback);
      if (typeof value === 'string') {
        return value;
      }
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'readString failed for key=%{public}s: %{public}s', key, String(error));
      return fallback;
    }
    return fallback;
  }

  // ─── 容量检测 ──────────────────────────────────────────────────────────
  private warnIfLarge(json: string, label: string): void {
    const size = json.length * 2; // 粗略估算 UTF-16 字节数
    if (size > SIZE_WARN_THRESHOLD) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'Data size for %{public}s approaching Preferences limit: %{public}d bytes (threshold: %{public}d)',
        label, size, SIZE_WARN_THRESHOLD);
    }
  }

  // 防抖 flush：连续写入合并为一次，避免高频操作（连打勾/拖拽）每次写磁盘
  private flushTimerId: number = -1;
  private static readonly FLUSH_DELAY: number = 200; // ms

  private scheduleFlush(): void {
    if (this.flushTimerId >= 0) {
      clearTimeout(this.flushTimerId);
    }
    this.flushTimerId = setTimeout(() => {
      this.flushNow();
    }, PackStore.FLUSH_DELAY);
  }

  private async flushNow(): Promise<void> {
    if (this.prefs === undefined) {
      return;
    }
    try {
      await this.prefs.flush();
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'flush failed: %{public}s', String(error));
    }
    this.flushTimerId = -1;
  }

  /** 立即刷盘：取消防抖定时器并同步写入。用于页面销毁/切后台等紧急时刻。 */
  async forceFlush(): Promise<void> {
    if (this.flushTimerId >= 0) {
      clearTimeout(this.flushTimerId);
      this.flushTimerId = -1;
    }
    await this.flushNow();
  }

  private async writeString(key: string, value: string): Promise<void> {
    if (this.prefs === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'writeString skipped (prefs undefined), key=%{public}s', key);
      return;
    }
    try {
      await this.prefs.put(key, value);
      this.scheduleFlush();
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'writeString failed for key=%{public}s: %{public}s', key, String(error));
    }
  }
}
