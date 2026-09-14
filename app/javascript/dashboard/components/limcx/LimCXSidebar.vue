<script setup>
import { computed, ref, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import { useWindowSize } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { getPlatformBranding } from 'dashboard/branding/limcxBranding';
import LimCXLogo from './LimCXLogo.vue';
import {
  getUserPermissions,
  hasPermissions,
  getCurrentAccount,
} from 'dashboard/helper/permissionsHelper';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['showCreateAccountModal', 'closeMobileSidebar']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const { width: windowWidth } = useWindowSize();

const uiSettings = computed(() => store?.getters?.getUISettings || {});
const branding = computed(() => getPlatformBranding(uiSettings.value));

const storedCollapsed = () => {
  if (typeof window === 'undefined') return false;
  const local = localStorage.getItem('limcx_sidebar_collapsed');
  if (local !== null) return local === 'true';
  return Boolean(uiSettings.value?.sidebar_collapsed);
};

const collapsed = ref(storedCollapsed());
const expandedGroups = ref({
  savedViews: false,
  channels: {},
});
const showWorkspaceMenu = ref(false);
const versionLabel = 'v4.17';

const isMobile = computed(() => windowWidth.value < 768);

// Effective collapsed state: on mobile drawer it is always expanded
const isEffectivelyCollapsed = computed(
  () => !isMobile.value && collapsed.value
);

const toggleCollapse = () => {
  collapsed.value = !collapsed.value;
  localStorage.setItem('limcx_sidebar_collapsed', String(collapsed.value));
  store?.dispatch('updateUISettings', {
    uiSettings: {
      ...uiSettings.value,
      sidebar_collapsed: collapsed.value,
    },
  });
};

const currentUser = computed(() => store?.getters?.getCurrentUser || {});
const userAccounts = computed(() => currentUser.value?.accounts || []);
const currentAccountId = computed(
  () => store?.getters?.getCurrentAccountId || null
);
const currentAccount = computed(() =>
  getCurrentAccount(currentUser.value, currentAccountId.value)
);
const permissions = computed(() =>
  getUserPermissions(currentUser.value, currentAccountId.value)
);
const isAdmin = computed(() => currentAccount.value?.role === 'administrator');

const canAccess = requiredPermissions => {
  if (isAdmin.value) return true;
  if (!requiredPermissions || !requiredPermissions.length) return true;
  return hasPermissions(requiredPermissions, permissions.value);
};

// Data stores and unread counts
const inboxes = computed(() => store?.getters?.['inboxes/getInboxes'] || []);
const conversationCustomViews = computed(
  () => store?.getters?.['customViews/getConversationCustomViews'] || []
);
const unreadNotificationCount = computed(
  () => store?.getters?.['notifications/getUnreadCount'] || 0
);
const allUnreadCount = computed(
  () => store?.getters?.['conversationUnreadCounts/getAllUnreadCount'] || 0
);
const participatingUnreadCount = computed(
  () =>
    store?.getters?.['conversationUnreadCounts/getParticipatingUnreadCount'] ||
    0
);
const unattendedUnreadCount = computed(
  () =>
    store?.getters?.['conversationUnreadCounts/getUnattendedUnreadCount'] || 0
);
const mentionsUnreadCount = computed(
  () => store?.getters?.['conversationUnreadCounts/getMentionsUnreadCount'] || 0
);
const getFolderUnreadCount = computed(() => {
  const getter =
    store?.getters?.['conversationUnreadCounts/getFolderUnreadCount'];
  return id => (getter ? getter(id) : 0);
});
const getInboxUnreadCount = computed(() => {
  const getter =
    store?.getters?.['conversationUnreadCounts/getInboxUnreadCount'];
  return id => (getter ? getter(id) : 0);
});

const totalFolderUnreadCount = computed(() => {
  return conversationCustomViews.value.reduce(
    (sum, view) => sum + (getFolderUnreadCount.value(view.id) || 0),
    0
  );
});

onMounted(() => {
  if (store) {
    store.dispatch('labels/get').catch(() => {});
    store.dispatch('inboxes/get').catch(() => {});
    store.dispatch('notifications/unReadCount').catch(() => {});
    store.dispatch('teams/get').catch(() => {});
    store.dispatch('attributes/get').catch(() => {});
    store.dispatch('customViews/get', 'conversation').catch(() => {});
    store.dispatch('customViews/get', 'contact').catch(() => {});
    store.dispatch('conversationUnreadCounts/get').catch(() => {});
  }
});

const accountId = computed(() => currentAccountId.value);
const baseParams = computed(() => ({ accountId: accountId.value }));

const isItemActive = item => {
  if (!item) return false;
  if (item.activeOn && Array.isArray(item.activeOn)) {
    if (item.activeOn.includes(route.name)) return true;
  }
  if (route.name === item.routeName) return true;
  return false;
};

const handleNavClick = () => {
  if (isMobile.value) {
    emit('closeMobileSidebar');
  }
};

const switchAccount = targetId => {
  showWorkspaceMenu.value = false;
  if (isMobile.value) {
    emit('closeMobileSidebar');
  }
  window.location.href = `/app/accounts/${targetId}/dashboard`;
};

// Channels mapping definitions
const CHANNEL_CONFIGS = [
  {
    key: 'facebook',
    labelKey: 'SIDEBAR.FACEBOOK',
    defaultLabel: 'Facebook',
    icon: 'i-ri-messenger-fill',
    types: [INBOX_TYPES.FB],
    queryChannel: 'facebook',
  },
  {
    key: 'instagram',
    labelKey: 'SIDEBAR.INSTAGRAM',
    defaultLabel: 'Instagram',
    icon: 'i-ri-instagram-fill',
    types: [INBOX_TYPES.INSTAGRAM],
    queryChannel: 'instagram',
  },
  {
    key: 'whatsapp',
    labelKey: 'SIDEBAR.WHATSAPP',
    defaultLabel: 'WhatsApp',
    icon: 'i-ri-whatsapp-fill',
    types: [INBOX_TYPES.WHATSAPP, INBOX_TYPES.TWILIO],
    medium: 'whatsapp',
    queryChannel: 'whatsapp',
  },
  {
    key: 'telegram',
    labelKey: 'SIDEBAR.TELEGRAM',
    defaultLabel: 'Telegram',
    icon: 'i-ri-telegram-fill',
    types: [INBOX_TYPES.TELEGRAM],
    queryChannel: 'telegram',
  },
  {
    key: 'website',
    labelKey: 'SIDEBAR.WEBSITE_CHAT',
    defaultLabel: 'Website Chat',
    icon: 'i-ri-global-fill',
    types: [INBOX_TYPES.WEB],
    queryChannel: 'website',
  },
  {
    key: 'email',
    labelKey: 'SIDEBAR.EMAIL',
    defaultLabel: 'Email',
    icon: 'i-ri-mail-fill',
    types: [INBOX_TYPES.EMAIL],
    queryChannel: 'email',
  },
];

const computedChannels = computed(() => {
  const allInboxes = inboxes.value;
  return CHANNEL_CONFIGS.map(config => {
    const channelInboxes = allInboxes.filter(inbox => {
      const matchType = config.types.includes(inbox.channel_type);
      if (!matchType) return false;
      if (config.medium && inbox.medium) {
        return inbox.medium === config.medium;
      }
      return true;
    });

    const unreadSum = channelInboxes.reduce(
      (sum, inbox) => sum + (getInboxUnreadCount.value(inbox.id) || 0),
      0
    );

    const hasInboxes = channelInboxes.length > 0;
    const isVisible = hasInboxes || isAdmin.value;

    let targetRoute = null;
    if (hasInboxes) {
      targetRoute = {
        name: 'inbox_dashboard',
        params: { ...baseParams.value, inbox_id: channelInboxes[0].id },
      };
    } else if (isAdmin.value) {
      targetRoute = {
        name: 'settings_inbox_new',
        params: baseParams.value,
        query: { channel: config.queryChannel },
      };
    }

    return {
      ...config,
      label: t(config.labelKey) || config.defaultLabel,
      inboxes: channelInboxes,
      unreadCount: unreadSum,
      isVisible,
      targetRoute,
      hasMultiple: channelInboxes.length > 1,
    };
  }).filter(c => c.isVisible);
});

// Operations items
const operationsItems = computed(() =>
  [
    {
      label: t('SIDEBAR.LIVE_QUEUE'),
      icon: 'i-lucide-activity',
      routeName: 'operations_live_queue',
      activeOn: ['operations_live_queue'],
      to: { name: 'operations_live_queue', params: baseParams.value },
      count: allUnreadCount.value,
      permissions: ['administrator', 'agent', 'conversation_manage'],
    },
    {
      label: t('SIDEBAR.AGENT_WORKLOAD'),
      icon: 'i-lucide-users',
      routeName: 'operations_agent_workload',
      activeOn: ['operations_agent_workload'],
      to: { name: 'operations_agent_workload', params: baseParams.value },
      permissions: ['administrator', 'agent', 'report_manage'],
    },
    {
      label: t('SIDEBAR.TEAM_AVAILABILITY'),
      icon: 'i-lucide-user-check',
      routeName: 'operations_team_availability',
      activeOn: ['operations_team_availability'],
      to: { name: 'operations_team_availability', params: baseParams.value },
      permissions: ['administrator', 'agent', 'report_manage'],
    },
    {
      label: t('SIDEBAR.CHANNEL_HEALTH'),
      icon: 'i-lucide-heart-pulse',
      routeName: 'operations_channel_health',
      activeOn: ['operations_channel_health'],
      to: { name: 'operations_channel_health', params: baseParams.value },
      permissions: ['administrator', 'agent', 'report_manage'],
    },
  ].filter(item => canAccess(item.permissions))
);

// Management items
const managementItems = computed(() =>
  [
    {
      label: t('SIDEBAR.TEAMS'),
      icon: 'i-lucide-users-round',
      routeName: 'settings_teams_list',
      activeOn: [
        'settings_teams_list',
        'settings_teams_new',
        'settings_teams_finish',
        'settings_teams_add_agents',
        'settings_teams_show',
        'settings_teams_edit',
        'settings_teams_edit_members',
        'settings_teams_edit_finish',
      ],
      to: { name: 'settings_teams_list', params: baseParams.value },
      permissions: ['administrator'],
    },
    {
      label: t('SIDEBAR.AGENTS'),
      icon: 'i-lucide-user-cog',
      routeName: 'agent_list',
      activeOn: ['agent_list'],
      to: { name: 'agent_list', params: baseParams.value },
      permissions: ['administrator'],
    },
  ].filter(item => canAccess(item.permissions))
);

// Automation items
const automationItems = computed(() =>
  [
    {
      label: t('SIDEBAR.WORKFLOWS'),
      icon: 'i-lucide-git-branch',
      routeName: 'automation_list',
      activeOn: ['automation_list', 'conversation_workflow_index'],
      to: { name: 'automation_list', params: baseParams.value },
      permissions: ['administrator'],
    },
    {
      label: t('SIDEBAR.CANNED_REPLIES'),
      icon: 'i-lucide-message-square-quote',
      routeName: 'canned_list',
      activeOn: ['canned_list'],
      to: { name: 'canned_list', params: baseParams.value },
      permissions: ['administrator', 'agent', 'custom_role'],
    },
    {
      label: t('SIDEBAR.KNOWLEDGE'),
      icon: 'i-lucide-book-open',
      routeName: 'portals_index',
      activeOn: [
        'portals_index',
        'portals_articles_index',
        'portals_articles_new',
        'portals_articles_edit',
        'portals_categories_index',
        'portals_locales_index',
        'portals_settings_index',
      ],
      to: {
        name: 'portals_index',
        params: {
          ...baseParams.value,
          navigationPath: 'portals_articles_index',
        },
      },
      permissions: ['administrator', 'knowledge_base_manage'],
    },
  ].filter(item => canAccess(item.permissions))
);

// Analytics items
const analyticsItems = computed(() =>
  [
    {
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-bar-chart-3',
      routeName: 'account_overview_reports',
      activeOn: [
        'account_overview_reports',
        'conversation_reports',
        'sla_reports',
        'csat_reports',
        'bot_reports',
      ],
      to: { name: 'account_overview_reports', params: baseParams.value },
      permissions: ['administrator', 'report_manage'],
    },
  ].filter(item => canAccess(item.permissions))
);

// Admin items
const adminItems = computed(() =>
  [
    {
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-settings',
      routeName: 'general_settings_index',
      activeOn: [
        'general_settings_index',
        'settings_home',
        'labels_list',
        'attributes_list',
        'agent_bots',
        'macros_wrapper',
        'settings_applications',
        'settings_data_imports',
        'auditlogs_list',
        'custom_roles_list',
        'sla_list',
        'security_settings_index',
        'billing_settings_index',
        'assignment_policy_index',
        'settings_inbox_list',
      ],
      to: { name: 'general_settings_index', params: baseParams.value },
      permissions: ['administrator'],
    },
  ].filter(item => canAccess(item.permissions))
);

const toggleSavedViews = () => {
  expandedGroups.value.savedViews = !expandedGroups.value.savedViews;
};

const isChannelActive = channel => {
  if (
    route.name === 'inbox_dashboard' ||
    route.name === 'conversation_through_inbox'
  ) {
    return channel.inboxes.some(
      i => String(i.id) === String(route.params.inbox_id)
    );
  }
  if (
    route.name === 'settings_inbox_new' &&
    route.query.channel === channel.queryChannel
  ) {
    return true;
  }
  return false;
};
</script>

<template>
  <!-- Mobile Backdrop Overlay -->
  <div
    v-if="isMobile && isMobileSidebarOpen"
    class="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm md:hidden transition-opacity"
    @click="emit('closeMobileSidebar')"
  />

  <aside
    class="flex flex-col h-full shrink-0 border-r border-slate-800/60 bg-slate-950 dark:bg-slate-950 text-slate-200 transition-all duration-200 ease-in-out select-none z-50"
    :class="[
      isMobile
        ? [
            'fixed inset-y-0 left-0 w-[272px] max-w-[85vw] shadow-2xl',
            isMobileSidebarOpen
              ? 'translate-x-0'
              : '-translate-x-full pointer-events-none',
          ]
        : isEffectivelyCollapsed
          ? 'w-[68px]'
          : 'w-[260px]',
    ]"
  >
    <!-- Header: Brand Logo & Collapse Toggle -->
    <div
      class="flex items-center justify-between gap-2 p-3 border-b border-slate-800/60"
    >
      <div
        class="flex items-center gap-2.5 min-w-0 flex-1"
        :class="{ 'justify-center': isEffectivelyCollapsed }"
      >
        <LimCXLogo :branding="branding" :collapsed="isEffectivelyCollapsed" />
      </div>
      <button
        v-if="!isMobile"
        class="grid flex-shrink-0 rounded-lg size-7 place-items-center text-slate-400 hover:text-white hover:bg-white/10 transition-colors"
        type="button"
        :title="
          isEffectivelyCollapsed
            ? $t('TOPBAR.EXPAND_SIDEBAR')
            : $t('TOPBAR.COLLAPSE_SIDEBAR')
        "
        @click="toggleCollapse"
      >
        <span
          class="size-4"
          :class="
            isEffectivelyCollapsed
              ? 'i-lucide-panel-left-open'
              : 'i-lucide-panel-left-close'
          "
        />
      </button>
      <button
        v-else
        class="grid flex-shrink-0 rounded-lg size-7 place-items-center text-slate-400 hover:text-white hover:bg-white/10"
        type="button"
        @click="emit('closeMobileSidebar')"
      >
        <span class="i-lucide-x size-4" />
      </button>
    </div>

    <!-- Workspace Switcher Area -->
    <div class="relative p-2 border-b border-slate-800/60">
      <button
        v-if="!isEffectivelyCollapsed"
        class="flex items-center justify-between w-full gap-2 px-2.5 py-1.5 text-left text-xs font-medium rounded-lg text-slate-200 hover:bg-white/[0.06] transition-colors group"
        type="button"
        @click="showWorkspaceMenu = !showWorkspaceMenu"
      >
        <div class="flex items-center gap-2 min-w-0">
          <div
            class="grid flex-shrink-0 text-[10px] font-bold text-white rounded size-5 place-items-center bg-blue-600/80"
          >
            {{ (currentAccount?.name || branding.appName)[0]?.toUpperCase() }}
          </div>
          <span class="truncate">{{
            currentAccount?.name || branding.appName
          }}</span>
        </div>
        <span
          class="i-lucide-chevrons-up-down size-3.5 text-slate-400 group-hover:text-white flex-shrink-0 transition-transform"
          :class="{ 'rotate-180': showWorkspaceMenu }"
        />
      </button>

      <button
        v-else
        class="grid place-items-center w-full py-1.5 rounded-lg text-slate-200 hover:bg-white/[0.06] transition-colors"
        type="button"
        :title="`${$t('TOPBAR.SWITCH_WORKSPACE')}: ${
          currentAccount?.name || branding.appName
        }`"
        @click="showWorkspaceMenu = !showWorkspaceMenu"
      >
        <div
          class="grid flex-shrink-0 text-[11px] font-bold text-white rounded-md size-7 place-items-center bg-blue-600/80"
        >
          {{ (currentAccount?.name || branding.appName)[0]?.toUpperCase() }}
        </div>
      </button>

      <!-- Workspace Switcher Dropdown -->
      <div
        v-if="showWorkspaceMenu"
        class="absolute left-2 right-2 top-full z-50 mt-1 p-1 rounded-lg border border-slate-800 bg-slate-900 shadow-xl backdrop-blur-md"
        :class="isEffectivelyCollapsed ? 'w-56 left-2' : 'w-auto'"
      >
        <div
          class="px-2 py-1 text-[10px] font-semibold uppercase text-slate-400 tracking-wider"
        >
          {{ $t('TOPBAR.WORKSPACES') }}
        </div>
        <div class="max-h-48 overflow-y-auto no-scrollbar py-0.5 space-y-0.5">
          <button
            v-for="acc in userAccounts"
            :key="acc.id"
            class="flex items-center justify-between w-full px-2 py-1.5 text-xs rounded-md text-left transition-colors"
            :class="
              Number(acc.id) === Number(currentAccountId)
                ? 'bg-blue-600/20 text-blue-400 font-medium'
                : 'text-slate-300 hover:text-white hover:bg-white/[0.06]'
            "
            type="button"
            @click="switchAccount(acc.id)"
          >
            <span class="truncate">{{ acc.name }}</span>
            <span
              v-if="Number(acc.id) === Number(currentAccountId)"
              class="i-lucide-check size-3.5 text-blue-400 shrink-0"
            />
          </button>
        </div>
        <div class="pt-1 mt-1 border-t border-slate-800">
          <button
            class="flex items-center gap-1.5 w-full px-2 py-1.5 text-xs text-slate-400 hover:text-white hover:bg-white/[0.06] rounded-md text-left transition-colors"
            type="button"
            @click="
              showWorkspaceMenu = false;
              emit('showCreateAccountModal');
            "
          >
            <span class="i-lucide-plus size-3.5" />
            <span>{{ $t('TOPBAR.NEW_WORKSPACE') }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Navigation Area -->
    <nav
      class="flex-1 min-h-0 px-2 py-3 overflow-y-auto overflow-x-hidden no-scrollbar space-y-5"
    >
      <!-- 1. CORE SECTION -->
      <section>
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.CONVERSATIONS') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <!-- Inbox -->
          <li>
            <RouterLink
              :to="{ name: 'inbox_view', params: baseParams }"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive({
                  routeName: 'inbox_view',
                  activeOn: ['inbox_view', 'inbox_view_conversation'],
                })
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? $t('SIDEBAR.INBOX') : undefined"
              @click="handleNavClick"
            >
              <span class="i-lucide-inbox size-4 shrink-0" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                $t('SIDEBAR.INBOX')
              }}</span>
              <span
                v-if="unreadNotificationCount > 0"
                class="rounded-full bg-blue-500 px-1.5 py-0.2 text-[10px] font-semibold text-white min-w-4 text-center"
                :class="{ 'absolute top-1 right-1': isEffectivelyCollapsed }"
              >
                {{ unreadNotificationCount }}
              </span>
            </RouterLink>
          </li>

          <!-- My Chats -->
          <li>
            <RouterLink
              :to="{ name: 'conversation_participating', params: baseParams }"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive({
                  routeName: 'conversation_participating',
                  activeOn: [
                    'conversation_participating',
                    'conversation_through_participating',
                  ],
                })
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="
                isEffectivelyCollapsed ? $t('SIDEBAR.MY_CHATS') : undefined
              "
              @click="handleNavClick"
            >
              <span class="i-lucide-message-square size-4 shrink-0" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                $t('SIDEBAR.MY_CHATS')
              }}</span>
              <span
                v-if="participatingUnreadCount > 0"
                class="rounded-full bg-slate-700 px-1.5 py-0.2 text-[10px] font-semibold text-slate-200 min-w-4 text-center"
              >
                {{ participatingUnreadCount }}
              </span>
            </RouterLink>
          </li>

          <!-- Unassigned -->
          <li>
            <RouterLink
              :to="{ name: 'conversation_unattended', params: baseParams }"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive({
                  routeName: 'conversation_unattended',
                  activeOn: [
                    'conversation_unattended',
                    'conversation_through_unattended',
                  ],
                })
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="
                isEffectivelyCollapsed
                  ? $t('SIDEBAR.UNATTENDED_CONVERSATIONS')
                  : undefined
              "
              @click="handleNavClick"
            >
              <span class="i-lucide-clock-alert size-4 shrink-0" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                $t('SIDEBAR.UNATTENDED_CONVERSATIONS')
              }}</span>
              <span
                v-if="unattendedUnreadCount > 0"
                class="rounded-full bg-amber-500/20 text-amber-300 px-1.5 py-0.2 text-[10px] font-semibold min-w-4 text-center"
              >
                {{ unattendedUnreadCount }}
              </span>
            </RouterLink>
          </li>

          <!-- Mentions -->
          <li>
            <RouterLink
              :to="{ name: 'conversation_mentions', params: baseParams }"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive({
                  routeName: 'conversation_mentions',
                  activeOn: [
                    'conversation_mentions',
                    'conversation_through_mentions',
                  ],
                })
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="
                isEffectivelyCollapsed
                  ? $t('SIDEBAR.MENTIONED_CONVERSATIONS')
                  : undefined
              "
              @click="handleNavClick"
            >
              <span class="i-lucide-at-sign size-4 shrink-0" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                $t('SIDEBAR.MENTIONED_CONVERSATIONS')
              }}</span>
              <span
                v-if="mentionsUnreadCount > 0"
                class="rounded-full bg-purple-500/20 text-purple-300 px-1.5 py-0.2 text-[10px] font-semibold min-w-4 text-center"
              >
                {{ mentionsUnreadCount }}
              </span>
            </RouterLink>
          </li>

          <!-- Saved Views -->
          <li>
            <div>
              <div
                class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group cursor-pointer"
                :class="[
                  isItemActive({
                    routeName: 'folder_conversations',
                    activeOn: [
                      'folder_conversations',
                      'conversations_through_folders',
                    ],
                  })
                    ? 'bg-blue-600/15 text-blue-400 font-medium'
                    : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                  { 'justify-center px-0': isEffectivelyCollapsed },
                ]"
                :title="
                  isEffectivelyCollapsed ? $t('SIDEBAR.SAVED_VIEWS') : undefined
                "
                @click="toggleSavedViews"
              >
                <span class="i-lucide-folder size-4 shrink-0" />
                <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                  $t('SIDEBAR.SAVED_VIEWS')
                }}</span>
                <span
                  v-if="!isEffectivelyCollapsed && totalFolderUnreadCount > 0"
                  class="rounded-full bg-slate-700 px-1.5 py-0.2 text-[10px] font-semibold text-slate-200 min-w-4 text-center"
                >
                  {{ totalFolderUnreadCount }}
                </span>
                <span
                  v-if="
                    !isEffectivelyCollapsed &&
                    conversationCustomViews.length > 0
                  "
                  class="i-lucide-chevron-right size-3 text-slate-500 transition-transform"
                  :class="{ 'rotate-90': expandedGroups.savedViews }"
                />
              </div>

              <!-- Saved Views Sub-items -->
              <ul
                v-if="
                  !isEffectivelyCollapsed &&
                  expandedGroups.savedViews &&
                  conversationCustomViews.length > 0
                "
                class="pl-6 mt-1 space-y-0.5 list-none border-l border-slate-800 ml-4.5"
              >
                <li v-for="view in conversationCustomViews" :key="view.id">
                  <RouterLink
                    :to="{
                      name: 'folder_conversations',
                      params: { ...baseParams, id: view.id },
                    }"
                    class="flex items-center justify-between px-2 py-1 text-[11px] rounded-md text-slate-400 hover:text-white hover:bg-white/[0.04] transition-colors"
                    :class="{
                      'text-blue-400 font-medium bg-blue-500/10':
                        String(route.params.id) === String(view.id),
                    }"
                    @click="handleNavClick"
                  >
                    <span class="truncate">{{ view.name }}</span>
                    <span
                      v-if="getFolderUnreadCount(view.id) > 0"
                      class="text-[10px] text-slate-400"
                    >
                      {{ getFolderUnreadCount(view.id) }}
                    </span>
                  </RouterLink>
                </li>
              </ul>
            </div>
          </li>

          <!-- Customers -->
          <li>
            <RouterLink
              :to="{
                name: 'contacts_dashboard_index',
                params: baseParams,
                query: { page: 1 },
              }"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive({
                  routeName: 'contacts_dashboard_index',
                  activeOn: [
                    'contacts_dashboard_index',
                    'contacts_edit',
                    'contacts_dashboard_active',
                    'contacts_dashboard_segments_index',
                    'contacts_dashboard_labels_index',
                  ],
                })
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="
                isEffectivelyCollapsed ? $t('SIDEBAR.CUSTOMERS') : undefined
              "
              @click="handleNavClick"
            >
              <span class="i-lucide-contact size-4 shrink-0" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                $t('SIDEBAR.CUSTOMERS')
              }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- 2. OPERATIONS SECTION -->
      <section v-if="operationsItems.length > 0">
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.OPERATIONS') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <li v-for="item in operationsItems" :key="item.label">
            <RouterLink
              :to="item.to"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive(item)
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? item.label : undefined"
              @click="handleNavClick"
            >
              <span class="size-4 shrink-0" :class="item.icon" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                item.label
              }}</span>
              <span
                v-if="!isEffectivelyCollapsed && item.count > 0"
                class="rounded-full bg-blue-500/20 text-blue-300 px-1.5 py-0.2 text-[10px] font-semibold min-w-4 text-center"
              >
                {{ item.count }}
              </span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- 3. CHANNELS SECTION -->
      <section v-if="computedChannels.length > 0">
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.CHANNELS') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <li v-for="channel in computedChannels" :key="channel.key">
            <RouterLink
              v-if="channel.targetRoute"
              :to="channel.targetRoute"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isChannelActive(channel)
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? channel.label : undefined"
              @click="handleNavClick"
            >
              <span class="size-4 shrink-0" :class="channel.icon" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                channel.label
              }}</span>
              <span
                v-if="!isEffectivelyCollapsed && channel.unreadCount > 0"
                class="rounded-full bg-blue-500/20 text-blue-300 px-1.5 py-0.2 text-[10px] font-semibold min-w-4 text-center"
              >
                {{ channel.unreadCount }}
              </span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- 4. MANAGEMENT SECTION -->
      <section v-if="managementItems.length > 0">
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.MANAGEMENT') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <li v-for="item in managementItems" :key="item.label">
            <RouterLink
              :to="item.to"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive(item)
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? item.label : undefined"
              @click="handleNavClick"
            >
              <span class="size-4 shrink-0" :class="item.icon" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                item.label
              }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- 5. AUTOMATION SECTION -->
      <section v-if="automationItems.length > 0">
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.AUTOMATION') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <li v-for="item in automationItems" :key="item.label">
            <RouterLink
              :to="item.to"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive(item)
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? item.label : undefined"
              @click="handleNavClick"
            >
              <span class="size-4 shrink-0" :class="item.icon" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                item.label
              }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- 6. ANALYTICS SECTION -->
      <section v-if="analyticsItems.length > 0">
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.REPORTS') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <li v-for="item in analyticsItems" :key="item.label">
            <RouterLink
              :to="item.to"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive(item)
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? item.label : undefined"
              @click="handleNavClick"
            >
              <span class="size-4 shrink-0" :class="item.icon" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                item.label
              }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <!-- 7. ADMIN SECTION -->
      <section v-if="adminItems.length > 0">
        <p
          v-if="!isEffectivelyCollapsed"
          class="px-2.5 mb-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500"
        >
          {{ $t('SIDEBAR.SETTINGS') }}
        </p>
        <ul class="space-y-0.5 m-0 p-0 list-none">
          <li v-for="item in adminItems" :key="item.label">
            <RouterLink
              :to="item.to"
              class="flex items-center gap-2.5 px-2.5 py-1.5 text-xs rounded-lg transition-all group"
              :class="[
                isItemActive(item)
                  ? 'bg-blue-600/15 text-blue-400 font-medium shadow-sm ring-1 ring-blue-500/20'
                  : 'text-slate-300 hover:text-white hover:bg-white/[0.06]',
                { 'justify-center px-0': isEffectivelyCollapsed },
              ]"
              :title="isEffectivelyCollapsed ? item.label : undefined"
              @click="handleNavClick"
            >
              <span class="size-4 shrink-0" :class="item.icon" />
              <span v-if="!isEffectivelyCollapsed" class="flex-1 truncate">{{
                item.label
              }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>
    </nav>

    <!-- Footer: Platform Info -->
    <div
      v-if="!isEffectivelyCollapsed"
      class="p-2.5 border-t border-slate-800/60 text-[11px] text-slate-400 flex items-center justify-between"
    >
      <span class="truncate">{{ branding.productName }}</span>
      <span class="text-slate-500">{{ versionLabel }}</span>
    </div>
  </aside>
</template>
