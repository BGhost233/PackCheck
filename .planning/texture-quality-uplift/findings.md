# 研究发现

## ArkUI Shape + Path 能力确认（API 23）

### 可用属性
- `Shape { Path() }` 支持标准 SVG path commands（M/L/C/Q/A/Z）
- `viewPort({ width, height })` 设置逻辑坐标系
- `stroke(color)` / `strokeWidth(vp)` / `fill(color)` / `strokeLineCap` / `strokeLineJoin`
- `antiAlias(true)` 默认开启

### 性能观察（Phase 2 教训）
- Circle + scale/opacity 动画在列表高频场景渲染质量不足（边缘锯齿）
- Shape+Path 静态渲染性能良好，控制点 < 50 无压力
- 建议控制在 25-30 控制点以内确保极致流畅

### 颜色处理规则
- 避坑清单 #1：gradient 中禁用 Color.Transparent
- 装饰性 Shape 颜色用同色相低 alpha（如 `'#262D7D46'` = 主题绿 15% alpha）
- 不要混色相：山脊线/等高线用绿色系，警示相关用琥珀色系

## GearPage 折叠 Header 现状

### scroll-driven 属性（7 个）
1. title fontSize: 28 → 18
2. ring opacity: 1 → 0 (p=0.4 消失)
3. ring scale: 1 → 0.6
4. pill opacity: 1 → 0 (p=0.5 消失)
5. collapsed summary opacity: 0 → 1 (p>0.5 出现)
6. expanded content height: (340-56)*(1-p) → 0
7. background blur: NONE → Thin → Regular

### 关键约束
- `hitTestBehavior(Transparent)` — 新增层不能拦截触摸
- `.clip(true)` 已在展开内容区 — 超出高度自动裁剪
- 滚动驱动值直接赋值（避坑清单 #3），animation 只加在输出端

## HomePage HeroCard 现状

### 结构
- Column(space:16) + padding(20) + borderRadius(20) + linearGradient(135°)
- geometryTransition 参与共享元素转场
- scroll-driven: opacity + scale
- 高度由内容撑开（~180-200vp）

### 装饰层位置选择
- 卡片底部 Shape 作为 Column 最后一个子组件
- 高度 40vp，width 100%
- 不需要 Stack 包裹（直接流式布局在底部）

## 空状态现状

| 位置 | 当前实现 | 改造计划 |
|------|---------|---------|
| GearPage EmptyState | 240vp Column + 文字 + 按钮 | 加插画（背包轮廓） |
| HomePage EmptyHero | 220vp Column + SymbolGlyph(camp) + 文字 + CTA | 替换 icon 为插画（山路） |
| HomePage 历史空 | 64vp 纯文字 | 不改（太小） |
| ChecklistDetail EmptyText | 纯文字 | 不改（场景不适合） |

## 插画 Path 数据设计原则

- 极简主义：4-6 笔勾勒意境，不追求写实
- 统一线宽 1.5vp
- 统一颜色 `'#332D7D46'`（主题绿 20% alpha）
- 无 fill，纯 stroke（线条画风格）
- 控制点 ≤ 25/插画
- viewPort 统一 120×100（逻辑像素）
