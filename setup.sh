#!/bin/bash
set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INSTALL_DIR="$HOME/vane-stack"
VANE_DIR="$INSTALL_DIR/Vane"
MCP_DIR="$INSTALL_DIR/vane-mcp-server"

echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD}  Vane AI Search — Полная Установка  ${NC}"
echo -e "${BOLD}  DeepSeek V4 Pro + SearxNG + MCP    ${NC}"
echo -e "${BOLD}======================================${NC}"
echo ""

# ── API Key ───────────────────────────────────────
echo -e "${YELLOW}🔑 API ключ DeepSeek${NC}"
if [ -z "$DEEPSEEK_API_KEY" ]; then
    read -p "Введи API ключ DeepSeek (или Enter чтобы пропустить): " DEEPSEEK_API_KEY
fi
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  Ключ не указан. Вставь его позже в $VANE_DIR/data/config.json${NC}"
    DEEPSEEK_API_KEY="sk-YOUR-DEEPSEEK-API-KEY-HERE"
fi
echo ""

# ── Prerequisites ─────────────────────────────────
echo -e "${BLUE}📦 Проверка зависимостей...${NC}"

command -v docker >/dev/null 2>&1 || { echo "❌ Docker не установлен. Установи: https://docker.com"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js не установлен. Установи: brew install node"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "❌ npm не установлен."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python 3 не установлен."; exit 1; }

echo -e "  ${GREEN}✅${NC} Docker: $(docker --version 2>&1 | head -1)"
echo -e "  ${GREEN}✅${NC} Node:   $(node --version 2>&1)"
echo -e "  ${GREEN}✅${NC} npm:    $(npm --version 2>&1)"
echo -e "  ${GREEN}✅${NC} Python: $(python3 --version 2>&1)"
echo ""

# ── Directory ─────────────────────────────────────
mkdir -p "$INSTALL_DIR"
echo -e "${GREEN}📁 Директория: $INSTALL_DIR${NC}"
echo ""

# ── Step 1: SearxNG ───────────────────────────────
echo -e "${BLUE}[1/5] SearxNG — поисковый движок${NC}"
docker rm -f searxng 2>/dev/null || true
docker run -d --name searxng -p 8080:8080 \
    -v "$(pwd)/configs/searxng-settings.yml:/etc/searxng/settings.yml:ro" \
    searxng/searxng
sleep 3
echo -e "  ${GREEN}✅${NC} SearxNG запущен на http://localhost:8080"
echo ""

# ── Step 2: Clone Vane ────────────────────────────
echo -e "${BLUE}[2/5] Vane — AI поисковик${NC}"
if [ -d "$VANE_DIR" ]; then
    echo "  Vane уже склонирован, обновляю..."
    cd "$VANE_DIR" && git pull 2>/dev/null || true
else
    git clone https://github.com/ItzCrazyKns/Vane.git "$VANE_DIR"
fi
cd "$VANE_DIR"
echo "  📦 Установка npm зависимостей..."
npm install --legacy-peer-deps --silent 2>&1 | tail -1
echo "  🔨 Сборка..."
npm run build 2>&1 | tail -1
echo -e "  ${GREEN}✅${NC} Vane собран"
echo ""

# ── Step 3: Patch Vane ────────────────────────────
echo -e "${BLUE}[3/5] Патч Vane для DeepSeek V4 Pro${NC}"
TARGET="$VANE_DIR/src/lib/models/providers/openai/openaiLLM.ts"
if grep -q 'response_format: { type: "json_object" }' "$TARGET" 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} Уже пропатчен"
else
    cp "$TARGET" "$TARGET.bak"
    sed -i '' 's/chat\.completions\.parse({/chat.completions.create({/' "$TARGET" 2>/dev/null || \
    sed -i 's/chat\.completions\.parse({/chat.completions.create({/' "$TARGET"
    sed -i '' 's/response_format: zodResponseFormat(input\.schema, .object.),/response_format: { type: "json_object" },/' "$TARGET" 2>/dev/null || \
    sed -i 's/response_format: zodResponseFormat(input\.schema, .object.),/response_format: { type: "json_object" },/' "$TARGET"
    echo "  🔨 Пересборка после патча..."
    npm run build 2>&1 | tail -1
    echo -e "  ${GREEN}✅${NC} Патч применён"
fi
echo ""

# ── Step 4: Configure DeepSeek ─────────────────────
echo -e "${BLUE}[4/5] Настройка DeepSeek V4 Pro${NC}"
mkdir -p "$VANE_DIR/data"
cp "$(pwd)/configs/vane-config.json" "$VANE_DIR/data/config.json" 2>/dev/null || \
cp configs/vane-config.json "$VANE_DIR/data/config.json"

# Replace API key
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|sk-YOUR-DEEPSEEK-API-KEY-HERE|$DEEPSEEK_API_KEY|g" "$VANE_DIR/data/config.json"
else
    sed -i "s|sk-YOUR-DEEPSEEK-API-KEY-HERE|$DEEPSEEK_API_KEY|g" "$VANE_DIR/data/config.json"
fi
echo -e "  ${GREEN}✅${NC} DeepSeek V4 Pro настроен"
echo ""

# ── Step 5: MCP Server ────────────────────────────
echo -e "${BLUE}[5/5] MCP Сервер${NC}"
if [ -d "$MCP_DIR" ]; then
    echo "  MCP-сервер уже склонирован, обновляю..."
    cd "$MCP_DIR" && git pull 2>/dev/null || true
else
    git clone https://github.com/Mobiss11/vane-mcp-server.git "$MCP_DIR"
fi
cd "$MCP_DIR"
if command -v uv >/dev/null 2>&1; then
    uv pip install -e . 2>&1 | tail -1
else
    pip3 install -e . 2>&1 | tail -1
fi
echo -e "  ${GREEN}✅${NC} MCP-сервер установлен"
echo ""

# ── Start Vane ─────────────────────────────────────
echo -e "${BLUE}🚀 Запуск Vane...${NC}"
cd "$VANE_DIR"
kill $(lsof -ti:3000) 2>/dev/null || true
SEARXNG_API_URL='http://localhost:8080' nohup npm run start > /tmp/vane.log 2>&1 &
sleep 5

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} Vane запущен: http://localhost:3000"
else
    echo -e "  ${YELLOW}⚠️  Vane может всё ещё запускаться. Проверь: tail -f /tmp/vane.log${NC}"
fi
echo ""

# ── Summary ────────────────────────────────────────
echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD}  ✅ Установка завершена!            ${NC}"
echo -e "${BOLD}======================================${NC}"
echo ""
echo -e "  🌐 Vane:        ${GREEN}http://localhost:3000${NC}"
echo -e "  🔍 SearxNG:     ${GREEN}http://localhost:8080${NC}"
echo -e "  🤖 LLM:         ${GREEN}DeepSeek V4 Pro${NC}"
echo -e "  🔌 MCP Server:  ${GREEN}vane-mcp${NC}"
echo ""
echo -e "  ${BOLD}Подключение MCP к Claude Desktop:${NC}"
echo "  Добавь в ~/Library/Application Support/Claude/claude_desktop_config.json:"
echo ""
echo '  {'
echo '    "mcpServers": {'
echo '      "vane": {'
echo "        \"command\": \"uv\","
echo "        \"args\": [\"run\", \"--directory\", \"$MCP_DIR\", \"vane-mcp\"],"
echo '        "env": { "VANE_BASE_URL": "http://localhost:3000" }'
echo '      }'
echo '    }'
echo '  }'
echo ""
echo -e "  ${BOLD}Подключение MCP к OpenCode:${NC}"
echo "  Добавь в ~/Library/Application Support/ai.opencode.desktop/opencode.settings"
echo ""
echo -e "  ${YELLOW}⚠️  Перезапусти MCP-клиент после добавления конфига${NC}"
echo -e "  ${YELLOW}⚠️  Первый поиск может быть медленным — скачивается embedding модель${NC}"
echo ""
