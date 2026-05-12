#!/bin/bash
# Проверка окружения для Vane + DeepSeek + MCP стека
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
check() { if command -v "$1" &>/dev/null; then echo -e "  ${GREEN}✅${NC} $2"; else echo -e "  ${RED}❌${NC} $2 — не найден"; fi }
version() { echo -e "     версия: $($1 --version 2>&1 | head -1)"; }

echo "========================================"
echo "  Vane Stack — проверка окружения"
echo "========================================"
echo ""

echo "🔧 Система:"
echo "  OS: $(uname -s) $(uname -m)"

echo ""
echo "📦 Обязательные компоненты:"
check docker "Docker (для SearxNG)" && version docker
check node "Node.js 20+ (для Vane)" && echo "     версия: $(node --version 2>&1)"
check npm "npm (менеджер пакетов Node)" && echo "     версия: $(npm --version 2>&1)"

echo ""
echo "🐍 Python / MCP:"
check python3 "Python 3.11+ (для MCP сервера)" && echo "     версия: $(python3 --version 2>&1)"
check uv "uv (менеджер пакетов Python)"
check pip3 "pip3"

echo ""
echo "🌐 Порты (должны быть свободны):"
for port in 3000 8080 8053; do
    if lsof -i :$port -sTCP:LISTEN &>/dev/null; then
        echo -e "  ${YELLOW}⚠️${NC}  Порт $port занят"
    else
        echo -e "  ${GREEN}✅${NC} Порт $port свободен"
    fi
done

echo ""
echo "📊 Ресурсы:"
if [[ "$(uname)" == "Darwin" ]]; then
    RAM=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GB", $1/1024/1024/1024}')
    echo "  RAM: $RAM"
    DISK=$(df -h / | tail -1 | awk '{print $4}')
    echo "  Свободно на диске: $DISK"
fi

echo ""
echo "========================================"
echo "  Готово."
echo "========================================"
