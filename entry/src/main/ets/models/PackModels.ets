export interface GearItem {
  id: string;
  name: string;
  category: string;
  weight?: number;
  price?: number;
  note?: string;
  tripCount?: number;
  createdAt: number;
  brand?: string;        // 品牌（packing：辨识/复购参考）
  acquiredAt?: number;   // 入手时间戳（archive：陪伴天数 = now - acquiredAt；与 createdAt 录入时间区分）
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

export function makeId(prefix: string): string {
  const randomPart = Math.floor(Math.random() * 1000000).toString();
  return prefix + '_' + Date.now().toString() + '_' + randomPart;
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
