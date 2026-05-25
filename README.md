# PackCheck 🏔️

鸿蒙原生户外装备管理 & 出行清单核查 App。

## 技术栈

- HarmonyOS NEXT
- ArkTS + ArkUI
- API 23
- 本地 Preferences 存储

## 设计风格

PackCheck 采用「光透极简」视觉方向，以山野绿 `#2D7D46` 作为主题色，搭配浅绿状态面、留白卡片、柔和圆角和轻量动效，突出装备核查场景里的清晰、克制和可靠感。

## 文件结构

```text
entry/src/main/ets/
├── pages/
│   └── Index.ets                    # 应用主入口，集中管理页面状态、弹窗、装备库与清单交互流程
├── components/
│   ├── HomePage.ets                 # 首页概览，展示出行清单入口、进度和快捷操作
│   ├── GearPage.ets                 # 装备库页面，负责装备列表、分组筛选、统计和目标重量编辑
│   ├── ChecklistDetail.ets          # 出行清单详情，负责打勾核查、分组折叠和清单明细展示
│   ├── ReviewPage.ets               # 核查复盘/逐项确认视图
│   └── WeightGauge.ets              # 重量仪表组件，用于装备总重与目标重量的可视化
├── services/
│   └── PackStore.ets                # Preferences 持久化服务，保存装备、清单、分类和目标重量
├── models/
│   └── PackModels.ets               # GearItem、ChecklistItem、TripChecklist 等核心数据模型
├── constants/
│   └── DesignTokens.ets             # 颜色、间距、圆角、视图标识和弹窗类型等设计/业务常量
├── utils/
│   └── ColorUtils.ets               # 分组颜色与头图渐变辅助方法
├── entryability/
│   └── EntryAbility.ets             # Stage 模型入口 Ability
└── entrybackupability/
    └── EntryBackupAbility.ets       # 备份恢复 Ability
```

## 本地开发

使用 DevEco Studio 打开项目根目录即可开发、预览和构建。

命令行构建可使用 DevEco Studio 自带的 Hvigor：

```bash
cd /Users/bghost233/Documents/PackCheck
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:$PATH \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon
```

## 设计规范速查表

| Token | Value |
| --- | --- |
| 主色 | `#2D7D46` |
| 浅绿 | `#E8F5E9` |
| 超浅绿 | `#F1F8F3` |
| 背景 | `#F8F9FA` |
| 圆角 | `16vp` |
| 动画 | `250ms EaseInOut` |

## 版本历史

### v0.1.0

当前版本已完成 PackCheck 的核心闭环：

- 装备库 CRUD、分组管理、重量/价格记录与统计面板
- 出行清单创建、打勾核查、装备库导入
- 折叠头部、标签筛选、弹性回弹和 spring 动效
- 本地 Preferences 持久化
