# PackCheck 路线图

> 最后更新：2026-06-24 | 当前版本：v0.7.8

---

## 📊 版本总览

| 版本 | 状态 | 核心交付 |
|------|------|---------|
| v0.1–v0.5 | ✅ | 核心闭环 + 动效体系 + 质感打磨 |
| v0.6.0 | ✅ | v2 地基层：3 Tab / 人生足迹 / 双段展开 / 渐进 chip / 配装种子 |
| v0.6.1 | ✅ | Sheet 统一 / 下滑关闭 / 配装质量加固 / 文档重组 |
| v0.7.0 | ✅ | 带格子的核查清单统一视图（第二灵魂）|
| v0.7.1–v0.7.4 | ✅ | UI 质感提升 + 聚焦态精装修 + 数据一致性 + Bug 修复 |
| v0.7.5 | ✅ | 顶部折叠交互统一（对齐 iOS Large Title） |
| v0.7.6 | ✅ | 行程详情页顶部收口 + 全屏沉浸 |
| v0.7.7 | ✅ | 装备库拖拽回归（避让让位 + optimistic 落位 + spring-load 展开）|
| v0.7.7-perf | ✅ | 全面性能优化（cache-on-@Watch + zoneKey 精确化 + O(1) 索引）|
| v0.7.7-cleanup | ✅ | 全面代码审查清理（净删 786 行）|
| v0.7.8 | ✅ | 行程编辑模块（Tabs 滑动 + CRUD + DayCard + 动效审查）|
| v0.8.0 | 🟡 中期 | GearPage 组件瘦身 |
| v1.0.0 | 🟣 远期 | 智能 PackCheck + 成就卡 + 深色模式 |

---

## 未完成单项

- [ ] 行程→装备自动反哺闭环（fromGearId 关联 + FootprintService 已就绪，缺创建行程时触发更新）
- [ ] 聚焦态待真机验收：P3 maxHeight 百分比 / zone_* follow:true 转场平滑度

---

## 🟡 中期（v0.8.0）—— 组件架构瘦身

GearPage 当前 ~2810 行 / 40 @State / 8 个子系统，需提取独立组件降低耦合。

- [ ] 提取 FabController（减 @State -7）
- [ ] 提取 DragToTripOverlay（减 @State -5）
- [ ] 提取 GroupDragController（减 @State -6）
- [ ] 目标：GearPage @State ~12，行数 ~1600

---

## 🟣 远期（v1.0.0）—— 智能 & 沉淀

- [ ] 按行程类型/历史智能推荐装备
- [ ] 轻量成就卡分享（累计里程/爬升/相伴最久伙伴）
- [ ] 深色模式完整支持（Colors token 已预留）
- [ ] 平板/折叠屏适配验证
- [ ] 行程内「已装包」勾选清单交互
- [ ] 授权导入 Strava/佳明轨迹自动算里程

---

## 🔗 关键文档索引

| 文档 | 路径 |
|------|------|
| 开发规范（必读） | `docs/DEVELOPMENT_STANDARDS.md` |
| ArkUI 避坑（52 条） | `memory/MEMORY.md` |
| 变更日志 | `CHANGELOG.md` |
