# Findings

## 现有架构发现
- GearItem 已有 `createdAt: number` 字段（毫秒时间戳）
- PackStore 基于 preferences API（Key-Value JSON 存储）
- WeightGauge 是独立 @Component struct，148×148 圆环 + 3 个 StatPill
- WeightGauge 在 GearPage header 折叠区，通过 opacity + scale 控制滚动折叠
- GEAR_HEADER_EXPANDED = 340vp，GEAR_HEADER_COLLAPSED = 56vp
- 圆盘 opacity 在 scrollProgress 40% 时降为 0
