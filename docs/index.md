---
layout: home

hero:

  name: "FlatNas"
  text: "轻量级个人导航页与仪表盘系统"
  tagline: "自带文件传输助手、日历、天气、备忘录、代办、RSS 订阅、热搜榜单、音乐播放器等组件，为 NAS 用户、极客和开发者提供的优雅导航起始页"
  actions:
    - theme: brand
      text: 🚀 FPK安装
      link: /flatnas1.0.41all.fpk
      target: _self
      download: true
    - theme: alt
      text: 📦 Docker 部署
      link: https://hub.docker.com/r/qdnas/flatnas
      target: _blank
    - theme: alt
      text: 🐱 GitHub
      link: https://github.com/Garry-QD/FlatNas
      target: _blank
    - theme: alt
      text: 🌐 官网地址
      link: https://flatnas.top/
      target: _blank

features:
  - title: 🖥️ 自由布局
    details: 支持网格布局，自由拖拽，不同尺寸组件随心配置，完美适配桌面与移动端。
  - title: 🧩 丰富组件
    details: 内置书签、时钟、天气、Todo、RSS 订阅、热搜榜单及音乐播放器。
  - title: 🌐 智能网络
    details: 集成智能网络环境识别，根据访问来源自动切换内外网访问策略。
  - title: 🎨 个性定制
    details: 支持自定义图标、壁纸及分组背景，内置版本检测与数据安全保护。

---

# 🚀 快速开始

### Docker-compose部署 (推荐)
```bash
version: "3.8"

services:
  flatnas:
    image: qdnas/flatnas:1.0.41
    container_name: flatnas
    restart: unless-stopped
    ports:
      - "23000:3000"
    volumes:
      - ./data:/app/server/data #指定路径下新建data
      - ./music:/app/server/music #映射播放器路径
      - ./PC:/app/server/PC #映射背景路径
      - ./APP:/app/server/APP #映射移动端背景路径
      - ./doc:/app/server/doc #映射文件传输助手路径
      - /var/run/docker.sock:/var/run/docker.sock #映射Docker Socket

```

<div class="footer-links">

### 交流互动

- **GitHub**: [Garry-QD/FlatNas](https://github.com/Garry-QD/FlatNas)
- **Gitee**: [gjx0808/FlatNas](https://gitee.com/gjx0808/FlatNas)
- **官网**: [flatnas.top](https://flatnas.top/)
📱或扫描下方的二维码：
![alt text](770c2281aaeb9096b997178db2b7b818.png)

</div>

