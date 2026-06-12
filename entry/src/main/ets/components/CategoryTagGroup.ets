import { LengthMetrics } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import {
  CHIP_BG_DEFAULT,
  CHIP_BORDER,
  DANGER_COLOR,
  PAGE_BG,
  PRIMARY_COLOR,
  PRIMARY_PRESSED,
  PRIMARY_STROKE_GHOST,
  TEXT_MAIN,
  TEXT_SECONDARY,
  TEXT_TERTIARY,
  TRANSPARENT,
  WHITE,
  WHITE_SECONDARY
} from '../constants/DesignTokens';
import {
  SPRING_PRESS,
  SPRING_GENERAL,
  SPRING_FILTER_PRESS,
  SPRING_FILTER_RELEASE,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  DURATION_CEREMONY_SHAKE
} from '../constants/AnimationTokens';
import { CATEGORY_ALL } from '../models/PackModels';
import { isProtectedCategory } from '../services/CategoryService';

/**
 * 统一分组标签组件
 * 支持 single（单选）/ multi（多选）两种选择模式
 * 支持长按进入编辑态（删除、重命名、拖拽排序、新增）
 */
@Component
export struct CategoryTagGroup {
  // ===== 数据 =====
  @Prop categories: string[] = [];
  @Prop selectedCategory: string = '';
  @Prop selectedCategories: string[] = [];

  // ===== 配置 =====
  @Prop mode: string = 'single'; // 'single' | 'multi'
  @Prop showAllOption: boolean = false;
  @Prop editable: boolean = true;
  @Prop showCount: boolean = false;
  @Prop countMap: Record<string, number> = {};

  // ===== 回调 =====
  onSelect: (category: string) => void = () => {};
  onMultiSelect: (categories: string[]) => void = () => {};
  onEditingChange: (editing: boolean) => void = () => {};
  onRename: (oldName: string, newName: string) => void = () => {};
  onDelete: (category: string) => void = () => {};
  onReorder: (categories: string[]) => void = () => {};
  onAdd: (name: string) => void = () => {};

  // ===== 内部状态 =====
  @State private isEditing: boolean = false;
  @State private pressedChip: string = '';
  @State private wiggleAngle: number = 0;
  // 定时器 id 无需驱动 UI，使用普通成员避免无谓的状态刷新
  private wiggleTimerId: number = -1;
  // 抖动方向交替标记（不进入 @State，仅在 setInterval 闭包内使用）
  private wiggleFlip: boolean = false;

  aboutToDisappear(): void {
    this.stopWiggle();
  }

  private displayCategories(): string[] {
    if (this.showAllOption) {
      const result: string[] = [CATEGORY_ALL];
      for (let i = 0; i < this.categories.length; i++) {
        result.push(this.categories[i]);
      }
      return result;
    }
    return this.categories;
  }

  private isSelected(category: string): boolean {
    if (this.mode === 'multi') {
      return this.selectedCategories.indexOf(category) >= 0;
    }
    return this.selectedCategory === category;
  }

  private handleTap(category: string): void {
    // haptic 已在 onTouch(Down) 触发，此处不重复
    if (this.isEditing) {
      // 编辑态下点击 = 重命名（受保护分组除外）
      if (!isProtectedCategory(category) && category !== CATEGORY_ALL) {
        this.onRename(category, '');
      }
      return;
    }
    if (this.mode === 'multi') {
      this.handleMultiSelect(category);
    } else {
      this.onSelect(category);
    }
  }

  private handleMultiSelect(category: string): void {
    if (category === CATEGORY_ALL) {
      this.onMultiSelect([CATEGORY_ALL]);
      return;
    }
    const next: string[] = [];
    for (let i = 0; i < this.selectedCategories.length; i++) {
      if (this.selectedCategories[i] !== CATEGORY_ALL && this.selectedCategories[i] !== category) {
        next.push(this.selectedCategories[i]);
      }
    }
    if (this.selectedCategories.indexOf(category) < 0) {
      next.push(category);
    }
    this.onMultiSelect(next.length === 0 ? [CATEGORY_ALL] : next);
  }

  private handleLongPress(category: string): void {
    if (!this.editable || category === CATEGORY_ALL) {
      return;
    }
    this.triggerHaptic(50);
    this.enterEditMode();
  }

  private enterEditMode(): void {
    if (this.isEditing) {
      return;
    }
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.isEditing = true;
    });
    this.onEditingChange(true);
    this.startWiggle();
  }

  exitEditMode(): void {
    if (!this.isEditing) {
      return;
    }
    this.stopWiggle();
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.isEditing = false;
    });
    this.onEditingChange(false);
  }

  private startWiggle(): void {
    // 防重入：若已有定时器在跑，先清掉旧的，杜绝 timer id 被覆盖导致的泄漏
    if (this.wiggleTimerId >= 0) {
      clearInterval(this.wiggleTimerId);
      this.wiggleTimerId = -1;
    }
    this.wiggleFlip = false;
    this.wiggleTimerId = setInterval(() => {
      // 交替正负角度，模拟 iOS 图标抖动；用 spring 让每次摆动更柔顺
      this.wiggleFlip = !this.wiggleFlip;
      this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
        this.wiggleAngle = this.wiggleFlip ? -1.5 : 1.5;
      });
    }, DURATION_CEREMONY_SHAKE);
  }

  private stopWiggle(): void {
    if (this.wiggleTimerId >= 0) {
      clearInterval(this.wiggleTimerId);
      this.wiggleTimerId = -1;
    }
    this.wiggleFlip = false;
    // 平滑归位，避免抖动戛然而止
    this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
      this.wiggleAngle = 0;
    });
  }

  private triggerHaptic(duration: number = 10): void {
    try {
      vibrator.startVibration({ type: 'time', duration: duration }, { usage: 'touch' });
    } catch (e) {
      // 静默失败
    }
  }

  private handleDelete(category: string): void {
    this.triggerHaptic();
    this.onDelete(category);
  }

  private chipCount(category: string): number {
    if (this.countMap[category] !== undefined) {
      return this.countMap[category] as number;
    }
    return 0;
  }

  build() {
    Column({ space: 4 }) {
      // 编辑态提示
      if (this.isEditing) {
        Row({ space: 6 }) {
          Text('编辑分组')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_COLOR)
          Text('·')
            .fontSize(12)
            .fontColor(TEXT_TERTIARY)
          Text('修改将影响所有行程')
            .fontSize(11)
            .fontColor(TEXT_TERTIARY)
          Blank()
          Text('完成')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_COLOR)
            .padding({ left: 10, right: 6, top: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor(this.pressedChip === '__done__' ? PRIMARY_STROKE_GHOST : TRANSPARENT)
            .scale({
              x: this.pressedChip === '__done__' ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
              y: this.pressedChip === '__done__' ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
            })
            .animation({ curve: SPRING_PRESS() })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.triggerHaptic();
                this.pressedChip = '__done__';
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.pressedChip = '';
              }
            })
            .onClick(() => {
              this.exitEditMode();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ bottom: 4 })
        .transition(TransitionEffect.OPACITY.combine(
          TransitionEffect.translate({ y: -8 })
        ).animation({ curve: SPRING_GENERAL() }))
      }

      // 标签区域
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(this.displayCategories(), (category: string) => {
          this.CategoryChip(category)
        }, (category: string) => category + (this.isEditing ? '_edit' : '_normal'))

        // 编辑态：新增按钮
        if (this.isEditing) {
          this.AddChip()
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private CategoryChip(category: string) {
    // 外层 Stack：承载标签主体 + 删除按钮（绝对定位）
    Stack() {
      // 标签主体 — 绑定 onTouch/onClick/LongPress
      Row({ space: 4 }) {
        Text(category)
          .fontSize(13)
          .fontWeight(this.isSelected(category) ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.isSelected(category) ? WHITE : (this.isEditing ? TEXT_MAIN : TEXT_SECONDARY))
          .maxLines(1)
        if (this.showCount && this.chipCount(category) > 0) {
          Text(this.chipCount(category).toString())
            .fontSize(11)
            .fontColor(this.isSelected(category) ? WHITE_SECONDARY : TEXT_TERTIARY)
        }
      }
      .height(32)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.chipBgColor(category))
      .border({
        width: this.isEditing && !isProtectedCategory(category) && category !== CATEGORY_ALL ? 1.5 : 1,
        color: this.chipBorderColor(category),
        style: this.isEditing && !isProtectedCategory(category) && category !== CATEGORY_ALL
          ? BorderStyle.Dashed : BorderStyle.Solid
      })
      .borderRadius(16)
      .onClick(() => {
        this.handleTap(category);
      })
      .gesture(
        LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
          .onAction(() => {
            this.handleLongPress(category);
          })
      )
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.triggerHaptic();
          this.getUIContext().animateTo({
            curve: SPRING_FILTER_PRESS()
          }, () => {
            this.pressedChip = category;
          });
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.getUIContext().animateTo({
            curve: SPRING_FILTER_RELEASE()
          }, () => {
            this.pressedChip = '';
          });
        }
      })

      // 编辑态：删除按钮 — 绝对定位在右上角外侧
      if (this.isEditing && !isProtectedCategory(category) && category !== CATEGORY_ALL) {
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(7)
            .fontColor([WHITE])
        }
        .width(18)
        .height(18)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(DANGER_COLOR)
        .borderRadius(9)
        .shadow({ radius: 4, color: '#33000000', offsetX: 0, offsetY: 1 })
        .position({ top: -5, right: -5 })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.handleDelete(category);
        })
        .transition(TransitionEffect.scale({ x: 0, y: 0 }).animation({
          curve: SPRING_GENERAL()
        }))
      }
    }
    .clip(false)
    .scale({
      x: this.chipScale(category),
      y: this.chipScale(category)
    })
    .rotate({ angle: this.chipRotation(category) })
    .animation({ curve: SPRING_FILTER_RELEASE() })
  }

  @Builder
  private AddChip() {
    Row({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(14)
        .fontColor([TEXT_TERTIARY])
      Text('新增')
        .fontSize(13)
        .fontColor(TEXT_TERTIARY)
    }
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor(PAGE_BG)
    .border({ width: 1.5, color: CHIP_BORDER, style: BorderStyle.Dashed })
    .borderRadius(16)
    .scale({
      x: this.pressedChip === '__add__' ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
      y: this.pressedChip === '__add__' ? PRESS_SCALE_DOWN : PRESS_SCALE_REST
    })
    .animation({ curve: SPRING_PRESS() })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedChip = '__add__';
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedChip = '';
      }
    })
    .onClick(() => {
      this.triggerHaptic();
      this.onAdd('');
    })
    .transition(TransitionEffect.scale({ x: 0, y: 0 }).animation({
      curve: SPRING_GENERAL()
    }))
  }


  private chipBgColor(category: string): string {
    if (this.isSelected(category)) {
      return this.pressedChip === category ? PRIMARY_PRESSED : PRIMARY_COLOR;
    }
    return this.pressedChip === category ? CHIP_BORDER : CHIP_BG_DEFAULT;
  }

  private chipBorderColor(category: string): string {
    if (this.isSelected(category)) {
      return this.pressedChip === category ? PRIMARY_PRESSED : PRIMARY_COLOR;
    }
    if (this.isEditing && !isProtectedCategory(category) && category !== CATEGORY_ALL) {
      return PRIMARY_COLOR;
    }
    return CHIP_BORDER;
  }

  private chipScale(category: string): number {
    if (this.pressedChip === category) {
      return PRESS_SCALE_DOWN;
    }
    return PRESS_SCALE_REST;
  }

  private chipRotation(category: string): number {
    if (this.isEditing && !isProtectedCategory(category) && category !== CATEGORY_ALL) {
      // 用 category 长度做相位偏移，让不同标签错开抖动
      const phaseOffset = category.length % 2 === 0 ? 1 : -1;
      return this.wiggleAngle * phaseOffset;
    }
    return 0;
  }
}
