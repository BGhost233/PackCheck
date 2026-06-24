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

// --- 每日行程相关类型 ---

// 交通方式
export type TransportMode = 'flight' | 'train' | 'bus' | 'drive' | 'walk' | 'bike' | 'boat' | 'other';

// 票务信息
export interface TicketInfo {
  type: string;             // "机票" / "火车票" / "大巴票"
  code?: string;            // 航班号/车次
  seat?: string;            // 座位
  price?: number;           // 价格
  note?: string;            // 备注
}

// 单段路程
export interface RouteSegment {
  id: string;
  from: string;             // 出发地名
  to: string;               // 到达地名
  transport: TransportMode; // 交通方式
  departTime?: string;      // 出发时间 "08:30"
  arriveTime?: string;      // 到达时间 "14:00"
  note?: string;            // 该段备注
  ticket?: TicketInfo;      // 票务信息（可选）
  accommodation?: string;   // 住宿信息（可选）
}

// 一天的行程
export interface DayItinerary {
  id: string;
  dayIndex: number;         // 第几天（从 1 开始）
  date?: string;            // 日期 "2024-10-03"
  segments: RouteSegment[]; // 路段序列（有序）
  note?: string;            // 整天的备注（收缩态显示）
}

// --- 行程清单 ---

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
  itinerary?: DayItinerary[]; // 每日行程（Phase 1 新增，optional 向后兼容）
}


// --- Patch 类型（部分更新，用于编辑场景） ---

export interface DayPatch {
  date?: string;
  note?: string;
}

export interface SegmentPatch {
  from?: string;
  to?: string;
  transport?: TransportMode;
  departTime?: string;
  arriveTime?: string;
  note?: string;
  ticket?: TicketInfo;
  accommodation?: string;
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
