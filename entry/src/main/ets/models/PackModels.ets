export interface GearItem {
  id: string;
  name: string;
  category: string;
  weight?: number;
  price?: number;
  note?: string;
  createdAt: number;
  brand?: string;        // 品牌（packing：辨识/复购参考）
  acquiredAt?: number;   // 入手时间戳（archive：陪伴天数 = now - acquiredAt；与 createdAt 录入时间区分）
  order?: number;        // 单品手动排序权重（问题9：长按拖动排序）。optional 向后兼容——无 order 的旧数据回退 createdAt 倒序
}

export interface ChecklistItem {
  id: string;
  name: string;
  group: string;
  checked: boolean;
  weight?: number;
  price?: number;
  fromGearId?: string;
}

export interface TripChecklist {
  id: string;
  title: string;
  date?: string;
  dateAt?: number;
  items: ChecklistItem[];
  createdAt: number;
  destination?: string;     // 目的地
  distanceKm?: number;      // 里程（km）
  maxAltitude?: number;     // 最高海拔（m）
  ascentM?: number;         // 累计爬升（m）
  durationHours?: number;   // 时长（h）
}


// 「全部」分类哨兵值：用于筛选/标签组中表示「不限分类」。统一引用此常量，禁止硬编码字符串。
export const CATEGORY_ALL = '全部';

// 系统保留分组（不可删除/重命名的兜底分组）。统一引用此常量，禁止硬编码。
export const CATEGORY_FALLBACK = '其他';

export const DEFAULT_CATEGORIES: string[] = [
  '证件',
  '穿着·上身',
  '穿着·下身',
  '穿着·配件',
  '背负系统',
  '行走系统',
  '睡眠系统',
  '饮食系统',
  '电力系统',
  '摄影系统',
  '安全急救',
  '清洁洗护',
  '其他'
];

let idCounter = 0;

export function makeId(prefix: string): string {
  idCounter = (idCounter + 1) % 1000000;
  const randomPart = Math.floor(Math.random() * 1000000).toString();
  return prefix + '_' + Date.now().toString() + '_' + idCounter.toString() + '_' + randomPart;
}

export function normalizeNumber(value: string): number | undefined {
  const cleaned = value.trim();
  if (cleaned.length === 0) {
    return undefined;
  }
  const parsed = Number(cleaned);
  if (Number.isNaN(parsed)) {
    return undefined;
  }
  return parsed;
}
