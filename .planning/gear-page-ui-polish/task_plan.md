# 装备库页面 UI 精细化打磨

## 目标
优化装备库（GearPage）的信息密度、交互反馈和视觉体验，使其从「功能可用」提升到「操作愉悦」。

## 约束
- 不改变现有数据结构（GearItem model 不变）
- 不改变组件层级和数据流（@Prop + callback 模式不变）
- 不影响已有功能（搜索、排序、多选、长按、左滑删除、FAB 等）
- 每项改动独立可回滚（细粒度 commit）
- 每项改动后必须 build 验证通过
- 动效遵循 CLAUDE.md 规范：Spring 弹性曲线，三段式按压，禁止 linear/ease

## 影响范围
| 文件 | 改动类型 |
|------|---------|
| `GearFilterPanel.ets` | Phase 1 + Phase 2 |
| `GearPage.ets` | Phase 3 + Phase 4 + Phase 5 |
| `DesignTokens.ets` | 可能新增常量 |
| `PackStore.ets` | Phase 4（持久化折叠状态） |

---

## Phase 1: 分类面板 Chip 化 — `complete`

### 1.1 CategoryCard 改为自适应宽度胶囊
- 去掉 `.width('30.5%')` 固定宽度
- 改为 `padding({ left: 12, right: 12 })` 内容撑开
- 高度从 42vp → 32vp（紧凑胶囊）
- borderRadius 从 12 → 16（全圆角胶囊感）
- 容器 Flex gap 统一为 `{ row: 8, column: 8 }`

### 1.2 数量角标适配
- 角标位置从 `margin({ top: -6, right: -6 })` 调整为 inline 显示
- 改为名称后方追加 `(n)` 文字，或保持角标但调整偏移量适配新尺寸

### 1.3 容器 padding 优化
- Scroll 内 Flex 的 padding 调整为 `{ left: 16, right: 16, top: 8, bottom: 16 }`

### 预期效果
- 一行可放 4-6 个分类（取决于文字长度）
- 紧凑但不拥挤，分类总数少时一屏可见全部

### 风险评估
- ✅ 不影响筛选逻辑（toggleCategory 不变）
- ✅ 不影响面板弹出/收回动画
- ⚠️ 角标定位需要适配新布局

---

## Phase 2: 分类点击 Spring + 触觉反馈 — `complete`

### 2.1 按压缩放动效
- 新增 @State `pressedCategory: string = ''`
- onTouch(Down) → pressedCategory = category
- onTouch(Up/Cancel) → pressedCategory = ''
- scale: 1 → 0.93（按下）→ 1.0（Spring 回弹）
- curve: `springMotion(0.25, 0.7)`（CLAUDE.md 按压专用参数）

### 2.2 选中态 Spring 动画
- backgroundColor 切换的 animation 从 `EaseInOut 150ms` → `springMotion(0.25, 0.7)`
- 配合 scale 回弹同时变色，形成「弹入+着色」一体化反馈

### 2.3 触觉振动
- 导入 `import { vibrator } from '@kit.SensorServiceKit'`
- 选中/取消选中时触发：`vibrator.startVibration({ type: 'time', duration: 25 })`
- 极轻一击，确认选中的微反馈

### 预期效果
- 点击瞬间有「按下→弹回」的物理感
- 配合手指轻振，建立「已确认选中」的认知闭环

### 风险评估
- ✅ 纯追加逻辑，不影响现有功能
- ⚠️ vibrator 需要 ohos.permission.VIBRATE 权限（检查是否已声明）

---

## Phase 3: 装备卡片精简 — `complete`

### 3.1 去掉冗余分类文字
- GearRow 中移除 `Text(item.category)` 那一行
- 移除 Column({ space: 4 }) 改为直接放 Text(item.name)
- 左侧色条保留，高度从 42vp → 24vp（视觉节奏点，不占主导）

### 3.2 缩小行高
- Row 高度从 64vp → 48vp
- 外层 Column padding 从 `{ top: 14, bottom: 14 }` → `{ top: 10, bottom: 10 }`
- 单卡总高从 92vp → 68vp（节省 26%）

### 3.3 右侧信息精简
- 只保留重量（最核心信息）
- 价格和出行次数移到展开详情中（Detail Builder 已有，无需新增）
- 右侧 Column 变为单行 Text

### 3.4 展开详情中补充被移除的信息
- Detail Builder 已经有分组、重量、价格、出行次数，无需改动
- 确认 Detail 中已有完整信息，精简列表行不丢失数据

### 预期效果
- 同屏可见装备数从 ~7 个提升到 ~10 个
- 视觉更清爽，聚焦装备名称 + 核心数据（重量）
- 信息层级更清晰：列表扫 → 展开详看

### 风险评估
- ✅ 不影响展开详情功能
- ✅ 不影响搜索、排序、多选
- ✅ 不影响左滑删除（swipeAction）
- ⚠️ `gearListIndex()` 和 `bottomSpacerHeight()` 中用了 92vp 估算，需同步更新

---

## Phase 4: 分组折叠状态持久化 — `complete`

### 4.1 PackStore 新增折叠状态存储
- `saveCollapsedGearGroups(groups: string[]): Promise<void>`
- `loadCollapsedGearGroups(): Promise<string[]>`
- 使用 preferences（同 targetWeight 的存储方式）

### 4.2 GearPage 初始化时读取
- `aboutToAppear()` 中调用 loadCollapsedGearGroups
- 结果赋值给 `this.collapsedGearGroups`

### 4.3 折叠/展开时同步写入
- `toggleGearGroupCollapse()` 方法末尾调用 saveCollapsedGearGroups
- 异步写入，不阻塞 UI

### 预期效果
- 用户折叠了不关注的分组后，下次进入保持折叠
- 对于装备较多的用户，减少每次进入的信息噪音

### 风险评估
- ✅ 新增字段 optional（无旧数据迁移问题）
- ✅ 读取失败时降级为空数组（全展开），不影响功能
- ⚠️ 需要确认 PackStore 中 preferences 的 key namespace 不冲突

---

## Phase 5: 搜索关键词高亮 — `complete`

### 5.1 新增高亮文本 Builder
- `@Builder HighlightText(text: string, keyword: string)`
- 将 text 按 keyword 拆分为 Span 数组
- 匹配部分用 PRIMARY_COLOR 着色 + FontWeight.Medium
- 无匹配时直接渲染原文（零开销）

### 5.2 GearRow 中替换名称渲染
- 将 `Text(item.name)` 替换为 `this.HighlightText(item.name, this.gearSearchKeyword)`
- 仅在 keyword 非空时触发拆分逻辑

### 预期效果
- 搜索 "帐" 时，"帐篷" 的 "帐" 字变绿加粗
- 提升搜索结果的可扫描性

### 风险评估
- ✅ 仅影响渲染层，不影响数据逻辑
- ⚠️ Text + Span 的性能在长列表中需注意（ForEach + LazyForEach 已有优化）
- ⚠️ ArkUI 中 Text 内部 Span 的写法需确认语法

---

## Phase 6: 筛选面板匹配数量预览 — `complete`

### 6.1 计算筛选后装备数
- 在 GearFilterPanel 中新增 prop 或 callback 获取当前筛选结果数量
- 或通过 gears + selectedCategories 在面板内部计算

### 6.2 UI 展示
- 在已有的 `已选：xxx` 文案后追加 ` · 共 N 件装备`
- 或在面板底部新增一行统计文案
- 数字变化时配合 counter 滚动动画（~400ms ease-out）

### 预期效果
- 选中/取消分类时实时看到「这次筛选能看到多少装备」
- 减少关闭面板后发现结果不对又要重开的来回操作

### 风险评估
- ✅ 纯展示追加，不影响现有逻辑
- ⚠️ 需要从父组件传入 gears 数据或计算方法

---

## Phase 7: 构建验证 + 收尾 — `complete`

### 7.1 全量构建验证
- `hvigorw assembleApp` 通过
- 无新增 lint warning

### 7.2 回归测试清单
- [ ] 分类面板打开/关闭动画正常
- [ ] 分类选择/取消选中功能正常
- [ ] 多选分类后装备列表正确过滤
- [ ] 装备卡片展开/收起正常
- [ ] 搜索功能正常 + 高亮显示
- [ ] 排序功能正常
- [ ] 多选模式 + 长按进入正常
- [ ] 左滑删除正常
- [ ] FAB 添加装备正常
- [ ] 分组折叠/展开 + 重启后保持状态

### 7.3 Git commit
- 每个 Phase 完成后独立 commit
- commit message 格式：`feat(gear-page): <具体改动描述>`

---

## Phase 8: 长按预览 + Context Menu — `pending`

### 目标
用 `bindContextMenu` + `preview: CustomBuilder` 替代现有 `LongPressGesture`，实现 iOS/鸿蒙原生级的长按预览卡片 + 菜单操作。

### 8.1 新增 GearPreviewCard Builder
- 预览卡片尺寸：宽度 280vp，自适应高度
- 内容：色条 + 装备名称（标题）、分组、重量、价格、出行次数、备注（截断2行）、添加时间
- 圆角 20vp，白色卡片 + 阴影，padding 20
- 风格比列表内的 Detail 更「卡片化」，独立浮动感

### 8.2 新增 GearContextMenu Builder
- 使用 `Menu { MenuItem(...) }` 语法
- 菜单项：编辑、多选、删除
- 每项配 SymbolGlyph 图标 + 文字
- 删除项用 DANGER_COLOR 着色

### 8.3 GearRow 移除 LongPressGesture + 绑定 bindContextMenu
- 移除 `.gesture(LongPressGesture({ duration: 500 })...)`
- 添加 `.bindContextMenu(this.GearContextMenu(item), ResponseType.LongPress, { ... })`
- preview: `this.GearPreviewCard(item)`
- previewAnimationOptions: `{ scale: [0.95, 1.08] }`
- placement: Placement.Bottom

### 8.4 菜单项回调连接
- 编辑 → `this.onOpenEditGear(item)`
- 多选 → `this.onEnterGearMultiSelect(item.id)`
- 删除 → `this.onConfirmDeleteGear(item)`

### 8.5 按压动效兼容性验证
- bindContextMenu 可能接管 touch 事件
- 如果 onTouch 的按压缩放和 bindContextMenu 冲突，需调整

### 预期效果
- 长按 500ms → 卡片浮起 → 预览信息卡 + 菜单弹出
- 系统级动画 + 蒙层模糊
- 菜单操作后恢复原状

### 风险评估
- ✅ API 23 完全支持 bindContextMenu + preview CustomBuilder
- ✅ 不影响 onClick（展开详情）、swipeAction（左滑删除）
- ⚠️ onTouch 按压动效可能需要移除或简化（系统会处理浮起效果）
- ⚠️ 多选模式下不应弹菜单（multiSelectMode 时应保持 Checkbox 点击逻辑）

---

## Phase 9: 构建验证 + 回归 — `pending`

### 9.1 hvigorw assembleApp 通过
### 9.2 回归清单
- [ ] 长按弹出预览卡片 + 菜单
- [ ] 菜单「编辑」正常打开编辑 Sheet
- [ ] 菜单「多选」正常进入多选模式
- [ ] 菜单「删除」正常弹确认
- [ ] 普通点击展开详情不受影响
- [ ] 左滑删除不受影响
- [ ] 多选模式下长按不弹菜单（直接勾选）
- [ ] 搜索/排序/筛选不受影响

---

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| （待填充） | | |
