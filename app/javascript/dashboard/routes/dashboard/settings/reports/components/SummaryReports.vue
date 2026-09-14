<script setup>
import OverviewReportFilters from './OverviewReportFilters.vue';
import AgentReportFilterBar from './AgentReportFilterBar.vue';
import AgentReportsCharts from './AgentReportsCharts.vue';
import ReportDrilldownDrawer from './ReportDrilldownDrawer.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatTime } from '@chatwoot/utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { usePolicy } from 'dashboard/composables/usePolicy';
import Table from 'dashboard/components/table/Table.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';
import { computed, onMounted, ref, h } from 'vue';
import { useI18n } from 'vue-i18n';
import SummaryReportLink from './SummaryReportLink.vue';

const props = defineProps({
  type: {
    type: String,
    default: 'account',
  },
  getterKey: {
    type: String,
    default: '',
  },
  actionKey: {
    type: String,
    default: '',
  },
  summaryKey: {
    type: String,
    default: '',
  },
  fetchItemsKey: {
    type: String,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();
const { checkPermissions } = usePolicy();

const from = ref(0);
const to = ref(0);
const businessHours = ref(false);
const activeFilters = ref({});

const activeView = ref('agent_overview');
const TIMING_AGGREGATES = ['average', 'median', 'p90'];
const selectedAggregate = ref('average');

const drilldownRequest = ref(null);

const handleDrilldown = drilldownData => {
  drilldownRequest.value = {
    metric: drilldownData.metric,
    metricName: drilldownData.metricName,
    bucketValue: drilldownData.bucketValue,
    isAverageMetric: drilldownData.isAverageMetric,
    bucketLabel:
      drilldownData.agentName ||
      (from.value
        ? `${new Date(from.value * 1000).toLocaleDateString()} - ${new Date(to.value * 1000).toLocaleDateString()}`
        : ''),
    from: from.value,
    to: to.value,
    type: drilldownData.agentId ? 'agent' : 'account',
    id: drilldownData.agentId || null,
    groupBy: 'day',
    businessHours: businessHours.value,
  };
};

const closeDrilldown = () => {
  drilldownRequest.value = null;
};

const flagMap = {
  agent: 'isFetchingAgentSummaryReports',
  inbox: 'isFetchingInboxSummaryReports',
  team: 'isFetchingTeamSummaryReports',
  label: 'isFetchingLabelSummaryReports',
};

const uiFlags = useMapGetter('summaryReports/getUIFlags');
const isLoading = computed(() => uiFlags.value[flagMap[props.type]] ?? false);

const rowItems = useMapGetter([props.getterKey]) || [];
const reportMetrics = useMapGetter([props.summaryKey]) || [];

const canViewReports = computed(() =>
  checkPermissions(['administrator', 'report_manage'])
);

const getMetrics = id =>
  reportMetrics.value.find(metrics => metrics.id === Number(id)) || {};

const columnHelper = createColumnHelper();

const defaulSpanRender = cellProps =>
  h(
    'span',
    {
      class: cellProps.getValue() ? '' : 'text-n-slate-12',
    },
    cellProps.getValue()
  );

const clickableCellRender =
  (metricKey, metricName, isAverage = false) =>
  cellProps => {
    const value = cellProps.getValue();
    const row = cellProps.row.original;
    if (value === '--' || value === undefined || value === null) {
      return h('span', { class: 'text-n-slate-12' }, value ?? '--');
    }
    return h(
      'button',
      {
        type: 'button',
        class:
          'hover:text-n-brand hover:underline font-medium text-left cursor-pointer transition-colors',
        onClick: () =>
          handleDrilldown({
            metric: metricKey,
            metricName: `${metricName} - ${row.name}`,
            bucketValue: typeof value === 'number' ? value : null,
            isAverageMetric: isAverage,
            agentId: row.id,
            agentName: row.name,
          }),
      },
      value
    );
  };

const comparisonCellRender = cellProps => {
  const value = cellProps.getValue();
  if (!value || typeof value !== 'object') {
    return h('span', { class: 'text-n-slate-12' }, value ?? '--');
  }

  return h('div', { class: 'flex flex-col' }, [
    h('span', { class: 'font-medium text-n-slate-12' }, value.agent ?? '--'),
    h(
      'span',
      { class: 'text-[11px] text-n-slate-11' },
      `${t('SUMMARY_REPORTS.COMPARISON.TEAM')}: ${value.team ?? '--'}`
    ),
  ]);
};

const renderAvgTime = value => (value ? formatTime(value) : '--');

const renderTiming = timing =>
  renderAvgTime(timing?.[selectedAggregate.value] ?? null);

const renderCount = value =>
  value !== undefined && value !== null ? value.toLocaleString() : '--';

const renderRate = (value, unit = '') =>
  value !== undefined && value !== null
    ? `${Number(value).toFixed(1)}${unit}`
    : '--';

const agentOverviewColumns = computed(() => [
  columnHelper.accessor('name', {
    header: t('SUMMARY_REPORTS.AGENT'),
    width: 250,
    cell: cellProps => h(SummaryReportLink, cellProps),
  }),
  columnHelper.accessor('conversationsCount', {
    header: t('SUMMARY_REPORTS.ASSIGNED'),
    width: 120,
    cell: clickableCellRender(
      'conversations_count',
      t('SUMMARY_REPORTS.ASSIGNED')
    ),
  }),
  columnHelper.accessor('repliedCount', {
    header: t('SUMMARY_REPORTS.REPLIED'),
    width: 120,
    cell: clickableCellRender(
      'avg_first_response_time',
      t('SUMMARY_REPORTS.REPLIED'),
      true
    ),
  }),
  columnHelper.accessor('openCount', {
    header: t('SUMMARY_REPORTS.OPEN'),
    width: 100,
    cell: clickableCellRender('conversations_count', t('SUMMARY_REPORTS.OPEN')),
  }),
  columnHelper.accessor('pendingCount', {
    header: t('SUMMARY_REPORTS.PENDING'),
    width: 100,
    cell: clickableCellRender(
      'conversations_count',
      t('SUMMARY_REPORTS.PENDING')
    ),
  }),
  columnHelper.accessor('closedCount', {
    header: t('SUMMARY_REPORTS.CLOSED'),
    width: 100,
    cell: clickableCellRender('resolutions_count', t('SUMMARY_REPORTS.CLOSED')),
  }),
  columnHelper.accessor('reopenedCount', {
    header: t('SUMMARY_REPORTS.REOPENED'),
    width: 110,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('currentWorkload', {
    header: t('SUMMARY_REPORTS.WORKLOAD'),
    width: 120,
    cell: clickableCellRender(
      'conversations_count',
      t('SUMMARY_REPORTS.WORKLOAD')
    ),
  }),
  columnHelper.accessor('messagesSent', {
    header: t('SUMMARY_REPORTS.MESSAGES_SENT'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('internalNotes', {
    header: t('SUMMARY_REPORTS.INTERNAL_NOTES'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('transfers', {
    header: t('SUMMARY_REPORTS.TRANSFERS'),
    width: 110,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('reassignments', {
    header: t('SUMMARY_REPORTS.REASSIGNMENTS'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('activeHours', {
    header: t('SUMMARY_REPORTS.ACTIVE_HOURS'),
    width: 120,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('chatsPerActiveHour', {
    header: t('SUMMARY_REPORTS.CHATS_PER_ACTIVE_HOUR'),
    width: 150,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('closedChatsPerActiveHour', {
    header: t('SUMMARY_REPORTS.CLOSED_CHATS_PER_ACTIVE_HOUR'),
    width: 150,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('csatScore', {
    header: t('SUMMARY_REPORTS.CSAT'),
    width: 120,
    cell: clickableCellRender('conversations_count', t('SUMMARY_REPORTS.CSAT')),
  }),
  columnHelper.accessor('positiveRatings', {
    header: t('SUMMARY_REPORTS.POSITIVE_RATINGS'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('negativeRatings', {
    header: t('SUMMARY_REPORTS.NEGATIVE_RATINGS'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('reopenRate', {
    header: t('SUMMARY_REPORTS.REOPEN_RATE'),
    width: 120,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('fcrRate', {
    header: t('SUMMARY_REPORTS.FCR'),
    width: 120,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('slaMet', {
    header: t('SUMMARY_REPORTS.SLA_MET'),
    width: 110,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('slaMissed', {
    header: t('SUMMARY_REPORTS.SLA_MISSED'),
    width: 110,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('queueWaitingTime', {
    header: t('SUMMARY_REPORTS.QUEUE_WAITING_TIME'),
    width: 170,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('firstCustomerResponseTime', {
    header: t('SUMMARY_REPORTS.FIRST_CUSTOMER_RESPONSE_TIME'),
    width: 190,
    cell: clickableCellRender(
      'avg_first_response_time',
      t('SUMMARY_REPORTS.FIRST_CUSTOMER_RESPONSE_TIME'),
      true
    ),
  }),
  columnHelper.accessor('assignmentFirstResponseTime', {
    header: t('SUMMARY_REPORTS.ASSIGNMENT_FIRST_RESPONSE_TIME'),
    width: 210,
    cell: clickableCellRender(
      'avg_first_response_time',
      t('SUMMARY_REPORTS.ASSIGNMENT_FIRST_RESPONSE_TIME'),
      true
    ),
  }),
  columnHelper.accessor('avgHandlingTime', {
    header: t('SUMMARY_REPORTS.AVG_HANDLING_TIME'),
    width: 170,
    cell: clickableCellRender(
      'avg_resolution_time',
      t('SUMMARY_REPORTS.AVG_HANDLING_TIME'),
      true
    ),
  }),
  columnHelper.accessor('activeHandlingTime', {
    header: t('SUMMARY_REPORTS.ACTIVE_HANDLING_TIME'),
    width: 180,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('responseTime', {
    header: t('SUMMARY_REPORTS.RESPONSE_TIME'),
    width: 160,
    cell: clickableCellRender(
      'reply_time',
      t('SUMMARY_REPORTS.RESPONSE_TIME'),
      true
    ),
  }),
  columnHelper.accessor('resolutionTime', {
    header: t('SUMMARY_REPORTS.RESOLUTION_TIME'),
    width: 160,
    cell: clickableCellRender(
      'avg_resolution_time',
      t('SUMMARY_REPORTS.RESOLUTION_TIME'),
      true
    ),
  }),
  columnHelper.accessor('chatDuration', {
    header: t('SUMMARY_REPORTS.CHAT_DURATION'),
    width: 160,
    cell: defaulSpanRender,
  }),
]);

const agentComparisonColumns = computed(() => [
  columnHelper.accessor('name', {
    header: t('SUMMARY_REPORTS.COMPARISON.AGENT'),
    width: 220,
    cell: cellProps => h(SummaryReportLink, cellProps),
  }),
  columnHelper.accessor('comparisonAssigned', {
    header: t('SUMMARY_REPORTS.COMPARISON.ASSIGNED_VS_TEAM'),
    width: 190,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonClosed', {
    header: t('SUMMARY_REPORTS.COMPARISON.CLOSED_VS_TEAM'),
    width: 190,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonCsat', {
    header: t('SUMMARY_REPORTS.COMPARISON.CSAT_VS_TEAM'),
    width: 180,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonFcr', {
    header: t('SUMMARY_REPORTS.COMPARISON.FCR_VS_TEAM'),
    width: 180,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonReopenRate', {
    header: t('SUMMARY_REPORTS.COMPARISON.REOPEN_RATE_VS_TEAM'),
    width: 190,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonFrt', {
    header: t('SUMMARY_REPORTS.COMPARISON.FRT_VS_TEAM'),
    width: 190,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonArt', {
    header: t('SUMMARY_REPORTS.COMPARISON.ART_VS_TEAM'),
    width: 190,
    cell: comparisonCellRender,
  }),
  columnHelper.accessor('comparisonActiveHours', {
    header: t('SUMMARY_REPORTS.COMPARISON.ACTIVE_HOURS_VS_TEAM'),
    width: 190,
    cell: comparisonCellRender,
  }),
]);

const teamColumns = computed(() => [
  columnHelper.accessor('name', {
    header: t('SUMMARY_REPORTS.TEAM'),
    width: 250,
    cell: cellProps => h(SummaryReportLink, cellProps),
  }),
  columnHelper.accessor('conversationsCount', {
    header: t('SUMMARY_REPORTS.HANDLED'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('resolutionsCount', {
    header: t('SUMMARY_REPORTS.RESOLVED'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('backlogCount', {
    header: t('SUMMARY_REPORTS.BACKLOG'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgFirstResponseTime', {
    header: t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME'),
    width: 160,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgResolutionTime', {
    header: t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME'),
    width: 160,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('reopenRate', {
    header: t('SUMMARY_REPORTS.REOPEN_RATE'),
    width: 130,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('csatScore', {
    header: t('SUMMARY_REPORTS.CSAT'),
    width: 120,
    cell: defaulSpanRender,
  }),
]);

const defaultColumns = computed(() => [
  columnHelper.accessor('name', {
    header: t(`SUMMARY_REPORTS.${props.type.toUpperCase()}`),
    width: 300,
    cell: cellProps => h(SummaryReportLink, cellProps),
  }),
  columnHelper.accessor('conversationsCount', {
    header: t('SUMMARY_REPORTS.CONVERSATIONS'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgFirstResponseTime', {
    header: t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgResolutionTime', {
    header: t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('avgReplyTime', {
    header: t('SUMMARY_REPORTS.AVG_REPLY_TIME'),
    width: 200,
    cell: defaulSpanRender,
  }),
  columnHelper.accessor('resolutionsCount', {
    header: t('SUMMARY_REPORTS.RESOLUTION_COUNT'),
    width: 200,
    cell: defaulSpanRender,
  }),
]);

const columns = computed(() => {
  if (props.type === 'agent') {
    return activeView.value === 'agent_vs_team'
      ? agentComparisonColumns.value
      : agentOverviewColumns.value;
  }
  if (props.type === 'team') {
    return teamColumns.value;
  }
  return defaultColumns.value;
});

const teamBenchmarkAverages = computed(() => {
  const metrics = reportMetrics.value;
  if (!metrics || metrics.length === 0) return {};

  const numAgents = metrics.length;
  const sumAssigned = metrics.reduce(
    (acc, m) => acc + (m.conversationsCount || 0),
    0
  );
  const sumClosed = metrics.reduce((acc, m) => acc + (m.closedCount || 0), 0);

  const csatItems = metrics.filter(m => m.csatScore != null);
  const avgCsat = csatItems.length
    ? csatItems.reduce((acc, m) => acc + m.csatScore, 0) / csatItems.length
    : null;

  const fcrItems = metrics.filter(m => m.fcrRate != null);
  const avgFcr = fcrItems.length
    ? fcrItems.reduce((acc, m) => acc + m.fcrRate, 0) / fcrItems.length
    : null;

  const reopenItems = metrics.filter(m => m.reopenRate != null);
  const avgReopen = reopenItems.length
    ? reopenItems.reduce((acc, m) => acc + m.reopenRate, 0) / reopenItems.length
    : null;

  const frtItems = metrics.filter(m => m.avgFirstResponseTime != null);
  const avgFrt = frtItems.length
    ? frtItems.reduce((acc, m) => acc + m.avgFirstResponseTime, 0) /
      frtItems.length
    : null;

  const artItems = metrics.filter(m => m.avgResolutionTime != null);
  const avgArt = artItems.length
    ? artItems.reduce((acc, m) => acc + m.avgResolutionTime, 0) /
      artItems.length
    : null;

  const hoursItems = metrics.filter(m => m.activeHours != null);
  const avgHours = hoursItems.length
    ? hoursItems.reduce((acc, m) => acc + m.activeHours, 0) / hoursItems.length
    : null;

  return {
    assigned: (sumAssigned / numAgents).toFixed(1),
    closed: (sumClosed / numAgents).toFixed(1),
    csat: avgCsat != null ? `${avgCsat.toFixed(1)}%` : '--',
    fcr: avgFcr != null ? `${avgFcr.toFixed(1)}%` : '--',
    reopenRate: avgReopen != null ? `${avgReopen.toFixed(1)}%` : '--',
    frt: renderAvgTime(avgFrt),
    art: renderAvgTime(avgArt),
    activeHours: avgHours != null ? `${avgHours.toFixed(1)}h` : '--',
  };
});

const tableData = computed(() =>
  rowItems.value.map(row => {
    const rowMetrics = getMetrics(row.id);
    const {
      conversationsCount,
      repliedCount,
      openCount,
      pendingCount,
      closedCount,
      reopenedCount,
      avgFirstResponseTime,
      avgResolutionTime,
      avgReplyTime,
      resolvedConversationsCount,
      currentWorkload,
      messagesSent,
      internalNotes,
      transfers,
      reassignments,
      activeHours,
      chatsPerActiveHour,
      closedChatsPerActiveHour,
      positiveRatings,
      negativeRatings,
      reopenRate,
      fcrRate,
      slaMet,
      slaMissed,
      backlogCount,
      csatScore,
      firstCustomerResponseTime,
      assignmentFirstResponseTime,
      avgHandlingTime,
      activeHandlingTime,
      queueWaitingTime,
      responseTime,
      resolutionTime,
      chatDuration,
    } = rowMetrics;

    const teamBench = teamBenchmarkAverages.value;

    return {
      id: row.id,
      name: row.name ?? row.title,
      type: props.type,
      conversationsCount: renderCount(conversationsCount),
      repliedCount: renderCount(repliedCount),
      openCount: renderCount(openCount),
      pendingCount: renderCount(pendingCount),
      closedCount: renderCount(closedCount),
      reopenedCount: renderCount(reopenedCount),
      currentWorkload: renderCount(currentWorkload),
      messagesSent: renderCount(messagesSent),
      internalNotes: renderCount(internalNotes),
      transfers: renderCount(transfers),
      reassignments: renderCount(reassignments),
      activeHours: renderRate(activeHours, 'h'),
      chatsPerActiveHour: renderRate(chatsPerActiveHour),
      closedChatsPerActiveHour: renderRate(closedChatsPerActiveHour),
      positiveRatings: renderCount(positiveRatings),
      negativeRatings: renderCount(negativeRatings),
      reopenRate: renderRate(reopenRate, '%'),
      fcrRate: renderRate(fcrRate, '%'),
      slaMet: renderCount(slaMet),
      slaMissed: renderCount(slaMissed),
      backlogCount: renderCount(backlogCount),
      avgFirstResponseTime: renderAvgTime(avgFirstResponseTime),
      avgReplyTime: renderAvgTime(avgReplyTime),
      avgResolutionTime: renderAvgTime(avgResolutionTime),
      resolutionsCount: renderCount(resolvedConversationsCount),
      csatScore: csatScore != null ? `${csatScore}%` : '--',
      queueWaitingTime: renderTiming(queueWaitingTime),
      firstCustomerResponseTime: renderTiming(firstCustomerResponseTime),
      assignmentFirstResponseTime: renderTiming(assignmentFirstResponseTime),
      avgHandlingTime: renderTiming(avgHandlingTime),
      activeHandlingTime: renderTiming(activeHandlingTime),
      responseTime: renderTiming(responseTime),
      resolutionTime: renderTiming(resolutionTime),
      chatDuration: renderTiming(chatDuration),

      comparisonAssigned: {
        agent: renderCount(conversationsCount),
        team: teamBench.assigned ?? '--',
      },
      comparisonClosed: {
        agent: renderCount(closedCount),
        team: teamBench.closed ?? '--',
      },
      comparisonCsat: {
        agent: csatScore != null ? `${csatScore}%` : '--',
        team: teamBench.csat ?? '--',
      },
      comparisonFcr: {
        agent: renderRate(fcrRate, '%'),
        team: teamBench.fcr ?? '--',
      },
      comparisonReopenRate: {
        agent: renderRate(reopenRate, '%'),
        team: teamBench.reopenRate ?? '--',
      },
      comparisonFrt: {
        agent: renderAvgTime(avgFirstResponseTime),
        team: teamBench.frt ?? '--',
      },
      comparisonArt: {
        agent: renderAvgTime(avgResolutionTime),
        team: teamBench.art ?? '--',
      },
      comparisonActiveHours: {
        agent: renderRate(activeHours, 'h'),
        team: teamBench.activeHours ?? '--',
      },
    };
  })
);

const fetchReportsWithRetry = async () => {
  const params = {
    since: from.value,
    until: to.value,
    businessHours: businessHours.value,
    ...activeFilters.value,
  };
  try {
    await store.dispatch(props.actionKey, params);
  } catch {
    try {
      await store.dispatch(props.actionKey, params);
    } catch {
      useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
    }
  }
};

const fetchAllData = () => {
  store.dispatch(props.fetchItemsKey);
  fetchReportsWithRetry();
};

onMounted(() => fetchAllData());

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  businessHours.value = updatedFilter.businessHours;
  activeFilters.value = updatedFilter;
  fetchAllData();
};

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  get columns() {
    return columns.value;
  },
  enableSorting: false,
  getCoreRowModel: getCoreRowModel(),
});

const downloadReports = () => {
  const dispatchMethods = {
    agent: 'downloadAgentReports',
    label: 'downloadLabelReports',
    inbox: 'downloadInboxReports',
    team: 'downloadTeamReports',
  };
  if (dispatchMethods[props.type]) {
    const fileName = generateFileName({
      type: props.type,
      to: to.value,
      businessHours: businessHours.value,
    });
    const params = {
      from: from.value,
      to: to.value,
      fileName,
      businessHours: businessHours.value,
      ...activeFilters.value,
    };
    store.dispatch(dispatchMethods[props.type], params);
  }
};

defineExpose({ downloadReports });
</script>

<template>
  <div class="flex flex-col gap-4">
    <template v-if="canViewReports">
      <!-- Filter Bar -->
      <AgentReportFilterBar
        v-if="type === 'agent'"
        :disabled="isLoading"
        @filter-change="onFilterChange"
      />
      <OverviewReportFilters
        v-else
        :disabled="isLoading"
        @filter-change="onFilterChange"
      />

      <!-- Lightweight Interactive Charts (Agent Reports) -->
      <AgentReportsCharts
        v-if="type === 'agent' && activeView === 'agent_overview'"
        :report-metrics="reportMetrics"
        :agents="rowItems"
        @drilldown="handleDrilldown"
      />

      <div
        v-if="type === 'agent'"
        class="flex flex-wrap items-center justify-between gap-3 mt-2"
      >
        <div class="flex items-center gap-2">
          <span
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider"
          >
            {{ $t('SUMMARY_REPORTS.VIEWS.LABEL') }}
          </span>
          <div class="flex p-0.5 rounded-lg bg-n-alpha-2 gap-0.5">
            <button
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md transition-colors"
              :class="
                activeView === 'agent_overview'
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="activeView = 'agent_overview'"
            >
              {{ $t('SUMMARY_REPORTS.VIEWS.AGENT_OVERVIEW') }}
            </button>
            <button
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md transition-colors"
              :class="
                activeView === 'agent_vs_team'
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="activeView = 'agent_vs_team'"
            >
              {{ $t('SUMMARY_REPORTS.VIEWS.AGENT_VS_TEAM') }}
            </button>
          </div>
        </div>

        <div
          v-if="activeView === 'agent_overview'"
          class="flex items-center gap-2"
        >
          <span class="text-xs text-n-slate-11">
            {{ $t('SUMMARY_REPORTS.TIMING_AGGREGATE.LABEL') }}
          </span>
          <div class="flex p-0.5 rounded-lg bg-n-alpha-2 gap-0.5">
            <button
              v-for="aggregate in TIMING_AGGREGATES"
              :key="aggregate"
              type="button"
              class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors"
              :class="
                selectedAggregate === aggregate
                  ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="selectedAggregate = aggregate"
            >
              {{
                $t(
                  `SUMMARY_REPORTS.TIMING_AGGREGATE.${aggregate.toUpperCase()}`
                )
              }}
            </button>
          </div>
        </div>
      </div>

      <div
        class="relative flex-1 overflow-auto px-2 py-2 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
      >
        <Table :table="table" />
        <Transition
          enter-active-class="transition-opacity duration-300 ease-out"
          leave-active-class="transition-opacity duration-200 ease-in"
          enter-from-class="opacity-0"
          enter-to-class="opacity-100"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0"
        >
          <div
            v-if="isLoading"
            class="absolute inset-0 flex justify-center pt-[12.5rem] bg-n-solid-1/70 rounded-xl pointer-events-none"
          >
            <Spinner :size="32" class="text-n-brand" />
          </div>
        </Transition>
      </div>

      <!-- Clickable Drilldown Drawer -->
      <ReportDrilldownDrawer
        :id="drilldownRequest?.id"
        :open="!!drilldownRequest"
        :metric="drilldownRequest?.metric"
        :metric-name="drilldownRequest?.metricName"
        :bucket-label="drilldownRequest?.bucketLabel"
        :bucket-value="drilldownRequest?.bucketValue"
        :is-average-metric="drilldownRequest?.isAverageMetric"
        :from="drilldownRequest?.from"
        :to="drilldownRequest?.to"
        :type="drilldownRequest?.type"
        :group-by="drilldownRequest?.groupBy"
        :business-hours="drilldownRequest?.businessHours"
        @close="closeDrilldown"
      />
    </template>
  </div>
</template>
