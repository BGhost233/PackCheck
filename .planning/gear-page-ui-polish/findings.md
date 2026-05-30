# 装备库 UI 优化 — 研究发现

## 现有代码结构

### GearFilterPanel.ets (222 行)
- CategoryCard Builder：固定 `width: 30.5%`，高 42vp，Flex wrap 布局
- 面板高度 52%，顶部弹出 + Spring 动画 + backdrop blur
- 已有 `已选：xxx` 状态提示文案
- 无按压动效，仅 150ms EaseInOut 颜色过渡

### GearPage.ets (1127 行)
- GearRow Builder：行高 64vp + padding 14*2 = 92vp 总高
- 显示字段：名称 + 分类文字 + 左侧色条 + 重量/价格/出行次数
- 已有按压缩放（scale 0.97），但非三段式
- 已有 swipeAction 左滑删除
- `collapsedGearGroups: string[]` 为 @State，但不持久化
- `bottomSpacerHeight()` 硬编码 92vp/装备估算

### 触觉振动
- Index.ets 中 Tab 切换已使用 `vibrator.startVibration({ type: 'time', duration: 50 })`
- 权限已声明（否则 Tab 切换也不会振）
- GearFilterPanel 中无 vibrator 引用

### 搜索功能
- GearPage 有 `gearSearchKeyword` prop
- filteredGears() 中用 `indexOf(keyword)` 匹配
- GearRow 渲染时不做高亮，直接 Text(item.name)

## ArkUI 技术确认

### Text + Span 高亮方案
```typescript
Text() {
  Span('普通文字').fontSize(16).fontColor(TEXT_MAIN)
  Span('高亮').fontSize(16).fontColor(PRIMARY_COLOR).fontWeight(FontWeight.Medium)
  Span('普通文字').fontSize(16).fontColor(TEXT_MAIN)
}
```
ArkUI 支持 Text 内嵌 Span，可用于关键词高亮。

### vibrator 导入
```typescript
import { vibrator } from '@kit.SensorServiceKit';
```
需要 `ohos.permission.VIBRATE` 权限（已在项目中声明）。

### Preferences 持久化
PackStore 中已有 preferences 读写模式（saveGearTargetWeight / loadGearTargetWeight），可直接复用。
