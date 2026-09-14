<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const store = useStore();
const { t } = useI18n();

const selectedInboxId = ref('all');
const selectedPriority = ref('all');
const selectedTeamId = ref('all');
const searchQuery = ref('');
const showRoutingExplanation = ref(false);
const activeConversationForExplanation = ref(null);

const unassignedChats = useMapGetter('getUnAssignedChats');
const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');
const currentAccountId = useMapGetter('getCurrentAccountId');

onMounted(() => {
  store.dispatch('fetchAllConversations');
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
  store.dispatch('agents/get');
});

const queueItems = computed(() => {
  let list = unassignedChats.value || [];

  if (selectedInboxId.value !== 'all') {
    list = list.filter(
      chat => String(chat.inbox_id) === String(selectedInboxId.value)
    );
  }

  if (selectedPriority.value !== 'all') {
    list = list.filter(chat => chat.priority === selectedPriority.value);
  }

  if (selectedTeamId.value !== 'all') {
    list = list.filter(
      chat => String(chat.meta?.team?.id) === String(selectedTeamId.value)
    );
  }

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    list = list.filter(chat => {
      const contact = chat.meta?.sender?.name || '';
      const id = String(chat.id);
      return contact.toLowerCase().includes(q) || id.includes(q);
    });
  }

  return list;
});

const totalInQueue = computed(() => unassignedChats.value?.length || 0);

const onlineAgentCount = computed(
  () =>
    (agents.value || []).filter(a => a.availability_status === 'online').length
);

const urgentCount = computed(() => {
  return (
    unassignedChats.value?.filter(chat => chat.priority === 'urgent').length ||
    0
  );
});

const getInbox = inboxId => {
  return inboxes.value?.find(i => i.id === inboxId);
};

const assigningConversationIds = ref(new Set());

const assignToMe = async chat => {
  // Guard against duplicate assignment requests from rapid double clicks.
  if (assigningConversationIds.value.has(chat.id)) return;
  assigningConversationIds.value = new Set([
    ...assigningConversationIds.value,
    chat.id,
  ]);

  try {
    await store.dispatch('assignAgent', {
      conversationId: chat.id,
      agentId: currentUser.value.id,
      assigneeType: 'User',
    });
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  } finally {
    const next = new Set(assigningConversationIds.value);
    next.delete(chat.id);
    assigningConversationIds.value = next;
  }
};

const openExplanationModal = chat => {
  activeConversationForExplanation.value = chat;
  showRoutingExplanation.value = true;
};

const explanationInboxAutoAssign = computed(() => {
  const inboxId = activeConversationForExplanation.value?.inbox_id;
  return Boolean(getInbox(inboxId)?.enable_auto_assignment);
});

const EXCLUSION_REASON_KEYS = {
  busy: 'OPERATIONS.LIVE_QUEUE.EXCLUSION.BUSY',
  offline: 'OPERATIONS.LIVE_QUEUE.EXCLUSION.OFFLINE',
};

const eligibleAgentsList = computed(() => {
  if (!activeConversationForExplanation.value) return [];
  return (agents.value || []).filter(
    agent => agent.confirmed && agent.availability_status === 'online'
  );
});

const excludedAgentsList = computed(() => {
  if (!activeConversationForExplanation.value) return [];
  return (agents.value || [])
    .filter(agent => agent.availability_status !== 'online')
    .map(agent => ({
      ...agent,
      reason: t(
        EXCLUSION_REASON_KEYS[agent.availability_status] ||
          'OPERATIONS.LIVE_QUEUE.EXCLUSION.BREAK'
      ),
    }));
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
          {{ $t('OPERATIONS.LIVE_QUEUE.TITLE') }}
        </h1>
        <p class="text-xs text-slate-400 mt-1">
          {{ $t('OPERATIONS.LIVE_QUEUE.SUBTITLE') }}
        </p>
      </div>

      <div class="flex items-center gap-2">
        <NextButton
          icon="i-lucide-rotate-cw"
          slate
          xs
          :label="$t('OPERATIONS.REFRESH')"
          @click="store.dispatch('fetchAllConversations')"
        />
      </div>
    </div>

    <!-- Stat Cards -->
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex flex-col"
      >
        <span class="text-xs font-medium text-slate-400">
          {{ $t('OPERATIONS.LIVE_QUEUE.TOTAL_IN_QUEUE') }}
        </span>
        <div class="mt-2 flex items-baseline gap-2">
          <span class="text-2xl font-bold text-white">{{ totalInQueue }}</span>
          <span class="text-[11px] text-amber-400">
            {{ $t('OPERATIONS.LIVE_QUEUE.WAITING') }}
          </span>
        </div>
      </div>

      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex flex-col"
      >
        <span class="text-xs font-medium text-slate-400">
          {{ $t('OPERATIONS.LIVE_QUEUE.URGENT_PRIORITY') }}
        </span>
        <div class="mt-2 flex items-baseline gap-2">
          <span class="text-2xl font-bold text-rose-400">{{
            urgentCount
          }}</span>
          <span class="text-[11px] text-slate-400">
            {{ $t('OPERATIONS.LIVE_QUEUE.HIGH_PRIORITY') }}
          </span>
        </div>
      </div>

      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex flex-col"
      >
        <span class="text-xs font-medium text-slate-400">
          {{ $t('OPERATIONS.LIVE_QUEUE.ACTIVE_INBOXES') }}
        </span>
        <div class="mt-2 flex items-baseline gap-2">
          <span class="text-2xl font-bold text-blue-400">{{
            inboxes?.length || 0
          }}</span>
          <span class="text-[11px] text-slate-400">
            {{ $t('OPERATIONS.LIVE_QUEUE.CHANNELS') }}
          </span>
        </div>
      </div>

      <div
        class="rounded-xl border border-slate-800/80 bg-slate-900/70 p-3.5 flex flex-col"
      >
        <span class="text-xs font-medium text-slate-400">
          {{ $t('OPERATIONS.LIVE_QUEUE.AVAILABLE_AGENTS') }}
        </span>
        <div class="mt-2 flex items-baseline gap-2">
          <span class="text-2xl font-bold text-emerald-400">
            {{ onlineAgentCount }}
          </span>
          <span class="text-[11px] text-slate-400">
            {{
              $t('OPERATIONS.LIVE_QUEUE.OF_TOTAL', {
                total: agents?.length || 0,
              })
            }}
          </span>
        </div>
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
          :placeholder="$t('OPERATIONS.LIVE_QUEUE.SEARCH_PLACEHOLDER')"
          class="w-full rounded-lg border border-slate-800 bg-slate-950 pl-9 pr-3 py-1.5 text-xs text-slate-200 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
      </div>

      <select
        v-model="selectedInboxId"
        class="rounded-lg border border-slate-800 bg-slate-950 px-2.5 py-1.5 text-xs text-slate-300 focus:border-blue-500 focus:outline-none"
      >
        <option value="all">
          {{ $t('OPERATIONS.LIVE_QUEUE.ALL_INBOXES') }}
        </option>
        <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
          {{ inbox.name }}
        </option>
      </select>

      <select
        v-model="selectedPriority"
        class="rounded-lg border border-slate-800 bg-slate-950 px-2.5 py-1.5 text-xs text-slate-300 focus:border-blue-500 focus:outline-none"
      >
        <option value="all">
          {{ $t('OPERATIONS.LIVE_QUEUE.ALL_PRIORITIES') }}
        </option>
        <option value="urgent">
          {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.URGENT') }}
        </option>
        <option value="high">
          {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.HIGH') }}
        </option>
        <option value="medium">
          {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.MEDIUM') }}
        </option>
        <option value="low">
          {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.LOW') }}
        </option>
      </select>

      <select
        v-model="selectedTeamId"
        class="rounded-lg border border-slate-800 bg-slate-950 px-2.5 py-1.5 text-xs text-slate-300 focus:border-blue-500 focus:outline-none"
      >
        <option value="all">
          {{ $t('OPERATIONS.LIVE_QUEUE.ALL_TEAMS') }}
        </option>
        <option v-for="team in teams" :key="team.id" :value="team.id">
          {{ team.name }}
        </option>
      </select>
    </div>

    <!-- Queue List Table -->
    <div
      class="rounded-xl border border-slate-800/80 bg-slate-900/60 overflow-hidden"
    >
      <div
        v-if="!queueItems.length"
        class="p-12 text-center text-sm text-slate-400"
      >
        <span
          class="i-lucide-check-circle-2 size-8 text-emerald-400 mx-auto block mb-2 opacity-80"
        />
        {{
          $t('OPERATIONS.LIVE_QUEUE.EMPTY') ||
          'All caught up! No unassigned conversations in queue.'
        }}
      </div>

      <table v-else class="w-full text-left border-collapse">
        <thead>
          <tr
            class="border-b border-slate-800/80 bg-slate-950/80 text-[11px] font-semibold text-slate-400 uppercase tracking-wider"
          >
            <th class="py-3 px-4">
              {{ $t('OPERATIONS.LIVE_QUEUE.COLUMN.CONVERSATION') }}
            </th>
            <th class="py-3 px-4">
              {{ $t('OPERATIONS.LIVE_QUEUE.COLUMN.INBOX') }}
            </th>
            <th class="py-3 px-4">
              {{ $t('OPERATIONS.LIVE_QUEUE.COLUMN.PRIORITY') }}
            </th>
            <th class="py-3 px-4">
              {{ $t('OPERATIONS.LIVE_QUEUE.COLUMN.WAITING_SINCE') }}
            </th>
            <th class="py-3 px-4">
              {{ $t('OPERATIONS.LIVE_QUEUE.COLUMN.TEAM') }}
            </th>
            <th class="py-3 px-4 text-right">
              {{ $t('OPERATIONS.LIVE_QUEUE.COLUMN.ACTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-800/60 text-xs text-slate-300">
          <tr
            v-for="chat in queueItems"
            :key="chat.id"
            class="hover:bg-white/[0.02] transition-colors"
          >
            <td class="py-3 px-4">
              <div class="flex items-center gap-2.5">
                <Avatar
                  :name="chat.meta?.sender?.name"
                  :src="chat.meta?.sender?.thumbnail"
                  :size="28"
                />
                <div class="flex flex-col min-w-0">
                  <router-link
                    :to="{
                      name: 'inbox_conversation',
                      params: {
                        accountId: currentAccountId,
                        conversationId: chat.id,
                      },
                    }"
                    class="font-medium text-slate-200 hover:text-blue-400 truncate"
                  >
                    {{
                      chat.meta?.sender?.name ||
                      $t('OPERATIONS.LIVE_QUEUE.ANONYMOUS')
                    }}
                  </router-link>
                  <span class="text-[11px] text-slate-500 font-mono"
                    >#{{ chat.id }}</span
                  >
                </div>
              </div>
            </td>

            <td class="py-3 px-4">
              <span
                class="inline-flex items-center gap-1.5 rounded-md bg-slate-800 px-2 py-0.5 text-[11px] text-slate-300 font-medium"
              >
                <span class="i-lucide-inbox size-3 text-slate-400" />
                {{
                  getInbox(chat.inbox_id)?.name ||
                  $t('OPERATIONS.LIVE_QUEUE.INBOX_FALLBACK')
                }}
              </span>
            </td>

            <td class="py-3 px-4">
              <span
                v-if="chat.priority === 'urgent'"
                class="rounded bg-rose-500/15 px-1.5 py-0.5 text-[10px] font-bold text-rose-400 uppercase tracking-wide"
              >
                {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.URGENT') }}
              </span>
              <span
                v-else-if="chat.priority === 'high'"
                class="rounded bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-amber-400 uppercase"
              >
                {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.HIGH') }}
              </span>
              <span
                v-else-if="chat.priority === 'medium'"
                class="rounded bg-blue-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-blue-300 uppercase"
              >
                {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.MEDIUM') }}
              </span>
              <span
                v-else-if="chat.priority === 'low'"
                class="rounded bg-slate-800 px-1.5 py-0.5 text-[10px] text-slate-400 uppercase"
              >
                {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.LOW') }}
              </span>
              <span
                v-else
                class="rounded bg-slate-800 px-1.5 py-0.5 text-[10px] text-slate-500 uppercase"
              >
                {{ $t('OPERATIONS.LIVE_QUEUE.PRIORITY.NONE') }}
              </span>
            </td>

            <td class="py-3 px-4 text-slate-400 text-xs">
              <TimeAgo
                :last-activity-timestamp="chat.timestamp"
                :created-at-timestamp="chat.created_at"
              />
            </td>

            <td class="py-3 px-4">
              <span
                v-if="chat.meta?.team?.name"
                class="rounded bg-indigo-500/15 px-2 py-0.5 text-[11px] text-indigo-300 font-medium"
              >
                {{ chat.meta.team.name }}
              </span>
              <span v-else class="text-slate-500 text-[11px]">
                {{ $t('OPERATIONS.LIVE_QUEUE.NO_TEAM') }}
              </span>
            </td>

            <td class="py-3 px-4 text-right">
              <div class="flex items-center justify-end gap-2">
                <NextButton
                  v-tooltip.top="$t('OPERATIONS.LIVE_QUEUE.VIEW_ROUTING')"
                  icon="i-lucide-info"
                  slate
                  xs
                  faded
                  @click="openExplanationModal(chat)"
                />
                <NextButton
                  icon="i-lucide-user-plus"
                  xs
                  color="blue"
                  :label="$t('OPERATIONS.LIVE_QUEUE.CLAIM')"
                  :is-loading="assigningConversationIds.has(chat.id)"
                  :disabled="assigningConversationIds.has(chat.id)"
                  @click="assignToMe(chat)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Routing Explanation Modal -->
    <Dialog
      v-if="showRoutingExplanation"
      :title="
        $t('OPERATIONS.LIVE_QUEUE.ROUTING_TITLE', {
          id: activeConversationForExplanation?.id,
        })
      "
      :description="$t('OPERATIONS.LIVE_QUEUE.ROUTING_DESCRIPTION')"
      @close="showRoutingExplanation = false"
    >
      <div class="space-y-4 text-xs text-slate-300">
        <div class="rounded-lg bg-slate-900 border border-slate-800 p-3">
          <span class="font-semibold text-white block mb-1">
            {{ $t('OPERATIONS.LIVE_QUEUE.MATCHED_RULE') }}
          </span>
          <p
            class="font-medium"
            :class="
              explanationInboxAutoAssign ? 'text-blue-400' : 'text-slate-400'
            "
          >
            {{
              explanationInboxAutoAssign
                ? $t('OPERATIONS.LIVE_QUEUE.AUTO_ASSIGNMENT_ENABLED')
                : $t('OPERATIONS.LIVE_QUEUE.AUTO_ASSIGNMENT_DISABLED')
            }}
          </p>
        </div>

        <div>
          <span class="font-semibold text-white block mb-2">
            {{
              $t('OPERATIONS.LIVE_QUEUE.ELIGIBLE_AGENTS', {
                count: eligibleAgentsList.length,
              })
            }}
          </span>
          <div
            v-if="!eligibleAgentsList.length"
            class="text-amber-400 text-[11px]"
          >
            {{ $t('OPERATIONS.LIVE_QUEUE.NO_ELIGIBLE_AGENTS') }}
          </div>
          <div v-else class="space-y-1.5">
            <div
              v-for="ag in eligibleAgentsList"
              :key="ag.id"
              class="flex items-center justify-between p-2 rounded bg-slate-900 border border-slate-800"
            >
              <div class="flex items-center gap-2">
                <span class="size-2 rounded-full bg-emerald-500" />
                <span class="font-medium text-slate-200">{{ ag.name }}</span>
              </div>
              <span class="text-[11px] text-emerald-400 font-mono">
                {{ $t('OPERATIONS.LIVE_QUEUE.ELIGIBLE_ONLINE') }}
              </span>
            </div>
          </div>
        </div>

        <div>
          <span class="font-semibold text-white block mb-2">
            {{
              $t('OPERATIONS.LIVE_QUEUE.EXCLUDED_AGENTS', {
                count: excludedAgentsList.length,
              })
            }}
          </span>
          <div class="space-y-1.5 max-h-40 overflow-y-auto">
            <div
              v-for="ag in excludedAgentsList"
              :key="ag.id"
              class="flex items-center justify-between p-2 rounded bg-slate-900 border border-slate-800"
            >
              <div class="flex items-center gap-2">
                <span class="size-2 rounded-full bg-slate-500" />
                <span class="text-slate-400">{{ ag.name }}</span>
              </div>
              <span class="text-[11px] text-slate-500">{{ ag.reason }}</span>
            </div>
          </div>
        </div>
      </div>
    </Dialog>
  </div>
</template>
