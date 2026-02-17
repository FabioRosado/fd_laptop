<script setup lang="ts">
import type { InternalAppWindowBinds } from '../../types/window.types'
import { onMounted, ref } from 'vue'
import { useApi } from '../../composables/useApi'
import { useLocale } from '../../stores/locale.store'
import { useNotifications } from '../../stores/notifications.store'
import { useLaptop } from '../../stores/laptop.store'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'

interface SaveLaptopPasswordResponse {
  success: boolean
  error?: string
  hasPassword: boolean
}

const MIN_PASSWORD_LENGTH = 4

const props = defineProps<Omit<InternalAppWindowBinds, 'appReady' | 'app'>>()

const locale = useLocale()
const notif = useNotifications()
const laptop = useLaptop()

const password = ref<string>('')
const isSaving = ref<boolean>(false)
const showPassword = ref<boolean>(false)

const saveLaptopPassword = async () => {
  if (isSaving.value) return

  if (password.value && password.value.trim().length < MIN_PASSWORD_LENGTH) {
    notif.show({
      summary: locale.t('settings_password_save_error_title'),
      detail: locale.t('settings_password_min_length_error')
    })

    return
  }

  isSaving.value = true

  const { data } = await useApi<SaveLaptopPasswordResponse>(
    'saveLaptopPassword',
    {
      method: 'POST',
      body: JSON.stringify({ password: password.value })
    },
    undefined,
    {
      success: false,
      error: locale.t('settings_password_save_error_description'),
      hasPassword: laptop.hasPassword
    }
  )

  const response = data.value as SaveLaptopPasswordResponse

  isSaving.value = false

  if (!response.success) {
    notif.show({
      summary: locale.t('settings_password_save_error_title'),
      detail: response.error || locale.t('settings_password_save_error_description')
    })
    return
  }

  laptop.updateLaptopSecurity(response.hasPassword)
  password.value = ''
  showPassword.value = false

  notif.show({
    summary: locale.t('settings_password_save_success_title'),
    detail: response.hasPassword
      ? locale.t('settings_password_save_success_enabled')
      : locale.t('settings_password_save_success_disabled')
  })
}

onMounted(() => {
  props.changeWindowTitle(locale.t('settings_password_title'))
})
</script>
<template>
  <div class="flex h-full flex-col gap-5">
    <div class="flex flex-col gap-2 rounded-lg bg-gray-300 p-4 dark:bg-gray-800">
      <h4 class="text-base font-semibold">{{ locale.t('settings_password_title') }}</h4>
      <p class="text-sm text-muted-color">{{ locale.t('settings_password_helptext') }}</p>
      <p class="text-xs text-muted-color" v-if="laptop.hasPassword">
        {{ locale.t('settings_password_enabled_label') }}
      </p>
      <p class="text-xs text-muted-color" v-else>
        {{ locale.t('settings_password_disabled_label') }}
      </p>
    </div>

    <div class="flex flex-col gap-3 rounded-lg bg-gray-300 p-4 dark:bg-gray-800">
      <label for="laptopPassword">{{ locale.t('settings_password_field_label') }}</label>
      <div class="flex items-center gap-2">
        <InputText
          class="flex-1"
          id="laptopPassword"
          v-model="password"
          :type="showPassword ? 'text' : 'password'"
          :placeholder="locale.t('settings_password_field_placeholder')"
        />
        <Button
          severity="secondary"
          :icon="showPassword ? 'pi pi-eye-slash' : 'pi pi-eye'"
          @click="showPassword = !showPassword"
        />
      </div>
      <small class="text-muted-color">{{ locale.t('settings_password_min_length_hint') }}</small>
      <div class="flex gap-2">
        <Button
          class="flex-1"
          :loading="isSaving"
          :label="locale.t('settings_password_save_button')"
          @click="saveLaptopPassword"
        />
        <Button
          class="flex-1"
          severity="secondary"
          :loading="isSaving"
          :label="locale.t('settings_password_remove_button')"
          @click="password = ''; saveLaptopPassword()"
        />
      </div>
    </div>
  </div>
</template>
