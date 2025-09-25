#!/bin/bash

# 部署脚本 - 在 EC2 实例上运行
set -euo pipefail

echo "=== 开始部署 AI QA System ==="

# 获取当前 commit SHA
COMMIT_SHA=$1
if [ -z "$COMMIT_SHA" ]; then
    echo "错误: 请提供 commit SHA"
    exit 1
fi

echo "部署版本: $COMMIT_SHA"

# 配置 AWS 凭证（来自环境变量）
echo "=== 配置 AWS 凭证 ==="
mkdir -p ~/.aws
{
  echo "[default]"
  if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo "aws_access_key_id=${AWS_ACCESS_KEY_ID}"
    echo "aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}"
  fi
  if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
    echo "aws_session_token=${AWS_SESSION_TOKEN}"
  fi
} > ~/.aws/credentials

{
  echo "[default]"
  echo "region=${AWS_REGION:-ap-southeast-2}"
  echo "output=json"
} > ~/.aws/config

# 预检与安装依赖
echo "=== 预检依赖（aws, docker, docker compose）==="
# 检测包管理器
if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
elif command -v yum >/dev/null 2>&1; then
  PKG_MGR="yum"
else
  PKG_MGR=""
fi

# 安装基础工具 unzip / curl（AWS CLI v2 需要 unzip）
if [ -n "${PKG_MGR}" ]; then
  if [ "$PKG_MGR" = "apt" ]; then
    sudo apt-get update -y >/dev/null 2>&1 || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip curl >/dev/null 2>&1 || true
  else
    sudo yum install -y unzip curl >/dev/null 2>&1 || true
  fi
fi

# 安装 Docker（如未安装）
if ! command -v docker >/dev/null 2>&1; then
  echo "安装 Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER || true
  sudo systemctl enable docker || true
  sudo systemctl start docker || true
fi

# 安装/修复 docker compose（优先使用 docker compose 子命令）
if ! docker compose version >/dev/null 2>&1; then
  echo "安装 docker compose 插件..."
  if [ "$PKG_MGR" = "apt" ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin >/dev/null 2>&1 || true
  elif [ "$PKG_MGR" = "yum" ]; then
    # 尝试放置到 cli-plugins
    DOCKER_COMPOSE_VERSION="v2.27.0"
    sudo mkdir -p /usr/libexec/docker/cli-plugins
    sudo curl -sSL -o /usr/libexec/docker/cli-plugins/docker-compose \
      https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64
    sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
  fi
fi

# 安装 AWS CLI v2（如未安装）
if ! command -v aws >/dev/null 2>&1; then
  echo "安装 AWS CLI v2..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp || true
  sudo /tmp/aws/install -i /usr/local/aws-cli -b /usr/local/bin || true
fi
aws --version || true

# 登录 ECR
echo "=== 登录 ECR ==="
AWS_REGION_VALUE="${AWS_REGION:-ap-southeast-2}"
aws ecr get-login-password --region "$AWS_REGION_VALUE" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# 停止现有容器
echo "=== 停止现有容器 ==="
docker compose down || true
# 停止上一次使用 prod 文件启动的容器（如有）
docker compose -f docker-compose.prod.yml down || true

# 拉取最新镜像
echo "=== 拉取最新镜像 ==="
docker pull $ECR_REGISTRY/duuhao/ai-qa-system/api-gateway:$COMMIT_SHA
docker pull $ECR_REGISTRY/duuhao/ai-qa-system/qa-service:$COMMIT_SHA
docker pull $ECR_REGISTRY/duuhao/ai-qa-system/user-service:$COMMIT_SHA
docker pull $ECR_REGISTRY/duuhao/ai-qa-system/frontend:$COMMIT_SHA

# 创建生产环境的 docker-compose 文件
echo "=== 创建生产环境配置 ==="
cat > docker-compose.prod.yml << EOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: ai-qa-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ai_qa_system
      MYSQL_DATABASE: ai_qa_system
      MYSQL_USER: ai_qa_user
      MYSQL_PASSWORD: ai_qa_password
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - ai-qa-network

  user-service:
    image: $ECR_REGISTRY/duuhao/ai-qa-system/user-service:$COMMIT_SHA
    container_name: ai-qa-user-service
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/ai_user_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai&createDatabaseIfNotExist=true
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: ai_qa_system
    ports:
      - "8081:8081"
    depends_on:
      - mysql
    networks:
      - ai-qa-network

  qa-service:
    image: $ECR_REGISTRY/duuhao/ai-qa-system/qa-service:$COMMIT_SHA
    container_name: ai-qa-qa-service
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/ai_qa_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai&createDatabaseIfNotExist=true
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: ai_qa_system
    ports:
      - "8082:8082"
    depends_on:
      - mysql
    networks:
      - ai-qa-network

  api-gateway:
    image: $ECR_REGISTRY/duuhao/ai-qa-system/api-gateway:$COMMIT_SHA
    container_name: ai-qa-api-gateway
    environment:
      SPRING_PROFILES_ACTIVE: docker
    ports:
      - "8080:8080"
    depends_on:
      - user-service
      - qa-service
    networks:
      - ai-qa-network

  frontend:
    image: $ECR_REGISTRY/duuhao/ai-qa-system/frontend:$COMMIT_SHA
    container_name: ai-qa-frontend
    environment:
      BACKEND_BASE_URL: http://api-gateway:8080
    ports:
      - "3000:3000"
    depends_on:
      - api-gateway
    networks:
      - ai-qa-network

volumes:
  mysql_data:

networks:
  ai-qa-network:
    driver: bridge
EOF

# 启动服务
echo "=== 启动服务 ==="
docker compose -f docker-compose.prod.yml up -d

# 等待服务启动
echo "=== 等待服务启动 ==="
sleep 30

# 配置 Nginx（通过 CI/CD 下发热修：/api/user → 8081，/api/qa → 8082）
echo "=== 配置 Nginx ==="
if ! command -v nginx >/dev/null 2>&1; then
  echo "安装 Nginx..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y nginx
  fi
fi

# 停止可能占用端口 80 的服务
echo "停止可能占用端口 80 的服务..."
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl stop httpd 2>/dev/null || true
sudo pkill -f "python.*80" 2>/dev/null || true

# 备份默认配置
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup 2>/dev/null || true
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# 创建 Nginx 配置
echo "创建 Nginx 配置..."
sudo tee /etc/nginx/sites-available/ai-qa-system << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # 临时热修：直接转发到后端服务，绕过网关
    location /api/user/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    location /api/qa/ {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # 前端页面
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# 启用站点配置
sudo ln -sf /etc/nginx/sites-available/ai-qa-system /etc/nginx/sites-enabled/

# 测试 Nginx 配置
echo "测试 Nginx 配置..."
sudo nginx -t

# 启动 Nginx
echo "启动 Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# 检查 Nginx 状态
echo "Nginx 状态:"
sudo systemctl status nginx --no-pager -l

# 健康检查
echo "=== 健康检查 ==="
sleep 10  # 等待服务完全启动

echo "检查容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "检查服务健康:"
curl -f http://localhost:8080/api/user/health || echo "User Service 健康检查失败"
curl -f http://localhost:8080/api/qa/health || echo "QA Service 健康检查失败"
curl -f http://localhost:3000 || echo "Frontend 健康检查失败"

echo "检查 Nginx 代理:"
curl -f http://localhost/api/user/health || echo "Nginx 代理 User Service 失败"
curl -f http://localhost/api/qa/health || echo "Nginx 代理 QA Service 失败"
curl -f http://localhost || echo "Nginx 代理 Frontend 失败"

# 打印关键服务日志（最近50行），便于定位错误
echo "=== 关键服务日志 ==="
docker compose logs --tail 50 user-service || true
docker compose logs --tail 50 api-gateway || true
docker compose logs --tail 50 qa-service || true

echo "=== 部署完成 ==="
echo "服务访问地址:"
echo "  Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "  API Gateway: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"

