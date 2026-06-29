// 字体排版 Token — 基于 HarmonyOS Sans 官方字阶（手机端）
// 参考 DEVELOPMENT_STANDARDS.md §2.2

// ============ 字号 (fp) ============

// --- 官方字阶 ---
export const FONT_SIZE_DISPLAY: number = 40;         // 仅启动/空状态大标题
export const FONT_SIZE_TITLE_LARGE: number = 24;      // 页面主标题
export const FONT_SIZE_TITLE_MEDIUM: number = 20;     // 区块标题
export const FONT_SIZE_SUBTITLE_LARGE: number = 18;   // 卡片标题
export const FONT_SIZE_SUBTITLE_MEDIUM: number = 16;  // 列表项主文本
export const FONT_SIZE_BODY_LARGE: number = 16;       // 正文段落（= SUBTITLE_MEDIUM）
export const FONT_SIZE_BODY_MEDIUM: number = 14;      // 正文默认
export const FONT_SIZE_CAPTION: number = 12;          // 辅助说明/时间戳

// --- 项目扩展字阶 ---
export const FONT_SIZE_PAGE_TITLE: number = 22;       // 页面标题（Index/Profile/TripDetail）
export const FONT_SIZE_BODY_SMALL: number = 13;       // 次级正文/列表描述/进度文字
export const FONT_SIZE_OVERLINE: number = 15;         // 加强正文/按钮文字/DayCard 标题
export const FONT_SIZE_MINI: number = 11;             // 最小辅助文字/hint/tab 标签

// --- 装饰性字阶（特定场景，谨慎使用） ---
export const FONT_SIZE_HERO_NUMBER: number = 28;      // ProfilePage 特大展示数字
export const FONT_SIZE_EMPTY_ICON: number = 32;       // 空状态 emoji/icon
export const FONT_SIZE_STAT_LARGE: number = 36;       // ProfilePage 超大统计数字
export const FONT_SIZE_EMOJI_LARGE: number = 48;      // GearPickerSheet 装饰 emoji
export const FONT_SIZE_AVATAR_FALLBACK: number = 56;  // ProfilePage 头像回退字母

// ============ 字重 ============

export const FONT_WEIGHT_BOLD: number = 700;
export const FONT_WEIGHT_MEDIUM: number = 500;

// ============ 等宽数字特性 ============
// 注：等宽数字 token 统一使用 Layout.ets 导出的 FONT_FEATURE_TNUM
