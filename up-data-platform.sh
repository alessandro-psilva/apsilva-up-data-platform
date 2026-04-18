#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$BASE_DIR/apsilva-bed-data-platform"
FRONTEND_STACK_DIR="$BASE_DIR/apsilva-fed-data-platform"
FRONTEND_ENV_FILE="$FRONTEND_STACK_DIR/.env"
FRONTEND_ENV_EXAMPLE="$FRONTEND_STACK_DIR/.env.example"
BACKEND_HOST="${BACKEND_HOST:-}"
BACKEND_PORT="${BACKEND_PORT:-}"
FRONTEND_PORT="${FRONTEND_PORT:-}"
FRONTEND_API_BASE_URL="${FRONTEND_API_BASE_URL:-}"
PID_FILE="$BASE_DIR/.apsilva-fed-http.pid"

ensure_frontend_env() {
  if [[ ! -f "$FRONTEND_ENV_FILE" ]]; then
    if [[ -f "$FRONTEND_ENV_EXAMPLE" ]]; then
      cp "$FRONTEND_ENV_EXAMPLE" "$FRONTEND_ENV_FILE"
      echo "[frontend] Arquivo .env criado a partir de .env.example"
    else
      cat >"$FRONTEND_ENV_FILE" <<EOF
    BACKEND_HOST=apsilva-bed-data-platform-api
    BACKEND_PORT=8000
    FRONTEND_PORT=8080
    FRONTEND_API_BASE_URL=http://apsilva-bed-data-platform-api:8000
AZURITE_BLOB_PORT=10000
AZURITE_QUEUE_PORT=10001
AZURITE_TABLE_PORT=10002
AZURITE_DATA_DIR=./azurite-data
PLATFORM_NET_NAME=apsilva-fed-platform-net
EOF
      echo "[frontend] Arquivo .env criado com valores padrao"
    fi
  fi
}

load_frontend_env() {
  ensure_frontend_env

  set -a
  # shellcheck disable=SC1090
  . "$FRONTEND_ENV_FILE"
  set +a

  : "${BACKEND_HOST:?BACKEND_HOST is required in $FRONTEND_ENV_FILE}"
  : "${BACKEND_PORT:?BACKEND_PORT is required in $FRONTEND_ENV_FILE}"
  : "${FRONTEND_PORT:?FRONTEND_PORT is required in $FRONTEND_ENV_FILE}"
  : "${FRONTEND_API_BASE_URL:?FRONTEND_API_BASE_URL is required in $FRONTEND_ENV_FILE}"
}

start_backend() {
  load_frontend_env
  echo "[backend] Limpando containers antigos..."
  (cd "$BACKEND_DIR" && docker compose down --remove-orphans)
  echo "[backend] Subindo API com Docker Compose..."
  (cd "$BACKEND_DIR" && docker compose up -d --build --force-recreate)
  echo "[backend] OK: http://${BACKEND_HOST}:${BACKEND_PORT}"
}

stop_backend() {
  echo "[backend] Parando API..."
  (cd "$BACKEND_DIR" && docker compose down)
  echo "[backend] OK"
}

start_frontend() {
  load_frontend_env

  # Encerra eventual servidor legado para evitar conflito na porta 8080.
  if [[ -f "$PID_FILE" ]]; then
    local current_pid
    current_pid="$(cat "$PID_FILE")"
    if kill -0 "$current_pid" 2>/dev/null; then
      kill "$current_pid" 2>/dev/null || true
      echo "[frontend] Processo legado $current_pid finalizado"
    fi
    rm -f "$PID_FILE"
  fi
  pkill -f "python3 -m http.server $FRONTEND_PORT" 2>/dev/null || true

  echo "[frontend] Subindo frontend containerizado + Azurite..."
  (cd "$FRONTEND_STACK_DIR" && docker compose up -d --build)
  echo "[frontend] OK: http://localhost:$FRONTEND_PORT"
  echo "[frontend] API target: $FRONTEND_API_BASE_URL"
}

stop_frontend() {
  load_frontend_env

  if [[ -f "$PID_FILE" ]]; then
    local current_pid
    current_pid="$(cat "$PID_FILE")"
    if kill -0 "$current_pid" 2>/dev/null; then
      kill "$current_pid" 2>/dev/null || true
      echo "[frontend] Processo legado $current_pid finalizado"
    fi
    rm -f "$PID_FILE"
  fi
  pkill -f "python3 -m http.server $FRONTEND_PORT" 2>/dev/null || true

  echo "[frontend] Parando frontend containerizado + Azurite..."
  (cd "$FRONTEND_STACK_DIR" && docker compose down)
  echo "[frontend] OK"
}

status_all() {
  load_frontend_env

  echo "--- Status backend ---"
  (cd "$BACKEND_DIR" && docker compose ps)
  echo
  echo "--- Status frontend ---"
  (cd "$FRONTEND_STACK_DIR" && docker compose ps)
}

start_all() {
  start_backend
  start_frontend
  echo
  echo "✅ Data Platform pronta!"
  echo
  echo "🐷 Interface web:      http://localhost:$FRONTEND_PORT"
  echo "📊 API Backend:        http://${BACKEND_HOST}:${BACKEND_PORT}"
  echo "📖 Swagger docs:       http://${BACKEND_HOST}:${BACKEND_PORT}/docs"
  echo "❤️  Health check:       http://${BACKEND_HOST}:${BACKEND_PORT}/health"
  echo "🔌 Front API target:   $FRONTEND_API_BASE_URL"
}

stop_all() {
  stop_frontend
  stop_backend
}

usage() {
  load_frontend_env
  cat <<EOF
Uso: $(basename "$0") [start|stop|restart|status]

Comandos:
  start    Sobe backend (docker compose) e frontend containerizado (nginx + Azurite)
  stop     Para frontend e backend
  restart  Reinicia tudo
  status   Mostra status dos dois

📍 Acesso:
  http://localhost:$FRONTEND_PORT        🐷 Frontend (container)
  http://${BACKEND_HOST}:${BACKEND_PORT}                 📊 API Backend
  http://localhost:10000                💾 Azurite Blob
  http://${BACKEND_HOST}:${BACKEND_PORT}/docs            📖 Swagger docs

Variaveis opcionais:
  BACKEND_HOST              Host da API (obrigatorio no .env)
  BACKEND_PORT              Porta da API (obrigatorio no .env)
  FRONTEND_PORT             Porta do frontend no host (obrigatorio no .env)
  FRONTEND_API_BASE_URL     URL da API consumida pelo frontend (obrigatorio no .env)

Obs:
  Se .env nao existir em apsilva-fed-data-platform, ele sera criado automaticamente.
EOF
}

main() {
  local command="${1:-start}"

  case "$command" in
    start)
      start_all
      ;;
    stop)
      stop_all
      ;;
    restart)
      stop_all
      start_all
      ;;
    status)
      status_all
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
