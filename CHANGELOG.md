# Changelog

> 详细 commit 历史见 `git log`。此处只保留近期版本摘要和早期版本一行概述。

## v0.7.12 (2026-06-29)

Index.ets 文件压缩：2346→2255 行（-91 行）。引入 `applyAndPersist` helper 统一封装 18 处重复的 applyChecklistState+saveChecklists 调用对；删除 7 个死方法（代理/计算）+ 8 个死 import；提取 CompletionToast 为独立组件。审计结论：2255 为 Index.ets 合理终态——剩余行全为 @Builder 路由 map、Sheet 调度、动画编排，命中 §8.2 不可拆。

## v0.7.11 (2026-06-29)

SheetContainer 重构：消灭 SheetOverlay "超级传话筒" 反模式。SheetOverlay（382 行，67 个绑定点）→ SheetContainer 纯壳容器（137 行，11 个接口点）。Index.ets trailing lambda 直接构建各子 Sheet，数据流从三跳变为一跳。新增 Sheet 改动点从 3 处降到 1 处。全局净减 ~245 行代码。

## v0.7.10 (2026-06-29)

完整性修复：对抗性审计发现 23 个问题，分 6 阶段系统修复。模型层 clone helper 收口全部手写字面量（DayItinerary/RouteSegment/TicketInfo/ChecklistItem）；PackStore 升级为 singleton + 防抖 flush + 运行时验证 + 容量告警；category 删除/重命名事务化更新；全部 TextInput 加 maxLength + 数值输入范围校验；250+ 处 fontSize 硬编码替换为 Typography token；EntryBackupAbility 升级为 onBackupEx/onRestoreEx 结构化返回。新增 DEVELOPMENT_STANDARDS §4.6 内化模式 / §5.2.1 clone 铁律 / §5.2.2 事务模式 / §7.2 备份恢复。避坑清单 51→54 条。

上帝组件瘦身 Wave 1-2（god-component split）：分 3 轮提取纯计算函数到 services、纯展示 @Builder 提为独立组件。GearService 新增 8 个纯函数（筛选/排序/统计/格式化），ChecklistService 新增 9 个纯函数（倒计时/分组/重量/日期显示）。组件行数变化：HomePage 1099→812（-26%），GearPage 2388→2063（-14%），Index 2388→2260（-5%）。后续瘦身方案 Phase 5-9 见 `.planning/god-component-split/next_plan.md`。

## v0.7.9 (2026-06-26)

多选功能全量删除：移除 GearPage 多选模式及关联状态/方法/回调（~600 行）、删除 GenerateTripSheet 与 MoveGroupSheet 组件、清理 SheetOverlay 路由分支与 SheetMode 常量。全项目净删 877 行。

## v0.7.8 (2026-06-24)

行程编辑模块完整落地。行程详情页新增「行程」Tab（原生 Tabs 左右滑动），支持按天/路段规划行程。含 ItineraryService CRUD 纯函数层、DayCard 手风琴展开、SegmentFormSheet/DayFormSheet 表单、全面交互动效审查、行程详情页审计修复（8 commit）、全量代码审查清理（28 文件净删 786 行）。

## v0.7.7 (2026-06-14)

装备库单品拖拽真机回归：拖拽避让丝滑让位（被拖项留洞 + 兄弟行平移填洞）、松手 optimistic 落位去卡顿、跨分组 spring-load 悬停 500ms 自动展开。

## v0.7.7-perf (2026-06-14)

全面性能优化 8 步：groupByZoneAll 单次分桶、display 缓存、GearPage cache-on-@Watch、拖拽索引 O(1)、TripDetailPage 缓存、gearIndex 父级构建下发、ForEach zoneKey 精确化。

## v0.7.7-cleanup (2026-06-23)

全项目代码审查清理：AnimationUtils 88% 切除、services 死代码删除、timer 泄漏修复 7 文件、hardcode token 化、无用 import 清理。21 文件 +290/-1076。

## v0.7.6 (2026-06-14)

行程详情页顶部收口：navbar 重做（删 ··· 换核查图标 + 高度 56→40）、标题随折叠呼吸（字号插值）、全屏沉浸。

## v0.7.5 (2026-06-13)

顶部折叠交互统一：对齐 iOS Large Title（跟手 1:1 + 松手就近吸附），抽出 HeadCollapseController 统一滚动数学内核，三页迁移对齐。

## 早期版本概述

| 版本 | 日期 | 核心交付 |
|------|------|---------|
| v0.7.4 | 06-13 | 行程详情页格子交互三 Bug 修复 |
| v0.7.3 | 06-13 | 数据一致性修复 + 按压反馈补全 |
| v0.7.2 | 06-12 | 聚焦态满铺精装修 |
| v0.7.1 | 06-11 | UI 质感提升（容器化/转场重构/拖动深化）+ 审查修订 |
| v0.7.0 | 06-11 | 带格子的核查清单统一视图（第二灵魂）|
| v0.6.1 | 06-10 | Sheet 统一 / 配装质量加固 / 文档重组 |
| v0.6.0 | 06-09 | v2 地基层：3 Tab / 人生足迹 / 双段展开 / 配装种子 |
| v0.5.9 | 06-10 | 全量代码审查 213 项修复 |
| v0.5.0–v0.5.8 | 05-29~06-04 | 质感跃迁 / 动效 Token / 多选拖拽 / 分组排序 |
| v0.4.x | 05-28 | 共享元素转场 / Sheet Spring / 折叠屏适配 |
| v0.3.x | 05-27 | 仪式卡片交互 / 动效全面升级 |
| v0.2.0 | 05-26 | 首页体验升级 / 沉浸式布局 |
| v0.1.0 | 05-25 | 核心功能完成（装备 CRUD / 清单核查 / 本地持久化）|
