<script setup>
import { computed, onMounted, ref } from 'vue';
import SummaryReportsAPI from 'dashboard/api/summaryReports';
import MetricCard from './overview/MetricCard.vue';
import {
  getInboxIconByType,
  getReadableInboxByType,
} from 'dashboard/helper/inbox';

const isLoading = ref(false);
const channelData = ref({});

const channelEntries = computed(() => {
  return Object.entries(channelData.value)
    .map(([channelType, stats]) => {
      const cleanType = channelType.replace(/^Channel::/, '');
      const readableName = getReadableInboxByType(channelType);
      const icon = getInboxIconByType(channelType, null, 'fill');

      return {
        channelType,
        cleanType,
        name: readableName.toUpperCase(),
        icon,
        open: stats.open || 0,
        resolved: stats.resolved || 0,
        pending: stats.pending || 0,
        total: stats.total || 0,
      };
    })
    .sort((a, b) => b.total - a.total);
});

const totalVolume = computed(() => {
  return channelEntries.value.reduce((sum, item) => sum + item.total, 0);
});

const fetchChannelData = async () => {
  isLoading.value = true;
  try {
    const response = await SummaryReportsAPI.getChannelReports();
    channelData.value = response.data || {};
  } catch (error) {
    channelData.value = {};
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchChannelData();
});
</script>

<template>
  <div class="flex flex-row flex-wrap max-w-full">
    <MetricCard
      :header="$t('OVERVIEW_REPORTS.CHANNEL_DISTRIBUTION.HEADER')"
      :is-loading="isLoading"
      :loading-message="
        $t('OVERVIEW_REPORTS.CHANNEL_DISTRIBUTION.LOADING_MESSAGE')
      "
    >
      <div v-if="channelEntries.length" class="flex flex-col gap-4 w-full">
        <div
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3"
        >
          <div
            v-for="channel in channelEntries"
            :key="channel.channelType"
            class="flex flex-col p-3 rounded-lg bg-n-solid-3 border border-n-strong"
          >
            <div class="flex items-center justify-between gap-2 mb-2">
              <div class="flex items-center gap-2 min-w-0">
                <i
                  class="text-base text-n-slate-11 shrink-0"
                  :class="[channel.icon]"
                />
                <span class="text-xs font-semibold text-n-slate-12 truncate">
                  {{ channel.name }}
                </span>
              </div>
              <span class="text-xs font-bold text-n-slate-12">
                {{ channel.total.toLocaleString() }}
              </span>
            </div>

            <!-- Volume Progress Bar -->
            <div
              class="w-full bg-n-slate-4 dark:bg-n-slate-6 rounded-full h-1.5 mb-2 overflow-hidden"
            >
              <div
                class="bg-n-brand h-1.5 rounded-full"
                :style="{
                  width:
                    totalVolume > 0
                      ? `${Math.min(100, Math.round((channel.total / totalVolume) * 100))}%`
                      : '0%',
                }"
              />
            </div>

            <!-- Status breakdown pills -->
            <div class="flex items-center gap-2 text-[11px] text-n-slate-11">
              <span class="flex items-center gap-1">
                <span class="size-1.5 rounded-full bg-n-amber-9" />
                <span>
                  {{ $t('OVERVIEW_REPORTS.CHANNEL_DISTRIBUTION.OPEN') }}
                  {{ channel.open }}
                </span>
              </span>
              <span class="flex items-center gap-1">
                <span class="size-1.5 rounded-full bg-n-teal-9" />
                <span>
                  {{ $t('OVERVIEW_REPORTS.CHANNEL_DISTRIBUTION.RESOLVED') }}
                  {{ channel.resolved }}
                </span>
              </span>
              <span v-if="channel.pending > 0" class="flex items-center gap-1">
                <span class="size-1.5 rounded-full bg-n-slate-9" />
                <span>
                  {{ $t('OVERVIEW_REPORTS.CHANNEL_DISTRIBUTION.PENDING') }}
                  {{ channel.pending }}
                </span>
              </span>
            </div>
          </div>
        </div>
      </div>
      <div v-else class="text-sm text-n-slate-11 py-4 text-center w-full">
        {{ $t('OVERVIEW_REPORTS.CHANNEL_DISTRIBUTION.NO_DATA') }}
      </div>
    </MetricCard>
  </div>
</template>
