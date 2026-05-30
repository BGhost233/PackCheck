# Findings

## 代码结构
- GearFilterPanel: 独立组件，固定 height('52%')，内含 Scroll + Flex(wrap) 布局
- GearPage List: `.backgroundColor(CARD_BG)` 纯白背景，CollapsingHeader `.position({x:0,y:0})` 悬浮
- bindContextMenu 当前参数：previewAnimationOptions.scale [0.95,1.08], borderRadius 16
- GearPreviewCard 固定 width(280)

## 避坑清单相关
- 第1条：linearGradient 禁止 Color.Transparent，用 '#00F8F9FA'
- 第7条：同一属性不能同时有 .animation() 和 animateTo()
- CategoryChip 当前有 `.animation({ duration: 260, curve: springMotion(0.25, 0.7) })`，需移除改用 animateTo
