// 人生足迹聚合（纯函数）。「我」Tab 年报叙事数据源。spec §4.1
import { GearItem, TripChecklist } from '../models/PackModels';

export interface Footprint {
  tripCount: number;         // 同行次数
  totalDistanceKm: number;   // 累计里程
  totalAscentM: number;      // 累计爬升
  totalDurationHours: number; // 累计时长
  maxAltitude: number;       // 到过的最高海拔
  placeCount: number;        // 去过的地方数（destination 去重计数）
  gearCount: number;         // 装备总数
  longestCompanion?: LongestCompanion;  // 相伴最久的伙伴
  recentTrips: TripSummary[];           // 最近行程摘要（时间线叙事用）
}

export interface LongestCompanion {
  name: string;
  days: number;   // 陪伴天数 = now - acquiredAt（无 acquiredAt 则用 createdAt 兜底）
}

// 行程一句话摘要（时间线展示用）
export interface TripSummary {
  id: string;
  title: string;
  destination: string;
  dateLabel: string;       // 格式化日期，如 "6月1日"
  distanceKm?: number;
  ascentM?: number;
  gearCount: number;       // 该行程携带装备数
}

const MS_PER_DAY = 86400000;

export function computeFootprint(trips: TripChecklist[], gears: GearItem[]): Footprint {
  let totalDistanceKm = 0;
  let totalAscentM = 0;
  let totalDurationHours = 0;
  let maxAltitude = 0;
  const places: Set<string> = new Set<string>();

  for (let i = 0; i < trips.length; i++) {
    const t = trips[i];
    if (typeof t.distanceKm === 'number') {
      totalDistanceKm += t.distanceKm;
    }
    if (typeof t.ascentM === 'number') {
      totalAscentM += t.ascentM;
    }
    if (typeof t.durationHours === 'number') {
      totalDurationHours += t.durationHours;
    }
    if (typeof t.maxAltitude === 'number' && t.maxAltitude > maxAltitude) {
      maxAltitude = t.maxAltitude;
    }
    if (t.destination !== undefined && t.destination.trim().length > 0) {
      places.add(t.destination.trim());
    }
  }

  const result: Footprint = {
    tripCount: trips.length,
    totalDistanceKm: Math.round(totalDistanceKm * 10) / 10,
    totalAscentM: Math.round(totalAscentM),
    totalDurationHours: Math.round(totalDurationHours * 10) / 10,
    maxAltitude: maxAltitude,
    placeCount: places.size,
    gearCount: gears.length,
    longestCompanion: computeLongestCompanion(gears),
    recentTrips: computeRecentTrips(trips),
  };
  return result;
}

function computeLongestCompanion(gears: GearItem[]): LongestCompanion | undefined {
  if (gears.length === 0) {
    return undefined;
  }
  const now = Date.now();
  let best: GearItem | undefined = undefined;
  let bestStart: number = Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < gears.length; i++) {
    const g = gears[i];
    const start: number = typeof g.acquiredAt === 'number' ? g.acquiredAt : g.createdAt;
    if (start < bestStart) {
      bestStart = start;
      best = g;
    }
  }
  if (best === undefined) {
    return undefined;
  }
  const days = Math.max(0, Math.floor((now - bestStart) / MS_PER_DAY));
  const companion: LongestCompanion = { name: best.name, days: days };
  return companion;
}

// 最近 5 条行程摘要，按时间倒序
function computeRecentTrips(trips: TripChecklist[]): TripSummary[] {
  if (trips.length === 0) {
    return [];
  }
  // 按 dateAt > createdAt 倒序排列
  const sorted = trips.slice().sort((a: TripChecklist, b: TripChecklist) => {
    const aTime = typeof a.dateAt === 'number' ? a.dateAt : a.createdAt;
    const bTime = typeof b.dateAt === 'number' ? b.dateAt : b.createdAt;
    return bTime - aTime;
  });
  const result: TripSummary[] = [];
  const limit = Math.min(5, sorted.length);
  for (let i = 0; i < limit; i++) {
    const t = sorted[i];
    const ts = typeof t.dateAt === 'number' ? t.dateAt : t.createdAt;
    result.push({
      id: t.id,
      title: t.title,
      destination: t.destination !== undefined ? t.destination.trim() : '',
      dateLabel: formatDateLabel(ts),
      distanceKm: t.distanceKm,
      ascentM: t.ascentM,
      gearCount: t.items.length,
    });
  }
  return result;
}

function formatDateLabel(timestamp: number): string {
  const d = new Date(timestamp);
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}
