# Nacos 与外部数据库备份

本文件用于记录临时停用的远程配置与数据库连接信息，便于后续恢复。

## Nacos（临时停用）
- 原计划使用：Spring Cloud Alibaba Nacos（discovery/config）
- 现状：Nacos 服务已下线，网关与服务端改为本地配置；仓库内已禁用：
  - `backend-services/api-gateway/src/main/resources/application.yml`：禁用 nacos discovery/config
  - `backend-services/api-gateway/src/main/resources/application-docker.yml`：禁用 nacos discovery/config
  - `backend-services/qa-service/src/main/resources/application.yml`：禁用 nacos discovery/config

## 外部 MySQL（备份）
- 连接串（备份）：`jdbc:mysql://54.219.180.170:3306/ai_qa_system`
- 当前使用：本机 MySQL 容器（docker-compose）

## 恢复指引
1. 恢复 Nacos：将上述文件中的 `spring.cloud.nacos.*.enabled` 改回 `true` 并配置 `server-addr`
2. 恢复外部 MySQL：将 `SPRING_DATASOURCE_URL` 或应用 `application*.yml` 中的 `datasource.url` 改回外部地址


