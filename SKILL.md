---
name: vane-skill
description: Используй когда пользователь хочет установить и настроить Vane (AI поисковик с DeepSeek V4 Pro), подключить SearxNG как поисковый бэкенд, настроить MCP-сервер для интеграции с Claude/OpenCode/Cursor, или развернуть полный self-hosted AI-search стек на своём сервере. Активируй при запросах: "установи Vane", "настрой AI поисковик", "запусти Vane + DeepSeek", "подключи MCP сервер Vane", "Perplexica MCP", "локальный аналог Perplexity", "self-hosted AI search", "поисковик с AI локально". Скилл автоматически проверяет наличие Docker/Node/Python, ставит всё одной командой (setup.sh), настраивает DeepSeek V4 Pro как LLM-провайдер, патчит совместимость, и поднимает MCP-сервер с 4 инструментами. Полный zero-to-hero за 10 минут.
---

# Vane Skill — AI Search Engine + DeepSeek V4 Pro + MCP

Локальный AI-поисковик уровня Perplexity. Само-хостится на твоём железе, использует DeepSeek V4 Pro как мозг, SearxNG как глаза, и подключается к любому MCP-клиенту.

> 💰 **Сколько экономим**: Perplexity Pro стоит **$20/мес**. DeepSeek V4 Pro API стоит **$0.27/M токенов** (со скидкой 75% до 31 мая). При 100 поисках в день — это **~$2-3/мес**. И data stays private — все поиски через SearxNG анонимны.

## Архитектура

```
┌─────────────────┐     MCP (stdio)      ┌──────────────────┐
│  Claude / Cursor │ ◄──────────────────► │  Vane MCP Server │
│  / OpenCode      │                     │  (vane-mcp)      │
└─────────────────┘                     └────────┬─────────┘
                                                  │ HTTP
                                         ┌────────▼─────────┐
                                         │  Vane (Next.js)   │
                                         │  localhost:3000   │
                                         └────────┬─────────┘
                                                  │
                              ┌───────────────────┼───────────────────┐
                              │                   │                   │
                     ┌────────▼─────────┐ ┌──────▼──────┐  ┌────────▼─────────┐
                     │  SearxNG (Docker)│ │ DeepSeek V4 │  │  Transformers.js │
                     │  localhost:8080  │ │ Pro API     │  │  (embeddings)    │
                     └──────────────────┘ └─────────────┘  └──────────────────┘
```

## Быстрый старт (один скрипт)

```bash
git clone https://github.com/Mobiss11/vane-skill.git
cd vane-skill
bash setup.sh
```

Скрипт сам:
1. Проверит Docker, Node, Python
2. Поднимет SearxNG в Docker
3. Склонирует и соберёт Vane из исходников
4. Пропатчит Vane для совместимости с DeepSeek V4 Pro
5. Настроит DeepSeek как LLM-провайдер
6. Установит MCP-сервер
7. Запустит всё и проверит что работает

## Пошаговая установка (руками)

### Шаг 0 — Проверь окружение

```bash
bash scripts/check_env.sh
```

Скрипт автоматически определит ОС и скажет чего не хватает.

**Нужно:**
- **Docker** (для SearxNG) — если нет, скрипт подскажет как поставить
- **Node.js 20+** — если нет: `brew install node` (Mac)
- **Python 3.11+** — обычно уже есть
- **uv** (менеджер пакетов) — `curl -LsSf https://astral.sh/uv/install.sh | sh`

#### Если Docker не установлен

Скилл автоматически определяет ОС и даёт правильную команду:

**macOS:**
```bash
brew install --cask docker
# Или скачать с https://docker.com
```

**Ubuntu/Debian:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Выйти и зайти заново
```

**Fedora:**
```bash
sudo dnf install docker docker-compose
sudo systemctl enable --now docker
```

**Windows:**
```bash
winget install Docker.DockerDesktop
# Или https://docs.docker.com/desktop/setup/install/windows-install/
```

**Если Docker совсем нельзя поставить** — SearxNG можно заменить публичным инстансом:
```bash
export SEARXNG_API_URL='https://searx.be'
```
Но учти: публичные инстансы медленнее и не приватны.

#### Альтернатива без Docker

Если Docker не вариант — можно использовать публичный SearxNG инстанс. Скилл подставит его автоматически если Docker не найден:

```bash
bash setup.sh --no-docker
```

Скрипт сам проверит доступность публичных SearxNG инстансов и выберет рабочий.

### Шаг 1 — Подними SearxNG

```bash
docker rm -f searxng 2>/dev/null
docker run -d --name searxng -p 8080:8080 \
  -v /tmp/searxng-settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng
```

Настройки SearxNG уже лежат в `configs/searxng-settings.yml` — они включают JSON-формат (нужен Vane) и отключают лимитер.

Проверка:
```bash
curl -s 'http://localhost:8080/search?q=test&format=json' | python3 -c "import sys,json; print(len(json.load(sys.stdin)['results']), 'results')"
```

### Шаг 2 — Поставь и собери Vane

```bash
cd /tmp
git clone https://github.com/ItzCrazyKns/Vane.git
cd Vane
npm install --legacy-peer-deps
npm run build
```

### Шаг 3 — Пропатчь Vane для DeepSeek

DeepSeek V4 Pro не поддерживает `response_format: json_schema` (только `json_object`). Нужно поправить 1 файл:

```bash
bash scripts/patch_vane.sh /tmp/Vane
```

**Что делает патч и почему он ОБЯЗАТЕЛЕН:**

Vane использует OpenAI SDK метод `chat.completions.parse()` который отправляет `response_format: { type: "json_schema", ... }`. DeepSeek V4 **не поддерживает** `json_schema` — только `json_object`. Без патча каждый поисковый запрос падает с ошибкой:

```
This response_format type is unavailable now
invalid_request_error
```

Патч исправляет ровно 2 строки в одном файле (`src/lib/models/providers/openai/openaiLLM.ts`):

| Было | Стало | Зачем |
|---|---|---|
| `chat.completions.parse({` | `chat.completions.create({` | Убираем structured output SDK |
| `response_format: zodResponseFormat(...)` | `response_format: { type: "json_object" }` | Меняем `json_schema` на поддерживаемый `json_object` |

Дополнительно патч инжектит `"Respond with valid JSON."` в промпт — это требование DeepSeek: слово `json` должно быть в сообщении пользователя для активации JSON-режима.

**Важно:** это ЕДИНСТВЕННЫЙ патч. Больше ничего в Vane менять не нужно. Модель `deepseek-chat` уже работает без thinking mode (не требует патча `extra_body`).

**Как проверить что патч применился:**

```bash
grep 'response_format.*json_object' /tmp/Vane/src/lib/models/providers/openai/openaiLLM.ts
# Должен показать: response_format: { type: "json_object" },
```

Если патч не применился — скрипт `patch_vane.sh` скажет об этом. После патча **обязательно пересобрать Vane**: `npm run build`.

### Шаг 4 — Настрой DeepSeek

Скопируй конфиг с DeepSeek в Vane:

```bash
cp configs/vane-config.json /tmp/Vane/data/config.json
```

**Модель по умолчанию:** `deepseek-chat` (это DeepSeek V4 Flash без thinking mode). 

Почему именно `deepseek-chat`, а не `deepseek-v4-pro`:
- `deepseek-chat` = DeepSeek V4 Flash с thinking mode **выключенным** — работает без патчей
- `deepseek-v4-pro` = DeepSeek V4 Pro с thinking mode **всегда включённым** — требует доп. патча `extra_body`
- Thinking mode не нужен для поиска — он добавляет 30-50% лишних токенов и требует пробрасывать `reasoning_content` между запросами (Vane не умеет)
- По оф. документации: `deepseek-chat` и `deepseek-reasoner` — это алиасы V4 Flash (non-thinking / thinking), **не** старый V3

Либо через веб-интерфейс (http://localhost:3000 → Settings):
1. Добавь провайдер: **OpenAI**
2. Name: `DeepSeek`
3. API Key: `sk-...` (твой ключ)
4. Base URL: `https://api.deepseek.com/v1`
5. Models: `deepseek-chat`

### Шаг 5 — Запусти Vane

```bash
cd /tmp/Vane
SEARXNG_API_URL='http://localhost:8080' npm run start
```

Проверка:
```bash
curl -s http://localhost:3000 | head -c 100  # Должен вернуть HTML
```

### Шаг 6 — Поставь MCP-сервер

```bash
cd /tmp
git clone https://github.com/Mobiss11/vane-mcp-server.git
cd vane-mcp-server
bash setup.sh
```

MCP-сервер даёт 4 инструмента: `web_search`, `balanced_search`, `deep_research`, `search_news`.

### Шаг 7 — Подключи к MCP-клиенту

**Claude Desktop** — отредактируй `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "vane": {
      "command": "uv",
      "args": ["run", "--directory", "/tmp/vane-mcp-server", "vane-mcp"],
      "env": {
        "VANE_BASE_URL": "http://localhost:3000"
      }
    }
  }
}
```

**OpenCode** — добавь в проектном `opencode.json` (ключ `mcp`, не `mcpServers`):

```json
{
  "mcp": {
    "vane": {
      "type": "local",
      "command": ["uv", "run", "--directory", "/tmp/vane-mcp-server", "vane-mcp"],
      "environment": {
        "PATH": "/opt/homebrew/bin:/Users/.../.local/bin:/usr/bin:/bin",
        "VANE_BASE_URL": "http://localhost:3000"
      },
      "enabled": true,
      "timeout": 120000
    }
  }
}
```

**Cursor** — добавь в `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "vane": {
      "command": "uvx",
      "args": ["vane-mcp"],
      "env": {
        "VANE_BASE_URL": "http://localhost:3000"
      }
    }
  }
}
```

После добавления — **перезапусти** IDE/MCP-клиент.

## Проверка всего стека

```bash
# 1. SearxNG
curl -s 'http://localhost:8080/search?q=hello&format=json' | python3 -c "import sys,json; print('SearxNG:', len(json.load(sys.stdin)['results']), 'results')"

# 2. Vane
curl -s http://localhost:3000 | head -c 50

# 3. MCP Server
uv run --directory /tmp/vane-mcp-server vane-mcp --version

# 4. Полный поисковый тест (Vane + DeepSeek)
curl -s 'http://localhost:3000/api/search' -X POST -H 'Content-Type: application/json' \
  -d '{"query":"цена биткоина","sources":["web"],"optimizationMode":"speed","chatModel":{"providerId":"deepseek","key":"deepseek-v4-pro"},"embeddingModel":{"providerId":"7f6e41e9-10c0-422c-8776-088fff2a9f48","key":"Xenova/all-MiniLM-L6-v2"},"history":[]}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','ERROR')[:200])"
```

## Решение проблем

### "Error Loading OpenAI Embedding Model"
Добавь embedding-модели в Transformers провайдер в конфиге Vane (`data/config.json`).

### "This response_format type is unavailable"
Патч из Шага 3 не применился. Это **единственный обязательный патч**. Проверь:
```bash
grep 'json_object' /tmp/Vane/src/lib/models/providers/openai/openaiLLM.ts
```
Если не показывает `response_format: { type: "json_object" }` — запусти `bash scripts/patch_vane.sh /tmp/Vane` и пересобери: `npm run build`.

### "The reasoning_content must be passed back"
Используется модель с thinking mode. Переключись на `deepseek-chat` (V4 Flash без thinking) в конфиге Vane или через веб-интерфейс Settings.

### "Invalid provider type"
В `config.json` тип провайдера должен быть `openai`, не `customOpenAI`.

### SearxNG не возвращает результаты
Проверь что JSON формат включён в `searxng-settings.yml`: `search.formats: [html, json]`.

### Vane не видит SearxNG
Проверь что `SEARXNG_API_URL` указывает на правильный хост. Если Vane в Docker, а SearxNG отдельно — используй `host.docker.internal` (Mac/Windows) или IP хоста (Linux).

## Файлы скилла

| Файл | Назначение |
|---|---|
| `SKILL.md` | ← ты здесь |
| `setup.sh` | One-click установка всего стека |
| `scripts/check_env.sh` | Проверка окружения (Docker, Node, Python) |
| `scripts/patch_vane.sh` | Патч Vane для совместимости с DeepSeek |
| `configs/vane-config.json` | Конфиг Vane с DeepSeek V4 Pro |
| `configs/searxng-settings.yml` | Конфиг SearxNG с JSON-форматом |
| `configs/claude_desktop.json` | Пример MCP-конфига для Claude Desktop |
| `configs/opencode.json` | Пример MCP-конфига для OpenCode |
| `configs/cursor.json` | Пример MCP-конфига для Cursor |
