<script setup>
import { computed } from 'vue';
import { formatTime } from '@chatwoot/utils';

const props = defineProps({
  reportMetrics: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['drilldown']);

const agentMap = computed(() => {
  const map = {};
  props.agents.forEach(agent => {
    map[agent.id] = agent.name || agent.title;
  });
  return map;
});

const rows = computed(() => {
  return props.reportMetrics.map(item => ({
    ...item,
    name: agentMap.value[item.id] || `Agent #${item.id}`,
  }));
});

// Aggregate calculations
const totalClosedChats = computed(() =>
  rows.value.reduce((sum, item) => sum + (item.closedCount || 0), 0)
);

const totalWorkload = computed(() =>
  rows.value.reduce((sum, item) => sum + (item.currentWorkload || 0), 0)
);

const avgFrt = computed(() => {
  const valid = rows.value.filter(item => item.avgFirstResponseTime != null);
  if (!valid.length) return null;
  return (
    valid.reduce((sum, item) => sum + item.avgFirstResponseTime, 0) /
    valid.length
  );
});

const avgReplyTime = computed(() => {
  const valid = rows.value.filter(item => item.avgReplyTime != null);
  if (!valid.length) return null;
  return valid.reduce((sum, item) => sum + item.avgReplyTime, 0) / valid.length;
});

const avgHandlingTime = computed(() => {
  const valid = rows.value.filter(item => {
    const val = item.avgHandlingTime?.average ?? item.avgResolutionTime;
    return val != null;
  });
  if (!valid.length) return null;
  const sum = valid.reduce((acc, item) => {
    const val = item.avgHandlingTime?.average ?? item.avgResolutionTime;
    return acc + val;
  }, 0);
  return sum / valid.length;
});

const avgCsat = computed(() => {
  const valid = rows.value.filter(item => item.csatScore != null);
  if (!valid.length) return null;
  return valid.reduce((sum, item) => sum + item.csatScore, 0) / valid.length;
});

// Top distributions for charts
const closedPerAgent = computed(() =>
  [...rows.value]
    .filter(item => (item.closedCount || 0) > 0)
    .sort((a, b) => (b.closedCount || 0) - (a.closedCount || 0))
    .slice(0, 5)
);

const workloadPerAgent = computed(() =>
  [...rows.value]
    .filter(item => (item.currentWorkload || 0) > 0)
    .sort((a, b) => (b.currentWorkload || 0) - (a.currentWorkload || 0))
    .slice(0, 5)
);

const frtPerAgent = computed(() =>
  [...rows.value]
    .filter(item => item.avgFirstResponseTime != null)
    .sort((a, b) => a.avgFirstResponseTime - b.avgFirstResponseTime)
    .slice(0, 5)
);

const replyPerAgent = computed(() =>
  [...rows.value]
    .filter(item => item.avgReplyTime != null)
    .sort((a, b) => a.avgReplyTime - b.avgReplyTime)
    .slice(0, 5)
);

const handlingPerAgent = computed(() =>
  [...rows.value]
    .filter(
      item => (item.avgHandlingTime?.average ?? item.avgResolutionTime) != null
    )
    .sort(
      (a, b) =>
        (a.avgHandlingTime?.average ?? a.avgResolutionTime) -
        (b.avgHandlingTime?.average ?? b.avgResolutionTime)
    )
    .slice(0, 5)
);

const csatPerAgent = computed(() =>
  [...rows.value]
    .filter(item => item.csatScore != null)
    .sort((a, b) => b.csatScore - a.csatScore)
    .slice(0, 5)
);

const onCardClick = (
  metric,
  metricName,
  bucketValue,
  isAverageMetric,
  agentId = null,
  agentName = null
) => {
  emit('drilldown', {
    metric,
    metricName,
    bucketValue,
    isAverageMetric,
    agentId,
    agentName,
  });
};
</script>

<template>
  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <!-- 1. First Response Time -->
    <div
      class="flex flex-col justify-between p-4 transition-all border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 border-n-container hover:border-n-brand/50 group"
      @click="
        onCardClick(
          'avg_first_response_time',
          $t('SUMMARY_REPORTS.CHARTS.FIRST_RESPONSE_TIME'),
          avgFrt,
          true
        )
      "
    >
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.FIRST_RESPONSE_TIME') }}
        </span>
        <span
          class="text-xs transition-opacity opacity-0 text-n-brand group-hover:opacity-100"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLICK_TO_DRILLDOWN') }}
        </span>
      </div>
      <div class="mt-2 text-2xl font-bold text-n-slate-12">
        {{ avgFrt != null ? formatTime(avgFrt) : '--' }}
      </div>
      <div
        class="flex flex-col gap-1.5 mt-3 pt-3 border-t border-n-container/50"
      >
        <div
          v-for="agent in frtPerAgent"
          :key="agent.id"
          class="flex items-center justify-between text-xs"
          @click.stop="
            onCardClick(
              'avg_first_response_time',
              `${$t('SUMMARY_REPORTS.CHARTS.FIRST_RESPONSE_TIME')} - ${agent.name}`,
              agent.avgFirstResponseTime,
              true,
              agent.id,
              agent.name
            )
          "
        >
          <span
            class="truncate max-w-[120px] text-n-slate-11 hover:text-n-brand font-medium"
          >
            {{ agent.name }}
          </span>
          <span class="font-medium text-n-slate-12">
            {{ formatTime(agent.avgFirstResponseTime) }}
          </span>
        </div>
        <div v-if="!frtPerAgent.length" class="text-xs text-n-slate-10 italic">
          {{ $t('SUMMARY_REPORTS.CHARTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- 2. Average Response Time -->
    <div
      class="flex flex-col justify-between p-4 transition-all border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 border-n-container hover:border-n-brand/50 group"
      @click="
        onCardClick(
          'reply_time',
          $t('SUMMARY_REPORTS.CHARTS.AVERAGE_RESPONSE_TIME'),
          avgReplyTime,
          true
        )
      "
    >
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.AVERAGE_RESPONSE_TIME') }}
        </span>
        <span
          class="text-xs transition-opacity opacity-0 text-n-brand group-hover:opacity-100"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLICK_TO_DRILLDOWN') }}
        </span>
      </div>
      <div class="mt-2 text-2xl font-bold text-n-slate-12">
        {{ avgReplyTime != null ? formatTime(avgReplyTime) : '--' }}
      </div>
      <div
        class="flex flex-col gap-1.5 mt-3 pt-3 border-t border-n-container/50"
      >
        <div
          v-for="agent in replyPerAgent"
          :key="agent.id"
          class="flex items-center justify-between text-xs"
          @click.stop="
            onCardClick(
              'reply_time',
              `${$t('SUMMARY_REPORTS.CHARTS.AVERAGE_RESPONSE_TIME')} - ${agent.name}`,
              agent.avgReplyTime,
              true,
              agent.id,
              agent.name
            )
          "
        >
          <span
            class="truncate max-w-[120px] text-n-slate-11 hover:text-n-brand font-medium"
          >
            {{ agent.name }}
          </span>
          <span class="font-medium text-n-slate-12">
            {{ formatTime(agent.avgReplyTime) }}
          </span>
        </div>
        <div
          v-if="!replyPerAgent.length"
          class="text-xs text-n-slate-10 italic"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- 3. Handling Time -->
    <div
      class="flex flex-col justify-between p-4 transition-all border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 border-n-container hover:border-n-brand/50 group"
      @click="
        onCardClick(
          'avg_resolution_time',
          $t('SUMMARY_REPORTS.CHARTS.HANDLING_TIME'),
          avgHandlingTime,
          true
        )
      "
    >
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.HANDLING_TIME') }}
        </span>
        <span
          class="text-xs transition-opacity opacity-0 text-n-brand group-hover:opacity-100"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLICK_TO_DRILLDOWN') }}
        </span>
      </div>
      <div class="mt-2 text-2xl font-bold text-n-slate-12">
        {{ avgHandlingTime != null ? formatTime(avgHandlingTime) : '--' }}
      </div>
      <div
        class="flex flex-col gap-1.5 mt-3 pt-3 border-t border-n-container/50"
      >
        <div
          v-for="agent in handlingPerAgent"
          :key="agent.id"
          class="flex items-center justify-between text-xs"
          @click.stop="
            onCardClick(
              'avg_resolution_time',
              `${$t('SUMMARY_REPORTS.CHARTS.HANDLING_TIME')} - ${agent.name}`,
              agent.avgHandlingTime?.average ?? agent.avgResolutionTime,
              true,
              agent.id,
              agent.name
            )
          "
        >
          <span
            class="truncate max-w-[120px] text-n-slate-11 hover:text-n-brand font-medium"
          >
            {{ agent.name }}
          </span>
          <span class="font-medium text-n-slate-12">
            {{
              formatTime(
                agent.avgHandlingTime?.average ?? agent.avgResolutionTime
              )
            }}
          </span>
        </div>
        <div
          v-if="!handlingPerAgent.length"
          class="text-xs text-n-slate-10 italic"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- 4. Closed Chats -->
    <div
      class="flex flex-col justify-between p-4 transition-all border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 border-n-container hover:border-n-brand/50 group"
      @click="
        onCardClick(
          'resolutions_count',
          $t('SUMMARY_REPORTS.CHARTS.CLOSED_CHATS'),
          totalClosedChats,
          false
        )
      "
    >
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLOSED_CHATS') }}
        </span>
        <span
          class="text-xs transition-opacity opacity-0 text-n-brand group-hover:opacity-100"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLICK_TO_DRILLDOWN') }}
        </span>
      </div>
      <div class="mt-2 text-2xl font-bold text-n-slate-12">
        {{ totalClosedChats.toLocaleString() }}
      </div>
      <div
        class="flex flex-col gap-1.5 mt-3 pt-3 border-t border-n-container/50"
      >
        <div
          v-for="agent in closedPerAgent"
          :key="agent.id"
          class="flex items-center justify-between text-xs"
          @click.stop="
            onCardClick(
              'resolutions_count',
              `${$t('SUMMARY_REPORTS.CHARTS.CLOSED_CHATS')} - ${agent.name}`,
              agent.closedCount,
              false,
              agent.id,
              agent.name
            )
          "
        >
          <span
            class="truncate max-w-[120px] text-n-slate-11 hover:text-n-brand font-medium"
          >
            {{ agent.name }}
          </span>
          <div class="flex items-center gap-2">
            <div class="w-16 h-1.5 rounded-full bg-n-alpha-2 overflow-hidden">
              <div
                class="h-full bg-n-brand rounded-full"
                :style="{
                  width: `${Math.min(100, Math.round((agent.closedCount / (totalClosedChats || 1)) * 100))}%`,
                }"
              />
            </div>
            <span class="font-medium text-n-slate-12 w-6 text-right">
              {{ agent.closedCount }}
            </span>
          </div>
        </div>
        <div
          v-if="!closedPerAgent.length"
          class="text-xs text-n-slate-10 italic"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- 5. Agent Workload -->
    <div
      class="flex flex-col justify-between p-4 transition-all border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 border-n-container hover:border-n-brand/50 group"
      @click="
        onCardClick(
          'conversations_count',
          $t('SUMMARY_REPORTS.CHARTS.AGENT_WORKLOAD'),
          totalWorkload,
          false
        )
      "
    >
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.AGENT_WORKLOAD') }}
        </span>
        <span
          class="text-xs transition-opacity opacity-0 text-n-brand group-hover:opacity-100"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLICK_TO_DRILLDOWN') }}
        </span>
      </div>
      <div class="mt-2 text-2xl font-bold text-n-slate-12">
        {{ totalWorkload.toLocaleString() }}
      </div>
      <div
        class="flex flex-col gap-1.5 mt-3 pt-3 border-t border-n-container/50"
      >
        <div
          v-for="agent in workloadPerAgent"
          :key="agent.id"
          class="flex items-center justify-between text-xs"
          @click.stop="
            onCardClick(
              'conversations_count',
              `${$t('SUMMARY_REPORTS.CHARTS.AGENT_WORKLOAD')} - ${agent.name}`,
              agent.currentWorkload,
              false,
              agent.id,
              agent.name
            )
          "
        >
          <span
            class="truncate max-w-[120px] text-n-slate-11 hover:text-n-brand font-medium"
          >
            {{ agent.name }}
          </span>
          <div class="flex items-center gap-2">
            <div class="w-16 h-1.5 rounded-full bg-n-alpha-2 overflow-hidden">
              <div
                class="h-full bg-n-teal-9 rounded-full"
                :style="{
                  width: `${Math.min(100, Math.round((agent.currentWorkload / (totalWorkload || 1)) * 100))}%`,
                }"
              />
            </div>
            <span class="font-medium text-n-slate-12 w-6 text-right">
              {{ agent.currentWorkload }}
            </span>
          </div>
        </div>
        <div
          v-if="!workloadPerAgent.length"
          class="text-xs text-n-slate-10 italic"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- 6. CSAT -->
    <div
      class="flex flex-col justify-between p-4 transition-all border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 border-n-container hover:border-n-brand/50 group"
      @click="
        onCardClick(
          'conversations_count',
          $t('SUMMARY_REPORTS.CHARTS.CSAT'),
          avgCsat,
          false
        )
      "
    >
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CSAT') }}
        </span>
        <span
          class="text-xs transition-opacity opacity-0 text-n-brand group-hover:opacity-100"
        >
          {{ $t('SUMMARY_REPORTS.CHARTS.CLICK_TO_DRILLDOWN') }}
        </span>
      </div>
      <div class="mt-2 text-2xl font-bold text-n-slate-12">
        {{ avgCsat != null ? `${avgCsat.toFixed(1)}%` : '--' }}
      </div>
      <div
        class="flex flex-col gap-1.5 mt-3 pt-3 border-t border-n-container/50"
      >
        <div
          v-for="agent in csatPerAgent"
          :key="agent.id"
          class="flex items-center justify-between text-xs"
          @click.stop="
            onCardClick(
              'conversations_count',
              `${$t('SUMMARY_REPORTS.CHARTS.CSAT')} - ${agent.name}`,
              agent.csatScore,
              false,
              agent.id,
              agent.name
            )
          "
        >
          <span
            class="truncate max-w-[120px] text-n-slate-11 hover:text-n-brand font-medium"
          >
            {{ agent.name }}
          </span>
          <span class="font-medium text-n-slate-12">
            {{ agent.csatScore }}%
          </span>
        </div>
        <div v-if="!csatPerAgent.length" class="text-xs text-n-slate-10 italic">
          {{ $t('SUMMARY_REPORTS.CHARTS.NO_DATA') }}
        </div>
      </div>
    </div>
  </div>
</template>
