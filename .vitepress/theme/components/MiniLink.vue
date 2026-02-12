<script setup>
defineProps({
  label: String,
  link: String
})
</script>

<template>
  <a :href="link" target="_blank" class="mini-btn">
    {{ label || '跳转' }} ➜
  </a>
</template>

<style scoped>
.mini-btn {
  display: inline-block; /* 关键：内联块级元素，不换行 */
  font-size: 12px;
  color: var(--vp-c-brand); /* 使用主题色 */
  border: 1px solid var(--vp-c-brand);
  padding: 2px 8px;
  border-radius: 4px;
  margin-left: 8px; /* 离前面的字稍微远一点 */
  text-decoration: none !important;
  vertical-align: middle; /* 对齐文字中线 */
  transition: all 0.2s;
  font-weight: normal;
  line-height: normal;
}

.mini-btn:hover {
  background-color: var(--vp-c-brand);
  color: white; /* 悬停变成实心 */
}
</style>