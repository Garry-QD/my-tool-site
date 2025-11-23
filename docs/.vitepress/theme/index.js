// 档案路径: docs/.vitepress/theme/index.js

import DefaultTheme from 'vitepress/theme'
import CopyCard from './components/CopyCard.vue' 
import LinkCard from './components/LinkCard.vue'
import MiniLink from './components/MiniLink.vue'
import '../style.css'  // 👈 修正点：这里保留你原本的两个点，指向上级目录


export default {
  extends: DefaultTheme, 
  enhanceApp({ app }) {
    // 注册 CopyCard 组件
    app.component('CopyCard', CopyCard)
    app.component('LinkCard', LinkCard)
    app.component('MiniLink', MiniLink)
  }
}