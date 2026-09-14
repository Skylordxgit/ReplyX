<script setup>
import { onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();

const inboxes = useMapGetter('inboxes/getInboxes');

onMounted(() => {
  store.dispatch('inboxes/get');
});

const getChannelIcon = channelType => {
  if (channelType?.includes('Facebook')) return 'i-ri-facebook-fill';
  if (channelType?.includes('Instagram')) return 'i-ri-instagram-line';
  if (channelType?.includes('Whatsapp')) return 'i-ri-whatsapp-line';
  if (channelType?.includes('Telegram')) return 'i-ri-telegram-fill';
  if (channelType?.includes('Email')) return 'i-lucide-mail';
  return 'i-lucide-globe';
};

const getChannelColor = channelType => {
  if (channelType?.includes('Facebook')) return 'text-blue-500';
  if (channelType?.includes('Instagram')) return 'text-pink-500';
  if (channelType?.includes('Whatsapp')) return 'text-emerald-500';
  if (channelType?.includes('Telegram')) return 'text-sky-400';
  if (channelType?.includes('Email')) return 'text-amber-400';
  return 'text-blue-400';
};
</script>

<template>
  <div
    class="flex flex-col flex-1 h-full min-w-0 overflow-y-auto bg-slate-950 p-4 sm:p-6 space-y-6 select-none"
  >
    <!-- Header -->
    <div
      class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between"
    >
      <div>
        <h1 class="text-xl font-bold tracking-tight text-white">
          {{ $t('OPERATIONS.CHANNEL_HEALTH.TITLE') }}
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          {{ $t('OPERATIONS.CHANNEL_HEALTH.SUBTITLE') }}
        </p>
      </div>

      <NextButton
        icon="i-lucide-rotate-cw"
        slate
        xs
        :label="$t('OPERATIONS.REFRESH')"
        @click="store.dispatch('inboxes/get')"
      />
    </div>

    <!-- Empty State -->
    <div
      v-if="!inboxes.length"
      class="rounded-xl border border-slate-800 bg-slate-900/40 p-12 text-center text-sm text-slate-400"
    >
      <span class="i-lucide-inbox size-8 text-slate-600 mx-auto block mb-2" />
      {{ $t('OPERATIONS.CHANNEL_HEALTH.EMPTY') }}
    </div>

    <!-- Channels Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="inbox in inboxes"
        :key="inbox.id"
        class="rounded-xl border border-slate-800/80 bg-slate-900/60 p-4 flex flex-col justify-between hover:border-slate-700/80 transition-all space-y-4"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="size-10 rounded-xl bg-slate-800/80 grid place-items-center shrink-0 border border-slate-700/60"
            >
              <span
                class="size-5"
                :class="[
                  getChannelIcon(inbox.channel_type),
                  getChannelColor(inbox.channel_type),
                ]"
              />
            </div>
            <div class="flex flex-col min-w-0">
              <span class="font-semibold text-white truncate text-sm">
                {{ inbox.name }}
              </span>
              <span class="text-xs text-slate-400 truncate font-mono">
                {{ inbox.channel_type }}
              </span>
            </div>
          </div>
        </div>

        <div
          class="pt-3 border-t border-slate-800/60 flex items-center justify-between text-xs text-slate-400"
        >
          <span>{{ $t('OPERATIONS.CHANNEL_HEALTH.AUTO_ASSIGNMENT') }}</span>
          <span
            class="font-medium"
            :class="
              inbox.enable_auto_assignment
                ? 'text-emerald-400'
                : 'text-slate-500'
            "
          >
            {{
              inbox.enable_auto_assignment
                ? $t('OPERATIONS.CHANNEL_HEALTH.ENABLED')
                : $t('OPERATIONS.CHANNEL_HEALTH.DISABLED')
            }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
