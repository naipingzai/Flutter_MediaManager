#!/bin/bash
# 媒体管理 - Web 一键启动脚本
# 用法: ./start_web.sh [stop|status|tunnel]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_PORT=8080
WEB_PORT=3000

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_port() {
    lsof -t -i:$1 >/dev/null 2>&1
}

stop_services() {
    echo -e "${YELLOW}停止所有服务...${NC}"
    kill $(lsof -t -i:$PROXY_PORT) 2>/dev/null
    kill $(lsof -t -i:$WEB_PORT) 2>/dev/null
    echo -e "${GREEN}已停止${NC}"
}

show_status() {
    echo -e "${YELLOW}=== 服务状态 ===${NC}"
    if check_port $PROXY_PORT; then
        echo -e "  CORS 代理 (:$PROXY_PORT): ${GREEN}运行中${NC}"
    else
        echo -e "  CORS 代理 (:$PROXY_PORT): ${RED}未运行${NC}"
    fi
    if check_port $WEB_PORT; then
        echo -e "  Web 服务器 (:$WEB_PORT): ${GREEN}运行中${NC}"
    else
        echo -e "  Web 服务器 (:$WEB_PORT): ${RED}未运行${NC}"
    fi
    echo ""
    echo -e "  本地访问: http://localhost:$WEB_PORT"
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$local_ip" ]; then
        echo -e "  局域网访问: http://$local_ip:$WEB_PORT"
    fi
}

start_services() {
    echo -e "${YELLOW}启动服务...${NC}"

    # 先停止已有的
    kill $(lsof -t -i:$PROXY_PORT) 2>/dev/null
    kill $(lsof -t -i:$WEB_PORT) 2>/dev/null
    sleep 1

    # 启动 CORS 代理
    cd "$SCRIPT_DIR"
    nohup python3 proxy/cors_proxy.py > /tmp/proxy.log 2>&1 &
    if check_port $PROXY_PORT; then
        echo -e "  ${GREEN}✓${NC} CORS 代理已启动 (:$PROXY_PORT)"
    else
        sleep 2
        if check_port $PROXY_PORT; then
            echo -e "  ${GREEN}✓${NC} CORS 代理已启动 (:$PROXY_PORT)"
        else
            echo -e "  ${RED}✗${NC} CORS 代理启动失败，查看: cat /tmp/proxy.log"
        fi
    fi

    # 检查 build 目录
    if [ ! -d "$SCRIPT_DIR/build/web" ]; then
        echo -e "  ${YELLOW}build/web 不存在，正在构建...${NC}"
        flutter build web --profile
    fi

    # 启动 Web 服务器
    nohup python3 -m http.server $WEB_PORT --directory "$SCRIPT_DIR/build/web" > /tmp/web_server.log 2>&1 &
    sleep 1
    if check_port $WEB_PORT; then
        echo -e "  ${GREEN}✓${NC} Web 服务器已启动 (:$WEB_PORT)"
    else
        echo -e "  ${RED}✗${NC} Web 服务器启动失败，查看: cat /tmp/web_server.log"
    fi

    echo ""
    echo -e "${GREEN}=== 启动完成 ===${NC}"
    echo -e "  本地访问: http://localhost:$WEB_PORT"
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$local_ip" ]; then
        echo -e "  局域网访问: http://$local_ip:$WEB_PORT"
    fi
    echo ""
    echo -e "  日志查看: F12 -> Console"
    echo -e "  停止服务: $0 stop"
}

case "${1:-start}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    status)
        show_status
        ;;
    tunnel)
        echo -e "${YELLOW}=== 远程访问隧道 ===${NC}"
        echo ""
        echo "需要安装 cloudflared 或 ngrok 之一"
        echo ""
        echo "方案 1 - Cloudflare Tunnel (免费):"
        echo "  # 终端 1: Web 前端"
        echo "  cloudflared tunnel --url http://localhost:$WEB_PORT"
        echo "  # 终端 2: CORS 代理"
        echo "  cloudflared tunnel --url http://localhost:$PROXY_PORT"
        echo ""
        echo "方案 2 - ngrok (需注册):"
        echo "  ngrok http $WEB_PORT"
        echo "  ngrok http $PROXY_PORT"
        echo ""
        echo "隧道启动后，在登录页面修改服务器地址为隧道 2 的 HTTPS 地址"
        ;;
    *)
        echo "用法: $0 {start|stop|status|tunnel}"
        ;;
esac
