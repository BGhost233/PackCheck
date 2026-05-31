/**
 * 空状态矢量插画组件
 * 三套极简线条画：gear（背包）、trip（山路）、complete（山顶旗帜）
 * 统一风格：stroke-only、1.5vp 线宽、主题绿 20% alpha、≤25 控制点/套
 */
import { SPRING_TAB, DURATION_ENTRANCE } from '../constants/AnimationTokens';
import {
  PRIMARY_STROKE_FAINT,
  TRANSPARENT
} from '../constants/Colors';

@Component
export struct EmptyIllustration {
  @Prop type: string = 'gear'; // 'gear' | 'trip' | 'complete'
  @State private appeared: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      this.appeared = true;
    }, 60);
  }

  // 背包轮廓 + 远山一笔
  private static readonly GEAR_PATH: string =
    'M 35 85 L 35 40 C 35 28 45 20 60 20 C 75 20 85 28 85 40 L 85 85 C 85 90 80 92 60 92 C 40 92 35 90 35 85 Z ' +
    'M 45 20 L 45 14 C 45 10 50 8 60 8 C 70 8 75 10 75 14 L 75 20 ' +
    'M 42 50 L 78 50 ' +
    'M 10 95 C 20 88 30 90 45 82 C 55 77 70 80 80 75 C 90 71 100 74 110 78';

  // 蜿蜒山路 + 远处山峰
  private static readonly TRIP_PATH: string =
    'M 10 90 C 25 85 30 70 45 65 C 55 62 50 50 60 45 C 70 40 65 30 75 25 C 82 22 88 18 95 15 ' +
    'M 5 60 L 25 30 L 40 55 L 55 25 L 70 50 L 85 20 L 95 40 ' +
    'M 20 32 L 25 30 L 30 33';

  // 山顶旗帜 + 简笔云
  private static readonly COMPLETE_PATH: string =
    'M 30 92 L 55 45 L 80 92 ' +
    'M 40 92 L 60 55 L 75 80 L 85 65 L 95 80 ' +
    'M 55 45 L 55 15 ' +
    'M 55 15 L 75 20 L 55 25 ' +
    'M 12 30 C 15 25 22 25 25 30 C 28 25 35 25 38 30 ' +
    'M 75 12 C 78 8 84 8 87 12 C 90 8 95 9 97 12';

  private pathCommands(): string {
    if (this.type === 'trip') {
      return EmptyIllustration.TRIP_PATH;
    }
    if (this.type === 'complete') {
      return EmptyIllustration.COMPLETE_PATH;
    }
    return EmptyIllustration.GEAR_PATH;
  }

  build() {
    Shape() {
      Path()
        .commands(this.pathCommands())
        .stroke(PRIMARY_STROKE_FAINT)
        .strokeWidth(1.5)
        .fill(TRANSPARENT)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
        .antiAlias(true)
    }
    .viewPort({ x: 0, y: 0, width: 120, height: 100 })
    .width(120)
    .height(100)
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 8 })
    .animation({ duration: DURATION_ENTRANCE, curve: SPRING_TAB() })
  }
}
