<script setup>
import { computed, onMounted, ref } from 'vue';
import { OVERVIEW_METRICS } from '../constants';
import { useToggle } from '@vueuse/core';
import { formatTime } from '@chatwoot/utils';

import MetricCard from './overview/MetricCard.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';
const { t } = useI18n();

const uiFlags = useMapGetter('getOverviewUIFlags');
const agentStatus = useMapGetter('agents/getAgentStatus');
const accountConversationMetric = useMapGetter('getAccountConversationMetric');
const store = useStore();

const accounti18nKey = 'OVERVIEW_REPORTS.ACCOUNT_CONVERSATIONS';
const teams = useMapGetter('teams/getTeams');

const teamMenuList = computed(() => {
  return [
    { label: t('OVERVIEW_REPORTS.TEAM_CONVERSATIONS.ALL_TEAMS'), value: null },
    ...teams.value.map(team => ({ label: team.name, value: team.id })),
  ];
});

const agentStatusMetrics = computed(() => {
  let metric = {};
  Object.keys(agentStatus.value).forEach(key => {
    const metricName = t(
      `OVERVIEW_REPORTS.AGENT_STATUS.${OVERVIEW_METRICS[key]}`
    );
    metric[metricName] = agentStatus.value[key];
  });
  return metric;
});

const conversationMetrics = computed(() => {
  const metric = {};
  const data = accountConversationMetric.value || {};

  const keys = [
    'total',
    'open',
    'pending',
    'resolved',
    'unassigned',
    'avg_first_response_time',
    'avg_resolution_time',
    'csat',
  ];

  keys.forEach(key => {
    if (data[key] !== undefined && data[key] !== null) {
      const metricName = t(`${accounti18nKey}.${OVERVIEW_METRICS[key]}`);
      if (['avg_first_response_time', 'avg_resolution_time'].includes(key)) {
        metric[metricName] = data[key] ? formatTime(data[key]) : '--';
      } else if (key === 'csat') {
        metric[metricName] = data[key] != null ? `${data[key]}%` : '--';
      } else {
        metric[metricName] = data[key]?.toLocaleString() ?? '0';
      }
    }
  });

  if (Object.keys(metric).length === 0) {
    Object.keys(data).forEach(key => {
      if (OVERVIEW_METRICS[key]) {
        const metricName = t(`${accounti18nKey}.${OVERVIEW_METRICS[key]}`);
        metric[metricName] = data[key];
      }
    });
  }

  return metric;
});

const selectedTeam = ref(null);
const selectedTeamLabel = computed(() => {
  const team =
    teamMenuList.value.find(
      menuItem => menuItem.value === selectedTeam.value
    ) || {};
  return team.label;
});
const fetchData = () => {
  const params = {};
  if (selectedTeam.value) {
    params.team_id = selectedTeam.value;
  }
  store.dispatch('fetchAccountConversationMetric', params);
};

const { startRefetching } = useLiveRefresh(fetchData);
const [showDropdown, toggleDropdown] = useToggle();

const handleAction = ({ value }) => {
  toggleDropdown(false);
  selectedTeam.value = value;
  fetchData();
};

onMounted(() => {
  fetchData();
  startRefetching();
});
</script>

<template>
  <div class="flex flex-col items-center md:flex-row gap-4">
    <div
      class="flex-1 w-full max-w-full md:w-[70%] md:max-w-[70%] conversation-metric"
    >
      <MetricCard
        :header="t(`${accounti18nKey}.HEADER`)"
        :is-loading="uiFlags.isFetchingAccountConversationMetric"
        :loading-message="t(`${accounti18nKey}.LOADING_MESSAGE`)"
      >
        <template v-if="teams.length" #control>
          <div
            v-on-clickaway="() => toggleDropdown(false)"
            class="relative flex items-center group z-50"
          >
            <Button
              sm
              slate
              faded
              :label="selectedTeamLabel"
              class="capitalize rounded-md group-hover:bg-n-alpha-2"
              @click="toggleDropdown()"
            />
            <DropdownMenu
              v-if="showDropdown"
              :menu-items="teamMenuList"
              class="mt-1 ltr:right-0 rtl:left-0 xl:ltr:right-0 xl:rtl:left-0 top-full"
              label-class="capitalize"
              @action="handleAction($event)"
            />
          </div>
        </template>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 w-full">
          <div
            v-for="(metric, name, index) in conversationMetrics"
            :key="index"
            class="flex-1 min-w-[100px] pb-2"
          >
            <h3 class="text-xs font-medium text-n-slate-11 truncate">
              {{ name }}
            </h3>
            <p class="text-n-slate-12 text-2xl font-semibold mb-0 mt-1">
              {{ metric }}
            </p>
          </div>
        </div>
      </MetricCard>
    </div>
    <div class="flex-1 w-full max-w-full md:w-[30%] md:max-w-[30%]">
      <MetricCard :header="$t('OVERVIEW_REPORTS.AGENT_STATUS.HEADER')">
        <div class="grid grid-cols-3 gap-3 w-full">
          <div
            v-for="(metric, name, index) in agentStatusMetrics"
            :key="index"
            class="flex-1 min-w-[50px] pb-2"
          >
            <h3 class="text-xs font-medium text-n-slate-11 truncate">
              {{ name }}
            </h3>
            <p class="text-n-slate-12 text-2xl font-semibold mb-0 mt-1">
              {{ metric }}
            </p>
          </div>
        </div>
      </MetricCard>
    </div>
  </div>
</template>
