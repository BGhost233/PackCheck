# 新建行程滑块交互增强

## 目标
增强 TripCeremonyCard 的滑块按压反馈 + 到达终点仪式感动画

## 涉及文件
- `entry/src/main/ets/components/TripCeremonyCard.ets` — 唯一改动文件

---

## 阶段 1：按压反馈增强 [pending]

### 1.1 新增状态变量
```
@State private sliderBgColor: string = '#2D7D46'   // 滑块背景色（按压变深）
@State private trackSinkY: number = 0               // 轨道下沉量
@State private progressWidth: number = 0            // 绿色进度条宽度
@State private airplaneRotate: number = 0           // 飞机旋转角度
private lastRatchetProgress: number = 0             // 棘轮振动上次触发进度
```

### 1.2 按压触觉升级
- `onSlideStart`: `haptic.tick` → `haptic.effect.soft`（更有"肉感"的抓握反馈）
- 同时加 `trackSinkY = 1.5`（轨道微下沉）+ `sliderBgColor = '#256B3A'`（深一阶）

### 1.3 棘轮振动（滑动过程）
- `onSlideMove` 中每过 25% 进度触发一次 `haptic.clock.timer`
- 阈值档位：0.25 / 0.50 / 0.75（共3次 tick）
- 用 `lastRatchetProgress` 记录已触发档位，避免重复

### 1.4 绿色进度填充条（视觉）
- 在轨道背景之上、文案之下新增一个 Row
- 宽度 = `slideX + SLIDER_WIDTH/2`
- 颜色 = 线性渐变 `#2D7D46` opacity 0.12→0.30（随进度加深）
- 圆角左半圆

### 1.5 松手恢复
- `onSlideEnd` 恢复 `sliderBgColor = '#2D7D46'`、`trackSinkY = 0`、`lastRatchetProgress = 0`
- 进度条随 `slideX` 弹回自然归零（无需额外逻辑）

### 1.6 UI 构建改动
- 滑块 Column `.backgroundColor(this.sliderBgColor)` + `.animation({ duration: 150, curve: Curve.EaseOut })`
- 滑轨 Stack 加 `.translate({ y: this.trackSinkY })` + `.animation({ duration: 120, curve: Curve.EaseOut })`
- 新增绿色进度 Row（层级：轨道背景 → 进度条 → 文案 → 白遮罩 → 滑块）

---

## 阶段 2：仪式感 Phase 1 — 锁定确认 [pending]
**时间窗口：0~150ms**

### 2.1 新增状态变量
```
@State private ripple1Scale: number = 0.5           // 波纹1 缩放
@State private ripple1Opacity: number = 0           // 波纹1 透明度
@State private ripple2Scale: number = 0.5           // 波纹2 缩放
@State private ripple2Opacity: number = 0           // 波纹2 透明度
@State private ceremonyPhase: number = 0            // 仪式进度（0=未开始 1=锁定 2=蓄力 3=升空）
```

### 2.2 锁定逻辑（completeSlide 重写）
原 `completeSlide()` 全部重构为三阶段序列：

```
completeSlide() {
  isSlideComplete = true; isSliding = false;
  stopShimmer(); stopTitleShimmer();

  // 吸附到终点
  animateTo(100ms EaseOut) { slideX = maxSlide; sliderPressed = false; }

  // === Phase 1: 锁定确认 ===
  ceremonyPhase = 1;
  startCeremonyPhase1();
}
```

### 2.3 Phase 1 动画序列
```
startCeremonyPhase1():
  1. 滑块放大 1.15（spring 0.25/0.7）
  2. haptic: haptic.effect.sharp count:2（双击锁定感）
  3. 波纹1: scale 0.5→1.8 + opacity 0.5→0（400ms EaseOut）
  4. 波纹2: 延迟 60ms，scale 0.5→1.5 + opacity 0.35→0（350ms EaseOut）
  5. 150ms 后 → startCeremonyPhase2()
```

### 2.4 波纹 UI
- 在滑块终点位置放 2 个 Circle（直径 48，绿色 #2D7D46）
- `position` 固定在 `maxSlide` 处
- `scale` + `opacity` 绑定状态变量

---

## 阶段 3：仪式感 Phase 2 — 充能蓄力 [pending]
**时间窗口：150~550ms**

### 3.1 新增状态变量
```
@State private ceremonyCardScale: number = 1.0      // 仪式阶段卡片额外缩放
@State private ceremonyCardSinkY: number = 0        // 卡片下沉
@State private trackTextOpacity: number = 1.0       // "滑动出发" 文字透明度
@State private readyTextOpacity: number = 0         // "准备出发！" 文字透明度
@State private glowLayerOpacity: number = 0         // 卡片光晕层透明度
```

### 3.2 Phase 2 动画序列
```
startCeremonyPhase2():
  ceremonyPhase = 2;

  1. 卡片收缩蓄力: ceremonyCardScale → 0.97 + ceremonyCardSinkY → 3（spring 0.3/0.8）
  2. 文字切换: trackTextOpacity → 0 + readyTextOpacity → 1（150ms EaseOut）
  3. 飞机旋转朝上: airplaneRotate → -45（spring 0.3/0.75）
  4. 光晕呼吸: glowLayerOpacity → 0.10（200ms EaseOut）
  5. 滑块微缩回 1.0: sliderBounceScale → 1.0（从 Phase1 的 1.15 恢复）

  400ms 后 → startCeremonyPhase3()
```

### 3.3 文字切换 UI
- 轨道内用 Stack 叠放两个 Text："滑动出发" + "准备出发！"
- 各自绑定 opacity 状态 + `.animation({ duration: 150, curve: Curve.EaseOut })`
- "准备出发！" 额外加 `fontWeight(Bold)` + `fontColor('#2D7D46')`（更强调）

### 3.4 光晕层 UI
- 在主卡片 Column **外层** Stack 中、卡片之下放一个略大的圆角 Column
- `width('87%')` `height(308)` `borderRadius(28)` `backgroundColor('#2D7D46')`
- `opacity(glowLayerOpacity)` `blur(16)`
- 通过 opacity 动画控制亮灭

### 3.5 卡片 scale/translateY 绑定
- 主卡片 `.scale()` 中乘入 `ceremonyCardScale`
- 主卡片 `.translate()` 中加入 `ceremonyCardSinkY`

---

## 阶段 4：仪式感 Phase 3 — 弹射升空 [pending]
**时间窗口：550~1050ms**

### 4.1 Phase 3 动画序列
```
startCeremonyPhase3():
  ceremonyPhase = 3;

  1. 弹射预备: ceremonyCardScale → 1.03（先微放大，spring 0.25/0.7，100ms）
  2. haptic: haptic.effect.hard count:1（发射推力感）
  3. 数据创建: this.onFinish()
  4. 100ms 后触发 flyAway()（改进版）
```

### 4.2 flyAway 改进
```
flyAway():
  onExitStart();
  光晕消散: glowLayerOpacity → 0（200ms EaseOut）
  卡片飘走（保持现有逻辑）:
    launchTranslateY → -800
    launchScale → 0.85
    launchOpacity → 0
    launchRotate → -3
    (spring 0.35/0.78)
  遮罩消散: overlayOpacity → 0（350ms EaseOut）
  500ms 后: onDismiss()
```

---

## 阶段 5：构建验证 + 时序收尾 [pending]

### 5.1 构建
- 执行 `hvigorw assembleApp --no-daemon`
- 修复所有编译错误

### 5.2 时序复核
- 确认总耗时 ~1000ms 分配合理
- 确认 onFinish() 调用时机不影响数据创建
- 确认 onExitStart() 在飘走第一帧就触发

### 5.3 Git 提交
- `git add -A && git commit -m "feat: 增强新建行程滑块按压反馈与到达仪式感动画"`

---

## 约束与边界
- 不改任何其他文件
- 不改入场动画逻辑
- 不改 handleDismiss 退出逻辑
- 所有动画用 Spring 或 EaseOut，严禁 linear
- 振动 API 做 try-catch 兜底，不影响主流程
- 新增状态变量全部给默认值，向后兼容
