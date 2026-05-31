// 字体排版 Token — 基于 HarmonyOS Sans 官方字阶（手机端）

// ============ 字号 (fp) ============

export const FONT_SIZE_DISPLAY: number = 40;
export const FONT_SIZE_TITLE_LARGE: number = 24;
export const FONT_SIZE_TITLE_MEDIUM: number = 20;
export const FONT_SIZE_SUBTITLE_LARGE: number = 18;
export const FONT_SIZE_SUBTITLE_MEDIUM: number = 16;
export const FONT_SIZE_BODY_LARGE: number = 16;
export const FONT_SIZE_BODY_MEDIUM: number = 14;
export const FONT_SIZE_CAPTION: number = 12;

// ============ 字重 ============

export const FONT_WEIGHT_BOLD: number = 700;
export const FONT_WEIGHT_MEDIUM: number = 500;
export const FONT_WEIGHT_REGULAR: number = 400;

// ============ 字阶预设（字号 + 字重组合） ============

export interface TypographyToken {
  fontSize: number;
  fontWeight: number;
}

export const TYPE_DISPLAY: TypographyToken = { fontSize: FONT_SIZE_DISPLAY, fontWeight: FONT_WEIGHT_BOLD };
export const TYPE_TITLE_LARGE: TypographyToken = { fontSize: FONT_SIZE_TITLE_LARGE, fontWeight: FONT_WEIGHT_BOLD };
export const TYPE_TITLE_MEDIUM: TypographyToken = { fontSize: FONT_SIZE_TITLE_MEDIUM, fontWeight: FONT_WEIGHT_MEDIUM };
export const TYPE_SUBTITLE_LARGE: TypographyToken = { fontSize: FONT_SIZE_SUBTITLE_LARGE, fontWeight: FONT_WEIGHT_MEDIUM };
export const TYPE_SUBTITLE_MEDIUM: TypographyToken = { fontSize: FONT_SIZE_SUBTITLE_MEDIUM, fontWeight: FONT_WEIGHT_MEDIUM };
export const TYPE_BODY_LARGE: TypographyToken = { fontSize: FONT_SIZE_BODY_LARGE, fontWeight: FONT_WEIGHT_REGULAR };
export const TYPE_BODY_MEDIUM: TypographyToken = { fontSize: FONT_SIZE_BODY_MEDIUM, fontWeight: FONT_WEIGHT_REGULAR };
export const TYPE_CAPTION: TypographyToken = { fontSize: FONT_SIZE_CAPTION, fontWeight: FONT_WEIGHT_REGULAR };

// ============ 行高倍率 ============

export const LINE_HEIGHT_RATIO: number = 1.4;

// ============ 等宽数字特性 ============
// 注：等宽数字 token 统一使用 Layout.ets 导出的 FONT_FEATURE_TNUM
