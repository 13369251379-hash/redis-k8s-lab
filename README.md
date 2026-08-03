# Redis 高可用集群 + Prometheus + Grafana

Redis 主从 + Sentinel 哨兵高可用集群的云原生复现实验，带 Prometheus + Grafana 可视化监控，基于 Windows + Docker Desktop Kubernetes。

## 项目结构

```
redis-k8s-lab/
├── mysql-ha-k8s/                  # Redis HA 项目源码
│   ├── k8s/base/                  # namespace/configmap/secret/service/statefulset/sentinel
│   ├── k8s/monitoring/            # redis-exporter + PrometheusRule 告警规则
│   ├── k8s/argocd/                # ArgoCD Application
│   ├── argocd/                    # ArgoCD Application (顶层)
│   ├── docker/redis/              # Redis Dockerfile + redis.conf
│   └── Redis高可用集群云原生化实验手册.md/.pdf  # 完整实验手册
├── kube-prom-stack.tgz            # kube-prometheus-stack v61.3.0 Helm chart (含依赖)
├── monitoring-values.yaml         # kube-prometheus-stack 部署配置
├── grafana-dashboard763.json      # Redis Dashboard 763 原版
├── grafana-dashboard763-fixed.json # 修复版 (数据源指向 prometheus)
├── 启动监控访问.bat               # 双击启动 port-forward 访问 Grafana/Prometheus
└── README.md
```

## 架构

```
┌── Sentinel-0 ──┐
├── Sentinel-1 ──┤  3 哨兵, quorum=2, 自动故障转移
└── Sentinel-2 ──┘
       │
  ┌────┴────┐
  │         │
redis-0   redis-1,redis-2
Master    Slaves (只读)
```

监控链路: Redis → redis-exporter(9121) → Prometheus → Grafana (Redis Dashboard 763)

## 部署

### 1. Redis 主从 + 哨兵

```bash
kubectl apply -f mysql-ha-k8s/k8s/base/namespace.yaml
kubectl apply -f mysql-ha-k8s/k8s/base/configmap.yaml
kubectl apply -f mysql-ha-k8s/k8s/base/secret.yaml
kubectl apply -f mysql-ha-k8s/k8s/base/service.yaml
kubectl apply -f mysql-ha-k8s/k8s/base/statefulset.yaml
kubectl apply -f mysql-ha-k8s/k8s/base/sentinel.yaml
```

> 注意: `statefulset.yaml` / `sentinel.yaml` 的 imagePullPolicy 已从 `Never` 改为 `IfNotPresent` (新版 Docker Desktop 用 containerd, 本地 Docker 镜像不可见)

### 2. 监控栈 (kube-prometheus-stack)

```bash
tar -xzf kube-prom-stack.tgz
helm install kube-prom-stack ./kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring-values.yaml
```

### 3. redis-exporter + 告警

```bash
kubectl apply -f mysql-ha-k8s/k8s/monitoring/
```

## 访问

```bash
# 启动端口转发 (或双击 启动监控访问.bat)
kubectl port-forward -n monitoring svc/kube-prom-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus 9090:9090
```

- Grafana: http://localhost:3000  (admin / 123456)
- Prometheus: http://localhost:9090
- Redis Dashboard 直连: /d/e008bc3f-81a2-40f9-baf2-a33fd8dec7ec/redis-dashboard-for-prometheus-redis-exporter-1-x

## 验证

```bash
# 主从角色
kubectl exec redis-0 -n redis-ha -- redis-cli -a Redis@123456 info replication | grep role
# Sentinel 当前 master
kubectl exec deploy/sentinel -n redis-ha -- redis-cli -p 26379 sentinel master mymaster
# Redis 指标
curl http://localhost:9090/api/v1/query?query=redis_up
```

## 说明

- Docker Desktop K8s 的 NodePort 不暴露到宿主机, 需用 kubectl port-forward 访问
- Redis 不挂 PVC, 集群重启数据丢失 (仅实验用途)
- redis-exporter 固定抓取 master (redis-1), 避免 service 负载均衡导致指标在 master/slave 间跳变
