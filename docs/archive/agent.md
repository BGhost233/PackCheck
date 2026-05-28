# Agent Instructions

## 自验收

每次修改后：
1. `hvigorw assembleApp --no-daemon` 构建通过
2. 对照任务文档「验收标准」逐条确认
3. 检查颜色/字号/圆角是否符合设计规范
4. 确认无硬编码数据、无 console.log 残留
5. 输出验收报告（每条 ✅ 或 ❌ + 修复说明）

构建失败或验收标准未全部通过，不得提交代码。
