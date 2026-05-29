# 质感跃迁施工计划 (Texture Quality Uplift)

## 目标
在不影响当前已实现功能的前提下，通过低成本高回报的视觉细节改动，将 PackCheck 的界面质感从「功能完整」提升到「值得截图」。

## 约束
- 不改变现有数据结构（向后兼容）
- 不改变组件层级结构和数据流
- 每项改动独立可回滚（细粒度 commit）
- 每项改动后必须 build 验证通过
- Shape+Path 控制点 ≤ 30 个/组件（性能安全线）
- 滚动驱动动画必须直接赋值 + .animation()，禁止 animateTo（避坑清单 #3）

---

## Phase 1: 一行代码级提升 ✅ COMPLETE
- [x] 1.1 fontFeature tnum 等宽数字
- [x] 1.2 卡片底部微边框
- [x] 1.3 错落动画加速度曲线
- [~] 1.4 长按编辑态微倾斜（跳过，无功能入口）

## Phase 2: 小模块级提升 ✅ COMPLETE
- [x] 2.1 噪点纹理背景
- [x] 2.2 打勾墨水扩散（已回滚，实机效果不佳）
- [x] 2.3 Section Breathing 组间呼吸
- [x] 2.4 暖琥珀点缀色

---

## Phase 3: 特性级提升（户外品牌视觉识别）
**状态：** `in_progress`

### 3.1 HeroCard 山脊线装饰
- **目标：** 给首页 HeroCard 底部添加极淡山脊轮廓线，强化户外品牌识别
- **改动点：**
  - HeroCard 内部 Column 底部新增 `Shape { Path(commands) }` 组件
  - 使用 viewBox 相对坐标（宽度跟随卡片 100%），高度固定 40vp
  - 颜色：当前 heroGradientStart 色的 alpha 15% 版本（如 `'#26C8E6C9'` 或 `'#26FFF5E6'`）
  - 山脊线为 2-3 条起伏曲线，贝塞尔控制点 ≤ 15 个
  - 无交互逻辑，纯装饰
- **影响范围：** 仅 HomePage.ets 的 HeroCard @Builder
- **风险：** ⚠️ 低
  - Shape 在 geometryTransition 动画中跟随卡片整体 scale/opacity，无需特殊处理
  - 渐变色渗透规则：用 heroGradientStart 同色相 + 低 alpha，避免 Color.Transparent 灰带问题
- **验收：** 卡片底部有极淡起伏山脊线，正常使用几乎不可见，细看才感知，不影响任何触摸操作
- **回滚：** 删除 Shape 组件

### 3.2 GearPage Header 等高线视差
- **目标：** 装备库折叠 Header 背景添加等高线纹理，随滚动做 0.3x 慢速视差，增强深度感
- **改动点：**
  - GearPage CollapsingHeader 内部最底层新增一个 `Shape` 组件（等高线纹路 = 3-4 条间隔平行曲线）
  - 颜色：`#0A2D7D46`（主题绿 alpha ~4%）
  - 位置：absolute 定位在 header 内，width 100%，height = GEAR_HEADER_EXPANDED
  - 视差驱动：`translateY = -(gearScrollOffset * 0.3)`，直接赋值，输出端加 `.animation({ duration: 80, curve: Curve.EaseOut })`
  - `.clip(true)` 已在 header 上，展开内容折叠后等高线自然被裁剪
- **影响范围：** 仅 GearPage.ets 的 CollapsingHeader @Builder
- **风险：** ⚠️ 低
  - 不修改现有 7 个 scroll-driven 属性的逻辑
  - Shape 在 Stack 最底层，不影响 hitTestBehavior(Transparent)
  - 等高线 opacity 极低（4%），即使轻微偏移也不会造成视觉冲突
- **验收：** 展开 header 时可见极淡等高线纹路；滚动时纹路以 0.3x 速度上移，产生微妙深度差；完全折叠后纹路不可见
- **回滚：** 删除 Shape 组件

### 3.3 空状态矢量插画
- **目标：** 为三个空状态场景添加极简线条画，赋予品牌温度
- **改动点：**
  - 新增 `components/EmptyIllustration.ets` 组件，接收 `type: 'gear' | 'trip' | 'complete'` 参数
  - 三套 Path 数据（每套 ≤ 25 控制点）：
    - **gear（装备库空）**：一个极简背包轮廓 + 一条山脊线
    - **trip（首页无行程）**：蜿蜒山路 + 远处山峰轮廓
    - **complete（清单全完成）**：山顶旗帜 + 简笔云朵
  - 颜色：主题绿 `#2D7D46` 的 alpha 20%（`'#332D7D46'`），线宽 1.5vp
  - 尺寸：width 120vp × height 100vp，居中
  - 入场动画：opacity 0→1 + translateY(8→0) + spring(0.4, 0.8)
  - 替换 GearPage EmptyState 的纯文字 / HomePage EmptyHero 的 SymbolGlyph
  - ChecklistDetail EmptyText 保持不变（场景太小不适合插画）
- **影响范围：** 新增 EmptyIllustration.ets + 修改 GearPage.ets EmptyState() + HomePage.ets EmptyHero()
- **风险：** ⚠️ 低
  - 纯新增组件，空状态 = 无数据时才显示，不影响有数据时的任何逻辑
  - Path 控制点严格 ≤25，不会有渲染性能问题
  - @Builder 内不声明变量（避坑清单 #14），path commands 作为 static readonly 类属性预定义
- **验收：** 空状态有品牌识别度的线条画 + 温暖文案 + spring 入场；插画风格统一（同色、同线宽、同极简度）
- **回滚：** 删除 EmptyIllustration.ets + 恢复原 EmptyState/EmptyHero 内容

---

## 执行顺序

| 步骤 | 任务 | 预估改动量 | 依赖 |
|------|------|-----------|------|
| 1 | 3.3 空状态矢量插画 | ~120 行新增 | 无 |
| 2 | 3.1 HeroCard 山脊线装饰 | ~30 行新增 | 无 |
| 3 | 3.2 GearPage Header 等高线视差 | ~40 行新增 | 无 |
| 4 | 全量构建验证 + 全局视觉检查 | — | 1-3 |

**顺序理由：** 3.3 最独立（新文件），先做风险最低；3.1 和 3.2 都是在现有组件内部加层，顺序无强依赖，但 3.1 更简单先做。

---

## 验收标准（Phase 3）

### 功能完整性
- [ ] 装备库 CRUD 全流程正常
- [ ] 清单创建 → 导入 → 打勾 → 庆祝全流程正常
- [ ] geometryTransition 共享元素转场正常
- [ ] 折叠头部滚动跟随正常（GearPage + HomePage）
- [ ] FAB 拖拽吸附正常

### 视觉质感
- [ ] HeroCard 底部有极淡山脊线（侧看才感知）
- [ ] GearPage header 展开时有等高线纹路 + 滚动视差
- [ ] 空状态有品牌线条画 + spring 入场
- [ ] 三个插画风格统一（同色相、同线宽、同极简度）

### 性能
- [ ] Shape Path 渲染无帧率下降
- [ ] 等高线视差无卡顿（直接赋值 + animation 80ms）
- [ ] 空状态入场动画流畅

### 构建
- [ ] `hvigorw assembleApp` 构建通过
- [ ] 每项改动独立 commit

---

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| Phase 2.2 墨水扩散实机效果差 | 1 | git revert，ArkUI Circle 动画在列表场景渲染质量不足 |

---

## 明确不做清单
| 方案 | 原因 |
|------|------|
| 山脊线上的进度指示标记 | 需贝塞尔采样插值，复杂度 > 收益 |
| Header 拆双层视差 | 现有 7 属性联动过于复杂，调试风险大 |
| ChecklistDetail 空状态插画 | 场景太小（单行文字足够），加插画反而臃肿 |
| 复杂 SVG 插画（>50 控制点） | ArkUI Shape 渲染性能安全线 |
