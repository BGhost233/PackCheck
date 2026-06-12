// 色彩语义 Token — 项目唯一色值来源

// ============ 基础色 ============
export const WHITE: string = '#FFFFFF';
export const BLACK: string = '#000000';
export const TRANSPARENT: string = '#00000000';

// ============ 品牌/主色 ============
export const PRIMARY_COLOR: string = '#2D7D46';
export const LIGHT_PRIMARY_COLOR: string = '#E8F5E9';
export const PRIMARY_TINT_COLOR: string = '#F1F8F3';
export const PRIMARY_PRESSED: string = '#1F5C32';
export const PRIMARY_PRESSED_DEEP: string = '#256B3A';

// ============ 主色透明度变体 ============
export const PRIMARY_STROKE_FAINT: string = '#332D7D46';
export const PRIMARY_STROKE_GHOST: string = '#0A2D7D46';
export const PRIMARY_SHADOW: string = '#1A2D7D46';
export const PRIMARY_TRANSPARENT: string = '#002D7D46';
export const PRIMARY_SHADOW_LIGHT: string = '#262D7D46';
export const PRIMARY_HALF: string = '#802D7D46';
export const PRIMARY_FILL_SUBTLE: string = '#602D7D46';
export const PRIMARY_GRADIENT_START: string = '#1F2D7D46';
export const PRIMARY_GRADIENT_END: string = '#4D2D7D46';
// 拖拽目标格 glow 绿光阴影（alpha #40 ≈ 25%）
export const PRIMARY_SHADOW_GLOW: string = '#402D7D46';

// ============ 页面/卡片背景 ============
export const PAGE_BG: string = '#F8F9FA';
export const PAGE_BG_TRANSLUCENT: string = '#66F8F9FA';
// 贴底渐隐渐变起始端：PAGE_BG 的 0-alpha 版本（不能用 TRANSPARENT #00000000，否则偏黑）
export const PAGE_BG_TRANSPARENT: string = '#00F8F9FA';
export const CARD_BG: string = '#FFFFFF';
export const GROUP_HEADER_BG: string = '#F5F5F5';
export const INPUT_BG: string = '#F7F8F7';
export const CARD_FOOTER_BG: string = '#F0F4F0';
export const CHIP_BG_DEFAULT: string = '#F5F7F5';

// ============ 毛玻璃背景 ============
export const BLUR_BG: string = '#CCF8F9FA';
export const GLASS_BG: string = '#B0FFFFFF';
export const GLASS_BG_HEAVY: string = '#EBFFFFFF';
export const GLASS_BG_MEDIUM: string = '#E8FFFFFF';
export const GLASS_BG_LIGHT: string = '#EEFFFFFF';

// ============ 文字色 ============
export const TEXT_MAIN: string = '#1A1A1A';
export const TEXT_SECONDARY: string = '#666666';
export const TEXT_TERTIARY: string = '#999999';
export const WHITE_SECONDARY: string = '#CCFFFFFF';
export const WHITE_SEMI_TRANSPARENT: string = '#40FFFFFF';

// ============ 边框/分割线 ============
export const BORDER_COLOR: string = '#ECEFF1';
export const DIVIDER_COLOR: string = '#F0F0F0';
export const CHIP_BORDER: string = '#E0E0E0';
export const CARD_BORDER_BOTTOM_COLOR: string = '#E8E8E8';
// 元信息段间分隔点（介于 plain 文字 #999 与极淡 #F0F0F0 之间）：
//   明确弱于 plain 文字、强于纯背景线，给并列信息段清晰可见的轻量切分。
export const META_SEPARATOR: string = '#C2C2C2';

// ============ 功能色/状态色 ============
export const ARROW_COLOR: string = '#CCCCCC';
export const DISABLED_COLOR: string = '#CCCCCC';
export const PLACEHOLDER_COLOR: string = '#BBBBBB';
export const PROGRESS_END_COLOR: string = '#4CAF50';
export const PROGRESS_INACTIVE: string = '#90A4AE';

// ============ 强调/警告色 ============
export const DANGER_COLOR: string = '#E53935';
export const DANGER_TINT: string = '#FFF0F0';
export const ERROR_BORDER: string = '#FF4444';
export const AMBER_ACCENT: string = '#E8890C';
export const AMBER_TINT: string = '#FFF5E6';
export const PRICE_COLOR: string = '#4A90D9';
export const CELEBRATE_GOLD: string = '#FFD700';

// ============ 遮罩层 ============
export const OVERLAY_MASK: string = '#66000000';
export const OVERLAY_MASK_LIGHT: string = '#4D000000';
export const OVERLAY_DIM: string = '#33000000';
export const OVERLAY_SUBTLE: string = '#26000000';

// ============ 阴影色 ============
export const SHADOW_DEFAULT: string = '#1A000000';
export const SHADOW_LIGHT: string = '#14000000';
export const SHADOW_SUBTLE: string = '#0A000000';
export const SHADOW_MICRO: string = '#08000000';
export const SHADOW_MEDIUM: string = '#28000000';

// ============ Zone 颜色（配装系统） ============
export const ZONE_HEAD_COLOR: string = '#42A5F5';
export const ZONE_UPPER_COLOR: string = '#EF5350';
export const ZONE_LOWER_COLOR: string = '#5C6BC0';
export const ZONE_FEET_COLOR: string = '#8D6E63';
export const ZONE_CARRY_COLOR: string = '#FFA726';
export const ZONE_SLEEP_COLOR: string = '#7E57C2';
export const ZONE_MISC_COLOR: string = '#78909C';

// ============ Zone 颜色半透明变体（20% opacity） ============
export const ZONE_HEAD_TINT: string = '#3342A5F5';
export const ZONE_UPPER_TINT: string = '#33EF5350';
export const ZONE_LOWER_TINT: string = '#335C6BC0';
export const ZONE_FEET_TINT: string = '#338D6E63';
export const ZONE_CARRY_TINT: string = '#33FFA726';
export const ZONE_SLEEP_TINT: string = '#337E57C2';
export const ZONE_MISC_TINT: string = '#3378909C';

// ============ Zone 整块填充底色（便单式淡色块容器，~12% opacity） ============
// 用于 ZoneShell 整格淡色填充背景。比 TINT(20%) 更淡，避免整块染色过浓发脏；
// 比 STROKE(8~14%) 略重，保证内容文字在其上仍清晰可读。便单四象限色块同档观感。
export const ZONE_HEAD_FILL: string = '#1F42A5F5';
export const ZONE_UPPER_FILL: string = '#1FEF5350';
export const ZONE_LOWER_FILL: string = '#1F5C6BC0';
export const ZONE_FEET_FILL: string = '#1F8D6E63';
export const ZONE_CARRY_FILL: string = '#1FFFA726';
export const ZONE_SLEEP_FILL: string = '#1F7E57C2';
export const ZONE_MISC_FILL: string = '#1F78909C';

// ============ Zone 聚焦态卡片底色（便单式近实心淡色块，白底掺 ~20% 彩，不透明） ============
// 聚焦态卡片背后铺纯白遮罩隔离干扰，卡片本身需用「白里掺彩」的实心色（非彩色降透明度），
// 否则透出背后白会显灰发脏。色值 = ZONE_*_COLOR 与白色按 20% 混合后的不透明 hex。
// 8% 太淡（zone 色辨不出、卡片飘在遮罩上无实体感），加深到 20%——明显可辨该部位主题色，
// 又不至于像 FILL(半透明)那样大面积压抑，便单四象限聚焦色块同档：淡而有色、纯净、可读性高。
export const ZONE_HEAD_FOCUS_BG: string = '#D9EDFD';
export const ZONE_UPPER_FOCUS_BG: string = '#FCDDDC';
export const ZONE_LOWER_FOCUS_BG: string = '#DEE1F2';
export const ZONE_FEET_FOCUS_BG: string = '#E8E2E0';
export const ZONE_CARRY_FOCUS_BG: string = '#FFEDD3';
export const ZONE_SLEEP_FOCUS_BG: string = '#E5DDF3';
export const ZONE_MISC_FOCUS_BG: string = '#E4E9EB';

// ============ Zone 容器描边色（按饱和度分档，B-1） ============
// 高饱和（蓝/红/靛）~8% alpha，中饱和（橙/紫）~11%，低饱和（棕/灰蓝）~14%，
// 目的：视觉描边深浅在七个部位间观感均衡，避免高饱和色描边过重。
export const ZONE_HEAD_STROKE: string = '#1442A5F5';
export const ZONE_UPPER_STROKE: string = '#14EF5350';
export const ZONE_LOWER_STROKE: string = '#145C6BC0';
export const ZONE_FEET_STROKE: string = '#248D6E63';
export const ZONE_CARRY_STROKE: string = '#1CFFA726';
export const ZONE_SLEEP_STROKE: string = '#1C7E57C2';
export const ZONE_MISC_STROKE: string = '#2478909C';

// ============ Ceremony 渐变/光效 ============
export const WHITE_TRANSPARENT: string = '#00FFFFFF';
export const SHIMMER_WHITE_FAINT: string = '#18FFFFFF';
export const SHIMMER_GREEN_GLOSS: string = '#30E8F5E9';

// ============ Layer Badge 背景色（配装系统） ============
export const LAYER_BASE_BG: string = '#E3F2FD';
export const LAYER_MID_BG: string = '#FFF3E0';
export const LAYER_SHELL_BG: string = '#E8F5E9';
export const LAYER_INSULATION_BG: string = '#F3E5F5';
export const LAYER_ACCESSORY_BG: string = '#F5F5F5';
