<script setup lang="ts">
import { useApplications } from '../stores/apps.store'
import { useSettings } from '../stores/settings.store'
import { computed, defineAsyncComponent, ref, useTemplateRef, watch, type CSSProperties } from 'vue'
import DynamicDialog from 'primevue/dynamicdialog'
import { useLaptop } from '../stores/laptop.store'
import { backgroundUrl } from '../utils/url.utils'
import { onKeyStroke } from '@vueuse/core'
import { useNotifications } from '../stores/notifications.store'
import { useApi } from '../composables/useApi'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'

const Window = defineAsyncComponent(() => import('./Window.vue'))
const Taskbar = defineAsyncComponent(() => import('./Taskbar.vue'))
const Desktop = defineAsyncComponent(() => import('./Desktop.vue'))

const settings = useSettings()
const apps = useApplications()
const notif = useNotifications()
const laptop = useLaptop()

const laptopRef = useTemplateRef<HTMLDivElement>('laptopRef')
const lockPassword = ref<string>('')
const unlockError = ref<string>('')
const isUnlocking = ref<boolean>(false)
const showLockPassword = ref<boolean>(false)

const styles = computed<CSSProperties>(() => {
  if (!laptop.isOpen && !notif.shouldBeShown) {
    return {}
  }

  return {
    backgroundImage: `url(${backgroundUrl(settings.backgroundImage!)})`
  }
})

onKeyStroke(
  'Escape',
  (event) => {
    if (!laptop.isOpen) return

    event.preventDefault()
    event.stopPropagation()

    laptop.close(true)
  },
  {
    eventName: 'keydown',
    dedupe: true
  }
)

const unlockLaptop = async () => {
  if (isUnlocking.value) return

  isUnlocking.value = true
  unlockError.value = ''

  const { data } = await useApi<{ success: boolean; error?: string }>(
    'unlockLaptop',
    {
      method: 'POST',
      body: JSON.stringify({ password: lockPassword.value })
    },
    undefined,
    {
      success: false,
      error: laptop.t('laptop_lock_error')
    }
  )

  const response = data.value as { success: boolean; error?: string }

  isUnlocking.value = false

  if (!response.success) {
    unlockError.value = response.error || laptop.t('laptop_lock_error')
    return
  }

  lockPassword.value = ''
  unlockError.value = ''
  showLockPassword.value = false
  laptop.unlock()
}

watch(
  () => laptop.isLocked,
  (locked) => {
    if (locked) return

    lockPassword.value = ''
    unlockError.value = ''
    showLockPassword.value = false
  }
)
</script>
<template>
  <div
    id="laptop"
    ref="laptopRef"
    class="fixed flex h-[85vh] min-h-[642px] w-[80vw] min-w-[1134px] flex-1 transform overflow-hidden rounded-xl border-8 border-gray-900 bg-white bg-cover bg-center shadow-lg outline outline-1 -outline-offset-[1px] outline-gray-100/20 text-color hd:h-[80vh]"
    :style="styles"
    :class="{
      'left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 opacity-50 hover:opacity-100':
        laptop.isOpen,
      '-bottom-[75%] left-1/2 -translate-x-1/2 hd:-bottom-[70%]':
        !laptop.isOpen && notif.shouldBeShown
    }"
  >
    <div class="relative flex h-[calc(100%-1.0rem-3.5rem)] flex-1" v-if="laptop.isOpen">
      <div
        class="relative flex h-full w-full"
        :class="{
          'pointer-events-none': laptop.isLocked
        }"
      >
        <Desktop v-if="laptopRef" :parent="laptopRef" />
        <template v-if="laptopRef">
          <Window
            v-for="window in apps.windows"
            :key="window.app.id"
            :appWindow="window"
            :parent="laptopRef"
          />
        </template>
      </div>

      <div v-show="laptop.isLocked" class="absolute inset-0 z-10 flex w-full items-center justify-center">
        <div class="flex w-full max-w-md flex-col gap-4 rounded-lg bg-gray-200/90 p-6 dark:bg-gray-900/80">
          <h3 class="text-xl font-semibold">{{ laptop.t('laptop_lock_title') }}</h3>
          <p class="text-sm text-muted-color">{{ laptop.t('laptop_lock_description') }}</p>
          <div class="flex items-center gap-2">
            <InputText
              class="flex-1"
              v-model="lockPassword"
              :type="showLockPassword ? 'text' : 'password'"
              :placeholder="laptop.t('laptop_lock_input_placeholder')"
              :invalid="!!unlockError"
              @keyup.enter="unlockLaptop"
              autofocus
            />
            <Button
              severity="secondary"
              :icon="showLockPassword ? 'pi pi-eye-slash' : 'pi pi-eye'"
              @click="showLockPassword = !showLockPassword"
            />
          </div>
          <small class="text-red-200" v-if="unlockError">{{ unlockError }}</small>
          <Button
            fluid
            :label="laptop.t('laptop_lock_button')"
            :loading="isUnlocking"
            @click="unlockLaptop"
          />
        </div>
      </div>
    </div>

    <Taskbar
      v-if="laptopRef"
      :parent="laptopRef"
      v-show="!laptop.isLocked"
      :class="{
        'pointer-events-none': laptop.isLocked
      }"
    />
    <DynamicDialog appendTo="#laptop" v-if="laptop.isOpen" />
  </div>
</template>
