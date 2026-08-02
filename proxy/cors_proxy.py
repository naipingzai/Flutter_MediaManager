#!/usr/bin/env python3
"""本地 CORS 代理 - 让浏览器访问 123pan WebDAV
用法: python3 proxy/cors_proxy.py

123pan GET 文件返回 302 重定向到 CDN，urllib 跟随重定向时
丢失认证头导致 403。改用 http.client 手动处理重定向。
"""
import http.server
import http.client
import urllib.parse
import ssl
import sys
import json

PORT = 8080
TARGET_HOST = 'webdav.123pan.cn'
TARGET_SCHEME = 'https'

ssl_ctx = ssl.create_default_context()
ssl_ctx.check_hostname = False
ssl_ctx.verify_mode = ssl.CERT_NONE

BROWSER_UA = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/124.0.0.0 Safari/537.36'
)


def make_request(method, path, headers, body, max_redirects=5):
    """发送请求到 123pan，手动处理重定向"""
    host = TARGET_HOST
    url_path = path
    scheme = TARGET_SCHEME

    for _ in range(max_redirects + 1):
        if scheme == 'https':
            conn = http.client.HTTPSConnection(host, context=ssl_ctx, timeout=30)
        else:
            conn = http.client.HTTPConnection(host, timeout=30)

        try:
            conn.request(method, url_path, body=body, headers=headers)
            resp = conn.getresponse()
            resp_body = resp.read()

            # 301/302 重定向：跟随但保持认证头
            if resp.status in (301, 302, 303, 307, 308):
                location = resp.getheader('Location', '')
                if not location:
                    break
                parsed = urllib.parse.urlparse(location)
                host = parsed.hostname
                scheme = parsed.scheme
                url_path = parsed.path
                if parsed.query:
                    url_path += '?' + parsed.query
                # 更新 Host 头
                headers = dict(headers)
                headers['Host'] = host
                continue

            return resp.status, dict(resp.getheaders()), resp_body
        finally:
            conn.close()

    return 502, {}, b'{"error":"Too many redirects"}'


class CORSHandler(http.server.BaseHTTPRequestHandler):
    def _cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods',
                         'GET, PUT, POST, DELETE, OPTIONS, MKCOL, PROPFIND, PROPPATCH, COPY, MOVE')
        self.send_header('Access-Control-Allow-Headers',
                         'Authorization, Content-Type, Depth, If-None-Match, Overwrite, Destination')
        self.send_header('Access-Control-Expose-Headers', 'ETag, Content-Length, Content-Type, Location')
        self.send_header('Access-Control-Max-Age', '86400')

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):       self._proxy_request('GET')
    def do_HEAD(self):      self._proxy_request('HEAD')
    def do_PUT(self):       self._proxy_request('PUT')
    def do_POST(self):      self._proxy_request('POST')
    def do_DELETE(self):    self._proxy_request('DELETE')
    def do_MKCOL(self):     self._proxy_request('MKCOL')
    def do_PROPFIND(self):  self._proxy_request('PROPFIND')
    def do_PROPPATCH(self): self._proxy_request('PROPPATCH')
    def do_COPY(self):      self._proxy_request('COPY')
    def do_MOVE(self):      self._proxy_request('MOVE')

    def _proxy_request(self, method):
        try:
            # 解析路径和查询参数
            parsed_url = urllib.parse.urlparse(self.path)
            target_path = urllib.parse.unquote(parsed_url.path)
            query_params = urllib.parse.parse_qs(parsed_url.query)

            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None

            # 构建转发头
            headers = {
                'User-Agent': BROWSER_UA,
                'Accept': '*/*',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Host': TARGET_HOST,
                'Referer': 'https://webdav.123pan.cn/',
            }
            # 保留原始请求的关键头
            for key in ('Authorization', 'Content-Type', 'Depth', 'Overwrite',
                        'If-None-Match', 'If-Modified-Since', 'Lock-Token',
                        'Destination'):
                if key in self.headers:
                    headers[key] = self.headers[key]

            # 支持 URL 查询参数中的 auth（<img> 标签无法发送 Authorization 头）
            if 'Authorization' not in headers and 'auth' in query_params:
                headers['Authorization'] = query_params['auth'][0]

            status, resp_headers, resp_body = make_request(
                method, target_path, headers, body)

            self.send_response(status)
            self._cors_headers()
            for key, val in resp_headers.items():
                low = key.lower()
                # 跳过传输相关头和上游自带的CORS头（由代理统一添加）
                if low in ('transfer-encoding', 'connection', 'x-frame-options',
                           'access-control-allow-origin',
                           'access-control-allow-methods',
                           'access-control-allow-headers',
                           'access-control-expose-headers',
                           'access-control-max-age',
                           'access-control-allow-credentials'):
                    continue
                self.send_header(key, val)
            self.end_headers()
            if resp_body:
                self.wfile.write(resp_body)

        except (BrokenPipeError, ConnectionResetError, OSError) as e:
            # 客户端提前断开连接，忽略即可
            pass

        except Exception as e:
            self.send_response(502)
            self._cors_headers()
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'error': 'Proxy error',
                'message': str(e)
            }).encode())

    def log_message(self, format, *args):
        sys.stderr.write(f"  {self.command} {self.path} -> {args[0] if args else ''}\n")


if __name__ == '__main__':
    print(f'🚀 CORS 代理运行在 http://localhost:{PORT}')
    print(f'   转发目标: {TARGET_HOST}')
    print(f'   用法: APP 中 WebDAV 地址改为 http://localhost:{PORT}/webdav')
    print(f'   Ctrl+C 停止\n')
    server = http.server.HTTPServer(('0.0.0.0', PORT), CORSHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n⏹ 代理已停止')
