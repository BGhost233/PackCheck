import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DEFAULT_CATEGORIES, GearItem, TripChecklist } from '../models/PackModels';

const STORE_NAME = 'packcheck_store';
const KEY_GEARS = 'packcheck_gears';
const KEY_CHECKLISTS = 'packcheck_checklists';
const KEY_CATEGORIES = 'packcheck_categories';
const KEY_GEAR_TARGET_WEIGHT = 'gear_target_weight';
const KEY_COLLAPSED_GEAR_GROUPS = 'packcheck_collapsed_gear_groups';
const KEY_CATEGORY_ORDER = 'packcheck_category_order';
const KEY_SCHEMA_VERSION = 'packcheck_schema_version';
const DEFAULT_GEAR_TARGET_WEIGHT = 10000;
const CURRENT_SCHEMA_VERSION = 1;
const DEFAULT_ARRAY = '[]';
const LOG_DOMAIN = 0x0001;
const LOG_TAG = 'PackStore';

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
    // 未来在这里添加迁移逻辑（version 0 → 1 无需迁移，仅标记版本）
    await this.writeString(KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION.toString());
  }

  async getGears(): Promise<GearItem[]> {
    const value = await this.readString(KEY_GEARS, DEFAULT_ARRAY);
    return JSON.parse(value) as GearItem[];
  }

  async saveGears(gears: GearItem[]): Promise<void> {
    await this.writeString(KEY_GEARS, JSON.stringify(gears));
  }

  async getChecklists(): Promise<TripChecklist[]> {
    const value = await this.readString(KEY_CHECKLISTS, DEFAULT_ARRAY);
    return JSON.parse(value) as TripChecklist[];
  }

  async saveChecklists(checklists: TripChecklist[]): Promise<void> {
    await this.writeString(KEY_CHECKLISTS, JSON.stringify(checklists));
  }

  async getCategories(): Promise<string[]> {
    const value = await this.readString(KEY_CATEGORIES, DEFAULT_ARRAY);
    return JSON.parse(value) as string[];
  }

  async saveCategories(categories: string[]): Promise<void> {
    await this.writeString(KEY_CATEGORIES, JSON.stringify(categories));
  }

  async getGearTargetWeight(): Promise<number> {
    const value = await this.readString(KEY_GEAR_TARGET_WEIGHT, DEFAULT_GEAR_TARGET_WEIGHT.toString());
    const parsed = Number(value);
    if (!Number.isNaN(parsed) && parsed > 0) {
      return parsed;
    }
    return DEFAULT_GEAR_TARGET_WEIGHT;
  }

  async saveGearTargetWeight(weightGram: number): Promise<void> {
    await this.writeString(KEY_GEAR_TARGET_WEIGHT, weightGram.toString());
  }

  async getCollapsedGearGroups(): Promise<string[]> {
    const value = await this.readString(KEY_COLLAPSED_GEAR_GROUPS, DEFAULT_ARRAY);
    return JSON.parse(value) as string[];
  }

  async saveCollapsedGearGroups(groups: string[]): Promise<void> {
    await this.writeString(KEY_COLLAPSED_GEAR_GROUPS, JSON.stringify(groups));
  }

  async getCategoryOrder(): Promise<string[]> {
    const value = await this.readString(KEY_CATEGORY_ORDER, DEFAULT_ARRAY);
    return JSON.parse(value) as string[];
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
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'flush failed: %{public}s', String(error));
    }
    this.flushTimerId = -1;
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
