# 量化智库 · 外部代理接口文档(供 DeepSeek Harness 等代理读取)

本项目是一个**知识驱动的 A 股模拟交易系统**。知识库是它的"大脑":由用户积累的直播转写、笔记、交易复盘,以及人机共研的结论组成;策略从知识库选取知识子集驱动独立模拟账户交易;结果回灌验证知识。

外部代理(DeepSeek Harness)与本系统有两种集成方式:**文件接口**(推荐,零依赖)与 **HTTP API**(需要实时数据时)。

## 一、文件接口(推荐)

### 1. 知识收件箱 —— 你把分析结论写进智库

目录:`data/knowledge-inbox/`(可用环境变量 `BRAIN_KNOWLEDGE_INBOX` 修改)

把**人机共研确认后的知识**写成 `.md` 文件放入该目录,调度器约 1 分钟内自动入库,文件归档到 `processed/` 子目录。文件支持前置元数据:

```markdown
---
kind: distilled_rule
title: (可选)标题
styles: swing
symbols: 600519, 000977
industries: 半导体
tags: 止损, 仓位, 分时均价
confidence: 0.7
claim: 一句话操作主张(有此字段才按规则卡入库)
entry_conditions: 条件一; 条件二
exit_conditions: 条件一
risk_notes: 风险提示
---

(可选)正文:规则的背景、来源直播或讨论的上下文。
```

字段说明:
- `kind`:`distilled_rule`(规则卡)/`note`(笔记)/`trade_review`(交易复盘)/`reflection`(阶段反思);有 `claim` 时默认规则卡,否则默认 note
- `status`:默认 `active`(人机共研已确认);`styles` 可多选:`short`(短线)/`swing`(波段)/`medium`(中线)/`long`(长线)
- 规则卡的质量直接决定策略检索质量:主张要可执行,入场/出场条件尽量量化
- 未被确认的草稿**不要**放入收件箱;先与用户探讨达成一致

### 2. 知识镜像 —— 你从智库快速读取

目录:`data/exports/`(环境变量 `BRAIN_EXPORT_DIR`),调度器定期刷新(约 20 分钟)或调用 HTTP 导出接口后立即刷新:

- `knowledge.json`:全量知识(含 id/kind/status/styles/symbols/tags/rule/胜率统计),适合程序处理
- `knowledge.md`:按类型分组的可读镜像,适合直接阅读与检索
- `strategies.json`:策略清单(风格/知识子集/参数/账户收益)
- `events.json`:事件台账(新闻事件/关联知识预期/次日板块实际反应)

### 3. 转写自动入库

环境变量 `BRAIN_TRANSCRIPT_DIR` 指向直播转写目录时,新增的 `.md`/`.txt` 会被自动入库(kind=transcript,状态 pending)并触发 AI 蒸馏。**无需人工干预**。

## 二、HTTP API(127.0.0.1:8787,本地无鉴权)

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 存活检查 |
| GET | `/api/overview` | 总览:账户/策略/净值/最新决策/触发事件 |
| GET | `/api/knowledge?search=&status=&kind=&style=&limit=` | 知识检索(支持关键词/风格过滤) |
| GET | `/api/knowledge/stats` | 知识统计与高胜率条目 |
| PUT | `/api/knowledge/:id/status` | 修改状态(pending/active/retired) |
| PUT | `/api/knowledge/:id/styles` | 修改风格标签(数组) |
| POST | `/api/knowledge/ingest/inbox` | 立即扫描收件箱 |
| POST | `/api/knowledge/distill` | 立即蒸馏 pending 知识(需已配 API Key) |
| GET | `/api/strategies` | 策略列表(含收益/胜率统计) |
| GET | `/api/export/knowledge.json` | 全量知识 JSON(同时刷新镜像) |
| GET | `/api/export/knowledge.md` | 全量知识 Markdown |
| GET | `/api/proposals` | 进化提案列表 |
| POST | `/api/evolution/generate` | 请求 AI 生成进化提案 |

示例:

```bash
curl -s "http://127.0.0.1:8787/api/knowledge?style=swing&limit=5"
curl -s "http://127.0.0.1:8787/api/export/knowledge.md" -o knowledge.md
```

## 三、协作守则

1. **人与 AI 的分工**:转写自动入库是机器的活;收件箱里的内容必须是与用户探讨达成一致的结论——这是"人机共研"的契约
2. **引用编号**:知识条目在决策中以 `#KB<id>` 引用并参与胜率归因;写入规则卡时不必指定 id(系统自动分配),但在与用户讨论时可以用镜像里的 id 指代
3. **不要**直接修改 `data/stock-brain.db`(SQLite),一律通过收件箱或 API
4. **不要**把未经用户确认的推测写成规则卡;低把握的内容用 `kind: note` + `confidence` 如实标注
5. 交易相关操作(建策略/批准提案)属于用户决策,代理只提供分析与建议
