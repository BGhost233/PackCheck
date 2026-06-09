// 人生足迹聚合（纯函数）。「我」Tab 年报叙事数据源。spec §4.1
import { GearItem, TripChecklist } from '../models/PackModels';

export interface Footprint {
  tripCount: number;         // 同行次数
  totalDistanceKm: number;   // 累计里程
  totalAscentM: number;      // 累计爬升
  maxAltitude: number;       // 到过的最高海拔
  placeCount: number;        // 去过的地方数（destination 去重计数）
  gearCount: number;         // 装备总数
  longestCompanion?: LongestCompanion;  // 相伴最久的伙伴
}

export interface LongestCompanion {
  name: string;
  days: number;   // 陪伴天数 = now - acquiredAt（无 acquiredAt 则用 createdAt 兜底）
}

const MS_PER_DAY = 86400000;

export function computeFootprint(trips: TripChecklist[], gears: GearItem[]): Footprint {
  let totalDistanceKm = 0;
  let totalAscentM = 0;
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
    if (typeof t.maxAltitude === 'number' && t.maxAltitude > maxAltitude) {
      maxAltitude = t.maxAltitude;
    }
    if (t.destination !== undefined && t.destination.trim().length > 0) {
      places.add(t.destination.trim());
    }
  }

  const result: Footprint = {
    tripCount: trips.length,
    totalDistanceKm: Math.round(totalDistanceKm),
    totalAscentM: Math.round(totalAscentM),
    maxAltitude: maxAltitude,
    placeCount: places.size,
    gearCount: gears.length,
    longestCompanion: computeLongestCompanion(gears),
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
