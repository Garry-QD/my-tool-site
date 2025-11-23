<script setup>
defineProps({
  label: String, // 按钮上显示的文字
  link: String   // 跳转的地址
})
</script>

<template>
  <a :href="link" target="_blank" class="link-card">
    <span class="label">🚀 {{ label }}</span>
    <span class="arrow">前往 &rarr;</span>
  </a>
</template>

<style scoped>
/* 这是一个可点击的卡片样式 */
.link-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: var(--vp-c-bg-soft);
  padding: 14px 20px;
  border-radius: 8px;
  margin-bottom: 12px;
  border: 1px solid var(--vp-c-divider);
  text-decoration: none !important; /* 去掉下划线 */
  transition: all 0.25s;
  cursor: pointer;
}

/* 鼠标悬停时的效果 */
.link-card:hover {
  background-color: var(--vp-c-brand-soft); /* 变成主题色的浅色背景 */
  border-color: var(--vp-c-brand);
  transform: translateY(-2px); /* 微微上浮 */
}

.label {
  font-weight: 600;
  color: var(--vp-c-text-1);
  font-size: 15px;
}

.arrow {
  color: var(--vp-c-brand);
  font-weight: bold;
  font-size: 14px;
}
</style>