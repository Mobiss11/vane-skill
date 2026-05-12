# Vane Skill

AI-ассистент для установки и настройки полного self-hosted AI-search стека:
**Vane** (веб-интерфейс) + **DeepSeek V4 Pro** (LLM) + **SearxNG** (поиск) + **MCP Server** (интеграция).

> Создано для [OpenCode](https://opencode.ai), [Claude Desktop](https://claude.ai), [Cursor](https://cursor.com)

## 📦 Состав

| Компонент | Назначение | Порт |
|---|---|---|
| **Vane** | AI поисковик (Next.js) | 3000 |
| **SearxNG** | Мета-поисковый движок (Docker) | 8080 |
| **DeepSeek V4 Pro** | LLM-провайдер (API) | — |
| **Vane MCP Server** | MCP-интеграция (Python) | stdio / 8053 |

## 🚀 Установка

```bash
git clone https://github.com/Mobiss11/vane-skill.git
cd vane-skill
bash setup.sh
```

## 🛠️ Инструменты MCP

- `web_search` — быстрый веб-поиск
- `balanced_search` — сбалансированный поиск
- `deep_research` — глубокое исследование
- `search_news` — поиск новостей

## 📝 Лицензия

MIT
