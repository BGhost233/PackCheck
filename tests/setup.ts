/**
 * Vitest 全局 setup —— mock ArkTS 特有 API
 * 只有 ItineraryService.getTransportIcon() 用到 $r()，其余 service 纯 TS 逻辑无需 mock。
 */

// @ts-ignore: mock ArkTS 资源引用函数
(globalThis as any).$r = (resource: string) => ({ __resource: resource });
