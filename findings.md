# 研究发现

## HDS SDK 验证
- `MaterialType.IMMERSIVE = 101` ✅ 值正确
- `MaterialLevel.ADAPTIVE = 10` ✅ 值正确
- `HdsTabsFloatingStyle` 接口: barWidth, barSideMargin, barBottomMargin, gradientMask(HdsTabsBackgroundStyle), miniBar, systemMaterialEffect
- `HdsTabsBackgroundStyle`: maskColor(ResourceColor), maskHeight(number)
- `SystemMaterialParams`: materialType(MaterialType), materialLevel(MaterialLevel)
- HdsTabs 从 `@hms.hds.hdsBaseComponent` 导出，通过 `@kit.UIDesignKit` 重导出

## 数据排序
- `createChecklist()` 会 prepend 新数据（`[created, ...existing]`）
- 但 PackStore 从 preferences 读取时不排序
- HomePage.latestChecklist() 取 [0]，可能拿到最老的
- 修复：loadAppData 中排序
