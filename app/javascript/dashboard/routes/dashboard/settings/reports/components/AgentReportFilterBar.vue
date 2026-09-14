<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import {
  generateReportURLParams,
  parseReportURLParams,
} from '../helpers/reportFilterHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['filterChange']);

const store = useStore();
const route = useRoute();
const router = useRouter();

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const businessHoursSelected = ref(false);

const selectedInbox = ref('');
const selectedChannel = ref('');
const selectedStatus = ref('');
const selectedPriority = ref('');
const selectedTeam = ref('');
const selectedAgent = ref('');

const inboxes = useMapGetter('inboxes/getInboxes') || [];
const teams = useMapGetter('teams/getTeams') || [];
const agents = useMapGetter('agents/getAgents') || [];

const availableChannels = computed(() => {
  const channelTypes = new Set();
  (inboxes.value || []).forEach(inbox => {
    if (inbox.channel_type) {
      channelTypes.add(inbox.channel_type);
    }
  });
  return Array.from(channelTypes);
});

const formatChannelName = channelType => {
  return channelType
    .replace(/^Channel::/, '')
    .replace(/([A-Z])/g, ' $1')
    .trim();
};

const updateURLParams = () => {
  const params = generateReportURLParams({
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    businessHours: businessHoursSelected.value,
    range: selectedDateRange.value,
  });

  if (selectedInbox.value) params.inbox_id = selectedInbox.value;
  if (selectedChannel.value) params.channel_type = selectedChannel.value;
  if (selectedStatus.value) params.status = selectedStatus.value;
  if (selectedPriority.value) params.priority = selectedPriority.value;
  if (selectedTeam.value) params.team_id = selectedTeam.value;
  if (selectedAgent.value) params.user_id = selectedAgent.value;

  router.replace({ query: { ...params } });
};

const emitChange = () => {
  updateURLParams();
  emit('filterChange', {
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    businessHours: businessHoursSelected.value,
    inbox_id: selectedInbox.value ? Number(selectedInbox.value) : null,
    channel_type: selectedChannel.value || null,
    status: selectedStatus.value || null,
    priority: selectedPriority.value || null,
    team_id: selectedTeam.value ? Number(selectedTeam.value) : null,
    user_id: selectedAgent.value ? Number(selectedAgent.value) : null,
  });
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  emitChange();
};

const onSelectFilterChange = () => {
  emitChange();
};

const onBusinessHoursToggle = () => {
  emitChange();
};

const initializeFromURL = () => {
  const urlParams = parseReportURLParams(route.query);

  if (urlParams.range) {
    selectedDateRange.value = urlParams.range;
  }

  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }

  if (urlParams.businessHours) {
    businessHoursSelected.value = urlParams.businessHours;
  }

  if (route.query.inbox_id) selectedInbox.value = route.query.inbox_id;
  if (route.query.channel_type)
    selectedChannel.value = route.query.channel_type;
  if (route.query.status) selectedStatus.value = route.query.status;
  if (route.query.priority) selectedPriority.value = route.query.priority;
  if (route.query.team_id) selectedTeam.value = route.query.team_id;
  if (route.query.user_id) selectedAgent.value = route.query.user_id;
};

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  initializeFromURL();
  emitChange();
});
</script>

<template>
  <div
    class="flex flex-col gap-3 p-3 border shadow-sm rounded-xl bg-n-solid-2 border-n-container"
    :class="{ 'pointer-events-none opacity-50': disabled }"
  >
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex flex-wrap items-center gap-2">
        <WootDatePicker
          v-model:date-range="customDateRange"
          v-model:range-type="selectedDateRange"
          @date-range-changed="onDateRangeChange"
        />
      </div>

      <div class="flex items-center">
        <span
          class="mx-2 text-xs font-medium text-n-slate-11 whitespace-nowrap"
        >
          {{ $t('REPORT.BUSINESS_HOURS') }}
        </span>
        <ToggleSwitch
          v-model="businessHoursSelected"
          @change="onBusinessHoursToggle"
        />
      </div>
    </div>

    <!-- Filter selectors -->
    <div
      class="grid grid-cols-2 gap-2 pt-3 border-t sm:grid-cols-3 md:grid-cols-6 border-n-container/50"
    >
      <!-- Inbox -->
      <div>
        <label
          class="block mb-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.FILTERS.INBOX') }}
        </label>
        <select
          v-model="selectedInbox"
          class="w-full h-8 px-2 text-xs border rounded-lg bg-n-solid-1 text-n-slate-12 border-n-container focus:outline-none focus:border-n-brand"
          @change="onSelectFilterChange"
        >
          <option value="">
            {{ $t('SUMMARY_REPORTS.FILTERS.ALL_INBOXES') }}
          </option>
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
      </div>

      <!-- Channel -->
      <div>
        <label
          class="block mb-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.FILTERS.CHANNEL') }}
        </label>
        <select
          v-model="selectedChannel"
          class="w-full h-8 px-2 text-xs border rounded-lg bg-n-solid-1 text-n-slate-12 border-n-container focus:outline-none focus:border-n-brand"
          @change="onSelectFilterChange"
        >
          <option value="">
            {{ $t('SUMMARY_REPORTS.FILTERS.ALL_CHANNELS') }}
          </option>
          <option
            v-for="channel in availableChannels"
            :key="channel"
            :value="channel"
          >
            {{ formatChannelName(channel) }}
          </option>
        </select>
      </div>

      <!-- Status -->
      <div>
        <label
          class="block mb-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.FILTERS.STATUS') }}
        </label>
        <select
          v-model="selectedStatus"
          class="w-full h-8 px-2 text-xs border rounded-lg bg-n-solid-1 text-n-slate-12 border-n-container focus:outline-none focus:border-n-brand"
          @change="onSelectFilterChange"
        >
          <option value="">
            {{ $t('SUMMARY_REPORTS.FILTERS.ALL_STATUSES') }}
          </option>
          <option value="open">
            {{ $t('SUMMARY_REPORTS.FILTERS.STATUS_OPTIONS.OPEN') }}
          </option>
          <option value="pending">
            {{ $t('SUMMARY_REPORTS.FILTERS.STATUS_OPTIONS.PENDING') }}
          </option>
          <option value="snoozed">
            {{ $t('SUMMARY_REPORTS.FILTERS.STATUS_OPTIONS.SNOOZED') }}
          </option>
          <option value="resolved">
            {{ $t('SUMMARY_REPORTS.FILTERS.STATUS_OPTIONS.RESOLVED') }}
          </option>
        </select>
      </div>

      <!-- Priority -->
      <div>
        <label
          class="block mb-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY') }}
        </label>
        <select
          v-model="selectedPriority"
          class="w-full h-8 px-2 text-xs border rounded-lg bg-n-solid-1 text-n-slate-12 border-n-container focus:outline-none focus:border-n-brand"
          @change="onSelectFilterChange"
        >
          <option value="">
            {{ $t('SUMMARY_REPORTS.FILTERS.ALL_PRIORITIES') }}
          </option>
          <option value="urgent">
            {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.URGENT') }}
          </option>
          <option value="high">
            {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.HIGH') }}
          </option>
          <option value="medium">
            {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.MEDIUM') }}
          </option>
          <option value="low">
            {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.LOW') }}
          </option>
          <option value="none">
            {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.NONE') }}
          </option>
        </select>
      </div>

      <!-- Team -->
      <div>
        <label
          class="block mb-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.FILTERS.TEAM') }}
        </label>
        <select
          v-model="selectedTeam"
          class="w-full h-8 px-2 text-xs border rounded-lg bg-n-solid-1 text-n-slate-12 border-n-container focus:outline-none focus:border-n-brand"
          @change="onSelectFilterChange"
        >
          <option value="">
            {{ $t('SUMMARY_REPORTS.FILTERS.ALL_TEAMS') }}
          </option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </div>

      <!-- Agent -->
      <div>
        <label
          class="block mb-1 text-[11px] font-semibold tracking-wider uppercase text-n-slate-11"
        >
          {{ $t('SUMMARY_REPORTS.FILTERS.AGENT') }}
        </label>
        <select
          v-model="selectedAgent"
          class="w-full h-8 px-2 text-xs border rounded-lg bg-n-solid-1 text-n-slate-12 border-n-container focus:outline-none focus:border-n-brand"
          @change="onSelectFilterChange"
        >
          <option value="">
            {{ $t('SUMMARY_REPORTS.FILTERS.ALL_AGENTS') }}
          </option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </div>
    </div>
  </div>
</template>
