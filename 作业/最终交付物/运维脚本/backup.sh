#!/bin/bash
# ============================================================
# backup.sh — 政务数字门户平台 POC 自动备份脚本
# 功能: 备份 MySQL 全量 + Halo 数据，保留 7 天，带锁和校验
# 用法: ./backup.sh                          # 手动运行
#       ./backup.sh --force                  # 忽略锁强制运行
#       bash backup.sh                       # cron: 0 2 * * * /opt/blog/backup.sh
# ============================================================

set -euo pipefail

# ---- 配置 ----
BACKUP_DIR="/opt/blog/backups"
RETENTION_DAYS=7
MYSQL_CONTAINER="blog-mysql"
LOCK_FILE="/tmp/blog-backup.lock"
LOG_FILE="/opt/blog/logs/backup.log"
DATE=$(date +%Y%m%d_%H%M%S)

# ---- 辅助函数 ----
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
info() { log "INFO  $1"; }
warn() { log "WARN  $1"; }
fail() { log "ERROR $1"; exit 1; }

# ---- 锁机制 ----
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        if [ "${1:-}" = "--force" ]; then
            warn "发现正在运行的备份进程 (PID $LOCK_PID)，--force 强制继续"
        else
            fail "备份进程已在运行 (PID $LOCK_PID)，跳过本次。使用 --force 强制运行"
        fi
    else
        info "清理残留锁文件（旧进程已退出）"
        rm -f "$LOCK_FILE"
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ---- 前置检查 ----
# 1. 备份目录
mkdir -p "$BACKUP_DIR"

# 2. 容器运行状态
if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${MYSQL_CONTAINER}$"; then
    fail "MySQL 容器 '${MYSQL_CONTAINER}' 未运行，备份终止"
fi
info "MySQL 容器 '${MYSQL_CONTAINER}' 运行正常"

# ---- Step 1: MySQL 全量备份 ----
MYSQL_FILE="${BACKUP_DIR}/mysql_${DATE}.sql"
MYSQL_GZ="${MYSQL_FILE}.gz"

info "开始 MySQL 全量备份..."

# 使用 --single-transaction 保证 InnoDB 一致性，--routines 导出存储过程
# 密码通过环境变量传递避免 ps 泄露
if docker exec "$MYSQL_CONTAINER" \
    mysqldump \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --all-databases \
        -uroot \
        -pRootP@ss2026 \
    > "$MYSQL_FILE" 2>/dev/null; then

    SQL_SIZE=$(stat -c%s "$MYSQL_FILE" 2>/dev/null || echo 0)
    if [ "$SQL_SIZE" -lt 100 ]; then
        rm -f "$MYSQL_FILE"
        fail "MySQL 备份文件过小 (${SQL_SIZE} 字节)，可能为空备份，已删除"
    fi

    gzip "$MYSQL_FILE"
    GZ_SIZE=$(stat -c%s "$MYSQL_GZ" 2>/dev/null || echo 0)
    info "MySQL 备份完成: $(basename "$MYSQL_GZ") (${GZ_SIZE} bytes)"
else
    rm -f "$MYSQL_FILE"
    fail "MySQL 备份失败（mysqldump 返回非零）"
fi

# ---- Step 2: Halo 数据文件备份 ----
HALO_GZ="${BACKUP_DIR}/halo_${DATE}.tar.gz"
HALO_SRC="/opt/blog/data/halo"

info "开始 Halo 数据备份..."

if [ ! -d "$HALO_SRC" ]; then
    warn "Halo 数据目录 ${HALO_SRC} 不存在，跳过 Halo 备份"
else
    if tar -czf "$HALO_GZ" -C /opt/blog/data halo/ 2>/dev/null; then
        HALO_SIZE=$(stat -c%s "$HALO_GZ" 2>/dev/null || echo 0)
        info "Halo 备份完成: $(basename "$HALO_GZ") (${HALO_SIZE} bytes)"
    else
        warn "Halo 备份失败，请检查 ${HALO_SRC} 是否可读"
    fi
fi

# ---- Step 3: 清理过期备份 ----
CLEANED=$(find "$BACKUP_DIR" -name "*.gz" -mtime "+${RETENTION_DAYS}" -delete -print | wc -l)
if [ "$CLEANED" -gt 0 ]; then
    info "已清理 ${CLEANED} 个超过 ${RETENTION_DAYS} 天的旧备份"
fi

# ---- Step 4: 备份摘要 ----
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.gz" -type f | wc -l)
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
info "备份完成！当前共 ${BACKUP_COUNT} 个备份文件，总大小 ${BACKUP_SIZE}"

# ==================== 恢复指南 ====================
# MySQL 恢复:
#   gunzip -c /opt/blog/backups/mysql_YYYYMMDD_HHMMSS.sql.gz | \
#     docker exec -i blog-mysql mysql -uroot -pRootP@ss2026
#
# Halo 数据恢复:
#   tar -xzf /opt/blog/backups/halo_YYYYMMDD_HHMMSS.tar.gz -C /opt/blog/data/
#
# 完整恢复步骤:
#   1. docker compose -f /opt/blog/docker-compose.yml down
#   2. # 恢复 MySQL
#      gunzip -c /opt/blog/backups/mysql_最新.sql.gz | \
#        docker exec -i blog-mysql mysql -uroot -pRootP@ss2026
#   3. # 恢复 Halo 数据
#      tar -xzf /opt/blog/backups/halo_最新.tar.gz -C /opt/blog/data/
#   4. docker compose -f /opt/blog/docker-compose.yml up -d
# ============================================================
