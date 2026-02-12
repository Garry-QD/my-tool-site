// 档案路径: docs/.vitepress/theme/index.js

import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import CopyCard from './components/CopyCard.vue' 
import LinkCard from './components/LinkCard.vue'
import MiniLink from './components/MiniLink.vue'
import HomeCarousel from './components/HomeCarousel.vue'
import FileTransfer from './components/FileTransfer.vue' // 引入新组件
import '../style.css'  


export default {
  extends: DefaultTheme, 
  
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'home-hero-image': () => h(HomeCarousel),
      // 我们将文件传输助手图片注入到 home-hero-info 插槽中，通常它位于文字下方或侧边
      // 但为了实现复杂的左右布局，可能需要 CSS 配合
      // 或者我们可以尝试 'home-hero-after-text' 如果存在的话，但 VitePress 默认只有 home-hero-info
      // 实际上，home-hero-info 会替换默认的 info 区域（如果有的话）
      // 更好的方式可能是直接在 index.md 中通过 HTML 插入，或者这里通过插槽注入但需要 CSS 强力干预
      // 让我们试试直接注入到 'home-hero-actions-after' 看看位置，或者 'home-features-before'
      // 为了精确控制位置到文字右侧（桌面端），我们利用 'home-hero-image' 插槽已经被占用的情况
      // 实际上，VitePress 默认布局是 文字左 图片右。
      // 但我们之前把轮播图放在了 'home-hero-image'，并强制 CSS 改成了上下结构。
      // 现在用户想要：
      // 1. 轮播图在最上面 (Order 1)
      // 2. 文字在下面 (Order 2)
      // 3. 这里的“文字”区域，用户希望变成左右分栏：左边是原来的文字，右边是这个新图片。
      
      // 这比较复杂，因为 VPHero 组件内部结构相对固定。
      // 我们可以尝试把这个新图片作为 HomeCarousel 的一部分？ 不，它是独立的。
      // 或者，我们将这个图片注入到 'home-hero-actions-after'，然后用 CSS 将其定位到右侧。
      'home-hero-actions-after': () => h(FileTransfer)
    })
  },

  enhanceApp({ app }) {
    // 注册 CopyCard 组件
    app.component('CopyCard', CopyCard)
    app.component('LinkCard', LinkCard)
    app.component('MiniLink', MiniLink)
    app.component('HomeCarousel', HomeCarousel)
    app.component('FileTransfer', FileTransfer)
  }
}
