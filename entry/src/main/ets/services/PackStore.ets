import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DEFAULT_CATEGORIES, GearItem, TripChecklist } from '../models/PackModels';

const STORE_NAME = 'packcheck_store';
const KEY_GEARS = 'packcheck_gears';
const KEY_CHECKLISTS = 'packcheck_checklists';
const KEY_CATEGORIES = 'packcheck_categories';
const KEY_GEAR_TARGET_WEIGHT = 'gear_target_weight';
const KEY_COLLAPSED_GEAR_GROUPS = 'packcheck_collapsed_gear_groups';
const DEFAULT_GEAR_TARGET_WEIGHT = 10000;

export class PackStore {
  private prefs?: preferences.Preferences;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.prefs !== undefined) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, STORE_NAME);
    } catch (error) {
      return;
    }
    const categories = await this.getCategories();
    if (categories.length === 0) {
      await this.saveCategories(DEFAULT_CATEGORIES);
    }
  }

  async getGears(): Promise<GearItem[]> {
    const value = await this.readString(KEY_GEARS, '[]');
    return JSON.parse(value) as GearItem[];
  }

  async saveGears(gears: GearItem[]): Promise<void> {
    await this.writeString(KEY_GEARS, JSON.stringify(gears));
  }

  async getChecklists(): Promise<TripChecklist[]> {
    const value = await this.readString(KEY_CHECKLISTS, '[]');
    return JSON.parse(value) as TripChecklist[];
  }

  async saveChecklists(checklists: TripChecklist[]): Promise<void> {
    await this.writeString(KEY_CHECKLISTS, JSON.stringify(checklists));
  }

  async getCategories(): Promise<string[]> {
    const value = await this.readString(KEY_CATEGORIES, '[]');
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
    const value = await this.readString(KEY_COLLAPSED_GEAR_GROUPS, '[]');
    return JSON.parse(value) as string[];
  }

  async saveCollapsedGearGroups(groups: string[]): Promise<void> {
    await this.writeString(KEY_COLLAPSED_GEAR_GROUPS, JSON.stringify(groups));
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
      return fallback;
    }
    return fallback;
  }

  private async writeString(key: string, value: string): Promise<void> {
    if (this.prefs === undefined) {
      return;
    }
    try {
      await this.prefs.put(key, value);
      await this.prefs.flush();
    } catch (error) {
    }
  }
}
