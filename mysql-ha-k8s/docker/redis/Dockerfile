FROM redis:7.2-alpine

# 复制 Redis 配置（主从模式下共用，通过启动参数区分角色）
COPY redis.conf /usr/local/etc/redis/redis.conf

# 健康检查
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD redis-cli ping || exit 1

EXPOSE 6379
