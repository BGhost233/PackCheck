# 进度日志

## 会话 2026-05-26

### 探索阶段
- 读取所有核心文件（Index.ets, HomePage.ets, PackStore.ets, PackModels.ets, DesignTokens.ets, build-profile.json5）
- SDK 验证：确认 HDS 枚举值正确（IMMERSIVE=101, ADAPTIVE=10）
- 视觉原型：创建折叠头部和 Tab 栏对比预览（http://localhost:63871）
- 设计文档已写入 docs/superpowers/specs/2026-05-26-homepage-ux-upgrade-design.md

### 实现阶段
- ✅ 阶段1: Index.ets 数据排序修复 — checklists.sort by createdAt desc
- ✅ 阶段2: Index.ets HDS修复 — HdsTabs 显式宽高 + BottomTabBar 毛玻璃降级
- ✅ 阶段3: HomePage.ets 折叠头部 — 全部融入 Scroll + onScroll 驱动动画
- ✅ 阶段4: UI打磨 — HeroCard 点击保护 + 紧凑副标题 + 毛玻璃 bar
- ✅ ArkTS 编译验证通过

### 验收完成
- ✅ DevEco Studio 完整构建 + 真机运行 — 效果很好，验证通过

## 会话 2026-05-26 (续)

v0.2.0 全部阶段完成，准备进入下一轮迭代。

## 会话 2026-05-26 (续2) — 导航+Tab+滚动动效

### Phase 1: 返回导航修复 ✅
- Index.ets: 用 `Navigation` + `NavPathStack` 替代 `currentView` 组件显隐
- 新增 `NavDestinationMap` @Builder 管理 ChecklistDetail/ReviewPage 路由
- 新增 `onBackPress()` 根页面拦截 + Toast「再滑一次退出」+ 2秒二次确认
- `openChecklist/returnToHome/openReviewMode/exitReviewMode` 改用 pushPathByName/pop
- `createChecklist/generateChecklistFromSelectedGears` closeSheet 后 push
- 移除 `animateViewTransition()` 及相关状态
- 简化 `startShakeListening()` 去掉 currentView 判断
- Tab 切换不进栈（仅切 currentView + HdsTabsController）

### Phase 2: Tab 悬浮修复 ✅
- HdsTabs gradientMask: maskHeight 92→32, maskColor 加透明度 (#FFF1F3F5→#66F1F3F5)
- HomePage.ets: 底部 padding 108→100, GearPage.ets: 底部 padding 112→100
- 两页 padding 统一为 100vp

### Phase 3: 滚动边缘模糊渐隐 ✅
- 新建 `EdgeFade.ets` 复用组件 (EdgeFade + EdgeFadeBottom)
- HomePage: Scroll 外层 Stack 叠加 top/bottom 渐变
- GearPage: List 外层 Stack 叠加 top/bottom 渐变
- hitTestBehavior(Transparent) 不拦截触摸
- top fade 由 scrollProgress/gearFadeProgress 驱动, bottom fade 常显

### Phase 4: Tab 布局重构 ✅
- 移除 HdsTabs/HdsTabsController/hdsMaterial/deviceInfo 导入
- 用 Tabs + .barHeight(0) + TabsController 替代 HdsTabs
- CapsuleTabBar 作为 Stack overlay 悬浮，.backgroundBlurStyle(BlurStyle.Thin) 毛玻璃
- 新增 @State currentTabIndex + TabsController 驱动 Tab 切换
- 新增 CapsuleTabItem()，currentTabIndex 驱动选中态 + pressedTabIndex 按压反馈
- 移除 shouldShowBottomTabs()/HdsMainTabs()/BottomTabBar()/BottomTabItem()

### Bug 修复 v2 ✅
- **白屏修复(重做)**: NavDestinationMap 中给 ChecklistDetail/ReviewPage 加显式 `NavDestination()` 包装 + `.hideTitleBar(true)`，确保子页面内容区有正确的布局约束
- **返回按钮删除**: 移除 `.titleMode(NavigationTitleMode.Mini)` — 根页面不是 NavDestination，不需要系统返回按钮
- **全面屏适配**: Navigation 加 `.hideTitleBar(true)` + `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])` — 内容延伸到状态栏/导航栏区域
- **灰框修复(重做)**: Tabs `.backgroundColor(Color.Transparent)` 透到底层，Stack 根容器设 `.backgroundColor(PAGE_BG)` 作为唯一背景源

### 验证
- ArkTS 编译通过 (CompileArkTS)
- HAP 打包 + 签名通过 (PackageHap + SignHap + SignApp)
