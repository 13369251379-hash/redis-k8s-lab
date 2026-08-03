# Redis HA on Kubernetes

Redis 主从集群 + Sentinel 哨兵，基于 Docker Desktop K8s。

## 架构

```
┌── Sentinel-0 ──┐
├── Sentinel-1 ──┤  3 哨兵，quorum=2
└── Sentinel-2 ──┘
       │
  ┌────┴────┐
  │         │
redis-0   redis-1,redis-2
Master    Slaves (只读)
```

## 目录结构

```
├── docker/redis/
│   ├── Dockerfile          # 基于 redis:7.2-alpine
│   └── redis.conf          # Redis 基础配置
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml      # redis-ha 命名空间
│   │   ├── configmap.yaml      # Redis + Sentinel 配置
│   │   ├── secret.yaml         # Redis 密码
│   │   ├── service.yaml        # Headless + NodePort + Sentinel Service
│   │   ├── statefulset.yaml    # 3 副本 Redis StatefulSet
│   │   └── sentinel.yaml       # 3 副本 Sentinel Deployment
│   └── monitoring/
│       ├── redis-exporter.yaml     # Prometheus Redis Exporter
│       └── redis-alerts.yaml       # PrometheusRule 告警
├── argocd/
│   └── redis-app.yaml         # ArgoCD Application
├── .gitlab-ci.yml
└── README.md
```

## 部署步骤

### 1. 构建镜像

```bash
docker build -t redis-ha:7.2 ./docker/redis
```

### 2. 部署到 K8s

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/secret.yaml
kubectl apply -f k8s/base/service.yaml
kubectl apply -f k8s/base/statefulset.yaml
kubectl apply -f k8s/base/sentinel.yaml
```

### 3. 等待就绪

```bash
kubectl get pods -n redis-ha -w
```

### 4. 验证主从

```bash
# 查看 master 角色
kubectl exec -it redis-0 -n redis-ha -- redis-cli -a Redis@123456 info replication | grep role

# 写入数据
kubectl exec -it redis-0 -n redis-ha -- redis-cli -a Redis@123456 set hello world

# 在 slave 上读取
kubectl exec -it redis-1 -n redis-ha -- redis-cli -a Redis@123456 get hello
```

### 5. 验证 Sentinel

```bash
# 查看 Sentinel 监控的 master
kubectl exec -it deploy/sentinel -n redis-ha -- redis-cli -p 26379 sentinel master mymaster
```

### 6. 部署监控（可选）

```bash
kubectl apply -f k8s/monitoring/
```

### 7. ArgoCD 托管（可选）

```bash
kubectl apply -f argocd/redis-app.yaml
```

## 故障转移测试

```bash
# 删除 master
kubectl delete pod redis-0 -n redis-ha

# 观察 Sentinel 自动选举新 master
kubectl exec -it deploy/sentinel -n redis-ha -- redis-cli -p 26379 sentinel master mymaster
```

## 外部访问

```bash
# NodePort 访问
redis-cli -h localhost -p 30379 -a Redis@123456
```
