import { describe, it, expect } from 'vitest';
import {
  getDaySummary,
  addDay,
  insertDay,
  removeDay,
  updateDay,
  addSegment,
  removeSegment,
  updateSegment,
  createEmptySegment,
} from '../entry/src/main/ets/services/ItineraryService.ets';
import { DayItinerary, RouteSegment } from '../entry/src/main/ets/models/PackModels.ets';

function makeSegment(id: string, from: string, to: string, transport: string = 'train'): RouteSegment {
  return { id, from, to, transport: transport as any, departTime: '08:00', arriveTime: '12:00' };
}

function makeDay(id: string, dayIndex: number, segments: RouteSegment[] = [], from?: string, to?: string): DayItinerary {
  return { id, dayIndex, segments, from, to };
}

describe('ItineraryService - getDaySummary', () => {
  it('uses day-level from/to when available', () => {
    const day = makeDay('d1', 0, [makeSegment('s1', '北京', '上海')], '杭州', '南京');
    const summary = getDaySummary(day);
    expect(summary.from).toBe('杭州');
    expect(summary.to).toBe('南京');
  });

  it('falls back to first/last segment when no day-level from/to', () => {
    const day = makeDay('d1', 0, [
      makeSegment('s1', '北京', '石家庄'),
      makeSegment('s2', '石家庄', '郑州'),
    ]);
    const summary = getDaySummary(day);
    expect(summary.from).toBe('北京');
    expect(summary.to).toBe('郑州');
  });

  it('returns "未填写" for empty day', () => {
    const day = makeDay('d1', 0, []);
    const summary = getDaySummary(day);
    expect(summary.from).toBe('未填写');
    expect(summary.to).toBe('未填写');
  });

  it('extracts transport and times from segments', () => {
    const day = makeDay('d1', 0, [
      { id: 's1', from: 'A', to: 'B', transport: 'flight', departTime: '06:30', arriveTime: '09:00' },
      { id: 's2', from: 'B', to: 'C', transport: 'bus', arriveTime: '15:00' },
    ]);
    const summary = getDaySummary(day);
    expect(summary.mainTransport).toBe('flight');
    expect(summary.departTime).toBe('06:30');
    expect(summary.arriveTime).toBe('15:00');
  });
});

describe('ItineraryService - addDay', () => {
  it('adds to empty itinerary', () => {
    const result = addDay([]);
    expect(result.length).toBe(1);
    expect(result[0].dayIndex).toBe(0);
  });

  it('appends when afterIndex not specified', () => {
    const days = [makeDay('d0', 0), makeDay('d1', 1)];
    const result = addDay(days);
    expect(result.length).toBe(3);
    expect(result[2].dayIndex).toBe(2);
  });

  it('inserts after specified index', () => {
    const days = [makeDay('d0', 0), makeDay('d1', 1), makeDay('d2', 2)];
    const result = addDay(days, 0);
    expect(result.length).toBe(4);
    // Original d0 stays at 0, new at 1, d1 at 2, d2 at 3
    expect(result[0].id).toBe('d0');
    expect(result[0].dayIndex).toBe(0);
    expect(result[2].id).toBe('d1');
    expect(result[2].dayIndex).toBe(2);
  });

  it('renumbers all days after insertion', () => {
    const days = [makeDay('d0', 0), makeDay('d1', 1)];
    const result = addDay(days, 0);
    for (let i = 0; i < result.length; i++) {
      expect(result[i].dayIndex).toBe(i);
    }
  });
});

describe('ItineraryService - removeDay', () => {
  it('removes and renumbers', () => {
    const days = [makeDay('d0', 0), makeDay('d1', 1), makeDay('d2', 2)];
    const result = removeDay(days, 'd1');
    expect(result.length).toBe(2);
    expect(result[0].id).toBe('d0');
    expect(result[0].dayIndex).toBe(0);
    expect(result[1].id).toBe('d2');
    expect(result[1].dayIndex).toBe(1); // renumbered
  });

  it('no-op for non-existent id', () => {
    const days = [makeDay('d0', 0)];
    const result = removeDay(days, 'nonexistent');
    expect(result.length).toBe(1);
  });
});

describe('ItineraryService - updateDay', () => {
  it('updates date and note', () => {
    const days = [makeDay('d0', 0)];
    const result = updateDay(days, 'd0', { date: '2025-07-01', note: 'Day 1 note' });
    expect(result[0].date).toBe('2025-07-01');
    expect(result[0].note).toBe('Day 1 note');
  });

  it('updates from/to', () => {
    const days = [makeDay('d0', 0)];
    const result = updateDay(days, 'd0', { from: '成都', to: '拉萨' });
    expect(result[0].from).toBe('成都');
    expect(result[0].to).toBe('拉萨');
  });

  it('clears note with empty string', () => {
    const days = [makeDay('d0', 0)];
    days[0].note = 'old note';
    const result = updateDay(days, 'd0', { note: '' });
    expect(result[0].note).toBeUndefined();
  });

  it('ignores empty from/to (does not clear)', () => {
    const days = [makeDay('d0', 0, [], '原始出发', '原始到达')];
    const result = updateDay(days, 'd0', { from: '', to: '' });
    expect(result[0].from).toBe('原始出发');
    expect(result[0].to).toBe('原始到达');
  });
});

describe('ItineraryService - Segment CRUD', () => {
  it('addSegment appends to day', () => {
    const days = [makeDay('d0', 0, [makeSegment('s1', 'A', 'B')])];
    const newSeg: RouteSegment = { id: 's2', from: 'B', to: 'C', transport: 'bus' };
    const result = addSegment(days, 'd0', newSeg);
    expect(result[0].segments.length).toBe(2);
    expect(result[0].segments[1].id).toBe('s2');
  });

  it('addSegment inserts after index', () => {
    const days = [makeDay('d0', 0, [makeSegment('s1', 'A', 'B'), makeSegment('s3', 'C', 'D')])];
    const newSeg: RouteSegment = { id: 's2', from: 'B', to: 'C', transport: 'walk' };
    const result = addSegment(days, 'd0', newSeg, 0);
    expect(result[0].segments.map(s => s.id)).toEqual(['s1', 's2', 's3']);
  });

  it('removeSegment removes target', () => {
    const days = [makeDay('d0', 0, [makeSegment('s1', 'A', 'B'), makeSegment('s2', 'B', 'C')])];
    const result = removeSegment(days, 'd0', 's1');
    expect(result[0].segments.length).toBe(1);
    expect(result[0].segments[0].id).toBe('s2');
  });

  it('updateSegment patches fields', () => {
    const days = [makeDay('d0', 0, [makeSegment('s1', 'A', 'B')])];
    const result = updateSegment(days, 'd0', 's1', { from: 'X', transport: 'flight' });
    expect(result[0].segments[0].from).toBe('X');
    expect(result[0].segments[0].transport).toBe('flight');
    expect(result[0].segments[0].to).toBe('B'); // unchanged
  });
});

describe('ItineraryService - createEmptySegment', () => {
  it('creates segment with defaults', () => {
    const seg = createEmptySegment();
    expect(seg.id).toContain('seg_');
    expect(seg.from).toBe('');
    expect(seg.to).toBe('');
    expect(seg.transport).toBe('other');
  });
});

describe('ItineraryService - insertDay', () => {
  it('appends and renumbers', () => {
    const days = [makeDay('d0', 0)];
    const newDay: DayItinerary = { id: 'd1', dayIndex: 99, segments: [] };
    const result = insertDay(days, newDay);
    expect(result.length).toBe(2);
    expect(result[1].dayIndex).toBe(1); // renumbered from 99
  });
});
