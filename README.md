# Firefox + sing-box + Proxy UI

单镜像集成方案：Firefox 容器内置 sing-box，并附带 Leme-bot 代理管理面板。

## 功能
- Firefox 默认走本地 SOCKS5 代理
- 面板管理节点、生成/应用 sing-box 配置
- 配置与数据持久化到 `/app/data`

## 构建
```bash
docker build -t firefox-proxy-ui .
```

## 运行
```bash
docker run -d \
  --name firefox-proxy-ui \
  -p 25858:5900 \
  -p 18868:8080 \
  -p 15000:5000 \
  -v ./data:/app/data \
  -e DISPLAY_WIDTH=1920 \
  -e DISPLAY_HEIGHT=1080 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e FIREFOX_PROXY_PORT=20000 \
  firefox-proxy-ui
```

## 环境变量
- `DATA_DIR`：面板数据目录，默认 `/app/data`
- `FIREFOX_PROXY_HOST`：Firefox 代理主机，默认 `127.0.0.1`
- `FIREFOX_PROXY_PORT`：Firefox 代理端口，默认 `20000`
- `FIREFOX_PROXY_ENABLE`：是否强制 Firefox 走代理，默认 `0`
- `PROXY_LISTEN`：sing-box 本地监听地址，默认 `127.0.0.1`
- `PROXY_BASE_PORT`：节点本地端口起始值，默认 `20000`

## 说明
- 面板默认端口 `5000`
- sing-box 可执行文件位于 `/usr/local/bin/sing-box`
- Firefox 代理配置写入 `user.js`
