#!/bin/bash

# Nginx 配置脚本
set -euo pipefail

echo "=== 配置 Nginx 反向代理 ==="

# 安装 Nginx
if ! command -v nginx >/dev/null 2>&1; then
  echo "安装 Nginx..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y nginx
  else
    echo "错误: 无法安装 Nginx，请手动安装"
    exit 1
  fi
fi

# 创建 Nginx 配置
echo "创建 Nginx 配置..."
sudo tee /etc/nginx/conf.d/ai-qa-system.conf << 'EOF'
server {
    listen 80;
    server_name _;

    # API 请求转发到网关
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        
        # 超时设置
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
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

# 测试 Nginx 配置
echo "测试 Nginx 配置..."
sudo nginx -t

# 启动 Nginx
echo "启动 Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl reload nginx

echo "=== Nginx 配置完成 ==="
echo "Nginx 状态:"
sudo systemctl status nginx --no-pager -l
