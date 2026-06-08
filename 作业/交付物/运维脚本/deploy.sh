#!/bin/bash
# ============================================================
# deploy.sh — 政务数字门户平台 POC 一键部署脚本
# 功能: 在全新 openEuler 22.03 ARM VM 上 30 分钟内完成全量部署
# 用法: chmod +x deploy.sh && ./deploy.sh
# ============================================================

set -e  # 遇到错误立即退出

# ==================== 配置变量 ====================
DEPLOY_DIR="/opt/blog-platform"
DATA_DIR="/data"
MYSQL_ROOT_PASSWORD="RootP@ss2026"
MYSQL_PASSWORD="HaloP@ss2026"
GRAFANA_PASSWORD="Admin@2026"
BUSINESS_IP="192.168.20.10"
START_TIME=$(date +%s)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} 政务数字门户平台 POC 一键部署${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ==================== 1. 检查 Docker 环境 ====================
echo -e "${YELLOW}[1/6] 检查 Docker 环境...${NC}"

if ! command -v docker &> /dev/null; then
    echo "   Docker 未安装，正在安装..."
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # 配置镜像加速
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'DOCKERCONF'
{
  "registry-mirrors": ["https://registry.cn-hangzhou.aliyuncs.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
DOCKERCONF

    systemctl daemon-reload
    systemctl enable docker --now
    echo "   Docker 安装完成"
else
    echo "   Docker 已安装"
fi

DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
echo -e "   ${GREEN}✅ Docker ${DOCKER_VERSION}${NC}"

# ==================== 2. 拉取镜像 ====================
echo -e "${YELLOW}[2/6] 拉取镜像...${NC}"

IMAGES=(
    "halohub/halo:2.18"
    "mysql:8.0"
    "nginx:1.24"
    "prom/prometheus:v2.47"
    "grafana/grafana:10.0"
    "prom/node-exporter:latest"
)

PULL_COUNT=0
for img in "${IMAGES[@]}"; do
    echo "   拉取 $img ..."
    if docker pull "$img" &> /dev/null; then
        ((PULL_COUNT++))
        echo -e "     ${GREEN}✅${NC}"
    else
        echo -e "     ${RED}❌ 拉取失败，请检查网络${NC}"
        echo "     提示: 可配置阿里云镜像加速或使用离线镜像包"
        exit 1
    fi
done
echo -e "   ${GREEN}✅ 镜像拉取完成 (${PULL_COUNT}/${#IMAGES[@]})${NC}"

# cAdvisor 镜像（可能在其他仓库）
echo "   拉取 cadvisor ..."
docker pull gcr.io/cadvisor/cadvisor:latest &> /dev/null || {
    echo "   尝试替代镜像..."
    docker pull google/cadvisor:latest &> /dev/null || {
        echo -e "   ${YELLOW}⚠️  cadvisor 拉取失败，监控将缺少容器指标${NC}"
    }
}

# ==================== 3. 生成 SSL 证书 ====================
echo -e "${YELLOW}[3/6] 生成 SSL 证书...${NC}"

mkdir -p "${DEPLOY_DIR}/ssl"
if [ ! -f "${DEPLOY_DIR}/ssl/blog.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${DEPLOY_DIR}/ssl/blog.key" \
        -out "${DEPLOY_DIR}/ssl/blog.crt" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=Gov/CN=${BUSINESS_IP}" \
        -addext "subjectAltName=IP:${BUSINESS_IP}" 2>/dev/null
    echo -e "   ${GREEN}✅ SSL 自签名证书已生成 (365天有效)${NC}"
else
    echo -e "   ${GREEN}✅ SSL 证书已存在${NC}"
fi

# ==================== 4. 创建数据目录 ====================
echo -e "${YELLOW}[4/6] 创建数据目录...${NC}"

mkdir -p "${DATA_DIR}"/{mysql,halo,backup,prometheus,grafana,nginx/ssl}
echo -e "   ${GREEN}✅ 数据目录已创建${NC}"

# ==================== 5. 启动容器 ====================
echo -e "${YELLOW}[5/6] 启动容器...${NC}"

cd "${DEPLOY_DIR}"

# 导出环境变量供 docker-compose 使用
export MYSQL_ROOT_PASSWORD
export MYSQL_PASSWORD
export GRAFANA_PASSWORD

docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d

# 等待 MySQL 就绪
echo "   等待 MySQL 启动..."
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker exec mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent 2>/dev/null; then
        echo -e "   ${GREEN}✅ MySQL 就绪 (${WAITED}秒)${NC}"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    echo -n "."
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo -e "   ${RED}❌ MySQL 启动超时${NC}"
    echo "   请检查: docker logs mysql"
    exit 1
fi

# ==================== 6. 等待所有容器就绪 ====================
echo -e "${YELLOW}[6/6] 等待所有服务就绪...${NC}"

sleep 10

# 检查容器状态
CONTAINERS=("nginx" "halo" "mysql" "prometheus" "grafana" "node_exporter")
UP_COUNT=0
for container in "${CONTAINERS[@]}"; do
    STATUS=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "missing")
    if [ "$STATUS" = "running" ]; then
        echo -e "   ${GREEN}✅ ${container} — ${STATUS}${NC}"
        ((UP_COUNT++))
    else
        echo -e "   ${RED}❌ ${container} — ${STATUS}${NC}"
    fi
done

# ==================== 完成 ====================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN} 🎉 部署完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "  容器运行: ${GREEN}${UP_COUNT}/${#CONTAINERS[@]}${NC}"
echo -e "  部署耗时: ${GREEN}${MINUTES}分${SECONDS}秒${NC}"
echo ""
echo -e "${YELLOW}访问地址:${NC}"
echo -e "  博客首页:  ${GREEN}https://${BUSINESS_IP}${NC}"
echo -e "  博客后台:  ${GREEN}https://${BUSINESS_IP}/admin${NC}"
echo -e "  Grafana:   ${GREEN}https://${BUSINESS_IP}:3000${NC}"
echo -e "  Prometheus: ${GREEN}http://${BUSINESS_IP}:9090${NC}"
echo ""
echo -e "${YELLOW}数据库信息:${NC}"
echo -e "  主机: ${GREEN}${BUSINESS_IP}:3306${NC}"
echo -e "  数据库: ${GREEN}halo${NC}"
echo -e "  用户: ${GREEN}halo_user${NC}"
echo -e "  密码: ${GREEN}${MYSQL_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}⚠️  使用自签名证书，浏览器会提示不安全${NC}"
echo -e "${YELLOW}   请点击「高级」→「继续访问」${NC}"
echo ""

# 如果全部运行，退出码为 0
if [ $UP_COUNT -eq ${#CONTAINERS[@]} ]; then
    exit 0
else
    exit 1
fi
