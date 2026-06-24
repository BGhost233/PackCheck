// 行程日程相关纯业务逻辑 — 数据派生、摘要提取、图标映射
import { DayItinerary, TransportMode, TripChecklist } from '../models/PackModels';

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
 * 交通方式 → sys.symbol 图标名映射
 */
export function getTransportIconName(mode: TransportMode): string {
  switch (mode) {
    case 'flight':
      return 'airplane';
    case 'train':
      return 'tram';
    case 'bus':
      return 'bus';
    case 'drive':
      return 'car';
    case 'walk':
      return 'figure.walk';
    case 'bike':
      return 'bicycle';
    case 'boat':
      return 'ferry';
    default:
      return 'arrow.right';
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
