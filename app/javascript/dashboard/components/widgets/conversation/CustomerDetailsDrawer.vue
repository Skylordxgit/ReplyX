<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import {
  useStore,
  useMapGetter,
  useFunctionGetter,
} from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import {
  getInboxIconByType,
  getReadableInboxByType,
} from 'dashboard/helper/inbox';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';

import Avatar from 'next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConversationLabels from 'dashboard/routes/dashboard/conversation/labels/LabelBox.vue';
import ContactConversations from 'dashboard/routes/dashboard/conversation/ContactConversations.vue';
import LinearIssuesList from 'dashboard/components/widgets/conversation/linear/IssuesList.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: Number,
    default: undefined,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const { updateUISettings } = useUISettings();
const { isCloudFeatureEnabled } = useAccount();

const activeTab = ref('information');
const showMoreTop = ref(false);
const isExpandedWidth = ref(false);
const newNoteContent = ref('');
const isSubmittingNote = ref(false);
const mentionQuery = ref('');
const showMentionDropdown = ref(false);

const currentChat = useMapGetter('getSelectedChat');
const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value?.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value) || {});

const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');
const { agentsList } = useAgentsList(true, { includeAIAssignees: true });

const { savedLabels } = useConversationLabels();

// Linear / Tickets Integration check
const isLinearFeatureEnabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.LINEAR)
);
const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);
const isLinearConnected = computed(
  () => linearIntegration.value?.enabled || false
);

// Metadata & Attributes
const contactAdditionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);
const contactCustomAttributes = computed(
  () => contact.value.custom_attributes || {}
);
const conversationAdditionalAttributes = computed(
  () => currentChat.value?.additional_attributes || {}
);
const conversationCustomAttributes = computed(
  () => currentChat.value?.custom_attributes || {}
);

// Channel & Inbox info
const currentInbox = computed(() => {
  const targetId = props.inboxId || currentChat.value?.inbox_id;
  return inboxes.value?.find(i => i.id === targetId) || {};
});

const channelType = computed(() => currentChat.value?.meta?.channel);
const channelIcon = computed(() =>
  getInboxIconByType(channelType.value, null, 'fill')
);
const readableChannel = computed(() =>
  getReadableInboxByType(channelType.value)
);

// Top identity fields
const channelUsername = computed(() => {
  return (
    contactAdditionalAttributes.value.screen_name ||
    contactAdditionalAttributes.value.username ||
    currentChat.value?.meta?.sender?.identifier ||
    ''
  );
});

const externalUsername = computed(() => {
  return (
    contactCustomAttributes.value.icx_username ||
    contactCustomAttributes.value.external_id ||
    contact.value.identifier ||
    ''
  );
});

// Category / Topic
const category = computed(() => {
  return (
    conversationCustomAttributes.value.category ||
    conversationCustomAttributes.value.topic ||
    contactCustomAttributes.value.category ||
    ''
  );
});

// Notes & Call Logs
const privateNotes = computed(() => {
  const msgs = currentChat.value?.messages || [];
  return msgs.filter(m => m.private);
});

const callLogsCount = computed(() => {
  const msgs = currentChat.value?.messages || [];
  return msgs.filter(
    m =>
      m.content_type === 'call_log' ||
      m.attachments?.some(a => a.file_type === 'audio')
  ).length;
});

// Person in Charge
const currentAssignee = computed(() => currentChat.value?.meta?.assignee);
const participants = computed(() => {
  const parts = currentChat.value?.meta?.participants || [];
  return parts.filter(p => p.id !== currentAssignee.value?.id);
});

// Mentionable members filter
const mentionableAgents = computed(() => {
  if (!mentionQuery.value) return agentsList.value.slice(0, 5);
  const q = mentionQuery.value.toLowerCase();
  return agentsList.value
    .filter(
      a =>
        a.name?.toLowerCase().includes(q) || a.email?.toLowerCase().includes(q)
    )
    .slice(0, 5);
});

// Format dates
const formatTimestamp = ts => {
  if (!ts) return '--';
  try {
    const date = typeof ts === 'number' ? fromUnixTime(ts) : new Date(ts);
    return format(date, 'MMM d, yyyy');
  } catch {
    return '--';
  }
};

const formatNoteTime = ts => {
  if (!ts) return '';
  try {
    const date = typeof ts === 'number' ? fromUnixTime(ts) : new Date(ts);
    return format(date, 'MMM d, h:mm a');
  } catch {
    return '';
  }
};

// Copy actions
const onCopy = async text => {
  if (!text) return;
  try {
    await copyTextToClipboard(String(text));
    useAlert(t('CONTACT_PANEL.COPY_SUCCESSFUL'));
  } catch {
    // fallback
  }
};

// State Mutations
const onStatusChange = async status => {
  await store.dispatch('toggleStatus', {
    conversationId: props.conversationId,
    status,
  });
  useAlert(t('CONVERSATION.CHANGE_STATUS'));
};

const onPriorityChange = async priority => {
  await store.dispatch('assignPriority', {
    conversationId: props.conversationId,
    priority: priority || null,
  });
  useAlert(t('CONVERSATION.PRIORITY.CHANGE_PRIORITY'));
};

const onAssigneeChange = async agentId => {
  const selectedAgent = agentsList.value.find(a => a.id === Number(agentId));
  const assigneeType = selectedAgent?.assignee_type || 'User';

  await store.dispatch('assignAgent', {
    conversationId: props.conversationId,
    agentId: agentId ? Number(agentId) : null,
    assigneeType,
  });
  useAlert(t('CONVERSATION.CHANGE_AGENT'));
};

const onTeamChange = async teamId => {
  const targetTeam = teams.value.find(tItem => tItem.id === Number(teamId));
  await store.dispatch('assignTeam', {
    conversationId: props.conversationId,
    teamId: teamId ? Number(teamId) : 0,
  });
  await store.dispatch('setCurrentChatTeam', {
    team: targetTeam || null,
    conversationId: props.conversationId,
  });
  useAlert(t('CONVERSATION.CHANGE_TEAM'));
};

// Note Input & Mentions
const onNoteInput = e => {
  const val = e.target.value;
  const lastWord = val.split(/\s+/).pop();
  if (lastWord && lastWord.startsWith('@')) {
    mentionQuery.value = lastWord.slice(1);
    showMentionDropdown.value = true;
  } else {
    showMentionDropdown.value = false;
  }
};

const insertMention = agent => {
  const words = newNoteContent.value.split(/\s+/);
  words.pop();
  words.push(
    `[@${agent.name}](mention://user/${agent.id}/${encodeURIComponent(agent.name)}) `
  );
  newNoteContent.value = words.join(' ');
  showMentionDropdown.value = false;
};

const onAddNote = async () => {
  if (!newNoteContent.value.trim() || isSubmittingNote.value) return;

  isSubmittingNote.value = true;
  try {
    await store.dispatch('createMessage', {
      conversationId: props.conversationId,
      message: newNoteContent.value.trim(),
      private: true,
    });
    newNoteContent.value = '';
    showMentionDropdown.value = false;
    useAlert(t('CONTACTS_LAYOUT.SIDEBAR.NOTES.SAVE'));
  } catch {
    useAlert(t('CONTACT_PANEL.MUTATION_ERROR'));
  } finally {
    isSubmittingNote.value = false;
  }
};

const closeDrawer = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
  });
  emit('close');
};

const toggleExpandWidth = () => {
  isExpandedWidth.value = !isExpandedWidth.value;
};

watch(
  contactId,
  newId => {
    if (newId) {
      store.dispatch('contacts/show', { id: newId });
      store.dispatch('contactConversations/get', newId);
    }
  },
  { immediate: true }
);

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('teams/get');
  store.dispatch('inboxes/get');
  if (contactId.value) {
    store.dispatch('contacts/show', { id: contactId.value });
    store.dispatch('contactConversations/get', contactId.value);
  }
});
</script>

<template>
  <aside
    class="flex flex-col h-full overflow-hidden transition-all duration-300 ease-in-out border-l shadow-2xl bg-slate-950/95 backdrop-blur-md border-slate-800/80 text-slate-100"
    :class="
      isExpandedWidth
        ? 'w-[460px] min-w-[460px]'
        : 'w-[360px] min-w-[360px] 2xl:w-[400px] 2xl:min-w-[400px]'
    "
  >
    <!-- Top Bar: Title & Window Controls -->
    <div
      class="flex items-center justify-between px-4 py-3 border-b shrink-0 border-slate-800/60 bg-slate-900/60"
    >
      <div class="flex items-center gap-2">
        <span
          class="text-xs font-semibold tracking-wider text-emerald-400 uppercase"
        >
          {{ $t('CONTACT_PANEL.DRAWER.TITLE') }}
        </span>
      </div>

      <div class="flex items-center gap-1">
        <button
          type="button"
          class="p-1 rounded-md text-slate-400 hover:text-slate-100 hover:bg-slate-800 transition-colors"
          @click="toggleExpandWidth"
        >
          <span
            :class="
              isExpandedWidth ? 'i-lucide-minimize-2' : 'i-lucide-maximize-2'
            "
            class="size-3.5 block"
          />
        </button>
        <button
          type="button"
          class="p-1 rounded-md text-slate-400 hover:text-slate-100 hover:bg-slate-800 transition-colors"
          @click="closeDrawer"
        >
          <span class="i-lucide-x size-4 block" />
        </button>
      </div>
    </div>

    <!-- Scrollable Content -->
    <div
      class="flex-1 overflow-y-auto divide-y divide-slate-800/50 custom-scrollbar"
    >
      <!-- 1. Top Customer Profile Card -->
      <div
        class="flex flex-col gap-3 p-4 bg-gradient-to-b from-slate-900/40 to-transparent"
      >
        <div class="flex items-start gap-3">
          <Avatar
            :name="contact.name || 'Customer'"
            :src="contact.thumbnail"
            :size="48"
            :status="contact.availability_status"
            hide-offline-status
            class="ring-2 ring-emerald-500/20 shrink-0"
          />
          <div class="flex flex-col flex-1 min-w-0">
            <h3
              class="text-base font-bold truncate text-slate-100 leading-snug"
            >
              {{ contact.name || 'Anonymous Customer' }}
            </h3>

            <!-- Channel username / handle -->
            <span
              v-if="channelUsername"
              class="text-xs truncate text-emerald-400/90 font-medium"
            >
              {{ `@${channelUsername}` }}
            </span>

            <!-- External / ICX username -->
            <span
              v-if="externalUsername"
              class="text-[11px] truncate text-slate-400 font-mono"
            >
              {{ `ICX: ${externalUsername}` }}
            </span>
          </div>
        </div>

        <!-- User Tags / Labels -->
        <div v-if="savedLabels.length" class="flex flex-wrap gap-1.5 mt-1">
          <span
            v-for="label in savedLabels"
            :key="label"
            class="px-2 py-0.5 text-[11px] font-medium rounded-full bg-slate-800/80 border border-slate-700/60 text-emerald-300"
          >
            #{{ label }}
          </span>
        </div>

        <!-- Show More Toggle -->
        <div class="flex items-center justify-between pt-1">
          <button
            type="button"
            class="flex items-center gap-1 text-xs font-medium text-slate-400 hover:text-emerald-400 transition-colors"
            @click="showMoreTop = !showMoreTop"
          >
            <span>{{
              showMoreTop
                ? $t('CONTACT_PANEL.DRAWER.SHOW_LESS')
                : $t('CONTACT_PANEL.DRAWER.SHOW_MORE')
            }}</span>
            <span
              :class="
                showMoreTop ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
              "
              class="size-3 block"
            />
          </button>
        </div>

        <!-- Collapsible Top Metadata -->
        <div
          v-if="showMoreTop"
          class="flex flex-col gap-2 p-2.5 rounded-lg bg-slate-900/70 border border-slate-800 text-xs"
        >
          <div v-if="contact.email" class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.EMAIL')
            }}</span>
            <span class="truncate max-w-[200px] text-slate-200">{{
              contact.email
            }}</span>
          </div>
          <div
            v-if="contact.phone_number"
            class="flex items-center justify-between"
          >
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.PHONE')
            }}</span>
            <span class="text-slate-200">{{ contact.phone_number }}</span>
          </div>
          <div
            v-if="
              contactAdditionalAttributes.city ||
              contactAdditionalAttributes.country
            "
            class="flex items-center justify-between"
          >
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.LOCATION')
            }}</span>
            <span class="text-slate-200">
              {{
                [
                  contactAdditionalAttributes.city,
                  contactAdditionalAttributes.country,
                ]
                  .filter(Boolean)
                  .join(', ')
              }}
            </span>
          </div>
        </div>
      </div>

      <!-- 2. Segmented Tabs -->
      <div class="p-2">
        <div
          class="flex p-0.5 rounded-lg bg-slate-900/80 border border-slate-800/80"
        >
          <button
            type="button"
            class="flex-1 py-1.5 text-xs font-medium rounded-md transition-all text-center"
            :class="
              activeTab === 'information'
                ? 'bg-emerald-600/90 text-white shadow'
                : 'text-slate-400 hover:text-slate-200'
            "
            @click="activeTab = 'information'"
          >
            {{ $t('CONTACT_PANEL.INFORMATION_TAB') }}
          </button>
          <button
            type="button"
            class="flex-1 py-1.5 text-xs font-medium rounded-md transition-all text-center"
            :class="
              activeTab === 'contact_info'
                ? 'bg-emerald-600/90 text-white shadow'
                : 'text-slate-400 hover:text-slate-200'
            "
            @click="activeTab = 'contact_info'"
          >
            {{ $t('CONTACT_PANEL.CONTACT_INFO_TAB') }}
          </button>
          <button
            type="button"
            class="flex-1 py-1.5 text-xs font-medium rounded-md transition-all text-center"
            :class="
              activeTab === 'other'
                ? 'bg-emerald-600/90 text-white shadow'
                : 'text-slate-400 hover:text-slate-200'
            "
            @click="activeTab = 'other'"
          >
            {{ $t('CONTACT_PANEL.OTHER_TAB') }}
          </button>
        </div>
      </div>

      <!-- TAB 1: INFORMATION -->
      <div v-show="activeTab === 'information'" class="flex flex-col gap-4 p-4">
        <!-- Conversation Details Section -->
        <div
          class="flex flex-col gap-2.5 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60 text-xs"
        >
          <!-- Session / Conversation ID -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.SESSION_ID') }}
            </span>
            <div class="flex items-center gap-1.5">
              <span class="font-mono text-emerald-400 font-semibold"
                >#{{ currentChat.id }}</span
              >
              <button
                type="button"
                class="text-slate-400 hover:text-slate-100 p-0.5 rounded"
                @click="onCopy(currentChat.id)"
              >
                <span class="i-lucide-copy size-3 block" />
              </button>
            </div>
          </div>

          <!-- Status -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.STATUS') }}
            </span>
            <select
              :value="currentChat.status"
              class="h-7 px-2 text-xs font-medium border rounded bg-slate-800 text-slate-100 border-slate-700 focus:outline-none focus:border-emerald-500"
              @change="e => onStatusChange(e.target.value)"
            >
              <option value="open">
                {{ $t('CONVERSATION.HEADER.OPEN_ACTION') }}
              </option>
              <option value="pending">
                {{ $t('SUMMARY_REPORTS.FILTERS.STATUS_OPTIONS.PENDING') }}
              </option>
              <option value="snoozed">
                {{ $t('SUMMARY_REPORTS.FILTERS.STATUS_OPTIONS.SNOOZED') }}
              </option>
              <option value="resolved">
                {{ $t('CONVERSATION.HEADER.RESOLVE_ACTION') }}
              </option>
            </select>
          </div>

          <!-- Priority -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.PRIORITY') }}
            </span>
            <select
              :value="currentChat.priority || ''"
              class="h-7 px-2 text-xs font-medium border rounded bg-slate-800 text-slate-100 border-slate-700 focus:outline-none focus:border-emerald-500"
              @change="e => onPriorityChange(e.target.value)"
            >
              <option value="">
                {{ $t('CONTACT_PANEL.DRAWER.NONE') }}
              </option>
              <option :value="CONVERSATION_PRIORITY.URGENT">
                {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.URGENT') }}
              </option>
              <option :value="CONVERSATION_PRIORITY.HIGH">
                {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.HIGH') }}
              </option>
              <option :value="CONVERSATION_PRIORITY.MEDIUM">
                {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.MEDIUM') }}
              </option>
              <option :value="CONVERSATION_PRIORITY.LOW">
                {{ $t('SUMMARY_REPORTS.FILTERS.PRIORITY_OPTIONS.LOW') }}
              </option>
            </select>
          </div>

          <!-- Team -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.TEAM') }}
            </span>
            <select
              :value="currentChat.meta?.team?.id || ''"
              class="h-7 px-2 text-xs font-medium border rounded bg-slate-800 text-slate-100 border-slate-700 focus:outline-none focus:border-emerald-500 max-w-[170px] truncate"
              @change="e => onTeamChange(e.target.value)"
            >
              <option value="">
                {{ $t('CONTACT_PANEL.DRAWER.NONE') }}
              </option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </div>

          <!-- Category -->
          <div v-if="category" class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.CATEGORY') }}
            </span>
            <span class="font-medium text-slate-200 truncate max-w-[170px]">{{
              category
            }}</span>
          </div>

          <!-- Channel -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.CHANNEL') }}
            </span>
            <div class="flex items-center gap-1.5 text-slate-200">
              <span :class="[channelIcon]" class="size-3.5" />
              <span>{{ readableChannel }}</span>
            </div>
          </div>

          <!-- Inbox / Page -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.INBOX') }}
            </span>
            <span class="truncate max-w-[170px] text-slate-200 font-medium">{{
              currentInbox.name || '--'
            }}</span>
          </div>

          <!-- Tags / Labels Manager -->
          <div class="pt-2 mt-1 border-t border-slate-800/60">
            <span class="block mb-1.5 text-slate-400 font-medium">
              {{ $t('CONTACT_PANEL.DRAWER.TAGS_AND_LABELS') }}
            </span>
            <ConversationLabels :conversation-id="conversationId" />
          </div>
        </div>

        <!-- NOTES SECTION -->
        <div
          class="flex flex-col gap-2.5 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span
                class="text-xs font-semibold tracking-wider text-slate-300 uppercase"
              >
                {{ $t('CONTACT_PANEL.DRAWER.NOTES') }}
              </span>
              <span
                class="px-1.5 py-0.5 text-[10px] font-bold rounded-full bg-amber-500/20 text-amber-400"
              >
                {{ $t('CONTACT_PANEL.DRAWER.PRIVATE_NOTES') }}:
                {{ privateNotes.length }}
              </span>
            </div>
            <span
              v-if="callLogsCount > 0"
              class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-blue-500/20 text-blue-400"
            >
              {{ $t('CONTACT_PANEL.DRAWER.CALL_LOGS') }}: {{ callLogsCount }}
            </span>
          </div>

          <!-- Notes Feed List -->
          <div
            v-if="privateNotes.length"
            class="flex flex-col gap-2 max-h-48 overflow-y-auto pr-1 custom-scrollbar"
          >
            <div
              v-for="note in privateNotes"
              :key="note.id"
              class="p-2.5 rounded-lg bg-slate-800/80 border border-amber-500/20 text-xs flex flex-col gap-1"
            >
              <div
                class="flex items-center justify-between text-[11px] text-slate-400"
              >
                <span class="font-semibold text-amber-300/90">{{
                  note.sender?.name || 'Agent'
                }}</span>
                <span>{{ formatNoteTime(note.created_at) }}</span>
              </div>
              <p class="text-slate-200 whitespace-pre-wrap leading-relaxed">
                {{ note.content }}
              </p>
            </div>
          </div>
          <p v-else class="text-xs text-slate-400 italic py-1 text-center">
            {{ $t('CONTACT_PANEL.DRAWER.NO_PRIVATE_NOTES') }}
          </p>

          <!-- Add Note Text Area with @mention -->
          <div
            class="relative flex flex-col gap-2 pt-2 border-t border-slate-800"
          >
            <!-- Mention suggestions popup -->
            <div
              v-if="showMentionDropdown && mentionableAgents.length"
              class="absolute bottom-full mb-1 left-0 w-full rounded-lg bg-slate-900 border border-slate-700 shadow-xl overflow-hidden z-20"
            >
              <div
                class="px-2 py-1 text-[10px] font-semibold text-slate-400 uppercase bg-slate-950/60"
              >
                {{ $t('CONTACT_PANEL.DRAWER.MENTION_MEMBER') }}
              </div>
              <button
                v-for="agent in mentionableAgents"
                :key="agent.id"
                type="button"
                class="w-full px-3 py-1.5 text-xs text-left hover:bg-slate-800 flex items-center gap-2 transition-colors"
                @click="insertMention(agent)"
              >
                <Avatar :name="agent.name" :src="agent.thumbnail" :size="20" />
                <span class="truncate text-slate-100 font-medium">{{
                  agent.name
                }}</span>
              </button>
            </div>

            <textarea
              v-model="newNoteContent"
              rows="2"
              :placeholder="$t('CONTACT_PANEL.DRAWER.ADD_NOTE_PLACEHOLDER')"
              class="w-full p-2 text-xs border rounded-lg resize-none bg-slate-950 text-slate-100 border-slate-700 focus:outline-none focus:border-amber-500 placeholder-slate-500"
              @input="onNoteInput"
            />
            <div class="flex items-center justify-between">
              <span
                class="text-[10px] text-amber-400/80 font-medium flex items-center gap-1"
              >
                <span class="i-lucide-lock size-3 block" />
                {{ $t('CONTACT_PANEL.DRAWER.INTERNAL_NOTE_HINT') }}
              </span>
              <Button
                size="xs"
                :disabled="!newNoteContent.trim() || isSubmittingNote"
                :is-loading="isSubmittingNote"
                class="!bg-amber-600 hover:!bg-amber-500 text-white font-medium"
                :label="$t('CONTACT_PANEL.DRAWER.SAVE_NOTE')"
                @click="onAddNote"
              />
            </div>
          </div>
        </div>

        <!-- PERSON IN CHARGE SECTION -->
        <div
          class="flex flex-col gap-2.5 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60 text-xs"
        >
          <div class="flex items-center justify-between">
            <span
              class="text-xs font-semibold tracking-wider text-slate-300 uppercase"
            >
              {{ $t('CONTACT_PANEL.DRAWER.PERSON_IN_CHARGE') }}
            </span>
          </div>

          <!-- Current Assignee Card -->
          <div
            class="flex items-center justify-between p-2 rounded-lg bg-slate-800/50 border border-slate-700/40"
          >
            <div class="flex items-center gap-2 min-w-0">
              <Avatar
                :name="currentAssignee?.name || 'Unassigned'"
                :src="currentAssignee?.thumbnail"
                :size="28"
                :status="currentAssignee?.availability_status"
                hide-offline-status
              />
              <div class="flex flex-col min-w-0">
                <span class="font-medium text-slate-100 truncate">{{
                  currentAssignee?.name || 'Unassigned'
                }}</span>
                <span class="text-[10px] text-slate-400 truncate">{{
                  currentAssignee?.email || 'No agent assigned'
                }}</span>
              </div>
            </div>
            <!-- Assignee Change Dropdown -->
            <select
              :value="currentAssignee?.id || ''"
              class="h-7 px-2 text-xs font-medium border rounded bg-slate-900 text-slate-100 border-slate-700 focus:outline-none focus:border-emerald-500 max-w-[120px] truncate"
              @change="e => onAssigneeChange(e.target.value)"
            >
              <option value="">
                {{ $t('CONTACT_PANEL.DRAWER.UNASSIGN') }}
              </option>
              <option
                v-for="agent in agentsList"
                :key="agent.id"
                :value="agent.id"
              >
                {{ agent.name }}
              </option>
            </select>
          </div>

          <!-- Additional Responsible Agents / Participants -->
          <div
            v-if="participants.length"
            class="flex items-center justify-between pt-1"
          >
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.PARTICIPATING')
            }}</span>
            <div class="flex -space-x-1.5 overflow-hidden">
              <Avatar
                v-for="part in participants"
                :key="part.id"
                :name="part.name"
                :src="part.thumbnail"
                :size="22"
                class="ring-2 ring-slate-900"
              />
            </div>
          </div>
        </div>

        <!-- EXTRA MENU / SECTION -->
        <div
          class="flex flex-col gap-2.5 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60"
        >
          <span
            class="text-xs font-semibold tracking-wider text-slate-300 uppercase"
          >
            {{ $t('CONTACT_PANEL.DRAWER.RECENT_CONVERSATIONS') }}
          </span>
          <ContactConversations
            :contact-id="contactId"
            :conversation-id="conversationId"
          />

          <!-- Linear / External Tickets -->
          <div
            v-if="isLinearFeatureEnabled && isLinearConnected"
            class="pt-2 border-t border-slate-800"
          >
            <LinearIssuesList :conversation-id="conversationId" />
          </div>
        </div>
      </div>

      <!-- TAB 2: CONTACT INFO -->
      <div
        v-show="activeTab === 'contact_info'"
        class="flex flex-col gap-3 p-4 text-xs"
      >
        <div
          class="flex flex-col gap-2.5 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60"
        >
          <!-- Email -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.EMAIL')
            }}</span>
            <div v-if="contact.email" class="flex items-center gap-1.5">
              <a
                :href="`mailto:${contact.email}`"
                class="text-emerald-400 hover:underline truncate max-w-[180px]"
              >
                {{ contact.email }}
              </a>
              <button
                type="button"
                class="text-slate-400 hover:text-slate-100 p-0.5"
                @click="onCopy(contact.email)"
              >
                <span class="i-lucide-copy size-3 block" />
              </button>
            </div>
            <span v-else class="text-slate-500">--</span>
          </div>

          <!-- Phone -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.PHONE')
            }}</span>
            <div v-if="contact.phone_number" class="flex items-center gap-1.5">
              <a
                :href="`tel:${contact.phone_number}`"
                class="text-emerald-400 hover:underline"
              >
                {{ contact.phone_number }}
              </a>
              <button
                type="button"
                class="text-slate-400 hover:text-slate-100 p-0.5"
                @click="onCopy(contact.phone_number)"
              >
                <span class="i-lucide-copy size-3 block" />
              </button>
            </div>
            <span v-else class="text-slate-500">--</span>
          </div>

          <!-- Location -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.LOCATION')
            }}</span>
            <span
              v-if="
                contactAdditionalAttributes.city ||
                contactAdditionalAttributes.country
              "
              class="text-slate-200"
            >
              {{
                [
                  contactAdditionalAttributes.city,
                  contactAdditionalAttributes.country,
                ]
                  .filter(Boolean)
                  .join(', ')
              }}
            </span>
            <span v-else class="text-slate-500">--</span>
          </div>

          <!-- Timezone -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.TIMEZONE')
            }}</span>
            <span class="text-slate-200">{{
              contactAdditionalAttributes.timezone || '--'
            }}</span>
          </div>

          <!-- Language -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.LANGUAGE')
            }}</span>
            <span class="text-slate-200">{{
              contact.locale || contactAdditionalAttributes.language || '--'
            }}</span>
          </div>

          <!-- Customer Since -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.CUSTOMER_SINCE')
            }}</span>
            <span class="text-slate-200">{{
              formatTimestamp(contact.created_at)
            }}</span>
          </div>

          <!-- Last Seen -->
          <div class="flex items-center justify-between">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.LAST_SEEN')
            }}</span>
            <span class="text-slate-200">{{
              formatTimestamp(contact.last_activity_at || contact.created_at)
            }}</span>
          </div>
        </div>
      </div>

      <!-- TAB 3: OTHER -->
      <div
        v-show="activeTab === 'other'"
        class="flex flex-col gap-3 p-4 text-xs"
      >
        <!-- Custom Attributes -->
        <div
          class="flex flex-col gap-2 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60"
        >
          <span
            class="font-semibold tracking-wider text-slate-300 uppercase text-[11px]"
          >
            {{ $t('CONTACT_PANEL.DRAWER.CUSTOM_ATTRIBUTES') }}
          </span>
          <div
            v-if="
              Object.keys(contactCustomAttributes).length ||
              Object.keys(conversationCustomAttributes).length
            "
            class="flex flex-col gap-1.5"
          >
            <div
              v-for="(val, key) in {
                ...contactCustomAttributes,
                ...conversationCustomAttributes,
              }"
              :key="key"
              class="flex items-center justify-between py-1 border-b border-slate-800/40 last:border-0"
            >
              <span class="font-medium text-slate-400 capitalize">{{
                key.replace(/_/g, ' ')
              }}</span>
              <span class="text-slate-200 truncate max-w-[170px]">{{
                val
              }}</span>
            </div>
          </div>
          <p v-else class="text-slate-500 italic py-1">
            {{ $t('CONTACT_PANEL.DRAWER.NO_CUSTOM_ATTRIBUTES') }}
          </p>
        </div>

        <!-- Source & Referer -->
        <div
          v-if="
            contactAdditionalAttributes.source ||
            contactAdditionalAttributes.referer ||
            conversationAdditionalAttributes.referer
          "
          class="flex flex-col gap-2 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60"
        >
          <span
            class="font-semibold tracking-wider text-slate-300 uppercase text-[11px]"
          >
            {{ $t('CONTACT_PANEL.DRAWER.SOURCE') }}
          </span>
          <div class="flex flex-col gap-1">
            <span class="text-slate-400">{{
              $t('CONTACT_PANEL.DRAWER.REFERER')
            }}</span>
            <span class="text-slate-200 break-all font-mono text-[11px]">
              {{
                contactAdditionalAttributes.source ||
                contactAdditionalAttributes.referer ||
                conversationAdditionalAttributes.referer
              }}
            </span>
          </div>
        </div>

        <!-- Campaign & UTM -->
        <div
          v-if="
            conversationAdditionalAttributes.utm_source ||
            contactAdditionalAttributes.utm_source
          "
          class="flex flex-col gap-2 p-3 rounded-xl bg-slate-900/40 border border-slate-800/60"
        >
          <span
            class="font-semibold tracking-wider text-slate-300 uppercase text-[11px]"
          >
            {{ $t('CONTACT_PANEL.DRAWER.CAMPAIGN') }}
          </span>
          <div class="flex flex-col gap-1">
            <div
              v-if="conversationAdditionalAttributes.utm_source"
              class="flex justify-between"
            >
              <span class="text-slate-400">{{
                $t('CONTACT_PANEL.DRAWER.UTM_SOURCE')
              }}</span>
              <span class="text-slate-200">{{
                conversationAdditionalAttributes.utm_source
              }}</span>
            </div>
            <div
              v-if="conversationAdditionalAttributes.utm_medium"
              class="flex justify-between"
            >
              <span class="text-slate-400">{{
                $t('CONTACT_PANEL.DRAWER.UTM_MEDIUM')
              }}</span>
              <span class="text-slate-200">{{
                conversationAdditionalAttributes.utm_medium
              }}</span>
            </div>
            <div
              v-if="conversationAdditionalAttributes.utm_campaign"
              class="flex justify-between"
            >
              <span class="text-slate-400">{{
                $t('CONTACT_PANEL.DRAWER.UTM_CAMPAIGN')
              }}</span>
              <span class="text-slate-200">{{
                conversationAdditionalAttributes.utm_campaign
              }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
  width: 5px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background: rgba(100, 116, 139, 0.3);
  border-radius: 4px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: rgba(100, 116, 139, 0.5);
}
</style>
