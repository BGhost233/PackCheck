# 研究发现

## ArkUI API 可行性验证结果（2025-06-18）

### 完全支持（零顾虑）
| 能力 | API 版本 | 用法 |
|------|----------|------|
| fontFeature tnum | API 10+ | `.fontFeature("'tnum'")` |
| 单侧 border | API 7+ | `.border({ width: { bottom: 0.5 }, color: { bottom: '#E8E8E8' } })` |
| backgroundImage 平铺 | API 7+ | `.backgroundImage(src, ImageRepeat.XY)` 不支持 SVG |
| Shape + Path 矢量 | API 7+ | SVG path commands，贝塞尔曲线可画山脊线 |
| Particle 粒子 | API 10+ | 内置组件，可用于庆祝效果 |
| translate 动画 | API 7+ | animateTo + .translate() |
| blur/backdropBlur | API 7+ | 已在项目中广泛验证 |
| clip/mask | API 7+ | clip(true) / clip(Shape) 均可 |
| linearGradient | API 7+ | 注意透明色必须同色相只变 alpha |

### 有限制/需注意
| 能力 | 限制 |
|------|------|
| 渐变 border | .border() 不接受渐变值，需 Stack 嵌套模拟 |
| 路径动画 | 无 offset-path 概念，需手动贝塞尔采样 |
| 自定义 shader | 不支持 |
| 毛玻璃色相偏移 | BlurStyle 是固定预设，无 tint 参数 |
| SVG 文件作为 backgroundImage | 不支持 |

### 当前项目状态
- **零 UI 素材资源**——所有视觉纯代码实现（Color/Circle/linearGradient/shadow）
- **HdsTabs 仍在使用**——未被替换为自定义 TabBar（记忆中的 CapsuleTabBar 信息过时）
- **Tab 切换动画**：blur 脉冲（scale 0.96 + blur 6）+ 200ms 内置滑动，已是高质量实现
- **0.5vp border**：需要实际验证 ArkUI 是否渲染 sub-pixel width——备选方案改为 1vp

## fontFeature 格式验证
- ArkUI 官方文档写法：`.fontFeature("'tnum'")`（外双引号内单引号）
- 参考 CSS font-feature-settings 语法
- HarmonyOS Sans 支持 tnum（等宽数字）OpenType 特性

## 噪点纹理方案细节
- 推荐尺寸：64x64 或 128x128 PNG
- 内容：Gaussian noise，灰度，中值 128
- 叠加方式：absolute Image + opacity(0.02~0.03) + hitTestBehavior(None)
- 不能用 .opacity() 加在内容容器上（会影响子组件）
- 替代方案：如果 backgroundImage + ImageRepeat.XY 可用，直接加在根容器上用 overlay

## 错落动画公式分析
- 当前：`index * 40` → 线性等间距
- 建议：`Math.min(400, index * 30 + index * index * 4)`
- 效果：0, 34, 76, 126, 184, 250, 324, 400, 400, 400...
- 前 7 项有加速感，第 8 项起封顶在 400ms
