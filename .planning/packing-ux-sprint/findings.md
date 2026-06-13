# 研究发现

## 代码架构分析

### 状态刷新机制
- 所有 checklist 变更统一走 `applyChecklistState` → `checklistRenderNonce++`
- nonce 被拼入 ForEach key，强制整段 ForEach 重建（暴力但可靠）
- `saveGear()` 编辑后也手动 `checklistRenderNonce++`

### GearPickerSheet 设计
- 无状态选择器：`selectedItemIds` 完全由父级 `@Prop` 传入
- toggle 即时回调父级执行 add/remove，不自管选中态
- 用 `Scroll > Column > ForEach`（非 LazyForEach），全量渲染
- `groupedGears()` 每次 build 重算，无缓存

### 拖拽系统现状
- 双阶段：LongPress(400ms) → Pan(5vp) 触发
- 状态机：`'idle' | 'menu' | 'dragging'`
- 拖拽中锁死 Grid 滚动：`enableScrollInteraction(this.overlayPhase !== 'dragging')`
- `zoneRects` 静态收集，滚动后失效
- 无边缘自动滚动机制

### FocusedZoneView 手风琴展开
- `@State expandedItemId: string | null` 控制
- ForEach key: `item.id + '_' + (expanded?'e':'c')`
- 展开区 `buildItemDetail(item)` 显示品类/重量/品牌 chips + 备注
- 长按只弹菜单浮层，不做拖拽

### ForEach Key 策略汇总
| 组件 | Key 生成 | 备注 |
|------|----------|------|
| ZoneGridCell | `item.id` | 依赖 nonce 强制刷新 |
| FocusedZoneView | `item.id + '_' + expanded` | 展开态变化触发重建 |
| GearPickerSheet rows | `gear.id + '_' + selected` | 选中变化触发重建 |
| GearPage | `item.id` | 纯 id |

### AnimationTokens 关键预设
| Token | 参数 | 用途 |
|-------|------|------|
| SPRING_PANEL_ENTER | 0.38, 0.72 | 面板升起 |
| SPRING_PANEL_EXIT | 0.30, 0.88 | 面板收回 |
| SPRING_GENERAL | 0.35, 0.8 | 通用 |
| SPRING_PRESS | 0.25, 0.7 | 按压 |
| SPRING_HERO_EXPAND | 0.42, 0.73 | 聚焦展开 |
| SPRING_HERO_COLLAPSE | 0.36, 0.78 | 聚焦收起 |

### 技术风险
1. **自动滚动 + zoneRects**：Grid 滚动后 zoneRects 全局坐标失效，需要 scrollOffset 补偿或实时重收集
2. **聚焦态→网格态无缝衔接**：geometryTransition 动画期间 overlay 胶囊需保持稳定
3. **Sheet 与聚焦态共存**：z-index 层级需确保 Sheet > 聚焦态内容 > 网格态
4. **enableScrollInteraction**：改为 onScrollFrameBegin 拦截可能有兼容性问题

## 产品愿景对齐

- v3 核心：格子 = 带格子的核查清单，统一界面
- 空格子始终可见（认知辅助），有内容格子视觉权重自然高于空格子
- 拖拽不是核心范式（v2 塔科夫式已推翻），但作为辅助操作应该流畅
- 装备详情的本质是"快速查看+就地编辑"，不是"进入新页面"
