# PackCheck 路线图

> 最后更新：2026-06-10 | 当前版本：v0.6.1

---

## 已完成

### ✅ 第一步 · 地基层（v0.6.0）

v2「服役档案」转型的基础全部就位：3 Tab、数据字段、人生足迹年报、装备双段展开、渐进 chip 录入、配装数据种子。

### ✅ Sheet 体系统一 + 配装质量加固（v0.6.1）

9 种 Sheet 全部走集中式 SheetOverlay + 下滑关闭手势 + 景深参数统一。配装系统三轮深度审查修复（7 Critical @State mutation + timer 泄漏 + 退场动画 + counter 脱同步 + 空态 + NaN 防御 + 按压反馈补全）。

---

## 🔵 短期（v0.7.0）—— 带格子的核查清单（统一视图）

> **来源**：产品愿景纲领 §4（v3 修订）+ 技术 spec §6 + 地基层计划第二步。这是 PackCheck 的第二个灵魂。

### 背景

纲领文档定义了两个灵魂：服役档案（经历连接）和带格子的核查清单（科学打包）。前者已在地基层落地。后者的核心是：预设身体部位格子作为清单的分组骨架，用户在格子里填装备 + 出发前逐项打勾，一个统一界面完成全部。

### 任务清单

- [ ] **合并配装/清单为统一视图**：砍掉行程详情页的 SegmentButton（配装/清单 Tab 切换），合并 LoadoutView + ChecklistDetail 为一个统一组件
- [ ] **格子始终可见**：7 个身体部位分区（头部/上身/下身/鞋/背负/睡眠/杂项）始终展示，用 `GearLoadout.ets` 中已有的 `BodyZone`/`LayerOrder` 枚举 + `CATEGORY_SLOT_MAP` 映射表
- [ ] **空态设计**：空格子收缩为紧凑标题 + 虚线框占位区（虚线边框 + 中心「+」图标），点击添加；有内容的格子展开为完整卡片
- [ ] **衣物格子纵轴分层**：装备按 `category` 查表自动归入格子，衣物格子内按层级排序（贴身→保暖→防风）
- [ ] **长按拖拽跨区流转**（核心能力）：长按 item 450ms 进入拖拽态，跟手浮动卡片可跨 Zone 放置，松手更新 item.group。参考华为变单四象限拖拽。优先 LongPress+Pan 自实现，降级走系统 onDragStart/onDrop
- [ ] **行程→装备自动反哺闭环**：填完行程足迹自动喂给装备陪伴卡片（地基层已铺好 `fromGearId` 关联、`FootprintService` 聚合，缺的是创建行程时自动更新关联装备统计的触发逻辑）

### 参考文档
- `docs/v2-foundation/specs/2026-06-22-unified-checklist-view-design.md`（**主 spec**：统一核查清单视图完整设计，含 UI/交互/技术/路线）
- `docs/vision/2026-06-04-product-vision-and-restructure.md` §4（v3 修订：格子即清单，一体不分家）
- `docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md` §6（带格子的核查清单 spec）
- `entry/src/main/ets/constants/GearLoadout.ets`（已预埋的格子分组映射数据）

---

## 🟡 中期（v0.8.0）—— 组件架构瘦身

> **来源**：2026-06-10 代码审查 §3 + 本次设计文档 Tasks G-H-I。

### 背景

GearPage 当前 ~2270 行，26 个 @State，9 个 @Prop，承担 8 个独立子系统。需要将自包含的子系统提取为独立组件，降低耦合度和单个文件复杂度。

### 任务清单

- [ ] **提取 FabController**：FAB 拖拽定位 + 边缘吸附 + 重量编辑器弹窗。减少 GearPage @State -7。接口：`@Link targetWeightGram` + `@Prop gearCount/totalWeightGram/totalPriceYuan` + `onOpenAddGear`
- [ ] **提取 DragToTripOverlay**：装备拖拽到行程托盘的模态浮层。减少 GearPage @State -5，回调 -2。接口：`@Prop dragMode/dragStartX/dragStartY/checklists/selectedMultiGearIds` + `onAddGearsToTrip/onAddGearsToNewTrip/onCancelDrag`
- [ ] **提取 GroupDragController**：分组长按拖拽重排序。减少 GearPage @State -6。接口：`@Prop groupDragMode/dragGroupName/dragGroupCount/dragStartY/groupOrder/groupCardHeights` + `onReorderComplete`
- [ ] **GearPage 最终状态**：@Prop ~8，回调 ~13，@State ~12，组件行数 ~1600（符合规范）

### 参考文档
- `docs/design/plans/2026-06-10-sheet-unification-swipe-dismiss-gearpage-slim.md`（已删除该文件，内容已整合到此路线图中；完整设计方案见 plan 文件）

---

## 🟣 远期（v1.0.0）—— 智能 & 沉淀

> 这些是产品愿景中的第三步（智能）内容，优先级低于统一清单视图，但在其完成后自然成为下一步。

### L2 智能 PackCheck

- [ ] 按行程类型/目的地/历史主动提示"你这次可能需要带 X"
- [ ] 还没打勾的装备置顶提醒
- [ ] 基于历史行程的智能推荐

### 轻量成就卡分享

- [ ] 「我」Tab 生成可分享的成就卡图片（非主轴、克制、锦上添花）
- [ ] 包含关键数字（累计里程/爬升/相伴最久伙伴）+ 留白设计

### 体验打磨

- [ ] 深色模式完整支持（Colors token 体系已预留，`dark/color.json` 已配置启动色）
- [ ] 平板/折叠屏适配验证（module.json5 已声明 tablet/2in1）
- [ ] 无障碍：关键操作元素添加 `.accessibilityText()`
- [ ] 全局按压反馈补全（~30 个缺失点已在代码审查中标记）

### 可选的体验增强

- [ ] 行程内「已装包」勾选清单交互（L1 packing，`ChecklistItem.checked` 数据底座已就绪）
- [ ] 装备陪伴履历时间轴下钻（第二步可后置）
- [ ] 授权导入两步路/佳明/Strava 轨迹自动算里程/海拔（远期）

---

## 📊 版本总览

| 版本 | 状态 | 核心交付 |
|------|------|---------|
| v0.1–v0.5 | ✅ | 核心闭环 + 动效体系 + 质感打磨 |
| v0.6.0 | ✅ | v2 地基层：3 Tab / 人生足迹 / 双段展开 / 渐进 chip / 配装种子 |
| v0.6.1 | ✅ | Sheet 统一 / 下滑关闭 / 文档重组 |
| v0.7.0 | 🔵 短期 | 带格子的核查清单统一视图（第二灵魂） |
| v0.8.0 | 🟡 中期 | GearPage 组件瘦身 |
| v1.0.0 | 🟣 远期 | 智能 PackCheck + 成就卡 + 深色模式 |

---

## 🔗 关键文档索引

| 文档 | 用途 | 路径 |
|------|------|------|
| 开发规范 | 架构/设计语言/动效/组件规范（每次写代码前必读） | `docs/DEVELOPMENT_STANDARDS.md` |
| 产品愿景 | v2 服役档案转型纲领（方向性决策的最高依据） | `docs/vision/2026-06-04-product-vision-and-restructure.md` |
| 技术 spec | v2 工程落地完整设计（数据模型 diff + 交互逻辑 + 文案词典） | `docs/v2-foundation/specs/2026-06-09-service-archive-restructure-design.md` |
| 地基层计划 | 第一步可执行实现计划（已完成，留作参考） | `docs/v2-foundation/plans/2026-06-09-service-archive-foundation.md` |
| ArkUI 避坑 | 37 条实战踩坑记录（动效/手势/布局问题先查） | `memory/MEMORY.md` |
