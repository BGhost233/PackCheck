import { ChecklistItem, GearItem, TripChecklist } from '../models/PackModels';
import { resolveItemName } from '../services/ChecklistService';
import { zoneDisplayName } from '../services/LoadoutService';
import {
  CARD_BG,
  FONT_FEATURE_TNUM,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_TERTIARY
} from '../constants/DesignTokens';
import {
  WHITE,
  SHADOW_DEFAULT,
  TRANSPARENT
} from '../constants/Colors';
import {
  SPRING_PRESS,
  SPRING_GENERAL,
  SPRING_PANEL_EXIT,
  PRESS_SCALE_DOWN,
  PRESS_SCALE_REST,
  PANEL_SCALE_START,
  STAGGER_OFFSET_Y
} from '../constants/AnimationTokens';
import {
  FONT_SIZE_BODY_SMALL,
  FONT_SIZE_BODY_MEDIUM,
  FONT_SIZE_TITLE_LARGE,
  FONT_SIZE_CAPTION
} from '../constants/Typography';

/** 核查卡片宽度百分比 — 保持卡片不贴边但有呼吸感 */
const REVIEW_CARD_WIDTH: string = '78%';
/** 核查卡片高度 (vp) — 内容区舒适展示 item 名+操作按钮 */
const REVIEW_CARD_HEIGHT: number = 240;
/** 核查完成页高度 (vp) — 比卡片略高容纳两行文字+返回按钮 */
const REVIEW_SUMMARY_HEIGHT: number = 260;

@Component
export struct ReviewPage {
  @Prop checklists: TripChecklist[] = [];
  @Prop gears: GearItem[] = [];
  @Prop selectedChecklistId: string = '';
  @Prop reviewIndex: number = 0;
  @Prop reviewFinished: boolean = false;
  @Prop reviewDragX: number = 0;
  // D-2：非空时只核对 group===zone 的 item（聚焦态「逐项核查本区」）
  @Prop reviewZoneFilter: string | null = null;

  onUpdateDragX: (value: number) => void = (value: number): void => {};
  onMarkReviewItem: (checked: boolean) => void = (checked: boolean): void => {};
  onExitReviewMode: () => void = (): void => {};

  @State private uncheckedBtnPressed: boolean = false;
  @State private checkedBtnPressed: boolean = false;
  @State private exitBtnPressed: boolean = false;
  @State private backBtnPressed: boolean = false;
  @State private pageEntered: boolean = false;
  // 卡片横移本地接管：拖动跟手 / 飞出 / 弹回 全部走本地 state，确保 animateTo 能驱动动画
  // （reviewDragX 为父 @Prop 单向下发，子组件 animateTo 无法捕获其变化为动画，故本地接管）
  @State private dragX: number = 0;
  @State private isFlying: boolean = false;
  // 卡片入场：当前卡从背后位置弹入（每次换牌触发一次）
  @State private cardEntered: boolean = true;

  // timer 清理：所有延迟操作归入此数组，aboutToDisappear 遍历清
  private timerIds: number[] = [];
  private isAlive: boolean = true;

  aboutToAppear(): void {
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.pageEntered = true;
    }, 20) as number;
    this.timerIds.push(id);
  }

  aboutToDisappear(): void {
    this.isAlive = false;
    for (let i = 0; i < this.timerIds.length; i++) {
      clearTimeout(this.timerIds[i]);
    }
    this.timerIds = [];
  }

  private currentChecklist(): TripChecklist | undefined {
    for (let index = 0; index < this.checklists.length; index++) {
      if (this.checklists[index].id === this.selectedChecklistId) {
        return this.checklists[index];
      }
    }
    return undefined;
  }

  private currentReviewItem(): ChecklistItem | undefined {
    const checklist = this.currentChecklist();
    if (checklist === undefined || this.reviewIndex < 0 || this.reviewIndex >= checklist.items.length) {
      return undefined;
    }
    // D-2：zone filter 过滤后的 item 列表
    const items = this.filteredItems(checklist);
    if (this.reviewIndex >= items.length) {
      return undefined;
    }
    return items[this.reviewIndex];
  }

  // D-2：返回经过 zone filter 过滤后的核查 item 列表
  private filteredItems(checklist: TripChecklist): ChecklistItem[] {
    if (this.reviewZoneFilter !== null && this.reviewZoneFilter.length > 0) {
      const result: ChecklistItem[] = [];
      for (let i = 0; i < checklist.items.length; i++) {
        if (checklist.items[i].group === this.reviewZoneFilter) {
          result.push(checklist.items[i]);
        }
      }
      return result;
    }
    return checklist.items;
  }

  private currentReviewItemName(): string {
    const item = this.currentReviewItem();
    if (item === undefined) {
      return '';
    }
    return resolveItemName(item, this.gears);
  }

  private currentReviewItemGroup(): string {
    const item = this.currentReviewItem();
    return item === undefined ? '' : item.group;
  }

  // 当前卡片的有效横移：本地 dragX 统一承载（拖动跟手 / 飞出 / 弹回）
  private cardOffsetX(): number {
    return this.dragX;
  }

  // 跟手倾斜角（捏角滑动的物理直觉），克制系数；飞出时角度更大
  private cardRotation(): number {
    return this.cardOffsetX() * 0.04;
  }

  // 拖越远越淡（封顶 0.3），飞出时彻底淡出
  private cardOpacity(): number {
    if (this.isFlying) return 0;
    const d = Math.abs(this.cardOffsetX());
    return 1 - Math.min(d / 600, 0.3);
  }

  // 背后预览卡的缩放：随当前卡拖动距离从 0.94 趋近 1.0（下一张顶上来）
  private backCardScale(): number {
    const d = Math.min(Math.abs(this.cardOffsetX()), 160);
    return 0.94 + (d / 160) * 0.06;
  }

  // 背后预览卡的透明度：随拖动渐显
  private backCardOpacity(): number {
    const d = Math.min(Math.abs(this.cardOffsetX()), 160);
    return 0.5 + (d / 160) * 0.5;
  }

  // 松手判定：过阈值则让卡片飞出屏幕，动画结束再回调父组件换牌
  private flingCard(checked: boolean): void {
    const dir = checked ? 1 : -1;
    this.isFlying = true;
    this.getUIContext().animateTo({ curve: SPRING_PANEL_EXIT() }, () => {
      this.dragX = dir * 700;
    });
    // 飞出动画推进到位后换下一张；新卡从背后位置入场
    let id = setTimeout(() => {
      if (!this.isAlive) { return; }
      this.cardEntered = false;
      this.onMarkReviewItem(checked);
      this.onUpdateDragX(0);
      this.dragX = 0;
      this.isFlying = false;
      // 下一帧让新卡从背后弹入
      let innerId = setTimeout(() => {
        if (!this.isAlive) { return; }
        this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
          this.cardEntered = true;
        });
      }, 16) as number;
      this.timerIds.push(innerId);
    }, 260) as number;
    this.timerIds.push(id);
  }

  private checkedCount(checklist: TripChecklist): number {
    let count = 0;
    const items = this.filteredItems(checklist);
    for (let index = 0; index < items.length; index++) {
      if (items[index].checked) {
        count++;
      }
    }
    return count;
  }

  private currentChecklistItemCount(): number {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return 0;
    }
    return this.filteredItems(checklist).length;
  }

  private reviewSummaryText(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '';
    }
    const total = this.currentChecklistItemCount();
    return '已带 ' + this.checkedCount(checklist).toString() + ' 件，未带 ' +
      (total - this.checkedCount(checklist)).toString() + ' 件';
  }

  // D-2：聚焦态「逐项核查本区」顶栏 Zone 名
  private reviewTitle(): string {
    if (this.reviewZoneFilter !== null && this.reviewZoneFilter.length > 0) {
      // 复用 LoadoutService.zoneDisplayName 做翻译
      return '核查 · ' + zoneDisplayName(this.reviewZoneFilter ?? '');
    }
    return '';
  }

  build() {
    Column() {
      // D-2：聚焦态核查本区时显示 Zone 名提示退出返回聚焦态
      if (this.reviewZoneFilter !== null && this.reviewZoneFilter.length > 0) {
        Row() {
          Text(this.reviewTitle())
            .fontSize(FONT_SIZE_BODY_SMALL)
            .fontColor(TEXT_TERTIARY)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 4 })
      }
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor([TEXT_TERTIARY])
        Text('左滑未带')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_TERTIARY)
        Text('右滑已带')
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_TERTIARY)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor([TEXT_TERTIARY])
      }
      .padding({ top: 72, bottom: 40 })
      if (this.reviewFinished) {
        this.Summary();
      } else {
        this.Card();
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(PAGE_BG)
    .opacity(this.pageEntered ? 1 : 0)
    .translate({ y: this.pageEntered ? 0 : STAGGER_OFFSET_Y })
    .animation({ curve: SPRING_GENERAL() })
  }

  @Builder
  private Card() {
    if (this.currentReviewItem() !== undefined) {
      // 卡片堆叠：底层背后预览卡（随拖动上浮放大）+ 顶层当前卡（跟手倾斜，松手飞出）
      Stack() {
        // 背后预览卡（占位纵深，无内容，随拖动趋近顶层）
        Column()
          .width(REVIEW_CARD_WIDTH)
          .height(REVIEW_CARD_HEIGHT)
          .backgroundColor(CARD_BG)
          .borderRadius(20)
          .shadow({ radius: 12, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 4 })
          .scale({ x: this.backCardScale(), y: this.backCardScale() })
          .opacity(this.backCardOpacity())

        // 顶层当前卡
        Column({ space: 18 }) {
          Text(this.currentReviewItemName())
            .fontSize(FONT_SIZE_TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .textAlign(TextAlign.Center)
          Text(this.currentReviewItemGroup())
            .fontSize(FONT_SIZE_CAPTION)
            .fontColor(TEXT_TERTIARY)
        }
        .width('78%')
        .height(240)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(CARD_BG)
        .borderRadius(20)
        .shadow({ radius: 18, color: SHADOW_DEFAULT, offsetX: 0, offsetY: 8 })
        .translate({ x: this.cardOffsetX(), y: 0 })
        .rotate({ angle: this.cardRotation() })
        .opacity(this.cardEntered ? this.cardOpacity() : 0)
        .scale({ x: this.cardEntered ? 1 : PANEL_SCALE_START, y: this.cardEntered ? 1 : PANEL_SCALE_START })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event: GestureEvent) => {
              if (this.isFlying) return;
              this.dragX = event.offsetX;        // 本地跟手（无动画）
              this.onUpdateDragX(event.offsetX); // 同步父侧（兼容）
            })
            .onActionEnd((event: GestureEvent) => {
              if (this.isFlying) return;
              const offset = event.offsetX;
              if (offset > 80) {
                this.flingCard(true);
              } else if (offset < -80) {
                this.flingCard(false);
              } else {
                // 未过阈值：Spring 弹回原位
                this.onUpdateDragX(0);
                this.getUIContext().animateTo({ curve: SPRING_GENERAL() }, () => {
                  this.dragX = 0;
                });
              }
            })
        )
      }
      .width('100%')
      .height(240)
      .alignContent(Alignment.Center)
      Text((this.reviewIndex + 1).toString() + ' / ' + this.currentChecklistItemCount().toString())
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_TERTIARY)
        .fontFeature(FONT_FEATURE_TNUM)
        .padding({ top: 28, bottom: 18 })
      Row({ space: 12 }) {
        Button('未带')
          .height(44)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_MAIN)
          .backgroundColor(CARD_BG)
          .borderRadius(22)
          .scale({ x: this.uncheckedBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
            y: this.uncheckedBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
          .animation({ curve: SPRING_PRESS() })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.uncheckedBtnPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.uncheckedBtnPressed = false;
            }
          })
          .onClick(() => {
            if (this.isFlying) return;
            this.flingCard(false);
          })
        Button('已带')
          .height(44)
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(WHITE)
          .backgroundColor(PRIMARY_COLOR)
          .borderRadius(22)
          .scale({ x: this.checkedBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
            y: this.checkedBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
          .animation({ curve: SPRING_PRESS() })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.checkedBtnPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.checkedBtnPressed = false;
            }
          })
          .onClick(() => {
            if (this.isFlying) return;
            this.flingCard(true);
          })
      }
      Button('退出核查模式')
        .height(44)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(TEXT_TERTIARY)
        .backgroundColor(TRANSPARENT)
        .scale({ x: this.exitBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
          y: this.exitBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.exitBtnPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.exitBtnPressed = false;
          }
        })
        .onClick(() => {
          this.onExitReviewMode();
        })
    }
  }

  @Builder
  private Summary() {
    Column({ space: 16 }) {
      Text('核查完成')
        .fontSize(FONT_SIZE_TITLE_LARGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      if (this.reviewSummaryText().length > 0) {
        Text(this.reviewSummaryText())
          .fontSize(FONT_SIZE_BODY_MEDIUM)
          .fontColor(TEXT_TERTIARY)
          .fontFeature(FONT_FEATURE_TNUM)
      }
      Button('返回行程')
        .height(46)
        .fontSize(FONT_SIZE_BODY_MEDIUM)
        .fontColor(WHITE)
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(23)
        .scale({ x: this.backBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST,
          y: this.backBtnPressed ? PRESS_SCALE_DOWN : PRESS_SCALE_REST })
        .animation({ curve: SPRING_PRESS() })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.backBtnPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.backBtnPressed = false;
          }
        })
        .onClick(() => {
          this.onExitReviewMode();
        })
    }
    .width(REVIEW_CARD_WIDTH)
    .height(REVIEW_SUMMARY_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
  }
}
