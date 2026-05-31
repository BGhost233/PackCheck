# 装备资产趋势曲线 — 实施计划

## 目标
替换 WeightGauge 圆盘组件为资产趋势曲线，提供装备价值成长叙事。

## 设计规格
详见 `docs/superpowers/specs/2026-05-31-asset-trend-curve-design.md`

---

## Phase 1: 数据层 — `in_progress`
- [ ] 1.1 在 PackModels.ets 新增 AssetEvent interface
- [ ] 1.2 在 PackStore.ets 新增 assetEvents 读写方法
- [ ] 1.3 在 GearPage.ets 植入事件触发点（add/remove/edit）
- [ ] 1.4 实现历史数据回填逻辑
- [ ] 1.5 构建验证

## Phase 2: 组件骨架 — `pending`
- [ ] 2.1 创建 AssetTrendCard.ets 组件基础结构
- [ ] 2.2 实现标题行（当前总价 + 辅助标签）
- [ ] 2.3 实现统计卡片行（件数 / 本月新增 / 重量）
- [ ] 2.4 实现空状态
- [ ] 2.5 在 GearPage 中替换 WeightGauge 为 AssetTrendCard
- [ ] 2.6 构建验证

## Phase 3: Canvas 曲线绘制 — `pending`
- [ ] 3.1 Canvas 组件 + onAreaChange 获取尺寸
- [ ] 3.2 数据点映射算法（assetEvents → canvas 坐标）
- [ ] 3.3 贝塞尔平滑曲线绘制
- [ ] 3.4 渐变填充
- [ ] 3.5 里程碑圆点绘制
- [ ] 3.6 时间标签
- [ ] 3.7 构建验证

## Phase 4: 入场动画 — `pending`
- [ ] 4.1 drawProgress 状态 + animateTo 驱动
- [ ] 4.2 曲线裁剪绘制（基于 drawProgress）
- [ ] 4.3 里程碑点弹出动画
- [ ] 4.4 构建验证

## Phase 5: 滑动交互 — `pending`
- [ ] 5.1 onTouch 手势识别（水平滑动）
- [ ] 5.2 参考线 + 高亮圆点跟随
- [ ] 5.3 顶部数字实时变化 + 日期显示
- [ ] 5.4 事件浮层（触摸到有事件的节点时弹出）
- [ ] 5.5 触觉反馈（里程碑点/事件节点振动）
- [ ] 5.6 松手恢复动画
- [ ] 5.7 构建验证

## Phase 6: 滚动折叠 + 收尾 — `pending`
- [ ] 6.1 复用现有折叠逻辑（opacity + scale）
- [ ] 6.2 GEAR_HEADER_EXPANDED 高度微调
- [ ] 6.3 全量功能验证
- [ ] 6.4 git commit

---

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
