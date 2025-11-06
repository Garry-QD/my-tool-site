import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "谢氏老中医馆下载站",
  description: "收集常用的命令和工具下载",

  themeConfig: {

    // 顶部导航栏 (使用你 'commands' 文件夹的路径)
    nav: [
      { text: '首页', link: '/' },
      { text: '脚本和命令库', link: '/index.md' },
      { text: '下载专区', link: '/downloads/downloads.md' },
    ], // <-- 那个错误就是因为少了这里的逗号

    // 侧边栏 (使用 'commands' 和 'downloads' 路径)
    sidebar: [
      {
        text: '脚本和命令库',
        items: [
          { text: '飞牛脚本', link: '/index.md' },
          { text: '命令库', link: '/command/command.md' }
        ]
      },
      {
        text: '下载专区',
        items: [
          { text: '磁盘修复扫描工具', link: '/downloads/tools.md' }, // (这个指向 docs/tools.md)
          { text: '其他工具下载', link: '/downloads/downloads.md' },// (这个指向 docs/downloads.md)
        ]
      },
      {
        text: '飞牛镜像下载区',
        items: [
          { text: 'deb离线升级镜像', link: '/deb/deb.md' } // (这个指向 /deb/deb.md)
        ]
      }
    ]

  }
})