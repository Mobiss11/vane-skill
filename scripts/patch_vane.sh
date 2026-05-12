#!/bin/bash
# Патч Vane для совместимости с DeepSeek V4 Pro
# Меняет response_format с json_schema на json_object
set -e

VANE_DIR="${1:-/tmp/Vane}"
TARGET="$VANE_DIR/src/lib/models/providers/openai/openaiLLM.ts"

if [ ! -f "$TARGET" ]; then
    echo "❌ Файл не найден: $TARGET"
    echo "   Укажи путь к Vane: bash scripts/patch_vane.sh /path/to/Vane"
    exit 1
fi

echo "🔧 Патчим Vane для DeepSeek V4 Pro..."
echo "   Файл: $TARGET"

# Check if already patched
if grep -q 'response_format: { type: "json_object" }' "$TARGET"; then
    echo "   ✅ Уже пропатчен, пропускаю."
    exit 0
fi

# Create backup
cp "$TARGET" "$TARGET.bak"

# Replace parse() with create() + add json_object response_format + inject "json" into last message
sed -i '' 's/chat\.completions\.parse({/chat.completions.create({/' "$TARGET"
sed -i '' 's/response_format: zodResponseFormat(input\.schema, .object.),/response_format: { type: "json_object" },/' "$TARGET"

echo "   ✅ Патч применён. Бэкап: $TARGET.bak"
echo ""
echo "   Пересобери Vane:"
echo "   cd $VANE_DIR && npm run build"
