#!/bin/bash
# ============================================================
# deploy.sh — 政务数字门户平台 POC 一键部署脚本
# 环境: openEuler 22.03 ARM64 (鲲鹏920) + Docker 容器化
# 依赖: 同级目录需包含 docker-compose.yml、nginx.conf、prometheus.yml
# 用法: chmod +x deploy.sh && sudo ./deploy.sh
# 目标: 从零完成全量部署（7 个容器，含监控栈）
# 部署服务:
#   - Halo 博客         :8090
#   - MySQL 8.0         :3306
#   - Nginx 反向代理    :80 / 443
#   - Prometheus        :9090
#   - Grafana           :3000
#   - node_exporter     :9100 (host 网络)
#   - cAdvisor          :8080
# ============================================================

set -euo pipefail

# ---- 颜色定义 ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ---- 全局变量 ----
START_TIME=$(date +%s)
IP=$(hostname -I | awk '{print $1}')
DEPLOY_DIR="/opt/blog"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_STEPS=8

# ---- 错误处理 ----
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ] && [ $exit_code -ne 143 ]; then
        echo ""
        echo -e "${RED}========================================${NC}"
        echo -e "${RED} 部署失败 (退出码: ${exit_code})${NC}"
        echo -e "${RED} 请检查上方错误信息后重试${NC}"
        echo -e "${RED} 常见原因:${NC}"
        echo -e "${RED}   - 网络不通导致镜像拉取失败${NC}"
        echo -e "${RED}   - 端口冲突 (80/443/3306/8090/9090/3000/8080)${NC}"
        echo -e "${RED}   - CPU/内存/磁盘空间不足${NC}"
        echo -e "${RED}   - SELinux 阻止容器挂载 (检查 /var/log/audit/audit.log)${NC}"
        echo -e "${RED}========================================${NC}"
    fi
}
trap cleanup EXIT

# ---- 工具函数 ----
ok()    { echo -e "  ${GREEN}✔ $1${NC}"; }
warn()  { echo -e "  ${YELLOW}⚠ $1${NC}"; }
fail()  { echo -e "  ${RED}✘ $1${NC}"; exit 1; }
info()  { echo -e "  ${BLUE}→ $1${NC}"; }
step()  { echo ""; echo -e "${YELLOW}[$1/${TOTAL_STEPS}] $2...${NC}"; }

# ---- Banner ----
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} 政务数字门户平台 POC — 一键部署${NC}"
echo -e "${BLUE} 鲲鹏 ARM + openEuler 22.03 + Docker 容器化${NC}"
echo -e "${BLUE} 目标主机: ${IP}${NC}"
echo -e "${BLUE}========================================${NC}"

# ============================================================
# Step 1: 前置环境检查
# ============================================================
step 1 "前置环境检查"

# 1a. Root 权限
if [ "$(id -u)" -ne 0 ]; then
    fail "请以 root 用户运行: sudo ./deploy.sh"
fi
ok "Root 权限确认"

# 1b. 操作系统信息
if [ -f /etc/openEuler-release ]; then
    OS_VER=$(grep -oP '\d+\.\d+' /etc/openEuler-release | head -1)
    info "操作系统: openEuler ${OS_VER} $(uname -m)"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    info "操作系统: ${ID} ${VERSION_ID} $(uname -m)"
else
    warn "无法识别操作系统版本"
fi

# 1c. CPU 架构
ARCH=$(uname -m)
if [ "${ARCH}" != "aarch64" ]; then
    warn "当前架构 ${ARCH}，推荐 aarch64 (鲲鹏920)"
fi

# 1d. 网络连通性
if ping -c 1 -W 3 114.114.114.114 &>/dev/null; then
    ok "外网连通"
else
    warn "外网可能不通，镜像拉取可能失败"
fi

# 1e. 端口冲突检查
PORTS=(80 443 3306 8090 9090 3000 8080 9100)
CONFLICT=false
for port in "${PORTS[@]}"; do
    if ss -tlnp "sport = :${port}" 2>/dev/null | grep -q LISTEN; then
        warn "端口 ${port} 已被占用"
        CONFLICT=true
    fi
done
if [ "$CONFLICT" = true ]; then
    echo "   请先释放冲突端口后再部署"
fi
ok "端口冲突检查完成"

# 1f. 磁盘空间
AVAIL_GB=$(df -BG "${DEPLOY_DIR}" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
if [ -n "${AVAIL_GB}" ] && [ "${AVAIL_GB}" -lt 10 ]; then
    fail "磁盘空间不足: 仅剩 ${AVAIL_GB}G，需要至少 10G 可用空间"
fi
ok "磁盘空间: ${AVAIL_GB:-?}G 可用"

# 1g. 依赖配置文件检查
for f in docker-compose.yml nginx.conf prometheus.yml; do
    if [ ! -f "${SCRIPT_DIR}/${f}" ]; then
        fail "缺失配置文件: ${SCRIPT_DIR}/${f}，请确保所有 5 个运维脚本在同一目录"
    fi
done
ok "配置文件完整性检查通过"

# ============================================================
# Step 2: Docker 环境安装
# ============================================================
step 2 "Docker 环境安装"

install_docker() {
    info "安装 podman-docker..."
    dnf install -y podman podman-docker

    # 配置国内镜像加速
    mkdir -p /etc/containers
    cat > /etc/containers/registries.conf << 'REGISTRIES'
unqualified-search-registries = ["docker.io"]

[[registry]]
prefix = "docker.io"
location = "docker.m.daocloud.io"
REGISTRIES
    ok "Daocloud 镜像加速已配置（解决 docker.io 国内访问慢）"
}

if ! command -v docker &> /dev/null; then
    install_docker
else
    ok "Docker 已安装: $(docker --version 2>/dev/null || echo 'unknown')"
fi

# 启动容器运行时（podman 使用 socket-activated 模式）
docker ps &>/dev/null || {
    warn "Docker 服务未运行，尝试启动..."
    systemctl start podman.socket 2>/dev/null || true
    sleep 2
    docker ps &>/dev/null || fail "Docker 服务无法启动，请手动检查: systemctl status podman"
}
ok "容器运行时就绪"

# ---- 检测 Docker Compose ----
COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
    ok "Docker Compose v2 (内置插件)"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
    ok "Docker Compose v1: $(docker-compose --version 2>/dev/null | head -1)"
else
    warn "Docker Compose 未安装，尝试安装 podman-compose..."
    if command -v pip3 &>/dev/null; then
        pip3 install podman-compose
        COMPOSE_CMD="podman-compose"
    else
        dnf install -y python3-pip
        pip3 install podman-compose
        COMPOSE_CMD="podman-compose"
    fi
    ok "Podman Compose 已安装"
fi

# ---- 最终校验 Compose 命令 ----
if [ -z "${COMPOSE_CMD}" ]; then
    fail "Docker Compose 安装失败，请手动安装: pip3 install docker-compose"
fi

# ============================================================
# Step 3: 创建目录结构
# ============================================================
step 3 "创建数据目录结构"

mkdir -p "${DEPLOY_DIR}"/{data/{mysql,halo,prometheus,grafana},nginx/ssl,backups,logs}
ok "数据目录已创建: ${DEPLOY_DIR}/"

# ============================================================
# Step 4: 部署配置文件
# ============================================================
step 4 "部署配置文件"

cp "${SCRIPT_DIR}/docker-compose.yml" "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/nginx.conf" "${DEPLOY_DIR}/nginx/"
cp "${SCRIPT_DIR}/prometheus.yml" "${DEPLOY_DIR}/"
ok "配置文件已复制到 ${DEPLOY_DIR}/"

# 生成 .env（docker compose 自动读取）
cat > "${DEPLOY_DIR}/.env" << EOF
# ============================================================
# 环境变量 — 政务数字门户平台 POC
# 由 deploy.sh 自动生成于 $(date '+%Y-%m-%d %H:%M:%S')
# 请妥善保管以下密码，切勿提交到版本控制
# ============================================================
DEPLOY_DIR=${DEPLOY_DIR}
MYSQL_ROOT_PASSWORD=RootP@ss2026
MYSQL_PASSWORD=HaloP@ss2026
GRAFANA_PASSWORD=Admin@2026
EOF
chmod 600 "${DEPLOY_DIR}/.env"
ok ".env 环境变量文件已生成（权限 600）"

# ============================================================
# Step 5: SSL 证书（自签名）
# ============================================================
step 5 "SSL 自签名证书"

if [ -f "${DEPLOY_DIR}/nginx/ssl/blog.crt" ] && [ -f "${DEPLOY_DIR}/nginx/ssl/blog.key" ]; then
    ok "SSL 证书已存在，跳过生成"
else
    if ! command -v openssl &>/dev/null; then
        dnf install -y openssl
    fi
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${DEPLOY_DIR}/nginx/ssl/blog.key" \
        -out "${DEPLOY_DIR}/nginx/ssl/blog.crt" \
        -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=DMP-POC/CN=${IP}" 2>/dev/null
    ok "自签名证书已生成（有效期 365 天）"
    warn "生产环境请替换为 CA 签发证书"
fi

# ============================================================
# Step 6: Docker Compose 启动所有服务
# ============================================================
step 6 "Docker Compose 启动全部 7 个容器"

cd "${DEPLOY_DIR}"

info "拉取镜像（首次需 5~10 分钟，取决于网络）..."
${COMPOSE_CMD} pull --ignore-pull-failures 2>/dev/null || warn "部分镜像拉取失败，尝试直接启动..."

${COMPOSE_CMD} up -d

# 等待容器稳定
sleep 5
RUNNING_COUNT=$(${COMPOSE_CMD} ps --services 2>/dev/null | wc -l)
if [ "${RUNNING_COUNT}" -ge 7 ]; then
    ok "7 个容器全部启动成功"
else
    warn "预期 7 个容器，当前运行 ${RUNNING_COUNT} 个，请稍后检查: ${COMPOSE_CMD} ps"
fi

# ============================================================
# Step 7: 等待关键服务就绪
# ============================================================
step 7 "等待关键服务就绪"

info "等待 MySQL 就绪（最多 60 秒）..."
MYSQL_READY=false
for i in $(seq 1 30); do
    if docker exec blog-mysql mysqladmin ping -hlocalhost -uroot -pRootP@ss2026 2>/dev/null | grep -q "alive"; then
        MYSQL_READY=true
        ok "MySQL 就绪"
        break
    fi
    sleep 2
done
if [ "$MYSQL_READY" = false ]; then
    warn "MySQL 未在 60 秒内就绪，请手动检查: docker logs blog-mysql"
fi

info "等待 Nginx 就绪..."
for i in $(seq 1 15); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
    if [ "${HTTP_CODE}" != "000" ]; then
        ok "Nginx 就绪（HTTP ${HTTP_CODE}）"
        break
    fi
    sleep 2
done

# ============================================================
# Step 8: 设置定时备份
# ============================================================
step 8 "设置定时备份"

if [ -f "${SCRIPT_DIR}/backup.sh" ]; then
    cp "${SCRIPT_DIR}/backup.sh" "${DEPLOY_DIR}/"
    chmod +x "${DEPLOY_DIR}/backup.sh"

    CRON_JOB="0 2 * * * ${DEPLOY_DIR}/backup.sh >> ${DEPLOY_DIR}/logs/backup.log 2>&1"
    if crontab -l 2>/dev/null | grep -qF "${DEPLOY_DIR}/backup.sh"; then
        ok "定时备份任务已存在"
    else
        (crontab -l 2>/dev/null; echo "${CRON_JOB}") | crontab -
        ok "定时备份已添加: cron 每日 02:00"
    fi
else
    warn "backup.sh 未找到，跳过定时备份设置"
fi

# ============================================================
# 部署完成
# ============================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "  ${YELLOW}访问地址:${NC}"
echo -e "  博客首页:       ${GREEN}http://${IP}${NC}"
echo -e "  管理后台:       ${GREEN}http://${IP}:8090/console${NC}"
echo -e "  Grafana:        ${GREEN}http://${IP}:3000${NC}  (admin / Admin@2026)"
echo -e "  Prometheus:     ${GREEN}http://${IP}:9090${NC}"
echo ""
echo -e "  ${YELLOW}数据库信息:${NC}"
echo -e "  地址:           ${GREEN}${IP}:3306${NC}"
echo -e "  数据库:         ${GREEN}halo${NC}"
echo -e "  用户:           ${GREEN}halo_user${NC}"
echo -e "  密码:           ${GREEN}HaloP@ss2026${NC}"
echo ""
echo -e "  ${YELLOW}部署信息:${NC}"
echo -e "  耗时:           ${GREEN}${ELAPSED} 秒${NC}"
echo -e "  配置目录:       ${GREEN}${DEPLOY_DIR}${NC}"
echo -e "  定时备份:       ${GREEN}每日 02:00${NC}"
echo ""

# 容器状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${GREEN}  政务数字门户平台 POC 部署完成${NC}"
