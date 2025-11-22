// 档案路径: docs/.vitepress/theme/index.js

import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import '../style.css' 

export default {
  ...DefaultTheme,

  // (您用来注册 MyButton 的 enhanceApp 函数，如果有的话，请保留)
  // enhanceApp({ app }) {
  //   app.component('MyButton', MyButton) 
  // }
}