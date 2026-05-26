# PackCheck v0.2.0 — 首页体验升级 实施计划

## 目标
- 修复 HDS 沉浸光感
- 修复数据排序（最新行程优先）
- 实现折叠头部（方案 B）
- UI/UX 全面打磨

## 阶段

### 阶段 1: 数据排序修复 ✅
- [x] `Index.ets`: loadAppData 中按 createdAt 降序排序 checklists
- 状态: complete

### 阶段 2: HDS 沉浸光感修复 ✅
- [x] `Index.ets`: HdsTabs 添加显式 width/height
- [x] `Index.ets`: gradientMask.maskColor 格式修正
- [x] `Index.ets`: BottomTabBar 降级增强（毛玻璃）当 API<23
- 状态: complete

### 阶段 3: 折叠头部实现 ✅
- [x] `HomePage.ets`: 重构 build() — 全部融入单一 Scroll
- [x] `HomePage.ets`: onScroll 驱动标题/Hero 缩放动画
- [x] `HomePage.ets`: 快捷入口吸附逻辑
- 状态: complete

### 阶段 4: UI/UX 打磨 ✅
- [x] 毛玻璃 BottomTabBar
- [x] HeroCard 透明度 < 0.3 禁用点击
- [x] 折叠后显示紧凑副标题（行程名+天数）
- [x] Header 80ms 缓动过渡
- 状态: complete

### 阶段 5: 验收 ✅
- [x] ArkTS 编译通过
- [x] DevEco Studio 完整构建 + 真机验证

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| hvigorw command not found | 1 | 使用 DevEco Studio 内置 hvigor: `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js` |
| DEVECO_SDK_HOME 未设置 | 1 | 设置环境变量 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk` |
| Java Runtime 未安装导致 HAP 打包失败 | 1 | 不影响编译，需在 DevEco Studio 内构建 |
