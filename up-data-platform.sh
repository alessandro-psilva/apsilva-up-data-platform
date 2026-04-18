#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(dirname "$BASE_DIR")"
BACKEND_DIR="$REPOS_DIR/apsilva-bed-data-platform"
FRONTEND_STACK_DIR="$REPOS_DIR/apsilva-fed-data-platform"
BACKEND_REPO_NAME="$(basename "$BACKEND_DIR")"
FRONTEND_REPO_NAME="$(basename "$FRONTEND_STACK_DIR")"
BACKEND_HOST_PUBLIC="${BACKEND_HOST_PUBLIC:-${BACKEND_REPO_NAME}.localhost}"
FRONTEND_HOST_PUBLIC="${FRONTEND_HOST_PUBLIC:-${FRONTEND_REPO_NAME}.localhost}"
UP_ENV_FILE="$BASE_DIR/.env"
UP_ENV_EXAMPLE="$BASE_DIR/.env.example"
BACKEND_HOST="${BACKEND_HOST:-}"
BACKEND_PORT="${BACKEND_PORT:-}"
FRONTEND_PORT="${FRONTEND_PORT:-}"
FRONTEND_API_BASE_URL="${FRONTEND_API_BASE_URL:-}"
PID_FILE="$REPOS_DIR/.apsilva-fed-http.pid"

ensure_up_env() {
  if [[ ! -f "$UP_ENV_FILE" ]]; then
    if [[ -f "$UP_ENV_EXAMPLE" ]]; then
      cp "$UP_ENV_EXAMPLE" "$UP_ENV_FILE"
      echo "[orchestrator] Arquivo .env criado a partir de .env.example"
    else
      cat >"$UP_ENV_FILE" <<EOF
BACKEND_HOST=apsilva-bed-data-platform-api
BACKEND_PORT=8000
FRONTEND_PORT=8080
FRONTEND_API_BASE_URL=http://apsilva-bed-data-platform.localhost:8000
AZURITE_BLOB_PORT=10000
AZURITE_QUEUE_PORT=10001
AZURITE_TABLE_PORT=10002
AZURITE_DATA_DIR=./azurite-data
PLATFORM_NET_NAME=apsilva-platform-network
EOF
      echo "[orchestrator] Arquivo .env criado com valores padrao"
    fi
  fi
}

load_up_env() {
  ensure_up_env

  set -a
  # shellcheck disable=SC1090
  . "$UP_ENV_FILE"
  set +a

  : "${BACKEND_HOST:?BACKEND_HOST is required in $UP_ENV_FILE}"
  : "${BACKEND_PORT:?BACKEND_PORT is required in $UP_ENV_FILE}"
  : "${FRONTEND_PORT:?FRONTEND_PORT is required in $UP_ENV_FILE}"
  : "${FRONTEND_API_BASE_URL:?FRONTEND_API_BASE_URL is required in $UP_ENV_FILE}"
}

start_backend() {
  load_up_env
  echo "[backend] Limpando containers antigos..."
  (cd "$BACKEND_DIR" && docker compose down --remove-orphans)
  echo "[backend] Subindo API com Docker Compose..."
  (cd "$BACKEND_DIR" && docker compose up -d --build --force-recreate)
  echo "[backend] OK: http://${BACKEND_HOST_PUBLIC}:${BACKEND_PORT}"
}

stop_backend() {
  local purge_data="${1:-false}"
  echo "[backend] Parando API..."
  if [[ "$purge_data" == "true" ]]; then
    (cd "$BACKEND_DIR" && docker compose down -v)
    echo "[backend] Volumes removidos (-v)"
  else
    (cd "$BACKEND_DIR" && docker compose down)
  fi
  echo "[backend] OK"
}

start_frontend() {
  load_up_env

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
  echo "[frontend] OK: http://${FRONTEND_HOST_PUBLIC}:$FRONTEND_PORT"
  echo "[frontend] API target: $FRONTEND_API_BASE_URL"
}

stop_frontend() {
  local purge_data="${1:-false}"
  load_up_env

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
  if [[ "$purge_data" == "true" ]]; then
    (cd "$FRONTEND_STACK_DIR" && docker compose down -v)
    echo "[frontend] Volumes removidos (-v)"
  else
    (cd "$FRONTEND_STACK_DIR" && docker compose down)
  fi
  echo "[frontend] OK"
}

status_all() {
  load_up_env

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
  echo "Acesso local (host):"
  echo "🐷 Interface web:      http://$FRONTEND_HOST_PUBLIC:$FRONTEND_PORT"
  echo "📊 API Backend:        http://$BACKEND_HOST_PUBLIC:$BACKEND_PORT"
  echo "📖 Swagger docs:       http://$BACKEND_HOST_PUBLIC:$BACKEND_PORT/docs"
  echo "❤️  Health check:       http://$BACKEND_HOST_PUBLIC:$BACKEND_PORT/health"
  echo
  echo "Rede Docker (interna):"
  echo "🔌 Front API target:   $FRONTEND_API_BASE_URL"
  echo "🧭 API service:        http://${BACKEND_HOST}:${BACKEND_PORT}"
}

stop_all() {
  local purge_data="${1:-false}"
  stop_frontend "$purge_data"
  stop_backend "$purge_data"
}

usage() {
  load_up_env
  cat <<EOF
Uso: $(basename "$0") [start|stop|restart|status] [--purge-data]

Comandos:
  start    Sobe backend (docker compose) e frontend containerizado (nginx + Azurite)
  stop     Para frontend e backend (mantem volumes/dados)
  restart  Reinicia tudo
  status   Mostra status dos dois

Opcoes:
  --purge-data   Com stop/restart, remove volumes (docker compose down -v)

📍 Acesso:
  http://$FRONTEND_HOST_PUBLIC:$FRONTEND_PORT        🐷 Frontend (host)
  http://$BACKEND_HOST_PUBLIC:$BACKEND_PORT          📊 API Backend (host)
  http://localhost:10000                💾 Azurite Blob
  http://$BACKEND_HOST_PUBLIC:$BACKEND_PORT/docs    📖 Swagger docs (host)

📍 Rede Docker (interna):
  http://${BACKEND_HOST}:${BACKEND_PORT}                 📊 API Backend service
  $FRONTEND_API_BASE_URL                 🔌 Front API target

Variaveis opcionais:
  BACKEND_HOST_PUBLIC       Host publico da API no host (padrao: <repo-backend>.localhost)
  FRONTEND_HOST_PUBLIC      Host publico do frontend no host (padrao: <repo-frontend>.localhost)
  BACKEND_HOST              Host da API (obrigatorio no .env)
  BACKEND_PORT              Porta da API (obrigatorio no .env)
  FRONTEND_PORT             Porta do frontend no host (obrigatorio no .env)
  FRONTEND_API_BASE_URL     URL da API consumida pelo frontend (obrigatorio no .env)

Obs:
  Se .env nao existir em apsilva-up-data-platform, ele sera criado automaticamente.
EOF
}

main() {
  local command="${1:-start}"
  local purge_data="false"

  for arg in "$@"; do
    if [[ "$arg" == "--purge-data" ]]; then
      purge_data="true"
    fi
  done

  case "$command" in
    start)
      start_all
      ;;
    stop)
      stop_all "$purge_data"
      ;;
    restart)
      stop_all "$purge_data"
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
