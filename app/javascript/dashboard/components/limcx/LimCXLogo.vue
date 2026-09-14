<script setup>
import { computed } from 'vue';
import {
  DEFAULT_PLATFORM_BRANDING,
  getBrandLogo,
} from 'dashboard/branding/limcxBranding';

const props = defineProps({
  branding: {
    type: Object,
    default: () => DEFAULT_PLATFORM_BRANDING,
  },
  collapsed: {
    type: Boolean,
    default: false,
  },
});

const logo = computed(() =>
  getBrandLogo(props.branding, props.collapsed ? 'compact' : 'full')
);

const initials = computed(() =>
  (props.branding.productName || props.branding.appName || 'L')
    .split(' ')
    .map(part => part[0])
    .join('')
    .slice(0, 2)
);
</script>

<template>
  <div class="flex items-center min-w-0 gap-3">
    <img
      v-if="logo"
      :src="logo"
      :alt="branding.appName"
      class="object-contain rounded-md size-9"
    />
    <div
      v-else
      class="grid flex-shrink-0 text-sm font-semibold text-white rounded-md size-9 place-items-center"
      :style="{
        background: `linear-gradient(135deg, ${branding.primaryColor}, ${branding.accentColor})`,
      }"
    >
      {{ initials }}
    </div>
    <div v-if="!collapsed" class="min-w-0">
      <div class="text-sm font-semibold leading-5 truncate text-slate-50">
        {{ branding.appName }}
      </div>
      <div class="text-xs truncate text-slate-400">
        {{ branding.productName }}
      </div>
    </div>
  </div>
</template>
