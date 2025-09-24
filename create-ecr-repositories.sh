#!/bin/bash

# 创建ECR仓库脚本
# 使用方法: ./create-ecr-repositories.sh

set -e

# 配置
AWS_REGION="ap-southeast-2"
ECR_REGISTRY="381492153714.dkr.ecr.ap-southeast-2.amazonaws.com"

# 需要创建的仓库列表
REPOSITORIES=(
    "duuhao/ai-qa-system/api-gateway"
    "duuhao/ai-qa-system/qa-service"
    "duuhao/ai-qa-system/user-service"
    "duuhao/ai-qa-system/frontend"
)

echo "=== 开始创建ECR仓库 ==="
echo "AWS Region: $AWS_REGION"
echo "ECR Registry: $ECR_REGISTRY"
echo ""

# 检查AWS CLI是否已配置
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "错误: AWS CLI未配置或认证失败"
    echo "请先运行: aws configure"
    exit 1
fi

# 创建每个仓库
for repo in "${REPOSITORIES[@]}"; do
    echo "创建仓库: $repo"
    
    # 检查仓库是否已存在
    if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" > /dev/null 2>&1; then
        echo "  仓库已存在，跳过创建"
    else
        # 创建仓库
        aws ecr create-repository \
            --repository-name "$repo" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        
        echo "  仓库创建成功"
    fi
    
    echo ""
done

echo "=== ECR仓库创建完成 ==="
echo ""
echo "创建的仓库列表:"
for repo in "${REPOSITORIES[@]}"; do
    echo "  $ECR_REGISTRY/$repo"
done

echo ""
echo "现在可以运行CI/CD流程来推送镜像了！"
