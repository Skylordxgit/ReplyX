<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->

<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  BRANDING_UI_SETTINGS_KEY,
  getPlatformBranding,
  readLogoUpload,
} from 'dashboard/branding/limcxBranding';

defineProps({
  compact: {
    type: Boolean,
    default: false,
  },
});

const { uiSettings, updateUISettings } = useUISettings();
const branding = computed(() => getPlatformBranding(uiSettings.value));

const updateBranding = patch => {
  updateUISettings({
    [BRANDING_UI_SETTINGS_KEY]: {
      ...branding.value,
      ...patch,
    },
  });
};

const onUpload = async (event, key) => {
  const [file] = event.target.files || [];
  const data = await readLogoUpload(file);
  if (data) {
    updateBranding({ [key]: data });
  }
  event.target.value = '';
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="grid gap-2" :class="compact ? 'grid-cols-1' : 'grid-cols-3'">
    <label class="text-xs text-slate-400">
      Full logo
      <input
        class="block w-full mt-1 text-xs text-slate-300 file:mr-2 file:border-0 file:rounded-md file:bg-blue-500 file:px-2 file:py-1 file:text-white"
        type="file"
        accept="image/*"
        @change="onUpload($event, 'fullLogo')"
      />
    </label>
    <label class="text-xs text-slate-400">
      Compact logo
      <input
        class="block w-full mt-1 text-xs text-slate-300 file:mr-2 file:border-0 file:rounded-md file:bg-blue-500 file:px-2 file:py-1 file:text-white"
        type="file"
        accept="image/*"
        @change="onUpload($event, 'compactLogo')"
      />
    </label>
    <label class="text-xs text-slate-400">
      Favicon
      <input
        class="block w-full mt-1 text-xs text-slate-300 file:mr-2 file:border-0 file:rounded-md file:bg-blue-500 file:px-2 file:py-1 file:text-white"
        type="file"
        accept="image/*"
        @change="onUpload($event, 'favicon')"
      />
    </label>
  </div>
</template>
