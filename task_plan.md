# PackCheck UX/动效/交互优化计划

## 目标声明

作为专业 UX 设计师，从**第一性原理**出发，以 **Apple 等顶级标准**修复并优化用户提出的 10 个 UX/动效/交互问题。每条改动遵循铁律：最小改动、改完即构建验证（hvigorw assembleApp）、构建通过即 git commit、一次只做一件事、不硬编码 token、对照 DEVELOPMENT_STANDARDS + 避坑清单 46 条。

## 设计原则（贯穿全程）

- **第一性原理定方向**：每个交互先问「本质目的 + 用户心理模型」
- **用户体验定标准**：Apple 转场流畅度 / Linear 微交互密度 / Arc 手势自然感
- **技术可行性定路径**：ArkUI API 能力边界，降级也守体验底线
- Spring 弹性曲线全覆盖，严禁 linear/ease；静止态必须中性值（避坑 #17）
- 同属性禁 `.animation()` + `animateTo()` 并存（避坑 #7）

## 前置：处理 3 个未提交遗留改动

上一轮会话遗留改动（与本次 10 问题不冲突）：
- GearPage.ets：折叠组高度估算只算可见分组（Bug1）
- FocusedZoneView.ets：聚焦态子元素点击/长按抑制误触关闭 + gearVersion 刷新（Bug3a/4/5）
- UnifiedChecklistView.ets：移除废弃 renderNonce，改用 gearVersion

状态：`pending`
动作：构建验证 → 若通过则单独 commit，给本次优化一个干净起点。

---

## 执行顺序与阶段

按「低风险高确定性 → 高复杂度」排序，每阶段独立 commit。

### 阶段 1：问题1 — 长按装备直角深灰矩形边框
- 状态：`pending`
- 文件：`components/gear/ChecklistRow.ets` 第144行
- 根因：`.backgroundColor(this.pressed ? '#33000000' : TRANSPARENT)` — 半透明黑 + Row 无圆角 = 直角深灰矩形，收缩态+聚焦态共用此组件
- 方案：按压态改为带圆角的柔和高亮（圆角 12vp + 极淡主题色/中性灰填充，如 `#0A000000` 或 zoneFill 同源淡色），加 scale 微反馈。静止态保持 TRANSPARENT（避坑 #17）

### 阶段 2：问题5 — 格子收缩态展示 5 个装备（当前 4）
- 状态：`pending`
- 文件：`components/gear/ZoneGridCell.ets` 第32行
- 根因：`MAX_PREVIEW_ITEMS: number = 4`
- 方案：改 5；验证 cellHeight 容纳（GRID_ROW_HEIGHT=32，5 行需复核首屏密度反算 FIRST_SCREEN_ROWS 是否需同步调整，避免溢出裁剪）

### 阶段 3：问题3 — Check 按钮按下震动反馈
- 状态：`pending`
- 文件：`components/gear/ChecklistRow.ets`（onCheckedChange 第68行已有 hapticTick 但仅状态翻转时触发）
- 根因：触觉只在 toggle 完成时响，非「按下即响」
- 方案：在 check 命中区的 onTouch Down（TouchType.Down）即触发 hapticTick/hapticSoft，符合 Apple「按下即反馈」直觉

### 阶段 4：问题6 — 创建行程大卡片标题扫光糟糕
- 状态：`pending`
- 文件：`components/TripCeremonyCard.ets` 第964-972行 shimmer + 第248-261行 startTitleShimmer
- 根因：60vp 宽光带在 20vp 高 clip 标题行平移，灰色格子扫过感
- 方案：重做扫光为高级感金属光泽（更窄柔和光带 + 渐变羽化边缘 + 合适周期，参考 Apple/高端品牌文字微光），消除「灰格子扫过」

### 阶段 5：问题8 — 装备齐全庆祝动画（克制高级方向）
- 状态：`pending`
- 文件：`pages/Index.ets` showAchievement() 第1940行（同时弹 CompletionToast emoji 横幅 + showToastMessage 文字 = 双庆祝叠加）+ CompletionToast @Builder 第2695行
- 根因：双庆祝叠加 + emoji 风 + 遮挡内容 + 可读性低 + 动效生硬
- 方案（用户选**克制高级**）：去掉 emoji 横幅，统一为一个克制优雅的庆祝（如顶部细线进度满格脉冲 / 主题色微光 + 一句简洁文案），不遮挡内容，Spring 入退场，可读性优先

### 阶段 6：问题7 — 核查页面卡片滑动无动效生硬
- 状态：`pending`
- 文件：`components/ReviewPage.ets` 第202行 `.translate({x: reviewDragX})` + PanGesture 第203-217行
- 根因：仅跟手平移，松手后 reviewIndex 直接跳变 = 硬切，无旋转/缩放/透明度/飞出飞入
- 方案：卡片堆叠式切换 — 跟手平移 + 旋转/缩放/透明度联动，松手按方向飞出 + 下张卡飞入归位，全 Spring

### 阶段 7：问题2 — 选择装备 Sheet 滑动生硬 + head 不折叠
- 状态：`pending`
- 文件：`components/sheets/GearPickerSheet.ets` 第196-207行 Scroll 列表 + head 第117-133行
- 根因：列表 Scroll 无 `.edgeEffect(EdgeEffect.Spring)`（滑动僵硬）+ head 固定不折叠（信息密度低）
- 方案：① 列表加 EdgeEffect.Spring 回弹；② head 随滚动渐进折叠（走 HeadCollapseController，禁止重写滚动数学，对齐避坑 #46 + DEVELOPMENT_STANDARDS §4.3）；③ 列表入场 staggered 错落

### 阶段 8：问题4 — 网格收缩态底部两格滚到某位置消失
- 状态：`pending`（**动手前必须先构建复现确认根因**）
- 文件：`components/gear/UnifiedChecklistView.ets` buildGridState 第837-930行
- 疑似根因：Grid 未设 `.cachedCount()`，屏幕外 GridItem 被虚拟化回收 → 末行（杂项+倒数行）某滚动位置消失。或 cellHeight 反算 + bottom padding 100 导致内容总高不足
- 方案：先构建在真机/模拟器复现 → 确认是 cachedCount 还是高度计算 → 针对性修（优先 `.cachedCount(足量)` 防回收，或修正内容高度）

### 阶段 9：问题10 — 装备库单品长按编辑菜单不好看、信息密度低、文本框太大
- 状态：`pending`
- 文件：`components/EditGearPanel.ets`（name 第120行/note 第177行 都是 48vp 大文本框，字段竖排 16vp 松散）
- 根因：居中大弹窗，文本框过高，字段排布松散
- 方案：重设计为紧凑高密度面板 — 文本框降高（单行 name ~40vp、note 多行但克制）、字段间距收紧、视觉层级清晰，Apple 表单密度标准

### 阶段 10：问题9 — 装备库单品长按拖动排序 + 拖到其它分类（both）
- 状态：`pending`（**最复杂，放最后**）
- 文件：`components/GearPage.ets`（已有 group 级 groupDragMode 第124/1952-2052行可复用；单品当前是 bindContextMenu 第1526-1539行无拖拽）
- 用户拍板：**both**（组内排序 + 跨分类移动）；触发方案：**长按先弹二级菜单，手指一旦拖动→收起菜单进入拖拽态**（参考行程详情页 UnifiedChecklistView 长按拖拽 GestureGroup(LongPress+Pan) 范式）
- 方案：把单品 bindContextMenu 改为 GestureGroup(Sequence: LongPress 弹自绘菜单 → Pan 触发即收菜单进拖拽)；拖拽态复用 group 拖拽的 splice+spring 让位+碰撞检测+持久化；落点判定支持组内重排 + 跨分类移动；持久化 gear 顺序 + category

---

## 最终审查阶段
- 状态：`pending`
- 全量构建验证 `hvigorw assembleApp` 通过
- 对照 10 个问题逐条核对是否达标
- 检查无 token 硬编码、无 .animation()+animateTo() 冲突、静止态中性值
- 确认所有改动已 commit（细粒度回滚点）

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| (待记录) | | |
