#!/bin/bash
# ============================================================
# backup.sh — 政务数字门户平台 POC 数据库备份脚本
# 功能: mysqldump 全量备份 + 压缩 + 自动清理旧备份
# 用法: chmod +x backup.sh && ./backup.sh
# 定时: crontab -e → 0 2 * * * /opt/blog-platform/backup.sh
# ============================================================

set -e

# ==================== 配置 ====================
BACKUP_DIR="/data/backup"
RETENTION_DAYS=7
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-RootP@ss2026}"
MYSQL_DATABASE="halo"
MYSQL_CONTAINER="mysql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"

# ==================== 开始备份 ====================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ========== 备份开始 ==========" | tee -a "$LOG_FILE"

# 1. 检查 MySQL 容器状态
if ! docker ps --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ MySQL 容器未运行，备份中止！" | tee -a "$LOG_FILE"
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ MySQL 容器运行中" | tee -a "$LOG_FILE"

# 2. 确保备份目录存在
mkdir -p "$BACKUP_DIR"

# 3. 执行备份
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在备份数据库 ${MYSQL_DATABASE} ..." | tee -a "$LOG_FILE"

START_TIME=$(date +%s)

if docker exec "$MYSQL_CONTAINER" mysqldump \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --hex-blob \
    --default-character-set=utf8mb4 \
    "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"; then

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 备份成功" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]    文件: ${BACKUP_FILE}" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]    大小: ${FILE_SIZE}" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]    耗时: ${ELAPSED} 秒" | tee -a "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 备份失败！" | tee -a "$LOG_FILE"
    exit 1
fi

# 4. 清理过期备份
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理 ${RETENTION_DAYS} 天前的旧备份..." | tee -a "$LOG_FILE"

DELETED_COUNT=0
for old_backup in "$BACKUP_DIR"/backup_*.sql.gz; do
    if [ -f "$old_backup" ]; then
        # 获取文件修改时间（天数）
        FILE_AGE=$(($(date +%s) - $(date -r "$old_backup" +%s)))
        FILE_AGE_DAYS=$((FILE_AGE / 86400))

        if [ "$FILE_AGE_DAYS" -gt "$RETENTION_DAYS" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]    删除: $(basename "$old_backup") (${FILE_AGE_DAYS}天前)" | tee -a "$LOG_FILE"
            rm -f "$old_backup"
            ((DELETED_COUNT++))
        fi
    fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理完成，删除 ${DELETED_COUNT} 个过期备份" | tee -a "$LOG_FILE"

# 5. 显示当前备份列表
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 当前备份列表:" | tee -a "$LOG_FILE"
ls -lh "$BACKUP_DIR"/backup_*.sql.gz 2>/dev/null | awk '{print "    " $NF " (" $5 ")"}' | tee -a "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ========== 备份完成 ==========" | tee -a "$LOG_FILE"

# ==================== 恢复指南 ====================
# 如需从备份恢复，执行:
# gunzip -c /data/backup/backup_YYYYMMDD_HHMMSS.sql.gz | \
#   docker exec -i mysql mysql -u root -p"RootP@ss2026" halo
# docker restart halo

exit 0
