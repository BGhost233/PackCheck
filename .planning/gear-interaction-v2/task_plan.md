# 装备交互体验升级 v2

> 目标：解决用户反馈的 4 个核心交互问题，提升格子展开态的操作流畅度和反馈质感
> 状态：planning
> 创建：2026-06-13

---

## 背景

用户在行程详情页的「带格子的核查清单」中反馈了 4 个体验问题：
1. 展开态长按装备缺少「弹菜单→继续拖→格子内排序→拖到边缘→收缩→跨Zone拖拽」的连续手势流
2. 折叠态右上角加号冗余 + 展开态添加框位置不合理（在底部，装备多时需滚动）
3. 长按菜单缺少多选入口 + 多选后缺少批量拖拽能力
4. 点击/长按缺少按压反馈 + 菜单视觉简陋 + 关闭有延迟阻塞交互

---

## 阶段 1：按压反馈补齐 `[pending]`

### 目标
让 ChecklistRow 在所有模式下（网格态双热区 + 聚焦态）都有与装备库一致的按压反馈。

### 技术方案

**文件**：`entry/src/main/ets/components/gear/ChecklistRow.ets`

**改动**：
1. 删除 `checkOnlyHotzone` 对 `onTouch` 按压态的拦截——当前 `checkOnlyHotzone=true` 时 `onTouch` 直接 return，导致网格态/聚焦态无按压反馈
2. 硬编码 `0.96/1.0` 替换为 token `PRESS_SCALE_DOWN/PRESS_SCALE_REST`（从 AnimationTokens.ets 导入）
3. 按压时同步切换背景色：`CARD_BG → GROUP_HEADER_BG`（与 GearPage 对齐）
4. 确保长按触发时保持按压态（scale 0.96 持续），直到菜单弹出或转拖拽

**动画参数**：
- curve: `SPRING_PRESS()`（response 0.25, damping 0.70）
- scale: `PRESS_SCALE_DOWN(0.96) ↔ PRESS_SCALE_REST(1.0)`
- backgroundColor: `CARD_BG(#FFFFFF) → GROUP_HEADER_BG(#F5F5F5)`

**验收标准**：
- [ ] 网格态（折叠态）点击装备行有 scale 0.96 缩放 + 背景色变化
- [ ] 聚焦态（展开态）点击装备行有相同效果
- [ ] 长按 400ms 后保持按压态直到菜单弹出
- [ ] 松手后 Spring 回弹到 1.0，背景色恢复
- [ ] 动画参数全部来自 token，无硬编码
- [ ] 构建通过

---

## 阶段 2：菜单关闭即时响应 + 视觉升级 `[pending]`

### 目标
消除菜单关闭延迟（点击蒙层后立即可交互），升级菜单视觉质感。

### 技术方案

**文件**：
- `entry/src/main/ets/components/gear/UnifiedChecklistView.ets`（关闭逻辑）
- `entry/src/main/ets/components/gear/GearItemContextMenu.ets`（视觉）

**关闭逻辑修复**（UnifiedChecklistView）：
1. 当前问题：关闭时用 `animateTo` + `onFinish` 回调才重置 `overlayPhase`，动画期间点击无效
2. 修复：点击蒙层/菜单项瞬间**立即**将 `overlayPhase` 置为 `'idle'`
3. 退场动画改用 `.animation()` 修饰器驱动（跟随 opacity/scale 状态变化自动播放）
4. 状态切换即时，动画只是视觉过渡，不阻塞后续交互

**视觉升级**（GearItemContextMenu）：
1. 菜单卡片加 `backdropBlur(20)` + 半透明白底 `rgba(255,255,255,0.88)`
2. 预览卡圆角加大到 16vp，与菜单卡间距 8vp
3. 入场动画：scale(0.85→1.0) + opacity(0→1)，curve 用 `SPRING_PANEL_ENTER`
4. transform-origin 对齐长按点位方向（从手指位置展开）
5. 菜单项按压态：背景色过渡 `transparent → GROUP_HEADER_BG`

**验收标准**：
- [ ] 点击蒙层后，下一帧即可进行其他操作（无需等动画播完）
- [ ] 菜单退场有 Spring 缩回动画（scale 1→0.85 + opacity 1→0）
- [ ] 菜单卡片有毛玻璃效果（backdropBlur）
- [ ] 菜单从手指位置方向展开（非固定中心）
- [ ] 菜单项有按压态反馈
- [ ] 构建通过

---

## 阶段 3：添加入口重构 `[pending]`

### 目标
删除折叠态冗余加号按钮，展开态添加框移到顶部。

### 技术方案

**文件**：
- `entry/src/main/ets/components/gear/ZoneGridCell.ets`（删折叠态加号）
- `entry/src/main/ets/components/gear/FocusedZoneView.ets`（添加行移顶部）

**折叠态改动**（ZoneGridCell）：
1. `buildCountTrailing()` 方法中删除小型「+」按钮，只保留数量显示（如「3件」）
2. 删除相关的 `onTapAdd` 回调和 `hitTestBehavior(HitTestMode.Block)` 拦截
3. 用户想添加 → 点格子进展开态 → 顶部就是添加入口

**展开态改动**（FocusedZoneView）：
1. `buildAddRow()` 从 List 末尾（`ListItem` 最后一项）移到 List 顶部（第一项）
2. 视觉不变：虚线框 + 「+ 添加到{Zone}」
3. 多选模式下仍隐藏添加行（现有逻辑保留）

**验收标准**：
- [ ] 折叠态有内容格子标题栏只显示数量，无「+」按钮
- [ ] 折叠态空格子虚线框点击仍可添加（不受影响）
- [ ] 展开态进入后第一眼看到添加行（在列表顶部）
- [ ] 装备列表在添加行下方正常显示
- [ ] 多选模式下添加行隐藏
- [ ] 构建通过

---

## 阶段 4：展开态长按→菜单→拖拽连续手势流 `[pending]`

### 目标
实现展开态「长按弹菜单 → 不放手继续拖 → 菜单收回 → 格子内排序 → 拖到边缘 → 格子收缩 → 跨Zone拖拽」的完整连续手势。

### 技术方案

**文件**：
- `entry/src/main/ets/components/gear/FocusedZoneView.ets`（手势+排序+边缘检测）
- `entry/src/main/ets/components/gear/UnifiedChecklistView.ets`（接收收缩信号+跨Zone拖拽衔接）

**状态机设计**（FocusedZoneView 内部）：

```
idle → [LongPress 400ms] → menu
menu → [Pan > 5vp] → reordering（菜单 Spring 收回）
reordering → [手指X超出边缘阈值] → 触发 onEdgeDragOut 回调
reordering → [手指抬起] → 完成排序，回 idle
menu → [手指抬起] → 保持菜单显示
menu → [点击蒙层/菜单项] → 执行操作，回 idle
```

**格子内排序**（复用现有 reorder 逻辑）：
- 菜单收回后，被拖项浮起（scale 1.03 + shadow + zIndex 100）
- 纵向拖动，其他行让位（translateY 动画）
- 松手完成排序持久化

**边缘检测 → 收缩 → 跨Zone**：
1. 边缘阈值：手指 X 坐标距内容区左/右边界 < 40vp 时触发
2. 触发时调用 `onEdgeDragOut(item, globalX, globalY)` 回调通知 UnifiedChecklistView
3. UnifiedChecklistView 收到信号后：
   - 在 animateTo(SPRING_HERO_COLLAPSE) 内将 `focusedZone` 置空（触发 geometryTransition 收缩）
   - 同时将 `overlayPhase` 切为 `'dragging'`，拖拽胶囊出现在手指位置
   - 胶囊浮在最上层（zIndex 高于网格），收缩动画期间保持跟手
4. 收缩完成后，进入标准跨Zone拖拽流程（命中判定、目标格高亮、自动滚动、落点持久化）

**拖拽胶囊**：
- 复用现有网格态拖拽胶囊样式（圆角胶囊 + 装备名 + 品类 chip）
- 从聚焦态浮起项位置 Spring 过渡到手指跟随位置

**验收标准**：
- [ ] 展开态长按装备 → 弹出菜单+预览
- [ ] 不放手继续拖动 > 5vp → 菜单 Spring 收回，进入格子内排序
- [ ] 格子内纵向拖动，其他行让位动画正确
- [ ] 拖到左/右边缘 → 格子收缩动画（geometryTransition）
- [ ] 收缩期间拖拽胶囊保持跟手，不闪烁
- [ ] 收缩完成后进入跨Zone拖拽，目标格高亮+触觉反馈
- [ ] 松手落在目标格 → moveItemToZone 持久化
- [ ] 松手落回原格 → 取消，装备回原位
- [ ] 全程手指不离开屏幕，体验连续无断裂
- [ ] 构建通过

---

## 阶段 5：多选批量拖拽 `[pending]`

### 目标
长按菜单「选择多个」进入多选模式后，支持多选装备批量拖拽到其他格子。

### 技术方案

**文件**：
- `entry/src/main/ets/components/gear/FocusedZoneView.ets`（多选态长按触发批量拖拽）
- `entry/src/main/ets/components/gear/UnifiedChecklistView.ets`（批量胶囊+批量moveItemToZone）

**交互流程**：
1. 长按菜单点「选择多个」→ 进入多选模式（现有逻辑）
2. 勾选多件装备
3. 长按任一**已选中**项 → 所有选中项合并为「批量胶囊」→ 进入拖拽态
4. 拖到边缘 → 格子收缩 → 跨Zone拖拽（复用阶段4逻辑）
5. 松手落在目标格 → 批量 moveItemToZone

**批量胶囊视觉**：
- 主胶囊显示「N 件装备」文字
- 底部 2 层微错位卡片（translateX +2/+4, translateY +2/+4, opacity 递减）暗示堆叠
- 右上角数量 badge（主题色圆形 + 白色数字）

**批量持久化**：
- `onMoveItemsToZone(ids: string[], targetZone: BodyZone)` 新回调
- Index.ets 中遍历 ids 执行 immutable 更新，一次性持久化

**验收标准**：
- [ ] 多选模式下长按已选中项 → 出现批量胶囊
- [ ] 胶囊显示正确数量 + 堆叠视觉
- [ ] 拖到边缘触发收缩 + 跨Zone拖拽
- [ ] 落在目标格 → 所有选中项移入目标格
- [ ] 落回原格 → 取消，所有项回原位
- [ ] 批量移动后多选模式自动退出
- [ ] 构建通过

---

## 阶段 6：全面验收 `[pending]`

### 验收矩阵

| 维度 | 检查项 | 通过标准 |
|------|--------|----------|
| **按压反馈** | 网格态点击行 | scale 0.96 + 背景色 + Spring 回弹 |
| **按压反馈** | 聚焦态点击行 | 同上 |
| **按压反馈** | 长按保持态 | 按压态持续到菜单弹出 |
| **菜单关闭** | 点蒙层即时性 | 下一帧可交互，无阻塞 |
| **菜单视觉** | 毛玻璃+展开origin | backdropBlur 可见 + 从手指方向展开 |
| **添加入口** | 折叠态无加号 | 标题栏只有数量文字 |
| **添加入口** | 展开态顶部添加 | 进入展开态第一眼看到添加行 |
| **连续手势** | 长按→菜单→拖→排序 | 手指不离屏，状态连续过渡 |
| **连续手势** | 排序→边缘→收缩→跨Zone | geometryTransition 收缩 + 胶囊跟手 |
| **多选拖拽** | 批量胶囊 | 堆叠视觉 + 数量正确 |
| **多选拖拽** | 批量落点 | 所有选中项移入目标格 |
| **代码质量** | token 化 | 无硬编码色值/尺寸/曲线 |
| **代码质量** | 构建通过 | `hvigorw assembleApp` 零错误 |
| **代码质量** | 最小改动 | 不影响现有网格态拖拽/勾选/转场 |
| **动效规范** | Spring 曲线 | 全部使用 AnimationTokens 预设 |
| **动效规范** | 无 duration+Spring 混用 | 错落用 delay 不用 duration |
| **动效规范** | 静止态中性值 | scale=1.0, opacity=0或1 |

### 回归测试清单

- [ ] 网格态点击格子 → 正常进入聚焦态（geometryTransition 不受影响）
- [ ] 网格态长按装备 → 弹菜单 → 拖拽跨Zone（现有流程不受影响）
- [ ] 聚焦态勾选 checkbox → 正常切换勾选态 + 弹跳动画
- [ ] 聚焦态点击装备名 → 正常弹出 GearDetailSheet
- [ ] 空格子点击 → 正常打开 GearPickerSheet
- [ ] 返回键 → 正常关闭聚焦态/退出行程详情
- [ ] 多选模式 → 正常进入/退出 + 批量移除仍可用

---

## 执行顺序与依赖关系

```
阶段1（按压反馈）── 无依赖，独立执行
     ↓
阶段2（菜单关闭+视觉）── 依赖阶段1（按压态与菜单弹出衔接）
     ↓
阶段3（添加入口）── 无依赖，可与阶段1/2并行
     ↓
阶段4（连续手势流）── 依赖阶段2（菜单关闭逻辑是手势流的起点）
     ↓
阶段5（多选批量拖拽）── 依赖阶段4（复用边缘检测+收缩+跨Zone逻辑）
     ↓
阶段6（全面验收）── 依赖全部完成
```

**推荐执行路径**：1 → 2 → 3 → 4 → 5 → 6（线性，每步构建验证后 commit）

---

## 风险与注意事项

| 风险 | 缓解措施 |
|------|----------|
| geometryTransition 收缩期间拖拽胶囊闪烁 | 胶囊用 position absolute + zIndex 999 浮在最上层，不参与 transition |
| 边缘检测误触（用户只是排序拖到边上） | 阈值设 40vp + 需持续 200ms 才触发收缩（防抖） |
| 多选批量拖拽时 ForEach key 变化导致 UI 重建 | 拖拽期间冻结列表渲染，落点后一次性更新 |
| `.animation()` 和 `animateTo` 竞争 | 菜单关闭严格只用 `.animation()` 修饰器，不混用 |
| ChecklistRow 按压态与长按手势冲突 | onTouch Down 设按压态，LongPress 触发时保持，Pan 开始时保持，Up/Cancel 时清除 |

---

## 涉及文件清单

| 文件 | 阶段 | 改动类型 |
|------|------|----------|
| `components/gear/ChecklistRow.ets` | 1 | 按压反馈补齐 |
| `components/gear/UnifiedChecklistView.ets` | 2,4,5 | 菜单关闭+收缩衔接+批量拖拽 |
| `components/gear/GearItemContextMenu.ets` | 2 | 视觉升级 |
| `components/gear/ZoneGridCell.ets` | 3 | 删折叠态加号 |
| `components/gear/FocusedZoneView.ets` | 3,4,5 | 添加行移顶+连续手势+多选拖拽 |
| `pages/Index.ets` | 5 | 新增 onMoveItemsToZone 批量回调 |
