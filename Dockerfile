# Hotone Japan 前端 - Railway 生产部署
# Railway 自动检测此 Dockerfile，在 linux/amd64 环境内完成 npm build
FROM --platform=linux/amd64 node:18-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY package*.json package-lock.json* ./
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN npm ci --legacy-peer-deps 2>/dev/null || npm install
COPY . .
RUN npm run build

FROM nginx:1.23-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY docker/default.conf /etc/nginx/conf.d/default.conf
COPY docker/conf.json.template /usr/share/nginx/html/conf.json.template
COPY docker/config_env_subst.sh /docker-entrypoint.d/30_config_env_subst.sh
RUN chmod +x /docker-entrypoint.d/30_config_env_subst.sh
RUN apk add --no-cache gettext
EXPOSE 80
