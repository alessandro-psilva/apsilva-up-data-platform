# Quick Reference - Environment Configuration

## 🚀 TL;DR

```bash
# 1. Copy environment template
cp apsilva-fed-data-platform/.env.example apsilva-fed-data-platform/.env

# 2. Edit if needed (optional - defaults work for local dev)
nano apsilva-fed-data-platform/.env

# 3. Start everything
./up-data-platform.sh restart

# 4. Access frontend
open http://localhost:8080
```

---

## 📋 Required Environment Variables

These MUST be set in `.env` or containers will fail:

| Variable | Default | Purpose |
|----------|---------|---------|
| `FRONTEND_API_BASE_URL` | `http://apsilva-bed-data-platform-api:8000` | Backend API endpoint for frontend |
| `FRONTEND_PORT` | `8080` | Frontend port on localhost |
| `BACKEND_HOST` | `apsilva-bed-data-platform-api` | Backend service name |
| `BACKEND_PORT` | `8000` | Backend service port |

**Error if missing?** YES - container startup will fail with explicit error message.

---

## 🔧 Optional Environment Variables

These can be overridden but have sensible defaults:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CORS_ALLOWED_ORIGINS` | `http://localhost:8080,http://127.0.0.1:8080` | Backend CORS whitelist |
| `AZURITE_BLOB_PORT` | `10000` | Azure Blob storage port |
| `AZURITE_QUEUE_PORT` | `10001` | Azure Queue storage port |
| `AZURITE_TABLE_PORT` | `10002` | Azure Table storage port |
| `AZURITE_DATA_DIR` | `./azurite-data` | Azurite persistence directory |
| `PLATFORM_NET_NAME` | `apsilva-fed-platform-net` | Docker network name |

**Error if missing?** NO - safe defaults will be used (for backend compatibility).

---

## 🔐 Common Customizations

### For Production
```bash
# .env for production
FRONTEND_API_BASE_URL=https://api.production.com
CORS_ALLOWED_ORIGINS=https://frontend.production.com,https://api.production.com
FRONTEND_PORT=443
```

### For Staging
```bash
# .env for staging
FRONTEND_API_BASE_URL=https://api-staging.example.com
CORS_ALLOWED_ORIGINS=https://frontend-staging.example.com
```

### For Remote Backend
```bash
# .env with remote backend
FRONTEND_API_BASE_URL=http://remote-api.example.com:8000
BACKEND_HOST=remote-api.example.com  # Not used by frontend, but validates
BACKEND_PORT=8000
```

---

## 🔗 Service Names (Docker Internal)

The project uses **service names** instead of IPs for inter-container communication:

- Frontend connects to: `http://apsilva-bed-data-platform-api:8000` (service name)
- NOT: `http://localhost:8000` (only from host)
- NOT: `http://127.0.0.1:8000` (container doesn't have localhost)

This allows containers to find each other automatically on the Docker network.

---

## ✅ Verification

Check that parametrization is working:

```bash
# 1. Verify .env exists
cat apsilva-fed-data-platform/.env

# 2. Check frontend logs
docker compose -f apsilva-fed-data-platform/docker-compose.yml logs frontend

# 3. Look for "Generated assets/config.js with FRONTEND_API_BASE_URL=..."
# If you see this, parametrization worked!

# 4. Test API connectivity
curl http://localhost:8080/  # Should load frontend
curl http://localhost:8000/health  # Should get health check
```

---

## 🐛 Troubleshooting

### Frontend container fails to start
```bash
# Check error
docker compose -f apsilva-fed-data-platform/docker-compose.yml logs frontend

# Likely causes:
# - FRONTEND_API_BASE_URL not set: Add to .env
# - FRONTEND_PORT not set: Add to .env
# - Port already in use: Change FRONTEND_PORT in .env
```

### Frontend can't reach backend API
```bash
# Check error in browser console (F12)
# 1. Wrong URL? Check generated config.js:
docker exec apsilva-fed-data-platform-frontend cat /usr/share/nginx/html/assets/config.js

# 2. CORS error? Check backend CORS_ALLOWED_ORIGINS:
# Should include http://localhost:8080 (or your frontend URL)
```

### Backend container fails to start
```bash
# Check logs
docker compose -f apsilva-bed-data-platform/docker-compose.yml logs api

# Not related to parameterization - check backend .env
```

---

## 📚 More Information

- **Full Documentation**: See [PARAMETERIZATION_REPORT.md](../PARAMETERIZATION_REPORT.md)
- **Backend Config**: [apsilva-bed-data-platform/.env.example](../apsilva-bed-data-platform/.env.example)
- **Frontend Config**: [apsilva-fed-data-platform/.env.example](../apsilva-fed-data-platform/.env.example)
- **Orchestration**: [up-data-platform.sh](../up-data-platform.sh)

---

## 🎯 Key Principle

> **Everything is parametrized. Nothing is hardcoded.**

If you're seeing a localhost URL, it means either:
1. You're looking at the default value in code (will be overridden by .env)
2. You're looking at .env.example (use as template, don't edit directly)
3. You found a bug - please file an issue!

All actual runtime configuration comes from `.env` → Docker compose → Container environment.

