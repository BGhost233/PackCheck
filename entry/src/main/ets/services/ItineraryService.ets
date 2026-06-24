// 行程日程相关纯业务逻辑 — 数据派生、摘要提取、图标映射、CRUD 纯函数
import { DayItinerary, DayPatch, makeId, RouteSegment, SegmentPatch, TransportMode } from '../models/PackModels';

/**
 * 日摘要数据（供 DayCard 收缩态展示）
 */
export interface DaySummary {
  from: string;
  to: string;
  mainTransport: TransportMode;
  departTime: string | undefined;
  arriveTime: string | undefined;
}

/**
 * 从 itinerary 派生行程全局 meta 信息（日期、时长等）。
 * itinerary 为源，TripChecklist.dateAt/date 为派生。
 */
export function deriveTripMeta(itinerary: DayItinerary[]): TripMetaDerived {
  if (itinerary.length === 0) {
    return { dateAt: undefined, date: undefined, durationHours: undefined };
  }
  const firstDay = itinerary[0];
  const lastDay = itinerary[itinerary.length - 1];

  // 首日日期 → TripChecklist.dateAt / date
  let dateAt: number | undefined = undefined;
  const dateStr: string | undefined = firstDay.date;
  if (dateStr !== undefined && dateStr.length > 0) {
    const parsed = Date.parse(dateStr);
    if (!Number.isNaN(parsed)) {
      dateAt = parsed;
    }
  }

  // 推算总时长（可选：首日首段出发 → 末日末段到达）
  let durationHours: number | undefined = undefined;
  if (firstDay.segments.length > 0 && lastDay.segments.length > 0) {
    const firstDepart = firstDay.segments[0].departTime;
    const lastArrive = lastDay.segments[lastDay.segments.length - 1].arriveTime;
    if (firstDepart !== undefined && lastArrive !== undefined && dateStr !== undefined && lastDay.date !== undefined) {
      const startMs = Date.parse(dateStr + 'T' + firstDepart + ':00');
      const endMs = Date.parse(lastDay.date + 'T' + lastArrive + ':00');
      if (!Number.isNaN(startMs) && !Number.isNaN(endMs) && endMs > startMs) {
        durationHours = Math.round((endMs - startMs) / 3600000 * 10) / 10;
      }
    }
  }

  return { dateAt: dateAt, date: dateStr, durationHours: durationHours };
}

/**
 * deriveTripMeta 的返回类型
 */
export interface TripMetaDerived {
  dateAt: number | undefined;
  date: string | undefined;
  durationHours: number | undefined;
}

/**
 * 从一天的 segments 提取收缩态摘要：首尾地名 + 主交通方式 + 首尾时间
 */
export function getDaySummary(day: DayItinerary): DaySummary {
  if (day.segments.length === 0) {
    return { from: '未填写', to: '未填写', mainTransport: 'other', departTime: undefined, arriveTime: undefined };
  }
  const firstSeg = day.segments[0];
  const lastSeg = day.segments[day.segments.length - 1];
  return {
    from: firstSeg.from,
    to: lastSeg.to,
    mainTransport: firstSeg.transport,
    departTime: firstSeg.departTime,
    arriveTime: lastSeg.arriveTime
  };
}

/**
 * 交通方式 → SymbolGlyph Resource（用于 SymbolGlyph 组件）
 */
export function getTransportIcon(mode: TransportMode): Resource {
  switch (mode) {
    case 'flight':
      return $r('sys.symbol.airplane');
    case 'train':
      // HarmonyOS 无 tram/train symbol，复用 map 表达路线
      return $r('sys.symbol.map');
    case 'bus':
      // HarmonyOS 无 bus symbol，复用 map 表达路线
      return $r('sys.symbol.map');
    case 'drive':
      return $r('sys.symbol.car');
    case 'walk':
      return $r('sys.symbol.figure_walk');
    case 'bike':
      return $r('sys.symbol.bicycle');
    case 'boat':
      // HarmonyOS 无 ferry/boat symbol，复用 map 表达路线
      return $r('sys.symbol.map');
    default:
      return $r('sys.symbol.arrow_right');
  }
}

/**
 * 交通方式 → 中文标签
 */
export function getTransportLabel(mode: TransportMode): string {
  switch (mode) {
    case 'flight':
      return '飞机';
    case 'train':
      return '火车';
    case 'bus':
      return '大巴';
    case 'drive':
      return '自驾';
    case 'walk':
      return '徒步';
    case 'bike':
      return '骑行';
    case 'boat':
      return '轮船';
    default:
      return '其他';
  }
}

// ============ CRUD 纯函数（全部 immutable，返回新数组） ============

/**
 * 新增一天。afterIndex 为插入位置的 index（插入到该位置之后），
 * 省略或越界则追加到末尾。dayIndex 自动重排。
 */
export function addDay(itinerary: DayItinerary[], afterIndex?: number): DayItinerary[] {
  const newDay: DayItinerary = {
    id: makeId('day'),
    dayIndex: 0, // 下方 renumber
    segments: []
  };
  const result = itinerary.slice();
  const insertAt = (afterIndex !== undefined && afterIndex >= 0 && afterIndex < result.length)
    ? afterIndex + 1
    : result.length;
  result.splice(insertAt, 0, newDay);
  return renumberDays(result);
}

/**
 * 删除一天（按 dayId）。dayIndex 自动重排。
 */
export function removeDay(itinerary: DayItinerary[], dayId: string): DayItinerary[] {
  const result = itinerary.filter((d) => d.id !== dayId);
  return renumberDays(result);
}

/**
 * 更新一天的元信息（date/note），不影响 segments。
 */
export function updateDay(itinerary: DayItinerary[], dayId: string, patch: DayPatch): DayItinerary[] {
  return itinerary.map((d) => {
    if (d.id !== dayId) {
      return d;
    }
    const updated: DayItinerary = {
      id: d.id,
      dayIndex: d.dayIndex,
      segments: d.segments,
      date: patch.date !== undefined ? patch.date : d.date,
      note: patch.note !== undefined ? patch.note : d.note
    };
    return updated;
  });
}

/**
 * 在指定 day 中新增一段路程。afterIndex 为插入位置（省略追加末尾）。
 */
export function addSegment(
  itinerary: DayItinerary[],
  dayId: string,
  segment: RouteSegment,
  afterIndex?: number
): DayItinerary[] {
  return itinerary.map((d) => {
    if (d.id !== dayId) {
      return d;
    }
    const segs = d.segments.slice();
    const insertAt = (afterIndex !== undefined && afterIndex >= 0 && afterIndex < segs.length)
      ? afterIndex + 1
      : segs.length;
    segs.splice(insertAt, 0, segment);
    return { id: d.id, dayIndex: d.dayIndex, date: d.date, note: d.note, segments: segs } as DayItinerary;
  });
}

/**
 * 删除指定 day 中的一段路程。
 */
export function removeSegment(itinerary: DayItinerary[], dayId: string, segmentId: string): DayItinerary[] {
  return itinerary.map((d) => {
    if (d.id !== dayId) {
      return d;
    }
    const segs = d.segments.filter((s) => s.id !== segmentId);
    return { id: d.id, dayIndex: d.dayIndex, date: d.date, note: d.note, segments: segs } as DayItinerary;
  });
}

/**
 * 更新指定 day 中的一段路程（patch 模式）。
 */
export function updateSegment(
  itinerary: DayItinerary[],
  dayId: string,
  segmentId: string,
  patch: SegmentPatch
): DayItinerary[] {
  return itinerary.map((d) => {
    if (d.id !== dayId) {
      return d;
    }
    const segs: RouteSegment[] = d.segments.map((s) => {
      if (s.id !== segmentId) {
        return s;
      }
      const updated: RouteSegment = {
        id: s.id,
        from: patch.from !== undefined ? patch.from : s.from,
        to: patch.to !== undefined ? patch.to : s.to,
        transport: patch.transport !== undefined ? patch.transport : s.transport,
        departTime: patch.departTime !== undefined ? patch.departTime : s.departTime,
        arriveTime: patch.arriveTime !== undefined ? patch.arriveTime : s.arriveTime,
        note: patch.note !== undefined ? patch.note : s.note,
        ticket: patch.ticket !== undefined ? patch.ticket : s.ticket,
        accommodation: patch.accommodation !== undefined ? patch.accommodation : s.accommodation
      };
      return updated;
    });
    return { id: d.id, dayIndex: d.dayIndex, date: d.date, note: d.note, segments: segs } as DayItinerary;
  });
}

/**
 * 按给定 id 顺序重排天列表。dayIndex 自动重排。
 */
export function reorderDays(itinerary: DayItinerary[], orderedIds: string[]): DayItinerary[] {
  const idMap = new Map<string, DayItinerary>();
  itinerary.forEach((d) => idMap.set(d.id, d));
  const result: DayItinerary[] = [];
  orderedIds.forEach((id) => {
    const day = idMap.get(id);
    if (day !== undefined) {
      result.push(day);
    }
  });
  return renumberDays(result);
}

/**
 * 创建新路段（带默认值）。
 */
export function createEmptySegment(): RouteSegment {
  return {
    id: makeId('seg'),
    from: '',
    to: '',
    transport: 'other'
  };
}

// --- 内部工具 ---

function renumberDays(days: DayItinerary[]): DayItinerary[] {
  return days.map((d, i) => {
    if (d.dayIndex === i) {
      return d;
    }
    return { id: d.id, dayIndex: i, date: d.date, note: d.note, segments: d.segments } as DayItinerary;
  });
}

