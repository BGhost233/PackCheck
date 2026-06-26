import { describe, it, expect } from 'vitest';
import {
  groupByZoneAll,
  calcProgress,
  zoneDisplayName,
  zoneColor,
  zoneFill,
  allZones,
  hitTestZoneRect,
} from '../entry/src/main/ets/services/LoadoutService.ets';
import { ChecklistItem } from '../entry/src/main/ets/models/PackModels.ets';
import { BodyZone } from '../entry/src/main/ets/constants/GearLoadout.ets';

function makeItem(id: string, group: string, checked = false): ChecklistItem {
  return { id, name: `item-${id}`, group, checked };
}

describe('LoadoutService - groupByZoneAll', () => {
  it('returns all 7 zones even for empty input', () => {
    const result = groupByZoneAll([]);
    expect(result.size).toBe(7);
    for (const zone of allZones()) {
      expect(result.get(zone)).toEqual([]);
    }
  });

  it('groups by exact BodyZone value', () => {
    const items = [
      makeItem('a', BodyZone.Head),
      makeItem('b', BodyZone.Head),
      makeItem('c', BodyZone.Feet),
    ];
    const result = groupByZoneAll(items);
    expect(result.get(BodyZone.Head)!.length).toBe(2);
    expect(result.get(BodyZone.Feet)!.length).toBe(1);
    expect(result.get(BodyZone.Carry)!.length).toBe(0);
  });

  it('infers zone from CATEGORY_SLOT_MAP', () => {
    const items = [
      makeItem('a', '穿着\u00B7上身'),  // → UpperBody
      makeItem('b', '行走系统'),        // → Feet
      makeItem('c', '睡眠系统'),        // → Sleep
    ];
    const result = groupByZoneAll(items);
    expect(result.get(BodyZone.UpperBody)!.length).toBe(1);
    expect(result.get(BodyZone.Feet)!.length).toBe(1);
    expect(result.get(BodyZone.Sleep)!.length).toBe(1);
  });

  it('infers zone from fuzzy text matching', () => {
    const items = [
      makeItem('a', '帽子'),      // 头 → Head
      makeItem('b', '登山鞋'),    // 鞋 → Feet
      makeItem('c', '背包'),      // 背 → Carry
      makeItem('d', '睡袋'),      // 睡 → Sleep
      makeItem('e', '冲锋裤'),    // 裤 → LowerBody
    ];
    const result = groupByZoneAll(items);
    expect(result.get(BodyZone.Head)!.length).toBe(1);
    expect(result.get(BodyZone.Feet)!.length).toBe(1);
    expect(result.get(BodyZone.Carry)!.length).toBe(1);
    expect(result.get(BodyZone.Sleep)!.length).toBe(1);
    expect(result.get(BodyZone.LowerBody)!.length).toBe(1);
  });

  it('unknown group falls back to Misc', () => {
    const items = [makeItem('a', '完全随机的分组名')];
    const result = groupByZoneAll(items);
    expect(result.get(BodyZone.Misc)!.length).toBe(1);
  });
});

describe('LoadoutService - calcProgress', () => {
  it('returns 0/0 for empty items', () => {
    const p = calcProgress([]);
    expect(p.checked).toBe(0);
    expect(p.total).toBe(0);
  });

  it('counts checked correctly', () => {
    const items = [makeItem('a', 'x', true), makeItem('b', 'x', false), makeItem('c', 'x', true)];
    const p = calcProgress(items);
    expect(p.checked).toBe(2);
    expect(p.total).toBe(3);
  });
});

describe('LoadoutService - zoneDisplayName', () => {
  it('maps all zones to Chinese', () => {
    expect(zoneDisplayName(BodyZone.Head)).toBe('头部');
    expect(zoneDisplayName(BodyZone.UpperBody)).toBe('上身');
    expect(zoneDisplayName(BodyZone.LowerBody)).toBe('下身');
    expect(zoneDisplayName(BodyZone.Feet)).toBe('脚部');
    expect(zoneDisplayName(BodyZone.Carry)).toBe('背负');
    expect(zoneDisplayName(BodyZone.Sleep)).toBe('睡眠');
    expect(zoneDisplayName(BodyZone.Misc)).toBe('杂项');
  });

  it('returns raw value for unknown zone', () => {
    expect(zoneDisplayName('unknown')).toBe('unknown');
  });
});

describe('LoadoutService - zoneColor / zoneFill', () => {
  it('returns non-empty color string for all zones', () => {
    for (const zone of allZones()) {
      expect(zoneColor(zone).length).toBeGreaterThan(0);
      expect(zoneFill(zone).length).toBeGreaterThan(0);
    }
  });
});

describe('LoadoutService - hitTestZoneRect', () => {
  it('detects hit inside a zone rect', () => {
    const rects = new Map<string, number[]>();
    // rect: [globalX, globalY, width, height]
    rects.set(BodyZone.Head, [100, 100, 200, 100]);
    rects.set(BodyZone.Carry, [100, 250, 200, 100]);

    const zones = [BodyZone.Head, BodyZone.Carry];
    // Tap inside Head: global (150, 130), overlay origin (0, 0)
    expect(hitTestZoneRect(rects, zones, 150, 130, 0, 0)).toBe(BodyZone.Head);
  });

  it('returns null when miss', () => {
    const rects = new Map<string, number[]>();
    rects.set(BodyZone.Head, [100, 100, 200, 100]);
    expect(hitTestZoneRect(rects, [BodyZone.Head], 50, 50, 0, 0)).toBeNull();
  });

  it('accounts for overlay origin offset', () => {
    const rects = new Map<string, number[]>();
    // rect stored in global coords: x=200, y=300, w=100, h=80
    rects.set(BodyZone.Feet, [200, 300, 100, 80]);

    // overlay origin at (50, 50)
    // local rect: (150, 250, 100, 80) — tap at global (220, 330) → local (170, 280)
    // local point (170, 280) vs local rect (150, 250)→(250, 330): hit!
    expect(hitTestZoneRect(rects, [BodyZone.Feet], 220, 330, 50, 50)).toBe(BodyZone.Feet);
  });

  it('returns first matching zone (order matters)', () => {
    const rects = new Map<string, number[]>();
    // Overlapping rects
    rects.set(BodyZone.Head, [0, 0, 100, 100]);
    rects.set(BodyZone.Carry, [0, 0, 100, 100]);

    const zones = [BodyZone.Head, BodyZone.Carry];
    expect(hitTestZoneRect(rects, zones, 50, 50, 0, 0)).toBe(BodyZone.Head);
  });
});
