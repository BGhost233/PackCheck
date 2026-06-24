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
 * 交通方式 → sys.symbol 图标名映射（字符串，用于文本展示场景）
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

/**
 * 开发期 Mock 数据：模拟 4 天户外行程（成都→日隆→大本营→长坪沟→成都）
 * TODO: Phase 2 移除，改为真实数据
 */
export function createMockItinerary(): DayItinerary[] {
  return [
    {
      id: 'mock-day-1',
      dayIndex: 0,
      date: '2025-05-01',
      note: '抵达日隆镇，采购补给物资',
      segments: [
        {
          id: 'seg-1-1',
          from: '成都双流',
          to: '四姑娘山镇',
          transport: 'bus',
          departTime: '07:00',
          arriveTime: '12:30',
          ticket: { type: '大巴', code: 'CD-SG0501', seat: '前排', price: 158 },
          note: '茶店子客运站出发'
        },
        {
          id: 'seg-1-2',
          from: '四姑娘山镇',
          to: '日隆镇客栈',
          transport: 'walk',
          departTime: '12:45',
          arriveTime: '13:00',
          accommodation: '雪域假日酒店'
        }
      ]
    },
    {
      id: 'mock-day-2',
      dayIndex: 1,
      date: '2025-05-02',
      note: '徒步进山至大本营，海拔 3800m',
      segments: [
        {
          id: 'seg-2-1',
          from: '日隆镇',
          to: '长坪沟口',
          transport: 'drive',
          departTime: '06:30',
          arriveTime: '07:00',
          note: '包车前往沟口'
        },
        {
          id: 'seg-2-2',
          from: '长坪沟口',
          to: '枯树滩',
          transport: 'walk',
          departTime: '07:30',
          arriveTime: '10:00'
        },
        {
          id: 'seg-2-3',
          from: '枯树滩',
          to: '大本营',
          transport: 'walk',
          departTime: '10:30',
          arriveTime: '15:00',
          accommodation: '大本营营地（帐篷）'
        }
      ]
    },
    {
      id: 'mock-day-3',
      dayIndex: 2,
      date: '2025-05-03',
      note: '冲顶日，视天气决定路线',
      segments: [
        {
          id: 'seg-3-1',
          from: '大本营',
          to: '垭口',
          transport: 'walk',
          departTime: '04:00',
          arriveTime: '08:00',
          note: '凌晨出发，注意保暖'
        },
        {
          id: 'seg-3-2',
          from: '垭口',
          to: '大本营',
          transport: 'walk',
          departTime: '09:00',
          arriveTime: '13:00'
        }
      ]
    },
    {
      id: 'mock-day-4',
      dayIndex: 3,
      date: '2025-05-04',
      note: '下撤返回成都',
      segments: [
        {
          id: 'seg-4-1',
          from: '大本营',
          to: '长坪沟口',
          transport: 'walk',
          departTime: '07:00',
          arriveTime: '11:00'
        },
        {
          id: 'seg-4-2',
          from: '长坪沟口',
          to: '日隆镇',
          transport: 'drive',
          departTime: '11:30',
          arriveTime: '12:00'
        },
        {
          id: 'seg-4-3',
          from: '四姑娘山镇',
          to: '成都',
          transport: 'bus',
          departTime: '13:00',
          arriveTime: '18:30',
          ticket: { type: '大巴', code: 'SG-CD0504', price: 158 }
        }
      ]
    }
  ];
}
