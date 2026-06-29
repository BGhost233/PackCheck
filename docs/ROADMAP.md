# PackCheck 路线图

> 最后更新：2026-06-29 | 当前版本：v0.7.11

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
| v0.7.9 | ✅ | 多选功能全量删除（GearPage 瘦身 -600 行，净删 877 行）|
| v0.7.10 | ✅ | 完整性修复 + 上帝组件瘦身 Wave 1-2（纯计算下沉 services + GearPage/HomePage/Index 瘦身）|
| v0.7.11 | ✅ | SheetContainer 重构：消灭 SheetOverlay 超级中继，trailing lambda 纯壳容器（原 Phase 6 Sheet 解耦，已完成）|
| v0.8.0 | 🟡 中期 | 上帝组件瘦身 Phase 5/7/8/9（@Builder 子组件化 → 状态分组 → 交互控制器 → 最终收口） |
| v1.0.0 | 🟣 远期 | 智能 PackCheck + 成就卡 + 深色模式 |

---

## 未完成单项

- [ ] 行程→装备自动反哺闭环（fromGearId 关联 + FootprintService 已就绪，缺创建行程时触发更新）
- [ ] 聚焦态待真机验收：P3 maxHeight 百分比 / zone_* follow:true 转场平滑度

---

## 🟡 中期（v0.8.0）—— 上帝组件瘦身（Phase 5/7/8/9）

> 已完成：Wave 1-2（纯计算下沉 + 纯展示 @Builder 提取） + Phase 6 SheetContainer 解耦（v0.7.11 已交付）。
> 效果：HomePage 1099→812, GearPage 2388→2063, SheetOverlay 382行删除→SheetContainer 137行。
> 完整方案见 `.planning/god-component-split/next_plan.md`。

**Phase 5 — @Builder 子组件化**（低风险，带自己状态的 @Builder 提为独立 @Component）
- [ ] GearPage: 拖拽浮层 FloatingGroupCard / GearGroupSection / GearItemRow
- [ ] Index.ets: ChecklistCard / EmptyHomeView / HeroContent
- [ ] 预期：GearPage -200~300 行，Index -150~200 行

~~**Phase 6 — SheetContainer 解耦**~~ ✅ 已在 v0.7.11 完成（方式：trailing lambda 纯壳而非 Manager 组件，效果更优）

**Phase 7 — 状态分组**（中风险，减 @State）
- [ ] GearPage: DragState / FilterState 分组管理器
- [ ] Index: SheetState / NavigationState 分组管理器
- [ ] 预期：@State 净减 30-40%

**Phase 8 — 交互控制器**（高风险，触及动画状态机）
- [ ] GearPage: FabController / GroupDragController 提取
- [ ] 必须对照 §8.2 「不该拆」清单

**Phase 9 — 最终收口**
- [ ] 目标：Index < 2000，GearPage < 1500，HomePage < 700
- [ ] 全量审计 + 文档同步

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
| ArkUI 避坑（54 条） | `memory/MEMORY.md` |
| 变更日志 | `CHANGELOG.md` |
