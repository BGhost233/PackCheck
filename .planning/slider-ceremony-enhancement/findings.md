# 研究发现

## Vibrator API
- 可用 preset: haptic.clock.timer / haptic.effect.soft / haptic.effect.hard / haptic.effect.sharp
- count 参数支持重复振动（count:2 = 双击）
- 项目中已有 haptic.tick 和 haptic.sharp.strong 使用

## ArkUI 动画能力
- backgroundColor 支持 .animation() 平滑过渡
- SymbolGlyph 支持 .rotate()（项目 GearPage 已验证）
- Circle scale+opacity 可实现波纹效果
- .shadow() 颜色动态变化不可靠，改用独立发光层 + opacity

## 现有代码结构
- TripCeremonyCard.ets 约 755 行
- completeSlide() 是核心改动点（298-341行）
- flyAway() 需小幅改进（346-371行）
- 滑轨 UI 在 CeremonyCardFront @Builder 中（663-737行）
