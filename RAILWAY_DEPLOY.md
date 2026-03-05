# Hotone Japan 部署到 Railway 指南

本指南帮助你将 **htjpgantt-front**（前端）和 **htjpgantt-docker**（后端）部署到 Railway。

> ⚠️ **重要**：请新建一个 Railway 项目，不要在你现有的项目里操作，以免影响其他数据。

---

## 快速开始（3 步）

1. **推送代码**：将本仓库 push 到 GitHub，GitHub Actions 会自动构建前端镜像到 `ghcr.io/SeanFXM/htjpgantt-front:latest`
2. **修改 htjpgantt-docker**：把 `docker-compose.yml` 里 `taiga-front` 的 image 改为 `ghcr.io/seanfxm/htjpgantt-front:latest`
3. **Railway 部署**：New Project → 选择 htjpgantt-docker 仓库 → 配置环境变量（见下文）

---

## 一、前置准备

1. **Railway 账号**：https://railway.app 注册
2. **GitHub 账号**：确保两个仓库已 push 到 GitHub：
   - https://github.com/SeanFXM/htjpgantt-front
   - https://github.com/SeanFXM/htjpgantt-docker
3. **Docker Hub 或 GitHub Container Registry**：用于存放自定义前端镜像（见下文）

---

## 二、方案概览

Taiga 栈包含多个服务，Railway 需要逐个部署。推荐流程：

| 步骤 | 内容 |
|------|------|
| 1 | 构建并推送自定义前端镜像 |
| 2 | 修改 htjpgantt-docker 使用该镜像 |
| 3 | 在 Railway 新建项目并部署 |
| 4 | 配置环境变量和域名 |

---

## 三、步骤 1：构建并推送前端镜像

### 3.1 本地构建（可选，用于测试）

```bash
cd htjpgantt-front
docker build -f Dockerfile.railway -t htjpgantt-front:latest .
```

### 3.2 使用 GitHub Actions 自动构建（推荐）

在 `htjpgantt-front` 仓库根目录创建 `.github/workflows/docker-publish.yml`：

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.railway
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/htjpgantt-front:latest
```

Push 到 main 后，镜像会发布到：`ghcr.io/SeanFXM/htjpgantt-front:latest`

### 3.3 或使用 Docker Hub

```bash
docker build -f Dockerfile.railway -t 你的用户名/htjpgantt-front:latest .
docker push 你的用户名/htjpgantt-front:latest
```

---

## 四、步骤 2：修改 htjpgantt-docker 使用自定义前端

在 **htjpgantt-docker** 仓库中，修改 `docker-compose.yml` 的 `taiga-front` 服务：

**原：**
```yaml
taiga-front:
  image: taigaio/taiga-front:latest
```

**改为（使用 GHCR）：**
```yaml
taiga-front:
  image: ghcr.io/seanfxm/htjpgantt-front:latest
```

或使用 Docker Hub：
```yaml
taiga-front:
  image: 你的用户名/htjpgantt-front:latest
```

> 若使用 GHCR，需在 Railway 中配置 `GHCR_TOKEN` 或使用公开镜像（public package 无需登录）。

---

## 五、步骤 3：在 Railway 部署

### 5.1 新建项目（不影响现有项目）

1. 打开 https://railway.app
2. 点击 **New Project**
3. 选择 **Deploy from GitHub repo**
4. 选择 **SeanFXM/htjpgantt-docker**

### 5.2 使用 Docker Compose（Railway 已支持）

1. 在项目画布上，尝试 **拖拽** `docker-compose.yml` 到画布
2. 或手动添加服务：**+ New** → **GitHub Repo** → 选择 `htjpgantt-docker`

### 5.3 若 Compose 导入不完整，则手动添加服务

按以下顺序添加：

| 服务类型 | 说明 |
|----------|------|
| **PostgreSQL** | + New → Database → PostgreSQL |
| **taiga-db** | 若 Compose 中有，可保留；或改用 Railway 的 PostgreSQL |
| **taiga-back** | 使用镜像 `taigaio/taiga-back:latest` |
| **taiga-front** | 使用镜像 `ghcr.io/seanfxm/htjpgantt-front:latest` |
| **taiga-events** | 使用镜像 `taigaio/taiga-events:latest` |
| **taiga-protected** | 使用镜像 `taigaio/taiga-protected:latest` |
| **taiga-gateway** | 使用镜像 `nginx:1.19-alpine`，需挂载 `taiga-gateway/taiga.conf` |
| **RabbitMQ x2** | taiga-async-rabbitmq、taiga-events-rabbitmq |

---

## 六、步骤 4：配置环境变量

在 Railway 项目 **Variables** 中设置（参考 htjpgantt-docker 的 `.env`）：

```env
# 必填：部署后替换为 Railway 分配的域名
TAIGA_SCHEME=https
TAIGA_DOMAIN=你的项目.railway.app
SUBPATH=
WEBSOCKETS_SCHEME=wss

# 必填：随机字符串
SECRET_KEY=请生成一个随机字符串

# 数据库（若用 Railway PostgreSQL，从插件中复制连接信息）
POSTGRES_USER=postgres
POSTGRES_PASSWORD=从Railway复制
POSTGRES_HOST=从Railway复制

# RabbitMQ（保持默认或按需修改）
RABBITMQ_USER=taiga
RABBITMQ_PASS=taiga
RABBITMQ_VHOST=taiga
RABBITMQ_ERLANG_COOKIE=随机字符串

# 其他
EMAIL_BACKEND=console
ATTACHMENTS_MAX_AGE=360
ENABLE_TELEMETRY=False
PUBLIC_REGISTER_ENABLED=true
```

---

## 七、步骤 5：初始化数据库和超级用户

部署完成后，在 Railway 中打开 **taiga-manage** 或 **taiga-back** 的 Shell，执行：

```bash
python manage.py migrate
python manage.py createsuperuser
```

或使用 htjpgantt-docker 的脚本（若在本地能连到 Railway 数据库）：

```bash
./taiga-manage.sh migrate
./taiga-manage.sh createsuperuser
```

---

## 八、常见问题

### 1. 前端镜像构建失败

- 确保 `npm run build` 在本地可成功
- 使用 `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true` 避免 Puppeteer 下载失败

### 2. 无法连接数据库 / RabbitMQ

- 检查 Railway 内部网络和变量中的 `POSTGRES_HOST`、`RABBITMQ_*`
- 使用 Railway 提供的 `$RAILWAY_TCP_PROXY_DOMAIN` 等变量（若文档中有说明）

### 3. 前端显示空白或 API 报错

- 确认 `conf.json` 中的 `api`、`eventsUrl` 指向正确的后端地址
- 检查 `TAIGA_DOMAIN`、`TAIGA_SCHEME` 是否与访问域名一致

### 4. 不影响现有 Railway 项目

- 始终在 **New Project** 中操作
- 不要选择已有项目或已有服务进行覆盖

---

## 九、简化方案（若上述步骤过复杂）

可考虑：

1. **Render.com**：对 Docker Compose 支持较好
2. **Coolify**：自托管，支持 Compose
3. **单机 Docker**：在 VPS 上 `docker-compose up -d`

若需要，我可以根据你选择的平台再写一份对应部署文档。
