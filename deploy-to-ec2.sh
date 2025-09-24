#!/bin/bash

# 部署脚本 - 在 EC2 实例上运行
set -e

echo "=== 开始部署 AI QA System ==="

# 获取当前 commit SHA
COMMIT_SHA=$1
if [ -z "$COMMIT_SHA" ]; then
    echo "错误: 请提供 commit SHA"
    exit 1
fi

echo "部署版本: $COMMIT_SHA"

# 登录 ECR
echo "=== 登录 ECR ==="
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $ECR_REGISTRY

# 停止现有容器
echo "=== 停止现有容器 ==="
docker-compose down || true

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
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/ai_user_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
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
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/ai_qa_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
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
docker-compose -f docker-compose.prod.yml up -d

# 等待服务启动
echo "=== 等待服务启动 ==="
sleep 30

# 健康检查
echo "=== 健康检查 ==="
curl -f http://localhost:8080/api/qa/health || echo "QA Service 健康检查失败"
curl -f http://localhost:8081/api/user/health || echo "User Service 健康检查失败"
curl -f http://localhost:3000 || echo "Frontend 健康检查失败"

echo "=== 部署完成 ==="
echo "服务访问地址:"
echo "  Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "  API Gateway: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
