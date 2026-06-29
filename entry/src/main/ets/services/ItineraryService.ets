// 行程日程相关纯业务逻辑 — 数据派生、摘要提取、图标映射、CRUD 纯函数
import { DayItinerary, DayPatch, makeId, RouteSegment, SegmentPatch, TicketInfo, TransportMode } from '../models/PackModels';

// ─── 防腐 Helper：不可变克隆 ────────────────────────────────────────────
// ArkTS 禁止 {...obj} 展开，所有字段逐一拷贝。
// DayItinerary / RouteSegment / TicketInfo 新增 optional 字段，只需在此处补一行。

/** TicketInfo 可覆盖字段 */
export interface TicketInfoOverrides {
  type?: string;
  code?: string;
  price?: number;
  seat?: string;
  note?: string;
}

/**
 * 克隆 TicketInfo，用 overrides 覆盖指定字段。
 * ⚠️ 唯一事实源：所有 TicketInfo 不可变更新必须走此函数。
 */
export function cloneTicketInfo(source: TicketInfo, overrides?: TicketInfoOverrides): TicketInfo {
  return {
    type: overrides?.type !== undefined ? overrides.type : source.type,
    code: overrides?.code !== undefined ? overrides.code : source.code,
    seat: overrides?.seat !== undefined ? overrides.seat : source.seat,
    price: overrides?.price !== undefined ? overrides.price : source.price,
    note: overrides?.note !== undefined ? overrides.note : source.note
  };
}

/** RouteSegment 可覆盖字段（仅限不涉及"清空为 undefined"的场景） */
export interface RouteSegmentOverrides {
  from?: string;
  to?: string;
  transport?: TransportMode;
  departTime?: string;
  arriveTime?: string;
  note?: string;
  ticket?: TicketInfo;
  accommodation?: string;
}

/**
 * 克隆 RouteSegment，用 overrides 覆盖指定字段，其余原样保留。
 * ⚠️ 唯一事实源：所有 RouteSegment 不可变更新必须走此函数或 cloneRouteSegmentFull。
 */
export function cloneRouteSegment(source: RouteSegment, overrides?: RouteSegmentOverrides): RouteSegment {
  return {
    id: source.id,
    from: overrides?.from !== undefined ? overrides.from : source.from,
    to: overrides?.to !== undefined ? overrides.to : source.to,
    transport: overrides?.transport !== undefined ? overrides.transport : source.transport,
    departTime: overrides?.departTime !== undefined ? overrides.departTime : source.departTime,
    arriveTime: overrides?.arriveTime !== undefined ? overrides.arriveTime : source.arriveTime,
    note: overrides?.note !== undefined ? overrides.note : source.note,
    ticket: overrides?.ticket !== undefined ? overrides.ticket : source.ticket,
    accommodation: overrides?.accommodation !== undefined ? overrides.accommodation : source.accommodation
  };
}

/**
 * 全字段克隆 RouteSegment：显式传入每个可选字段（含 undefined = 清空）。
 * 用于 updateSegment 等需要逐字段 patch 的场景。
 */
export function cloneRouteSegmentFull(source: RouteSegment,
  from: string, to: string, transport: TransportMode,
  departTime: string | undefined, arriveTime: string | undefined,
  note: string | undefined, ticket: TicketInfo | undefined,
  accommodation: string | undefined): RouteSegment {
  return {
    id: source.id,
    from: from,
    to: to,
    transport: transport,
    departTime: departTime,
    arriveTime: arriveTime,
    note: note,
    ticket: ticket,
    accommodation: accommodation
  };
}

/** DayItinerary 可覆盖字段（仅限不涉及"清空为 undefined"的场景） */
export interface DayItineraryOverrides {
  dayIndex?: number;
  from?: string;
  to?: string;
  date?: string;
  segments?: RouteSegment[];
  note?: string;
}

/**
 * 克隆 DayItinerary，用 overrides 覆盖指定字段，其余原样保留。
 * ⚠️ 唯一事实源：所有 DayItinerary 不可变更新必须走此函数或 cloneDayItineraryFull。
 */
export function cloneDayItinerary(source: DayItinerary, overrides?: DayItineraryOverrides): DayItinerary {
  return {
    id: source.id,
    dayIndex: overrides?.dayIndex !== undefined ? overrides.dayIndex : source.dayIndex,
    from: overrides?.from !== undefined ? overrides.from : source.from,
    to: overrides?.to !== undefined ? overrides.to : source.to,
    date: overrides?.date !== undefined ? overrides.date : source.date,
    segments: overrides?.segments !== undefined ? overrides.segments : source.segments,
    note: overrides?.note !== undefined ? overrides.note : source.note
  };
}

/**
 * 全字段克隆 DayItinerary：显式传入每个可选字段（含 undefined = 清空）。
 */
export function cloneDayItineraryFull(source: DayItinerary,
  dayIndex: number, from: string | undefined, to: string | undefined,
  date: string | undefined, segments: RouteSegment[],
  note: string | undefined): DayItinerary {
  return {
    id: source.id,
    dayIndex: dayIndex,
    from: from,
    to: to,
    date: date,
    segments: segments,
    note: note
  };
}

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
    return cloneDayItineraryFull(d, d.dayIndex,
      patchFrom !== undefined ? patchFrom : d.from,
      patchTo !== undefined ? patchTo : d.to,
      patch.date !== undefined ? (patch.date.length > 0 ? patch.date : undefined) : d.date,
      d.segments,
      patch.note !== undefined ? (patch.note.length > 0 ? patch.note : undefined) : d.note
    );
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
    return cloneDayItinerary(d, { segments: segs });
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
    return cloneDayItinerary(d, { segments: segs });
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
      return cloneRouteSegmentFull(s,
        patch.from !== undefined ? patch.from : s.from,
        patch.to !== undefined ? patch.to : s.to,
        patch.transport !== undefined ? patch.transport : s.transport,
        patch.departTime !== undefined ? (patch.departTime.length > 0 ? patch.departTime : undefined) : s.departTime,
        patch.arriveTime !== undefined ? (patch.arriveTime.length > 0 ? patch.arriveTime : undefined) : s.arriveTime,
        patch.note !== undefined ? (patch.note.length > 0 ? patch.note : undefined) : s.note,
        patch.ticket !== undefined ? patch.ticket : s.ticket,
        patch.accommodation !== undefined ? (patch.accommodation.length > 0 ? patch.accommodation : undefined) : s.accommodation
      );
    });
    return cloneDayItinerary(d, { segments: segs });
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
    return cloneDayItinerary(d, { dayIndex: i });
  });
}

