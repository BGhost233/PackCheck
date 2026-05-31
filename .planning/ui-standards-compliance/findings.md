# 审计发现

## 色值审计
- 共 146 处硬编码色值分布在 20 个文件中
- 最重灾区：GearPage(39)、TripCeremonyCard(27)、ChecklistDetail(10)
- 需新增约 35 个 Colors token
- 可直接映射现有 token 约 35 处

## 动画参数审计
- 共 95+ 处硬编码动画参数
- Curve.EaseInOut 使用 5 处（全部 ChecklistDetail）
- Curve.EaseOut 使用约 20 处
- 裸调 curves.springMotion 约 55 处
- 硬编码 duration 约 70 处
- 需新增 8 个 Duration token + 5 个 Ceremony Duration + 8 个 Spring token

## 按压反馈审计
- 8 个文件完全缺失按压反馈
- GearPage 装备行用 backgroundColor 变色（非标准）
- GearSortSheet 静态 scale（非动态响应）
