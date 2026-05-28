# Findings

## Index.ets 结构分析
- 总行数: 2514
- @State 变量: 60+
- @Builder Sheet: 8 个（GearSheet, TripSheet, EditTripSheet, TempItemSheet, ImportSheet, GearSortSheet, GenerateTripSheet, SheetOverlay）
- 公共 @Builder: 3 个（FormInput, DatePickerField, GearCategoryTags/TempItemCategoryTags）
- 转发方法（胶水代码）: ~200 行
- 业务操作方法: ~40 个

## Sheet @Builder 行号范围
- SheetOverlay: 2065-2130 (65 行)
- sheetTitle(): 2132-2158 (26 行)
- GearSortSheet: 2161-2197 (36 行)
- SortOption: 2173-2197 (内嵌)
- GenerateTripSheet: 2200-2221 (21 行)
- GearSheet: 2224-2260 (36 行)
- EditTripSheet: 2263-2278 (15 行)
- TripSheet: 2282-2298 (16 行)
- TempItemSheet: 2301-2333 (32 行)
- GearCategoryTags: 2338-2354 (16 行)
- TempItemCategoryTags: 2357-2373 (16 行)
- ImportSheet: 2377-2464 (87 行)
- DatePickerField: 2467-2495 (28 行)
- FormInput: 2498-2512 (14 行)

## 依赖关系
- Sheet 内部引用的 Index state: sheetMode, gearSortMode, gearName, gearCategory, gearWeight, gearPrice, gearNote, editingGearId, tripTitle, tripDate, tempItemName, tempItemGroup, showTempAddNotice, importGearIds, importGearCategory, generateTripTitle, selectedMultiGearIds, errorText
- Sheet 内部调用的 Index 方法: closeSheet(), saveGear(), createChecklist(), saveTripInfo(), addTempItem(), importSelectedGear(), generateChecklistFromSelectedGears(), openAddGearFromImport()
