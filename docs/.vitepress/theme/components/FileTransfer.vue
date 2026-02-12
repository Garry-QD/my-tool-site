<template>
  <div class="file-transfer-image-container">
    <img src="/文件传输助手.png" alt="文件传输助手" class="file-transfer-img" />
  </div>
</template>

<style scoped>
.file-transfer-image-container {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
}

.file-transfer-img {
  max-width: 100%;
  max-height: 400px; /* 限制高度，避免过大 */
  width: auto;
  height: auto;
  object-fit: contain;
  border-radius: 8px;
  /* box-shadow: 0 4px 12px rgba(0,0,0,0.1); 可选：添加一点阴影 */
}
</style>
