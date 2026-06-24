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
 * 从一天的 segments 提取收缩态摘要：首尾地名 + 主交通方式 + 首尾时间
 */
export function getDaySummary(day: DayItinerary): DaySummary {
  // 优先用天级 from/to；旧数据无此字段时 fallback 到 segments 首尾
  const dayFrom = (day.from !== undefined && day.from.length > 0)
    ? day.from
    : (day.segments.length > 0 ? day.segments[0].from : '未填写');
  const dayTo = (day.to !== undefined && day.to.length > 0)
    ? day.to
    : (day.segments.length > 0 ? day.segments[day.segments.length - 1].to : '未填写');

  // 交通方式和时间从 segments 取（它们是路段级概念）
  const mainTransport: TransportMode = day.segments.length > 0 ? day.segments[0].transport : 'other';
  const departTime = day.segments.length > 0 ? day.segments[0].departTime : undefined;
  const arriveTime = day.segments.length > 0 ? day.segments[day.segments.length - 1].arriveTime : undefined;

  return { from: dayFrom, to: dayTo, mainTransport: mainTransport, departTime: departTime, arriveTime: arriveTime };
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
 * 插入一个已构建好的 DayItinerary（由表单组装）。追加到末尾，dayIndex 自动重排。
 */
export function insertDay(itinerary: DayItinerary[], day: DayItinerary): DayItinerary[] {
  const result = itinerary.slice();
  result.push(day);
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
    // patch 语义：undefined=不修改，''=显式清空，string=新值
    // from/to 为空字符串时视为 undefined（防御性忽略，不允许清空必填字段）
    const patchFrom = (patch.from !== undefined && patch.from.length > 0) ? patch.from : undefined;
    const patchTo = (patch.to !== undefined && patch.to.length > 0) ? patch.to : undefined;
    const updated: DayItinerary = {
      id: d.id,
      dayIndex: d.dayIndex,
      from: patchFrom !== undefined ? patchFrom : d.from,
      to: patchTo !== undefined ? patchTo : d.to,
      segments: d.segments,
      date: patch.date !== undefined ? (patch.date.length > 0 ? patch.date : undefined) : d.date,
      note: patch.note !== undefined ? (patch.note.length > 0 ? patch.note : undefined) : d.note
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
    return { id: d.id, dayIndex: d.dayIndex, from: d.from, to: d.to, date: d.date, note: d.note, segments: segs } as DayItinerary;
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
    return { id: d.id, dayIndex: d.dayIndex, from: d.from, to: d.to, date: d.date, note: d.note, segments: segs } as DayItinerary;
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
      // patch 语义：undefined=不修改，''=显式清空，有值=新值
      const updated: RouteSegment = {
        id: s.id,
        from: patch.from !== undefined ? patch.from : s.from,
        to: patch.to !== undefined ? patch.to : s.to,
        transport: patch.transport !== undefined ? patch.transport : s.transport,
        departTime: patch.departTime !== undefined ? (patch.departTime.length > 0 ? patch.departTime : undefined) : s.departTime,
        arriveTime: patch.arriveTime !== undefined ? (patch.arriveTime.length > 0 ? patch.arriveTime : undefined) : s.arriveTime,
        note: patch.note !== undefined ? (patch.note.length > 0 ? patch.note : undefined) : s.note,
        ticket: patch.ticket !== undefined ? patch.ticket : s.ticket,
        accommodation: patch.accommodation !== undefined ? (patch.accommodation.length > 0 ? patch.accommodation : undefined) : s.accommodation
      };
      return updated;
    });
    return { id: d.id, dayIndex: d.dayIndex, from: d.from, to: d.to, date: d.date, note: d.note, segments: segs } as DayItinerary;
  });
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
    return { id: d.id, dayIndex: i, from: d.from, to: d.to, date: d.date, note: d.note, segments: d.segments } as DayItinerary;
  });
}

