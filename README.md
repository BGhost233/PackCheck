# PackCheck

鸿蒙原生户外装备管理 & 出行清单核查 App。为户外爱好者打造的「装备整理 → 清单打勾 → 轻装出发」完整工作流，追求 Apple 级别的转场流畅度和微交互密度。

## 项目背景

户外出行前的装备整理是一件繁琐但关键的事——忘带一样东西可能毁掉整趟旅程。PackCheck 用极致的交互体验把这个过程变得愉悦：翻转卡片创建行程、滑动出发确认、Spring 弹性动效贯穿全局。不是工具，是仪式。

## 技术栈

- HarmonyOS NEXT / ArkTS + ArkUI
- DevEco Studio，API 23（SDK 6.1.0）
- 本地持久化：Preferences
- 构建：hvigor

## 当前版本：v0.5.4

### 已实现功能

**装备库管理**：装备 CRUD（名称/分类/重量/价格/备注）、分组折叠展开、筛选面板、重量/价格环形仪表切换。

**出行清单**：创建行程清单、从装备库导入物品、打勾核查、分组折叠、100% 完成庆祝动画、清单编辑（重命名/改日期）。

**仪式感交互**：宝可梦卡牌翻转入场动画、滑动出发确认（正圆滑块骑在轨道上 + 白色遮罩吞噬已滑区域 + 磁吸吸附 + 卡片飘走）、未填名称时输入框抖动+边框闪红、点击空白收起键盘。

**动效体系**：Spring 弹性曲线统一全局、底部胶囊 Tab 果冻 pill 切换、列表 staggered 错落入场（加速度曲线）、折叠头部滚动驱动、geometryTransition 共享元素一镜到底转场、按压三段式反馈、Sheet 面板 Spring 弹性升起/收回。

**视觉质感**：等宽数字 `fontFeature('tnum')`、噪点纹理纸感背景（64×64 noise tile）、Section Breathing 分组呼吸间距、暖琥珀警示色系（接近目标 80-100% 态）、卡片底部微边框。

**基础体验**：全屏沉浸式布局、窗口背景色统一消除闪屏色差、数据持久化。

## 设计规范

**色彩**：主题色 `#2D7D46` 山野绿，背景 `#F8F9FA` 羽白，卡片纯白 + 底部 0.5vp 微边框，圆角 16vp。辅助色 `#E8890C` 暖琥珀（倒计时 ≤3 天 / 重量接近预算 80-100%）。

**动效**：所有动画使用 Spring 弹性曲线（`response: 0.35, dampingFraction: 0.8`），严禁 linear/ease。按压用 `0.25/0.7`，Tab 滑动用 `0.4/0.75`。

**交互**：所有可点击元素必须有按压反馈（scale 三段式）。二级菜单/弹窗必须有过渡动画。列表入场必须 staggered 错落。数字变化必须 counter 滚动。

## 架构概览

```
entry/src/main/ets/
├── pages/Index.ets          — 应用主入口，路由 & 全局状态管理（~2045 行）
├── components/              — UI 组件
│   ├── HomePage.ets         — 首页概览（折叠头部 + 清单列表）
│   ├── GearPage.ets         — 装备库（分组折叠 + 沉浸式头部）
│   ├── ReviewPage.ets       — 核查复盘
│   ├── ChecklistDetail.ets  — 清单详情（打勾核查）
│   ├── TripCeremonyCard.ets — 新建行程仪式卡片（翻转 + 滑动出发）
│   ├── EditGearPanel.ets    — 装备编辑半屏面板
│   ├── EditItemPanel.ets    — 清单项编辑面板
│   ├── GearFilterPanel.ets  — 装备筛选面板
│   ├── WeightGauge.ets      — 重量/价格环形仪表
│   └── sheets/              — Sheet 面板组件（从 Index.ets 提取）
│       ├── SheetOverlay.ets — 遮罩容器 + Sheet 路由
│       ├── GearSortSheet.ets
│       ├── GenerateTripSheet.ets
│       ├── GearFormSheet.ets
│       ├── TripFormSheet.ets
│       ├── TempItemSheet.ets
│       └── ImportSheet.ets
├── models/PackModels.ets    — 数据模型定义
├── services/                — 业务逻辑层
│   ├── PackStore.ets        — Preferences 持久化封装
│   ├── GearService.ets      — 装备业务逻辑（export class GearCalc 聚合导出）
│   └── ChecklistService.ets — 清单业务逻辑（export class CheckCalc 聚合导出）
├── constants/               — 设计 Token
│   ├── DesignTokens.ets     — 颜色/间距/圆角
│   └── AnimationTokens.ets  — Spring 曲线/时长/缩放
└── utils/ColorUtils.ets     — 分组颜色辅助函数
```

## 目录结构

```
PackCheck/
├── AppScope/                — 应用级配置 & 资源
├── entry/                   — 主模块源码
├── docs/
│   ├── design/              — 设计文档
│   │   ├── plans/           — 版本实施计划
│   │   └── specs/           — 设计规格说明
│   └── archive/             — 已完成的历史文档
├── hvigor/                  — 构建配置
├── CLAUDE.md                — AI 协作规范 & 动效避坑清单
├── CHANGELOG.md             — 版本变更记录
└── README.md                — 本文件
```

## 构建 & 运行

```bash
# 构建（需要 DevEco Studio 环境）
hvigorw assembleApp

# 或指定 SDK 路径
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp
```

构建产物位于 `build/` 目录，可通过 DevEco Studio 直接部署到设备或模拟器。

## 版本路线图

| 版本 | 状态 | 主题 |
|------|------|------|
| v0.1.0 | ✅ 已完成 | 核心闭环（装备 CRUD + 清单打勾 + 持久化） |
| v0.2.0 | ✅ 已完成 | 首页体验升级（折叠头部 + 沉浸式布局 + 数据排序） |
| v0.3.0 | ✅ 已完成 | 动效 & 微交互全面升级（Spring 体系 + Tab 果冻 + 错落入场） |
| v0.3.1 | ✅ 已完成 | 仪式卡片交互完善（日期选择 + 抖动提示 + 键盘收起） |
| v0.4.0 | ✅ 已完成 | 动效与转场优化（共享元素一镜到底 + Sheet 弹性动画） |
| v0.4.2 | ✅ 已完成 | 结构重构（Sheet 组件化 + 命名空间导出，Index.ets -18.6%） |
| v0.5.0 | ✅ 已完成 | 质感跃迁（tnum 等宽数字 + 噪点纹理 + Section Breathing + 暖琥珀色系） |
| v0.5.3 | ✅ 已完成 | 清单页 Bug 修复 + 快速核查快捷入口 + 装备库弹性回弹/分组拖拽 |
| v0.5.4 | ✅ 当前 | 装备库 5 项体验优化（搜索展开/拖拽定位/折叠动画/多选点击/托盘滚速） |

## 开发约定

详见 [CLAUDE.md](./CLAUDE.md)，核心原则：

- 用户体验 > 技术偏好 > 代码整洁 > 架构优雅
- 先出方案等确认，再动手写代码
- 每次改动构建验证通过后立即 commit
- 所有动画统一 Spring 弹性曲线，严禁 linear/ease
