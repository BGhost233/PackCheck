// 塔科夫式配装系统数据种子（第二步实现配装 UI 时使用，地基层只建表）。纲领 §4 / spec §3.5、§6

// 横轴：身体部位 / 容器槽位（纲领 §4.3）
export enum BodyZone {
  Head = 'head',
  UpperBody = 'upper',
  LowerBody = 'lower',
  Feet = 'feet',
  Carry = 'carry',
  Sleep = 'sleep',
  Misc = 'misc',
}

// 纵轴：分层顺序（贴身→最外，纲领 §4.3）
export enum LayerOrder {
  Base = 1,
  Mid = 2,
  Shell = 3,
  Insulation = 4,
  Accessory = 9,
}

export interface SlotHint {
  zone: BodyZone;
  layer: LayerOrder;
}

// 品类 → 默认槽位（弱映射，第二步可手动微调）。key 与 DEFAULT_CATEGORIES 严格一致
export const CATEGORY_SLOT_MAP: Record<string, SlotHint> = {
  '证件':       { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '穿着·上身':  { zone: BodyZone.UpperBody, layer: LayerOrder.Mid },
  '穿着·下身':  { zone: BodyZone.LowerBody, layer: LayerOrder.Base },
  '穿着·配件':  { zone: BodyZone.Head,      layer: LayerOrder.Accessory },
  '背负系统':   { zone: BodyZone.Carry,     layer: LayerOrder.Accessory },
  '行走系统':   { zone: BodyZone.Feet,      layer: LayerOrder.Base },
  '睡眠系统':   { zone: BodyZone.Sleep,     layer: LayerOrder.Accessory },
  '饮食系统':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '电力系统':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '摄影系统':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '安全急救':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '清洁洗护':   { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
  '其他':       { zone: BodyZone.Misc,      layer: LayerOrder.Accessory },
};

// 给定品类返回槽位提示，未命中回退到 Misc/Accessory
export function slotHintForCategory(category: string): SlotHint {
  const hint = CATEGORY_SLOT_MAP[category];
  if (hint !== undefined) {
    return hint;
  }
  const fallback: SlotHint = { zone: BodyZone.Misc, layer: LayerOrder.Accessory };
  return fallback;
}
