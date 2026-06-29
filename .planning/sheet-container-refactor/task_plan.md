# SheetContainer 重构方案

## 目标声明

**消灭 SheetOverlay "超级传话筒" 反模式**：当前每新增一个 Sheet 需要在 3 处同步扩展（Index 声明代理变量 → SheetOverlay @Prop 中继 → Index 调用处绑定），产生 O(n) 线性增长的噪音代码。重构后每新增 Sheet 只需 1 处改动。

**量化目标**：
- Index.ets 净删 ~160 行（32 代理变量 + 32 行 reset 方法 + 138 行传参区 → 收敛为 ~40 行）
- SheetOverlay.ets 从 382 行→ ~120 行（只保留容器壳 + 手势 + 路由）
- 新增 Sheet 的改动点从 3 处降到 1 处

## 约束

- ArkUI @Prop 不支持 interface 类型，只能传 class 或基础类型
- SheetOverlay 通过 `if sheetMode !== ''` 条件渲染，每次打开时 remount（子组件 aboutToAppear 重新执行）
- 每个子 Sheet 已经实现了 §4.6 "初始值内化" 模式（@Prop initialXxx → aboutToAppear 复制到本地 @State）
- 不得破坏 swipe-to-dismiss 手势和 overlay 动画
- 必须通过 `devecocli build` 编译验证

---

## 第一性原理分析

### 根本问题

SheetOverlay 只做了一件事：**按 sheetMode 路由到对应子组件并传参**。但它用了最重的方式——声明式 @Prop 逐个中继。这违反了信息论最小描述长度原则：信息已经存在于 Index.ets 的 open 方法中，却要被冗余地编码三次。

### 本质需求

1. **路由**：按 sheetMode 决定显示哪个 Sheet — 必须保留
2. **数据传递**：把打开时的初始值传给子 Sheet — 可以优化传递方式
3. **容器 UI**：标题、关闭按钮、遮罩、手势 — 必须保留
4. **回调上行**：子 Sheet 完成后通知 Index 执行业务逻辑 — 可以优化绑定方式

### 解法选择

| 方案 | 描述 | 优点 | 缺点 | 结论 |
|------|------|------|------|------|
| A. Payload class 打包 | 用 class SheetPayload 打包所有初始值，单个 @Prop 传递 | 极大减少 prop 数量 | @Prop 对 class 的 deep-copy 开销；所有 Sheet 共享一个超级 class 仍是味道 | ❌ 治标不治本 |
| B. @Builder + 回调注册表 | Index 用 @Builder 直接构建对应 Sheet，SheetOverlay 只提供容器壳 | SheetOverlay 彻底瘦身为纯容器；新增 Sheet 只改 Index 的 @Builder | 需要验证 @Builder 在 if 条件渲染内是否正常；Index 的 @Builder 区会膨胀 | ⚠️ 可能可行但 ArkUI @Builder 限制多 |
| C. 直接内联 + SheetContainer 纯壳 | 消灭 SheetOverlay 中的路由逻辑，把所有 if/else 搬回 Index 的 SheetContainer 调用处，SheetOverlay 只保留手势 + 遮罩 + 标题 | 零中继、零重复声明；子 Sheet 直接在 Index 作用域内构建，天然访问所有状态 | Index build 方法会变长 | ❌ 违背上帝组件瘦身目标 |
| **D. SheetRegistry 模式** | 每个 Sheet 注册自己的 "配置对象"（title + builder + callbacks），SheetOverlay 只做 lookup + render | 最干净的解耦；新增 Sheet 只需注册 | 需要 ArkUI 支持 @BuilderParam 或 wrappedBuilder | ✅ **最优解** |

### 最终决策：方案 D — SheetRegistry + @BuilderParam

**核心思路**：
1. SheetOverlay 变成纯粹的"容器壳"：遮罩 + 标题栏 + 手势 + 内容槽（@BuilderParam）
2. Index.ets 中按 sheetMode 直接构建对应 Sheet（用 if/else + 直接传参）
3. 标题信息通过简单的 sheetTitle 参数传入
4. **SheetOverlay 完全不需要知道任何业务 Sheet 的存在**

这样 SheetOverlay 从 "知道 10 种 Sheet 的所有 Props 和 Callbacks" 变成 "只知道自己是个有动画的卡片容器"。

---

## 阶段计划

### Phase 1: SheetContainer 纯壳化 `[ pending ]`

**目标**：把 SheetOverlay 改造为只接收 sheetMode（控制是否显示）+ sheetTitle + @BuilderParam content 的纯容器。

**步骤**：
1.1 新建 `SheetContainer.ets`，只包含：
  - @Prop sheetMode（控制 opacity/translate 动画）
  - @Prop sheetTitle（显示标题）
  - @Prop sheetTranslateY / sheetOverlayOpacity（动画控制）
  - @Prop errorText（错误提示）
  - @BuilderParam content: () => void（内容槽）
  - onClose 回调
  - swipe-to-dismiss 手势逻辑
  - 标题栏 + 关闭按钮 UI

1.2 验证 @BuilderParam 在条件渲染下的行为（ArkUI 文档确认）

**预期产出**：一个 ~80 行的纯容器组件

### Phase 2: Index.ets 直接构建 Sheet 内容 `[ pending ]`

**目标**：在 Index.ets 中用 @Builder 方法按 sheetMode 路由到各子 Sheet，直接传参（不经过中继层）。

**步骤**：
2.1 在 Index.ets 新增 `@Builder sheetContent()` 方法，内含 if/else 按 sheetMode 分发到各子 Sheet
2.2 每个子 Sheet 的 props 直接从 Index 的 private 变量传入（已有的代理变量）
2.3 回调直接绑定 Index 的方法（不需要 lambda 中继）
2.4 调用 SheetContainer 时传入 sheetTitle + content: this.sheetContent

**预期产出**：Index.ets 新增 ~100 行 @Builder（但删除 ~138 行传参区 = 净减 ~38 行）

### Phase 3: 消灭旧 SheetOverlay `[ pending ]`

**目标**：删除 SheetOverlay.ets，更新 import，确保编译通过。

**步骤**：
3.1 删除 `components/sheets/SheetOverlay.ets`
3.2 Index.ets 的 import 从 SheetOverlay 改为 SheetContainer
3.3 运行 `devecocli build` 验证

### Phase 4: Index.ets 传参精简 `[ pending ]`

**目标**：现在 Sheet 内容直接在 Index @Builder 中构建，代理变量的赋值和 reset 可以进一步内联到 open 方法中。

**步骤**：
4.1 检查哪些代理变量仅在 open 方法中赋值 + @Builder 中传参，没有其他读取方 — 这些可以合并为 open 方法直接构建一个临时对象
4.2 对于每组 sheet（gear/trip/profile/tempItem/day/segment），评估是否能用一个 class 实例替代 N 个 private 变量
4.3 实施简化（如果 Phase 2 已经足够干净，此阶段可选）

### Phase 5: sheetTitle 逻辑迁移 `[ pending ]`

**目标**：当前 SheetOverlay 有一个 `sheetTitle()` 方法（~40 行 if/else）。重构后有两个选择：

- 选项 A：标题由 open 方法设置到一个 private sheetTitle 变量 — 最简单
- 选项 B：标题由各子 Sheet 自己声明 — 更解耦但改动大

**步骤**：
5.1 采用选项 A — 在每个 open 方法中设置 `this.currentSheetTitle = 'xxx'`
5.2 删除 sheetTitle() 方法
5.3 SheetContainer 只从 prop 读取标题字符串

### Phase 6: 编译验证 + 回归测试 `[ pending ]`

**步骤**：
6.1 `devecocli build` 通过
6.2 手动功能回归：每种 Sheet 打开/关闭/提交正常
6.3 动画流畅度验证：swipe-to-dismiss、overlay 淡入淡出

### Phase 7: 代码审计 + 文档更新 `[ pending ]`

**步骤**：
7.1 更新 `docs/DEVELOPMENT_STANDARDS.md` 架构章节
7.2 更新 MEMORY.md 相关条目
7.3 git commit

---

## 风险登记

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| @BuilderParam 在条件渲染 `if sheetMode !== ''` 内不触发 | 容器壳无法显示内容 | Phase 1.2 先验证；备选方案：用 Visibility.Hidden 替代 if |
| @Builder 方法中 this 绑定丢失 | 回调执行时 this 不是 Index 实例 | 用箭头函数包装回调；或改用 @BuilderParam 的 trailing lambda 语法 |
| 子 Sheet 依赖 remount（aboutToAppear）初始化 | 如果容器壳不 remount，初始值不刷新 | 保持 `if sheetMode !== ''` 条件渲染，确保每次 open 都 remount |
| 编译器对 @Builder 方法体量有隐式限制 | 过长的 @Builder 报错 | 拆分为多个 private @Builder 方法 |

---

## 成功标准

- [ ] SheetOverlay → SheetContainer，代码 ≤ 100 行
- [ ] Index.ets SheetContainer 调用处 ≤ 10 行（只传 mode/title/content）
- [ ] 新增 Sheet 只需：① 写子 Sheet 组件 ② 在 Index @Builder 加一个 else if ③ 写 open 方法
- [ ] 零 UI 回归
- [ ] `devecocli build` 通过
