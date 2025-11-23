<script setup>
import { ref } from 'vue'

const props = defineProps({
  label: String, // 显示的文件名
  link: String   // 实际的下载链接
})

const btnText = ref('复制链接')
const isCopied = ref(false)

const copyLink = async () => {
  try {
    await navigator.clipboard.writeText(props.link)
    btnText.value = '已复制! ✅'
    isCopied.value = true
    
    // 2秒后恢复原样
    setTimeout(() => {
      btnText.value = '复制链接'
      isCopied.value = false
    }, 2000)
  } catch (e) {
    alert('复制失败，请手动复制')
  }
}
</script>

<template>
  <div class="copy-card">
    <span class="file-name">📄 {{ label }}</span>
    <button class="copy-btn" :class="{ success: isCopied }" @click="copyLink">
      {{ btnText }}
    </button>
  </div>
</template>

<style scoped>
.copy-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: var(--vp-c-bg-soft); /* 跟随主题色 */
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 10px;
  border: 1px solid var(--vp-c-divider);
}

.file-name {
  font-weight: 500;
  color: var(--vp-c-text-1);
}

.copy-btn {
  font-size: 13px;
  padding: 4px 12px;
  border-radius: 4px;
  background-color: var(--vp-c-brand);
  color: white;
  transition: all 0.2s;
}

.copy-btn:hover {
  background-color: var(--vp-c-brand-dark);
}

.copy-btn.success {
  background-color: #10b981; /* 绿色成功色 */
  cursor: default;
}
</style>