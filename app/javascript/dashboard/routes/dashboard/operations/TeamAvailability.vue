<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();

const searchQuery = ref('');

const teams = useMapGetter('teams/getTeams');
const conversations = useMapGetter('getAllConversations');
const currentAccountId = useMapGetter('getCurrentAccountId');

const refresh = () => {
  store.dispatch('teams/get');
  store.dispatch('fetchAllConversations');
};

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('fetchAllConversations');
});

// Conversation payloads expose assignee/team under `meta`.
// Aggregate once instead of re-scanning the conversation list per team.
const statsByTeamId = computed(() => {
  const totals = new Map();
  (conversations.value || []).forEach(conversation => {
    const teamId = conversation.meta?.team?.id;
    if (!teamId || conversation.status !== 'open') return;

    const entry = totals.get(teamId) || { open: 0, unassigned: 0 };
    entry.open += 1;
    if (!conversation.meta?.assignee) entry.unassigned += 1;
    totals.set(teamId, entry);
  });
  return totals;
});

const filteredTeams = computed(() => {
  let list = teams.value || [];
  const query = searchQuery.value.trim().toLowerCase();

  if (query) {
    list = list.filter(
      team =>
        team.name?.toLowerCase().includes(query) ||
        team.description?.toLowerCase().includes(query)
    );
  }

  return list.map(team => {
    const totals = statsByTeamId.value.get(team.id) || {
      open: 0,
      unassigned: 0,
    };
    return {
      ...team,
      openCount: totals.open,
      unassignedCount: totals.unassigned,
    };
  });
});
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
          {{ $t('OPERATIONS.TEAM_AVAILABILITY.TITLE') }}
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          {{ $t('OPERATIONS.TEAM_AVAILABILITY.SUBTITLE') }}
        </p>
      </div>

      <div class="flex items-center gap-2">
        <router-link
          :to="{
            name: 'settings_teams_new',
            params: { accountId: currentAccountId },
          }"
        >
          <NextButton
            icon="i-lucide-plus"
            xs
            color="blue"
            :label="$t('OPERATIONS.TEAM_AVAILABILITY.NEW_TEAM')"
          />
        </router-link>
        <NextButton
          icon="i-lucide-rotate-cw"
          slate
          xs
          :label="$t('OPERATIONS.REFRESH')"
          @click="refresh"
        />
      </div>
    </div>

    <!-- Search Box -->
    <div class="relative max-w-md">
      <span
        class="i-lucide-search size-4 absolute left-3 top-2.5 text-slate-400"
      />
      <input
        v-model="searchQuery"
        type="text"
        :placeholder="$t('OPERATIONS.TEAM_AVAILABILITY.SEARCH_PLACEHOLDER')"
        class="w-full rounded-lg border border-slate-800 bg-slate-950 pl-9 pr-3 py-1.5 text-xs text-slate-200 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
      />
    </div>

    <!-- Empty State -->
    <div
      v-if="!filteredTeams.length"
      class="rounded-xl border border-slate-800 bg-slate-900/40 p-12 text-center text-sm text-slate-400"
    >
      <span class="i-lucide-users size-8 text-slate-600 mx-auto block mb-2" />
      {{ $t('OPERATIONS.TEAM_AVAILABILITY.EMPTY') }}
    </div>

    <!-- Teams Grid -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div
        v-for="team in filteredTeams"
        :key="team.id"
        class="rounded-xl border border-slate-800/80 bg-slate-900/60 p-5 flex flex-col justify-between hover:border-slate-700/80 transition-all space-y-4"
      >
        <div>
          <!-- Top Row: Team Name + Routing Badge -->
          <div class="flex items-start justify-between gap-3">
            <div>
              <h3
                class="text-base font-bold text-white flex items-center gap-2"
              >
                {{ team.name }}
                <span
                  v-if="team.allow_auto_assign"
                  class="rounded-full bg-emerald-500/15 text-emerald-400 text-[10px] font-medium px-2 py-0.5"
                >
                  {{ $t('OPERATIONS.TEAM_AVAILABILITY.AUTO_ROUTING_ON') }}
                </span>
                <span
                  v-else
                  class="rounded-full bg-slate-800 text-slate-400 text-[10px] font-medium px-2 py-0.5"
                >
                  {{ $t('OPERATIONS.TEAM_AVAILABILITY.MANUAL') }}
                </span>
              </h3>
              <p class="text-xs text-slate-400 mt-1 line-clamp-2">
                {{
                  team.description ||
                  $t('OPERATIONS.TEAM_AVAILABILITY.NO_DESCRIPTION')
                }}
              </p>
            </div>

            <router-link
              :to="{
                name: 'settings_teams_edit',
                params: { accountId: currentAccountId, teamId: team.id },
              }"
            >
              <NextButton icon="i-lucide-settings" slate xs faded />
            </router-link>
          </div>

          <!-- Routing Settings & Strategy -->
          <div class="mt-4 flex flex-wrap items-center gap-2">
            <span
              class="rounded-md border border-slate-800 bg-slate-950 px-2 py-1 text-[11px] text-slate-300 font-mono"
            >
              {{
                $t('OPERATIONS.TEAM_AVAILABILITY.STRATEGY', {
                  strategy: team.allow_auto_assign
                    ? $t('OPERATIONS.TEAM_AVAILABILITY.STRATEGY_AUTO')
                    : $t('OPERATIONS.TEAM_AVAILABILITY.STRATEGY_MANUAL'),
                })
              }}
            </span>
            <span
              class="rounded-md border border-slate-800 bg-slate-950 px-2 py-1 text-[11px] text-slate-300"
            >
              {{
                $t('OPERATIONS.TEAM_AVAILABILITY.MEMBERS', {
                  count: team.members?.length || 0,
                })
              }}
            </span>
          </div>
        </div>

        <!-- Team Stats Row -->
        <div
          class="pt-3 border-t border-slate-800/60 grid grid-cols-2 gap-3 text-center"
        >
          <div class="rounded-lg bg-slate-950 p-2 border border-slate-800/60">
            <span
              class="text-[10px] text-slate-400 block uppercase font-medium"
            >
              {{ $t('OPERATIONS.TEAM_AVAILABILITY.OPEN_CHATS') }}
            </span>
            <span class="text-base font-bold text-white">{{
              team.openCount
            }}</span>
          </div>
          <div class="rounded-lg bg-slate-950 p-2 border border-slate-800/60">
            <span
              class="text-[10px] text-slate-400 block uppercase font-medium"
            >
              {{ $t('OPERATIONS.TEAM_AVAILABILITY.UNASSIGNED') }}
            </span>
            <span class="text-base font-bold text-amber-400">{{
              team.unassignedCount
            }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
