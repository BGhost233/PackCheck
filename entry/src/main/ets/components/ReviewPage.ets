import { ChecklistItem, TripChecklist } from '../models/PackModels';
import {
  CARD_BG,
  PAGE_BG,
  PRIMARY_COLOR,
  TEXT_MAIN,
  TEXT_TERTIARY
} from '../constants/DesignTokens';

@Component
export struct ReviewPage {
  @Prop checklists: TripChecklist[] = [];
  @Prop selectedChecklistId: string = '';
  @Prop reviewIndex: number = 0;
  @Prop reviewFinished: boolean = false;
  @Prop reviewDragX: number = 0;

  onUpdateDragX: (value: number) => void = (value: number): void => {};
  onMarkReviewItem: (checked: boolean) => void = (checked: boolean): void => {};
  onExitReviewMode: () => void = (): void => {};

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
    return checklist.items[this.reviewIndex];
  }

  private currentReviewItemName(): string {
    const item = this.currentReviewItem();
    return item === undefined ? '' : item.name;
  }

  private currentReviewItemGroup(): string {
    const item = this.currentReviewItem();
    return item === undefined ? '' : item.group;
  }

  private checkedCount(checklist: TripChecklist): number {
    let count = 0;
    for (let index = 0; index < checklist.items.length; index++) {
      if (checklist.items[index].checked) {
        count++;
      }
    }
    return count;
  }

  private currentChecklistItemCount(): number {
    const checklist = this.currentChecklist();
    return checklist === undefined ? 0 : checklist.items.length;
  }

  private reviewSummaryText(): string {
    const checklist = this.currentChecklist();
    if (checklist === undefined) {
      return '';
    }
    return '已带 ' + this.checkedCount(checklist).toString() + ' 件，未带 ' +
      (checklist.items.length - this.checkedCount(checklist)).toString() + ' 件';
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(14)
          .fontColor([TEXT_TERTIARY])
        Text('左滑未带')
          .fontSize(14)
          .fontColor(TEXT_TERTIARY)
        Text('右滑已带')
          .fontSize(14)
          .fontColor(TEXT_TERTIARY)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
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
  }

  @Builder
  private Card() {
    if (this.currentReviewItem() !== undefined) {
      Column({ space: 18 }) {
        Text(this.currentReviewItemName())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .textAlign(TextAlign.Center)
        Text(this.currentReviewItemGroup())
          .fontSize(12)
          .fontColor(TEXT_TERTIARY)
      }
      .width('78%')
      .height(240)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(CARD_BG)
      .borderRadius(20)
      .shadow({ radius: 18, color: '#1A000000', offsetX: 0, offsetY: 8 })
      .translate({ x: this.reviewDragX, y: 0, z: 0 })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionUpdate((event: GestureEvent) => {
            this.onUpdateDragX(event.offsetX);
          })
          .onActionEnd((event: GestureEvent) => {
            const offset = event.offsetX;
            this.onUpdateDragX(0);
            if (offset > 80) {
              this.onMarkReviewItem(true);
            } else if (offset < -80) {
              this.onMarkReviewItem(false);
            }
          })
      )
      Text((this.reviewIndex + 1).toString() + ' / ' + this.currentChecklistItemCount().toString())
        .fontSize(14)
        .fontColor(TEXT_TERTIARY)
        .padding({ top: 28, bottom: 18 })
      Row({ space: 12 }) {
        this.ReviewButton('未带', false);
        this.ReviewButton('已带', true);
      }
      Button('退出核查模式')
        .height(44)
        .fontSize(14)
        .fontColor(TEXT_TERTIARY)
        .backgroundColor('#00000000')
        .onClick(() => {
          this.onExitReviewMode();
        })
    }
  }

  @Builder
  private ReviewButton(title: string, checked: boolean) {
    Button(title)
      .height(44)
      .fontSize(14)
      .fontColor(checked ? '#FFFFFF' : TEXT_MAIN)
      .backgroundColor(checked ? PRIMARY_COLOR : CARD_BG)
      .borderRadius(22)
      .onClick(() => {
        this.onMarkReviewItem(checked);
      })
  }

  @Builder
  private Summary() {
    Column({ space: 16 }) {
      Text('核查完成')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      if (this.reviewSummaryText().length > 0) {
        Text(this.reviewSummaryText())
          .fontSize(14)
          .fontColor(TEXT_TERTIARY)
      }
      Button('返回清单')
        .height(46)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY_COLOR)
        .borderRadius(23)
        .onClick(() => {
          this.onExitReviewMode();
        })
    }
    .width('78%')
    .height(260)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
  }
}
