# 生活动态 - Web 端部署指南

## 一、本地运行（开发调试）

### 前置条件

- Python 3.x
- Flutter SDK

### 构建

```bash
cd AdvanceMediaKB-FR

# 构建 Web 版本（profile 模式，保留日志输出）
flutter build web --profile

# 或 release 模式（无日志，体积更小）
flutter build web
```

### 启动服务

需要同时运行两个服务：

```bash
# 终端 1：启动 CORS 代理（端口 8080）
python3 proxy/cors_proxy.py

# 终端 2：启动 Web 静态服务器（端口 3000）
python3 -m http.server 3000 --directory build/web
```

或用一条命令后台启动：

```bash
cd AdvanceMediaKB-FR
nohup python3 proxy/cors_proxy.py > /tmp/proxy.log 2>&1 &
nohup python3 -m http.server 3000 --directory build/web > /tmp/web_server.log 2>&1 &
```

### 访问

浏览器打开 http://localhost:3000

### 登录配置

- 服务器地址：`http://localhost:8080/webdav`
- 认证方式：账号密码
- 用户名：`17302587963`
- 密码：`8lx029wi`（需手动输入）
- 存储路径：`/life-journal`

### 查看日志

1. 按 **F12** 打开浏览器开发者工具
2. 切换到 **Console** 标签页
3. 所有日志带前缀：`[INFO]`、`[OK]`、`[WARN]`、`[ERROR]`

### 停止服务

```bash
# 查找进程
ps aux | grep -E "(cors_proxy|http.server)" | grep -v grep

# 或直接杀掉端口
kill $(lsof -t -i:8080) 2>/dev/null  # 停止代理
kill $(lsof -t -i:3000) 2>/dev/null  # 停止Web服务器
```

---

## 二、远程访问方案

没有服务器资源时，可以使用以下免费方案：

### 方案 1：Cloudflare Tunnel（推荐，免费）

最稳定的免费方案，不需要公网 IP。

```bash
# 1. 安装 cloudflared
# macOS
brew install cloudflared
# Linux (Debian/Ubuntu)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# 2. 启动本地服务（同上）
python3 proxy/cors_proxy.py &
python3 -m http.server 3000 --directory build/web &

# 3. 启动隧道（无需注册，一条命令）
cloudflared tunnel --url http://localhost:3000

# 会输出类似：https://xxx-yyy-zzz.trycloudflare.com
# 用这个地址在任何设备上访问
```

**注意：** 远程访问时 CORS 代理也需要被远程访问到。需要修改 `build/web/main.dart.js`
中的代理地址，或启动第二个隧道：

```bash
# 隧道 1：Web 前端
cloudflared tunnel --url http://localhost:3000

# 隧道 2：CORS 代理
cloudflared tunnel --url http://localhost:8080
```

然后修改登录页面的默认服务器地址为隧道 2 的地址。

### 方案 2：ngrok（免费，需注册）

```bash
# 1. 安装 ngrok
# https://ngrok.com/download 下载

# 2. 注册并配置 authtoken
ngrok config add-authtoken YOUR_TOKEN

# 3. 启动隧道
ngrok http 3000   # Web 前端
ngrok http 8080   # CORS 代理（新终端）
```

### 方案 3：GitHub Pages（纯静态，适合展示）

将 `build/web` 部署到 GitHub Pages：

```bash
# 1. 构建
flutter build web

# 2. 把 build/web 内容推到 gh-pages 分支
cd build/web
git init
git add .
git commit -m "deploy"
git remote add origin git@github.com:你的用户名/你的仓库.git
git push -f origin main:gh-pages

# 3. 在 GitHub 仓库 Settings > Pages 中开启
# 访问 https://你的用户名.github.io/你的仓库/
```

**注意：** GitHub Pages 是纯静态托管，CORS 代理需要单独部署到其他地方。

### 方案 4：局域网访问（同一 WiFi）

```bash
# 1. 查看本机 IP
hostname -I

# 2. 启动服务时绑定 0.0.0.0（代理默认已绑定）
python3 proxy/cors_proxy.py &
python3 -m http.server 3000 --directory build/web &

# 3. 手机/其他电脑访问 http://你的IP:3000
# 例如 http://192.168.1.100:3000
```

---

## 三、架构说明

```
浏览器 (localhost:3000)
  ↓ WebDAV 请求
CORS 代理 (localhost:8080)
  ↓ 伪装 Chrome UA + 跟随 302 + 过滤重复 CORS 头
123pan WebDAV (webdav.123pan.cn)
```

### 为什么需要 CORS 代理？

1. **123pan 不支持 CORS**：浏览器不允许跨域请求
2. **403 Forbidden**：123pan 对非浏览器 UA 返回 403，代理伪装 Chrome UA
3. **302 重定向**：GET 文件返回 302 到 CDN，代理手动跟随重定向并保持认证头
4. **图片认证**：`<img>` 标签无法发送 Authorization 头，代理支持 URL 参数 `?auth=xxx`

---

## 四、问题诊断

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| `Access-Control-Allow-Origin` 多个值 | 代理和上游都返回 CORS 头 | 已修复，代理过滤上游 CORS 头 |
| 图片 401 Unauthorized | `<img>` 无法发送 Authorization 头 | 已修复，URL 参数传递认证 |
| 连接超时 | 123pan 服务器响应慢 | 检查网络，等待重试 |
| 页面空白 | Web 服务器未启动 | 确认 `python3 -m http.server 3000` 运行中 |
| CORS 错误 | 代理未启动 | 确认 `python3 proxy/cors_proxy.py` 运行中 |
