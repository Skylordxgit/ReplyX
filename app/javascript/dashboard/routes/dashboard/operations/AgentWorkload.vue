<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Avatar from 'next/avatar/Avatar.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const DEFAULT_CAPACITY_LIMIT = 10;

const store = useStore();

const searchQuery = ref('');
const selectedTeam = ref('all');
const selectedAvailability = ref('all');

const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const conversations = useMapGetter('getAllConversations');

const refresh = () => {
  store.dispatch('agents/get');
  store.dispatch('fetchAllConversations');
};

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('teams/get');
  store.dispatch('fetchAllConversations');
});

// Conversation payloads expose the assignee under `meta.assignee`.
// There is no top level `assignee_id` on the dashboard conversation model.
// Aggregate once per conversation list change instead of re-scanning per agent.
const workloadByAgentId = computed(() => {
  const totals = new Map();
  (conversations.value || []).forEach(conversation => {
    const agentId = conversation.meta?.assignee?.id;
    if (!agentId) return;

    const entry = totals.get(agentId) || { open: 0, pending: 0, unread: 0 };
    if (conversation.status === 'open') entry.open += 1;
    if (conversation.status === 'pending') entry.pending += 1;
    if ((conversation.unread_count || 0) > 0) entry.unread += 1;
    totals.set(agentId, entry);
  });
  return totals;
});

const agentIdsForTeam = computed(() => {
  if (selectedTeam.value === 'all') return null;
  const team = (teams.value || []).find(
    item => String(item.id) === String(selectedTeam.value)
  );
  return new Set((team?.members || []).map(member => member.id));
});

const filteredAgents = computed(() => {
  let list = agents.value || [];

  if (selectedAvailability.value !== 'all') {
    list = list.filter(
      a => a.availability_status === selectedAvailability.value
    );
  }

  if (agentIdsForTeam.value) {
    list = list.filter(a => agentIdsForTeam.value.has(a.id));
  }

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    list = list.filter(
      a =>
        a.name?.toLowerCase().includes(q) || a.email?.toLowerCase().includes(q)
    );
  }

  return list;
});

const agentCards = computed(() =>
  filteredAgents.value.map(agent => {
    const totals = workloadByAgentId.value.get(agent.id) || {
      open: 0,
      pending: 0,
      unread: 0,
    };
    const max =
      Number(agent.custom_attributes?.capacity_limit) || DEFAULT_CAPACITY_LIMIT;

    return {
      ...agent,
      openCount: totals.open,
      pendingCount: totals.pending,
      unreadCount: totals.unread,
      capacity: {
        current: totals.open,
        max,
        percentage: Math.min(100, Math.round((totals.open / max) * 100)),
      },
    };
  })
);

const availableCount = computed(
  () =>
    agents.value?.filter(a => a.availability_status === 'online').length || 0
);
const busyCount = computed(
  () => agents.value?.filter(a => a.availability_status === 'busy').length || 0
);
const breakCount = computed(
  () =>
    agents.value?.filter(
      a => a.availability_status === 'away' || a.availability_status === 'break'
    ).length || 0
);
const offlineCount = computed(
  () =>
    agents.value?.filter(
      a => !a.availability_status || a.availability_status === 'offline'
    ).length || 0
);
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
          {{ $t('OPERATIONS.AGENT_WORKLOAD.TITLE') }}
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.SUBTITLE') }}
        </p>
      </div>

      <NextButton
        icon="i-lucide-rotate-cw"
        slate
        xs
        :label="$t('OPERATIONS.REFRESH')"
        @click="refresh"
      />
    </div>

    <!-- Availability Status Summary Cards -->
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex items-center justify-between"
      >
        <div class="flex flex-col">
          <span class="text-xs font-medium text-slate-400">
            {{ $t('OPERATIONS.AGENT_WORKLOAD.AVAILABLE') }}
          </span>
          <span class="text-2xl font-bold text-emerald-400 mt-1">{{
            availableCount
          }}</span>
        </div>
        <span class="size-3 rounded-full bg-emerald-500 shadow-sm" />
      </div>

      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex items-center justify-between"
      >
        <div class="flex flex-col">
          <span class="text-xs font-medium text-slate-400">
            {{ $t('OPERATIONS.AGENT_WORKLOAD.BUSY') }}
          </span>
          <span class="text-2xl font-bold text-amber-400 mt-1">{{
            busyCount
          }}</span>
        </div>
        <span class="size-3 rounded-full bg-amber-500 shadow-sm" />
      </div>

      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex items-center justify-between"
      >
        <div class="flex flex-col">
          <span class="text-xs font-medium text-slate-400">
            {{ $t('OPERATIONS.AGENT_WORKLOAD.ON_BREAK') }}
          </span>
          <span class="text-2xl font-bold text-blue-400 mt-1">{{
            breakCount
          }}</span>
        </div>
        <span class="size-3 rounded-full bg-blue-500 shadow-sm" />
      </div>

      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex items-center justify-between"
      >
        <div class="flex flex-col">
          <span class="text-xs font-medium text-slate-400">
            {{ $t('OPERATIONS.AGENT_WORKLOAD.OFFLINE') }}
          </span>
          <span class="text-2xl font-bold text-slate-400 mt-1">{{
            offlineCount
          }}</span>
        </div>
        <span class="size-3 rounded-full bg-slate-600 shadow-sm" />
      </div>
    </div>

    <!-- Filters & Search -->
    <div
      class="flex flex-wrap items-center gap-3 rounded-xl border border-slate-800/80 bg-slate-900/50 p-3"
    >
      <div class="relative flex-1 min-w-[200px]">
        <span
          class="i-lucide-search size-4 absolute left-3 top-2.5 text-slate-400"
        />
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="$t('OPERATIONS.AGENT_WORKLOAD.SEARCH_PLACEHOLDER')"
          class="w-full rounded-lg border border-slate-800 bg-slate-950 pl-9 pr-3 py-1.5 text-xs text-slate-200 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
      </div>

      <select
        v-model="selectedTeam"
        class="rounded-lg border border-slate-800 bg-slate-950 px-2.5 py-1.5 text-xs text-slate-300 focus:border-blue-500 focus:outline-none"
      >
        <option value="all">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.ALL_TEAMS') }}
        </option>
        <option v-for="team in teams" :key="team.id" :value="team.id">
          {{ team.name }}
        </option>
      </select>

      <select
        v-model="selectedAvailability"
        class="rounded-lg border border-slate-800 bg-slate-950 px-2.5 py-1.5 text-xs text-slate-300 focus:border-blue-500 focus:outline-none"
      >
        <option value="all">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.ALL_STATUSES') }}
        </option>
        <option value="online">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.AVAILABLE') }}
        </option>
        <option value="busy">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.BUSY') }}
        </option>
        <option value="away">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.ON_BREAK') }}
        </option>
        <option value="offline">
          {{ $t('OPERATIONS.AGENT_WORKLOAD.OFFLINE') }}
        </option>
      </select>
    </div>

    <!-- Agents Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      <div
        v-for="agent in agentCards"
        :key="agent.id"
        class="rounded-xl border border-slate-800/80 bg-slate-900/60 p-4 flex flex-col justify-between hover:border-slate-700/80 transition-all"
      >
        <div>
          <!-- Top Row: Avatar + Info + Role -->
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <Avatar
                :name="agent.name"
                :src="agent.thumbnail"
                :size="40"
                :status="agent.availability_status"
              />
              <div class="flex flex-col min-w-0">
                <span class="font-semibold text-white truncate text-sm">
                  {{ agent.name }}
                </span>
                <span class="text-xs text-slate-400 truncate">
                  {{ agent.email }}
                </span>
              </div>
            </div>

            <span
              class="rounded bg-blue-500/15 px-2 py-0.5 text-[10px] font-semibold text-blue-300 uppercase tracking-wide shrink-0"
            >
              {{ agent.role }}
            </span>
          </div>

          <!-- Capacity Bar -->
          <div class="mt-4 pt-3 border-t border-slate-800/60">
            <div
              class="flex items-center justify-between text-xs text-slate-400 mb-1.5"
            >
              <span>{{ $t('OPERATIONS.AGENT_WORKLOAD.ACTIVE_CAPACITY') }}</span>
              <span class="font-mono text-slate-200">
                {{
                  $t('OPERATIONS.AGENT_WORKLOAD.CAPACITY_SUMMARY', {
                    current: agent.capacity.current,
                    max: agent.capacity.max,
                    percentage: agent.capacity.percentage,
                  })
                }}
              </span>
            </div>
            <div class="h-2 w-full rounded-full bg-slate-800 overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-300"
                :class="{
                  'bg-emerald-500': agent.capacity.percentage < 70,
                  'bg-amber-500':
                    agent.capacity.percentage >= 70 &&
                    agent.capacity.percentage < 90,
                  'bg-rose-500': agent.capacity.percentage >= 90,
                }"
                :style="{ width: `${agent.capacity.percentage}%` }"
              />
            </div>
          </div>
        </div>

        <!-- Bottom Stat Pills -->
        <div
          class="mt-4 pt-3 border-t border-slate-800/60 grid grid-cols-3 gap-2 text-center"
        >
          <div class="rounded-lg bg-slate-950 p-2 border border-slate-800/60">
            <span
              class="text-[10px] text-slate-400 block uppercase font-medium"
            >
              {{ $t('OPERATIONS.AGENT_WORKLOAD.OPEN') }}
            </span>
            <span class="text-sm font-bold text-white">{{
              agent.openCount
            }}</span>
          </div>
          <div class="rounded-lg bg-slate-950 p-2 border border-slate-800/60">
            <span
              class="text-[10px] text-slate-400 block uppercase font-medium"
            >
              {{ $t('OPERATIONS.AGENT_WORKLOAD.PENDING') }}
            </span>
            <span class="text-sm font-bold text-amber-400">{{
              agent.pendingCount
            }}</span>
          </div>
          <div class="rounded-lg bg-slate-950 p-2 border border-slate-800/60">
            <span
              class="text-[10px] text-slate-400 block uppercase font-medium"
            >
              {{ $t('OPERATIONS.AGENT_WORKLOAD.UNREAD') }}
            </span>
            <span class="text-sm font-bold text-blue-400">{{
              agent.unreadCount
            }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
