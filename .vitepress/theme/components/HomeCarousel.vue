<template>
  <div class="home-carousel">
    <div class="carousel-container" @mouseenter="pause" @mouseleave="resume">
      <transition-group name="fade" tag="div" class="carousel-track">
        <div
          v-for="(image, index) in images"
          :key="image"
          v-show="currentIndex === index"
          class="carousel-slide"
        >
          <img :src="image" alt="FlatNas Preview" class="carousel-image" />
        </div>
      </transition-group>
      
      <div class="carousel-indicators">
        <span
          v-for="(image, index) in images"
          :key="index"
          :class="['indicator', { active: currentIndex === index }]"
          @click="goTo(index)"
        ></span>
      </div>

      <button class="nav-btn prev" @click="prev">❮</button>
      <button class="nav-btn next" @click="next">❯</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const images = [
  '/images/lunbo/0f0db4662a85d1718bf679583f697a70.png',
  '/images/lunbo/535f752973f0e7fbd63c7fcb1f87cdfd.png',
  '/images/lunbo/9f3469d525fe96105e42dde69e031fd5.png',
  '/images/lunbo/b27e2542ca9d2aa503529fa64cd355f5.png',
  '/images/lunbo/f5e979bcc1a262a25a06e082a4c07d22.png'
]

const currentIndex = ref(0)
let timer = null

const startTimer = () => {
  timer = setInterval(next, 4000)
}

const pause = () => {
  if (timer) clearInterval(timer)
}

const resume = () => {
  startTimer()
}

const next = () => {
  currentIndex.value = (currentIndex.value + 1) % images.length
}

const prev = () => {
  currentIndex.value = (currentIndex.value - 1 + images.length) % images.length
}

const goTo = (index) => {
  currentIndex.value = index
}

onMounted(() => {
  startTimer()
})

onUnmounted(() => {
  pause()
})
</script>

<style scoped>
.home-carousel {
  width: 100%;
  max-width: 1200px;
  margin: 20px auto;
  position: relative;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 10px 30px rgba(0,0,0,0.15);
  aspect-ratio: 16/9; /* 根据图片比例调整，这里假设是宽屏 */
}

.carousel-container {
  width: 100%;
  height: 100%;
  position: relative;
}

.carousel-track {
  width: 100%;
  height: 100%;
}

.carousel-slide {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.carousel-image {
  width: 100%;
  height: 100%;
  object-fit: cover; /* 或者 contain，取决于是否允许裁剪 */
  object-position: center;
  display: block;
}

/* Transitions */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.6s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

/* Indicators */
.carousel-indicators {
  position: absolute;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 10px;
  z-index: 10;
}

.indicator {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.5);
  cursor: pointer;
  transition: all 0.3s;
}

.indicator.active {
  background: #fff;
  transform: scale(1.2);
}

/* Navigation Buttons */
.nav-btn {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  background: rgba(0, 0, 0, 0.3);
  color: white;
  border: none;
  padding: 15px 10px;
  cursor: pointer;
  font-size: 18px;
  z-index: 10;
  transition: background 0.3s;
}

.nav-btn:hover {
  background: rgba(0, 0, 0, 0.6);
}

.prev {
  left: 0;
  border-top-right-radius: 8px;
  border-bottom-right-radius: 8px;
}

.next {
  right: 0;
  border-top-left-radius: 8px;
  border-bottom-left-radius: 8px;
}
</style>
