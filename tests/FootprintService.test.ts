import { describe, it, expect } from 'vitest';
import {
  computeFootprint,
  buildGearTripCountMap,
} from '../entry/src/main/ets/services/FootprintService.ets';
import { GearItem, TripChecklist, ChecklistItem } from '../entry/src/main/ets/models/PackModels.ets';

function makeGear(id: string, name: string, acquiredAt?: number): GearItem {
  return { id, name, category: '其他', createdAt: Date.now(), acquiredAt };
}

function makeTrip(id: string, opts?: Partial<TripChecklist>): TripChecklist {
  return {
    id,
    title: `trip-${id}`,
    items: [],
    createdAt: Date.now(),
    ...opts,
  };
}

function makeItem(id: string, fromGearId?: string): ChecklistItem {
  return { id, name: `item-${id}`, group: '其他', checked: false, fromGearId };
}

describe('FootprintService - computeFootprint', () => {
  it('returns zeros for empty inputs', () => {
    const fp = computeFootprint([], []);
    expect(fp.tripCount).toBe(0);
    expect(fp.totalDistanceKm).toBe(0);
    expect(fp.totalAscentM).toBe(0);
    expect(fp.maxAltitude).toBe(0);
    expect(fp.placeCount).toBe(0);
    expect(fp.gearCount).toBe(0);
    expect(fp.longestCompanion).toBeUndefined();
    expect(fp.recentTrips).toEqual([]);
  });

  it('aggregates trip stats correctly', () => {
    const trips = [
      makeTrip('t1', { distanceKm: 10.5, ascentM: 500, durationHours: 6, maxAltitude: 2000, destination: '黄山' }),
      makeTrip('t2', { distanceKm: 5.3, ascentM: 200, durationHours: 3, maxAltitude: 1500, destination: '泰山' }),
      makeTrip('t3', { distanceKm: 8, ascentM: 300, durationHours: 4, maxAltitude: 2500, destination: '黄山' }),
    ];
    const fp = computeFootprint(trips, []);
    expect(fp.tripCount).toBe(3);
    expect(fp.totalDistanceKm).toBe(23.8);
    expect(fp.totalAscentM).toBe(1000);
    expect(fp.totalDurationHours).toBe(13);
    expect(fp.maxAltitude).toBe(2500);
    expect(fp.placeCount).toBe(2); // 黄山 + 泰山
  });

  it('finds longest companion gear', () => {
    const now = Date.now();
    const gears = [
      makeGear('g1', 'New Tent', now - 86400000 * 10),     // 10 days
      makeGear('g2', 'Old Backpack', now - 86400000 * 365), // 365 days
      makeGear('g3', 'Stove', now - 86400000 * 30),         // 30 days
    ];
    const fp = computeFootprint([], gears);
    expect(fp.longestCompanion).toBeDefined();
    expect(fp.longestCompanion!.name).toBe('Old Backpack');
    expect(fp.longestCompanion!.days).toBeGreaterThanOrEqual(364);
  });

  it('gearCount reflects total gears', () => {
    const gears = [makeGear('g1', 'A'), makeGear('g2', 'B')];
    const fp = computeFootprint([], gears);
    expect(fp.gearCount).toBe(2);
  });

  it('recentTrips returns max 5 sorted by date', () => {
    const now = Date.now();
    const trips: TripChecklist[] = [];
    for (let i = 0; i < 8; i++) {
      trips.push(makeTrip(`t${i}`, { dateAt: now - 86400000 * (i + 1) }));
    }
    const fp = computeFootprint(trips, []);
    expect(fp.recentTrips.length).toBe(5);
    // Most recent first
    expect(fp.recentTrips[0].id).toBe('t0');
  });

  it('handles trips with undefined numeric fields gracefully', () => {
    const trips = [makeTrip('t1', { destination: '' })]; // no distanceKm etc
    const fp = computeFootprint(trips, []);
    expect(fp.totalDistanceKm).toBe(0);
    expect(fp.placeCount).toBe(0); // empty destination not counted
  });
});

describe('FootprintService - buildGearTripCountMap', () => {
  it('returns empty map for no trips', () => {
    expect(buildGearTripCountMap([]).size).toBe(0);
  });

  it('counts each gear once per trip', () => {
    const trips = [
      makeTrip('t1', { items: [makeItem('i1', 'g1'), makeItem('i2', 'g1'), makeItem('i3', 'g2')] }),
      makeTrip('t2', { items: [makeItem('i4', 'g1')] }),
    ];
    const map = buildGearTripCountMap(trips);
    expect(map.get('g1')).toBe(2); // appears in 2 trips
    expect(map.get('g2')).toBe(1); // appears in 1 trip
  });

  it('ignores items without fromGearId', () => {
    const trips = [makeTrip('t1', { items: [makeItem('i1'), makeItem('i2', '')] })];
    const map = buildGearTripCountMap(trips);
    expect(map.size).toBe(0);
  });
});
