@echo off
chcp 65001 >nul
echo ============================================
echo   Grafana:     http://localhost:3000
echo   Prometheus:  http://localhost:9090
echo   (admin / 123456)
echo ============================================
echo.
echo 正在启动端口转发，请保持弹出的两个窗口开启...
echo 关闭窗口即停止转发。
echo.
start "Grafana" cmd /k "kubectl port-forward -n monitoring svc/kube-prom-stack-grafana 3000:80"
start "Prometheus" cmd /k "kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus 9090:9090"
echo 已启动！现在可以打开浏览器访问 Grafana 和 Prometheus。
timeout /t 3 >nul
