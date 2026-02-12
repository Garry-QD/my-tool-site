import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "谢氏老中医馆",
  description: "收集常用的命令和工具下载",

  head: [
    /*
    [
      'script',
      {},
      `
      var _hmt = _hmt || [];
      (function() {
        var hm = document.createElement("script");
        hm.src = "https://hm.baidu.com/hm.js?dc721bfdbf3df3ea9776539aa8ba0d4b";
        var s = document.getElementsByTagName("script")[0]; 
        s.parentNode.insertBefore(hm, s);
      })();
      `
    ]
    */
  ],

  themeConfig: {

    // 顶部导航栏 (使用你 'commands' 文件夹的路径)
    nav: [
      { text: '首页', link: '/' },
      { text: '脚本库', link: '/scripts/scripts.md' },
      { text: '命令库', link: '/command/command.md' },
      { text: '飞牛疑难百科', link: '/QA/wiki.md' },
      { text: '磁盘修复扫描工具', link: '/downloads/tools.md' },
      { text: '其他工具下载', link: '/downloads/downloads.md' },
      { text: 'deb离线升级镜像', link: '/deb/deb.md' },
      { text: '建站工具', link: '/scripts/website-building.md' },
      { text: '互动交流', link: '/join-qq.md' },
    ], // <-- 那个错误就是因为少了这里的逗号

    // 侧边栏 (使用 'commands' 和 'downloads' 路径)
    sidebar: [
      { text: '首页', link: '/' },
      {
        text: '飞牛大全',
        items: [
          { text: '脚本库', link: '/scripts/scripts.md' },
          { text: '命令库', link: '/command/command.md' },
          { text: '飞牛疑难百科', link: '/QA/wiki.md' }
        ]
      },
      {
        text: '下载专区',
        items: [
          { text: '磁盘修复扫描工具', link: '/downloads/tools.md' }, // (这个指向 docs/tools.md)
          { text: '其他工具下载', link: '/downloads/downloads.md' },// (这个指向 docs/downloads.md)
          { text: 'deb离线升级镜像', link: '/deb/deb.md' } ,// (这个指向 /deb/deb.md)
          { text: '建站工具', link: '/scripts/website-building.md' } 
        ]
      },
      {
        text: '交流互动',
        items: [
          { text: '📀飞牛历史镜像包 ', link: 'http://0745daxin.art:5666/s/03fceb0f36de4b3c80' } ,// (这个指向 /deb/deb.md)
          { text: '🎛️飞牛显卡范围验证表', link: 'https://club.fnnas.com/forum.php?mod=viewthread&tid=4271&extra=page%3D1' },
          { text: '🌐飞牛网卡范围验证表', link: 'https://club.fnnas.com/forum.php?mod=viewthread&tid=18173&extra=page%3D1' },
          { text: '申请加群讨论', link: '/join-qq.md' }
        ]
      }
    ]
    
  }
})