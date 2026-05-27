# PackCheck 项目记忆

## 工作流约定

- **每次改动即 commit**：每次修改构建验证通过后，立即 `git add -A && git commit`，保持细粒度回滚点，方便随时回滚。
- **构建命令**：`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp`
- **先出方案再动手**：任何需求先输出理解+方案+理由，确认后才写代码。

## 设计决策

- 新建行程采用「宝可梦卡牌翻转」仪式感入场动画
- 确认按钮采用「长按蓄力→发射起飞」交互（全宽绿色按钮 + 底部进度条 + 三段缩放抖动 + 弹射）
- 主题色 `#2D7D46` 山野绿
- 所有动画使用 Spring 弹性曲线，严禁 linear/ease

## 架构

- 已从 Index.ets 提取独立组件：TripCeremonyCard、EditGearPanel、EditItemPanel、GearFilterPanel
- 已删除废弃组件：EdgeFade.ets
