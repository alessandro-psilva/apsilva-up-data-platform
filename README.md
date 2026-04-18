# Apsilva Data Platform - Orchestration & Setup

Central orchestration repository for the **Apsilva Data Platform**, managing both backend (FastAPI) and frontend (Nginx) services with full Docker containerization and environment-driven configuration.

## 📦 Project Structure

```
apsilva-up-data-platform/          # This repo - orchestration & setup
├── up-data-platform.sh            # Main orchestration script
├── .env.example                    # Environment variables template
├── ENVIRONMENT_QUICK_REFERENCE.md  # Quick reference for all env vars
└── README.md                       # This file

Sibling repositories (cloned as needed):
├── apsilva-bed-data-platform/      # FastAPI backend
│   ├── app/
│   ├── tests/
│   └── docker-compose.yml
└── apsilva-fed-data-platform/      # Nginx frontend + Azurite storage
    ├── frontend/
    ├── docker-compose.yml
    └── .env.example
```

## 🚀 Quick Start

### 1. Clone This Repository

```bash
cd ~/repos
git clone https://github.com/alessandro-psilva/apsilva-up-data-platform.git
cd apsilva-up-data-platform
```

### 2. Initialize Environment

```bash
# From the apsilva-up-data-platform directory
cp .env.example .env
nano .env
```

This will:
- Configure orchestration variables in this repository
- Keep sibling repos independent for direct execution

### 3. Start Services

```bash
./up-data-platform.sh restart
```

This starts:
- **Frontend** on `http://localhost:8080` (Nginx)
- **Backend** on `http://localhost:8000` (FastAPI)
- **Azurite Storage** on ports 10000-10002 (Azure Storage emulator)

### 4. Verify Installation

```bash
# Check frontend
curl http://localhost:8080/

# Check backend health
curl http://localhost:8000/health

# Check API
curl http://localhost:8000/databricks/jobs
```

## 📋 Available Commands

```bash
./up-data-platform.sh start      # Start all services
./up-data-platform.sh stop       # Stop all services
./up-data-platform.sh restart    # Restart all services
./up-data-platform.sh status     # Check service status
./up-data-platform.sh stop --purge-data  # Stop and remove volumes
```

## ⚙️ Environment Configuration

For orchestration runs (`./up-data-platform.sh ...`), configuration is environment-driven through `apsilva-up-data-platform/.env`.

Sibling repositories remain independent and can still be executed directly with their own `.env` files.

See `ENVIRONMENT_QUICK_REFERENCE.md` for complete variable documentation.

**Key variables:**

```env
# Backend
BACKEND_HOST=apsilva-bed-data-platform-api
BACKEND_PORT=8000

# Frontend
FRONTEND_API_BASE_URL=http://apsilva-bed-data-platform.localhost:8000
FRONTEND_PORT=8080

# Storage (Azurite)
AZURITE_BLOB_PORT=10000
AZURITE_QUEUE_PORT=10001
AZURITE_TABLE_PORT=10002
AZURITE_DATA_DIR=./azurite-data

# Docker network
PLATFORM_NET_NAME=apsilva-platform-network
```

## 🔒 Security

- **CORS**: Hardened to allow only `localhost:8080` and `127.0.0.1:8080`
- **Parameter Validation**: Strict type checking for API parameters (no nested objects)
- **Environment-Driven**: No hardcoded defaults; all configuration from env vars
- **Frontend API URL**: Must be host-reachable for browser execution (`http://apsilva-bed-data-platform.localhost:8000` by default)

## 📚 Documentation

- **[ENVIRONMENT_QUICK_REFERENCE.md](./ENVIRONMENT_QUICK_REFERENCE.md)** - Complete variable reference
- **[PARAMETERIZATION_REPORT.md](./PARAMETERIZATION_REPORT.md)** - Detailed parametrization patterns
- **Backend**: See `apsilva-bed-data-platform/DEVELOPMENT.md`
- **Frontend**: See `apsilva-fed-data-platform/README.md`

## 🛠️ Development Workflow

### Orchestrator Environment

```bash
cd apsilva-up-data-platform
cp .env.example .env
nano .env
```

### Run Backend Tests

```bash
cd apsilva-bed-data-platform
docker compose run --rm api pytest tests/
```

### Build Frontend

```bash
cd apsilva-fed-data-platform
docker compose build frontend
```

### View Logs

```bash
cd apsilva-fed-data-platform
docker compose logs -f frontend

cd apsilva-bed-data-platform
docker compose logs -f api
```

## 🚨 Troubleshooting

### Services won't start

Check `.env` file:
```bash
cat .env
```

All variables should be set. If missing, run:
```bash
cp .env.example .env
```

### Frontend can't reach backend

Verify FRONTEND_API_BASE_URL in `.env`:
```bash
grep FRONTEND_API_BASE_URL .env
```

Should be: `http://apsilva-bed-data-platform.localhost:8000` (host URL consumed by browser)

### Port conflicts

Change port in `.env`:
```bash
FRONTEND_PORT=9090
BACKEND_PORT=9000
```

Then restart:
```bash
./up-data-platform.sh restart
```

## 📞 Support

For issues, check the logs:
```bash
docker logs apsilva-fed-data-platform-frontend-1
docker logs apsilva-bed-data-platform-api-1
```

## 📝 License

Proprietary - Apsilva 2026
