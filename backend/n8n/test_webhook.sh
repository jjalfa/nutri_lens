#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Uso: ./backend/n8n/test_webhook.sh /ruta/a/tu_platillo.jpg"
  exit 1
fi

IMAGE_PATH="$1"
WEBHOOK_URL="${2:-http://localhost:5678/webhook/nutri-lens-analyze}"

if [ ! -f "$IMAGE_PATH" ]; then
  echo "Error: No existe el archivo '$IMAGE_PATH'"
  exit 1
fi

MIME_TYPE=$(file --mime-type -b "$IMAGE_PATH")
TMP_PAYLOAD=$(mktemp /tmp/nutri_lens_payload.XXXXXX.json)
trap 'rm -f "$TMP_PAYLOAD"' EXIT

python3 - "$IMAGE_PATH" "$MIME_TYPE" "$TMP_PAYLOAD" << 'PYEOF'
import base64, json, sys

image_path, mime_type, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(image_path, "rb") as f:
    encoded = base64.b64encode(f.read()).decode("utf-8")

with open(out_path, "w", encoding="utf-8") as out:
    json.dump({"imageBase64": encoded, "mimeType": mime_type}, out)
PYEOF

echo "Enviando '$IMAGE_PATH' ($MIME_TYPE) a $WEBHOOK_URL ..."
curl -sS -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data-binary "@$TMP_PAYLOAD" | python3 -m json.tool