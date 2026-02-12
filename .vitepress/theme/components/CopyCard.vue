<script setup>
import { ref } from 'vue'

const props = defineProps({
  label: String,
  link: String
})

const btnText = ref('复制链接')
const isCopied = ref(false)

// 兼容 HTTP 的老式复制函数
function legacyCopy(text) {
  const textArea = document.createElement("textarea")
  textArea.value = text
  
  // 把输入框藏起来，但不能用 display:none，否则无法选中
  textArea.style.top = "0"
  textArea.style.left = "0"
  textArea.style.position = "fixed"
  textArea.style.opacity = "0"

  document.body.appendChild(textArea)
  textArea.focus()
  textArea.select()

  try {
    const successful = document.execCommand('copy')
    document.body.removeChild(textArea)
    return successful
  } catch (err) {
    document.body.removeChild(textArea)
    return false
  }
}

const copyLink = async () => {
  let success = false

  // 1. 优先尝试现代 API (HTTPS环境)
  if (navigator.clipboard && navigator.clipboard.writeText) {
    try {
      await navigator.clipboard.writeText(props.link)
      success = true
    } catch (err) {
      // 如果现代 API 失败，尝试降级处理
      success = legacyCopy(props.link)
    }
  } else {
    // 2. 如果浏览器不支持现代 API (HTTP环境)，直接用老办法
    success = legacyCopy(props.link)
  }

  // 3. 处理结果反馈
  if (success) {
    btnText.value = '已复制! ✅'
    isCopied.value = true
    setTimeout(() => {
      btnText.value = '复制链接'
      isCopied.value = false
    }, 2000)
  } else {
    alert('复制失败，请手动长按链接复制')
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
  background-color: var(--vp-c-bg-soft);
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
  border: none;
  cursor: pointer;
  transition: all 0.2s;
}

.copy-btn:hover {
  background-color: var(--vp-c-brand-dark);
}

.copy-btn.success {
  background-color: #10b981;
  cursor: default;
}
</style>