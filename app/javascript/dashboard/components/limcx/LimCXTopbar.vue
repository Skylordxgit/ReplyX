<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { getPlatformBranding } from 'dashboard/branding/limcxBranding';
import Auth from 'dashboard/api/auth';
import { getCurrentAccount } from 'dashboard/helper/permissionsHelper';
import { vOnClickOutside } from '@vueuse/components';

const emit = defineEmits([
  'openKeyShortcutModal',
  'showCreateAccountModal',
  'toggleMobileSidebar',
]);

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const searchShortcut = useKbd(['$mod', 'k']);

const uiSettings = computed(() => store?.getters?.getUISettings || {});
const branding = computed(() => getPlatformBranding(uiSettings.value));
const currentUser = computed(() => store?.getters?.getCurrentUser || {});
const userAccounts = computed(() => currentUser.value?.accounts || []);
const currentAccountId = computed(
  () => store?.getters?.getCurrentAccountId || null
);
const currentAccount = computed(() =>
  getCurrentAccount(currentUser.value, currentAccountId.value)
);
const currentUserAvailability = computed(
  () => store?.getters?.getCurrentUserAvailability || 'offline'
);
const unreadNotificationCount = computed(
  () => store?.getters?.['notifications/getUnreadCount'] || 0
);
const isSuperAdmin = computed(() => currentUser.value?.type === 'SuperAdmin');

// Dropdown states
const showStatusDropdown = ref(false);
const showProfileDropdown = ref(false);
const showWorkspaceDropdown = ref(false);
const localStatus = ref(null);

const statuses = computed(() => [
  {
    key: 'online',
    label: t('TOPBAR.STATUS_AVAILABLE'),
    dotClass: 'bg-emerald-500 ring-4 ring-emerald-500/20',
  },
  {
    key: 'busy',
    label: t('TOPBAR.STATUS_BUSY'),
    dotClass: 'bg-amber-500 ring-4 ring-amber-500/20',
  },
  {
    key: 'away',
    label: t('TOPBAR.STATUS_BREAK'),
    dotClass: 'bg-orange-500 ring-4 ring-orange-500/20',
  },
  {
    key: 'offline',
    label: t('TOPBAR.STATUS_OFFLINE'),
    dotClass: 'bg-slate-500 ring-4 ring-slate-500/20',
  },
]);

const currentStatusObj = computed(() => {
  if (localStatus.value) {
    const found = statuses.value.find(s => s.key === localStatus.value);
    if (found) return found;
  }
  const avail = currentUserAvailability.value;
  return statuses.value.find(s => s.key === avail) || statuses.value[0];
});

const onSelectStatus = statusKey => {
  localStatus.value = statusKey;
  showStatusDropdown.value = false;
  const backendStatus = statusKey === 'away' ? 'busy' : statusKey;
  if (store) {
    store
      .dispatch('updateAvailability', {
        availability: backendStatus,
        account_id: currentAccountId.value,
      })
      .catch(() => {});
  }
};

const openGlobalSearch = () => {
  const ninja = document.querySelector('ninja-keys');
  if (ninja && typeof ninja.open === 'function') {
    ninja.open();
  } else if (currentAccountId.value) {
    router.push({
      name: 'search',
      params: { accountId: currentAccountId.value },
    });
  }
};

const openAppearance = () => {
  showProfileDropdown.value = false;
  const ninja = document.querySelector('ninja-keys');
  if (ninja && typeof ninja.open === 'function') {
    ninja.open({ parent: 'appearance_settings' });
  }
};

const navigateToNotifications = () => {
  if (currentAccountId.value) {
    router.push({
      name: 'inbox_view',
      params: { accountId: currentAccountId.value },
    });
  }
};

const navigateToProfile = () => {
  showProfileDropdown.value = false;
  if (currentAccountId.value) {
    router.push({
      name: 'profile_settings_index',
      params: { accountId: currentAccountId.value },
    });
  }
};

const switchAccount = targetId => {
  showWorkspaceDropdown.value = false;
  window.location.href = `/app/accounts/${targetId}/dashboard`;
};

const handleLogout = () => {
  showProfileDropdown.value = false;
  Auth.logout();
};
</script>

<template>
  <header
    class="flex h-14 shrink-0 items-center justify-between gap-3 border-b border-slate-800/60 bg-slate-900/90 dark:bg-slate-900/90 px-3 sm:px-4 z-30 select-none backdrop-blur-md"
  >
    <!-- Left: Mobile Toggle & Global Search -->
    <div class="flex items-center gap-2.5 flex-1 min-w-0 max-w-xl">
      <!-- Mobile Drawer Trigger -->
      <button
        class="grid rounded-lg size-8 place-items-center text-slate-300 hover:text-white hover:bg-white/[0.08] transition-colors md:hidden shrink-0"
        type="button"
        :title="$t('TOPBAR.OPEN_NAVIGATION')"
        @click="emit('toggleMobileSidebar')"
      >
        <span class="i-lucide-menu size-5" />
      </button>

      <!-- Global Search Bar -->
      <button
        class="flex min-w-0 flex-1 items-center gap-2.5 rounded-lg border border-slate-800 bg-slate-950/80 px-3 text-left text-slate-400 h-9 hover:border-blue-500/50 hover:bg-white/[0.03] transition-all group"
        type="button"
        @click="openGlobalSearch"
      >
        <span
          class="i-lucide-search size-4 text-slate-400 group-hover:text-blue-400 shrink-0 transition-colors"
        />
        <span class="hidden truncate text-xs sm:inline-block">
          {{ $t('TOPBAR.SEARCH_PLACEHOLDER') }}
        </span>
        <span class="inline-block truncate text-xs sm:hidden">
          {{ $t('TOPBAR.SEARCH_SHORT') }}
        </span>
        <span
          class="ml-auto hidden rounded border border-slate-700/60 bg-white/[0.04] px-1.5 py-0.5 text-[10px] font-mono text-slate-400 sm:inline-block shadow-sm"
        >
          {{ searchShortcut || '⌘K' }}
        </span>
      </button>
    </div>

    <!-- Right: Workspace Switcher, Availability, Notifications, Avatar & Profile -->
    <div class="flex items-center gap-2 shrink-0">
      <!-- Workspace Switcher (Header level) -->
      <div
        v-if="userAccounts.length > 1"
        v-on-click-outside="() => (showWorkspaceDropdown = false)"
        class="relative hidden md:block"
      >
        <button
          class="flex items-center gap-1.5 rounded-lg border border-slate-800 bg-slate-950/50 px-2.5 h-8 text-xs font-medium text-slate-300 hover:text-white hover:bg-white/[0.06] transition-colors"
          type="button"
          @click="showWorkspaceDropdown = !showWorkspaceDropdown"
        >
          <span class="i-lucide-building size-3.5 text-slate-400" />
          <span class="truncate max-w-[100px] lg:max-w-[140px]">
            {{ currentAccount?.name || branding.appName }}
          </span>
          <span class="i-lucide-chevron-down size-3 text-slate-500" />
        </button>

        <div
          v-if="showWorkspaceDropdown"
          class="absolute right-0 top-full mt-1.5 w-56 rounded-lg border border-slate-800 bg-slate-900 shadow-xl z-50 backdrop-blur-md p-1"
        >
          <div
            class="px-2 py-1 text-[10px] font-semibold uppercase text-slate-400 tracking-wider"
          >
            {{ $t('TOPBAR.SWITCH_WORKSPACE') }}
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
                showWorkspaceDropdown = false;
                emit('showCreateAccountModal');
              "
            >
              <span class="i-lucide-plus size-3.5" />
              <span>{{ $t('TOPBAR.NEW_WORKSPACE') }}</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Availability Selector -->
      <div
        v-on-click-outside="() => (showStatusDropdown = false)"
        class="relative"
      >
        <button
          class="flex items-center gap-2 rounded-lg border border-slate-800 bg-slate-950/50 px-2.5 h-8 text-xs font-medium text-slate-200 hover:bg-white/[0.06] transition-colors"
          type="button"
          @click="showStatusDropdown = !showStatusDropdown"
        >
          <span
            class="size-2 rounded-full shrink-0"
            :class="currentStatusObj.dotClass"
          />
          <span class="hidden sm:inline-block">{{
            currentStatusObj.label
          }}</span>
          <span class="i-lucide-chevron-down size-3 text-slate-400" />
        </button>

        <!-- Availability Dropdown Menu -->
        <div
          v-if="showStatusDropdown"
          class="absolute right-0 top-full mt-1.5 w-40 rounded-lg border border-slate-800 bg-slate-900 shadow-xl z-50 backdrop-blur-md p-1"
        >
          <div
            class="px-2 py-1 text-[10px] font-semibold uppercase text-slate-400 tracking-wider"
          >
            {{ $t('TOPBAR.AVAILABILITY') }}
          </div>
          <button
            v-for="status in statuses"
            :key="status.key"
            class="flex items-center gap-2.5 w-full px-2 py-1.5 text-xs rounded-md text-left transition-colors"
            :class="
              currentStatusObj.key === status.key
                ? 'bg-blue-600/20 text-blue-400 font-medium'
                : 'text-slate-300 hover:text-white hover:bg-white/[0.06]'
            "
            type="button"
            @click="onSelectStatus(status.key)"
          >
            <span
              class="size-2 rounded-full shrink-0"
              :class="status.dotClass"
            />
            <span class="flex-1">{{ status.label }}</span>
            <span
              v-if="currentStatusObj.key === status.key"
              class="i-lucide-check size-3.5 text-blue-400 shrink-0"
            />
          </button>
        </div>
      </div>

      <!-- Notifications Bell -->
      <button
        class="relative grid rounded-lg border border-slate-800 bg-slate-950/50 size-8 place-items-center text-slate-300 hover:text-white hover:bg-white/[0.06] transition-colors"
        type="button"
        :title="$t('TOPBAR.NOTIFICATIONS')"
        @click="navigateToNotifications"
      >
        <span class="i-lucide-bell size-4" />
        <span
          v-if="unreadNotificationCount > 0"
          class="absolute -top-1 -right-1 flex size-4 items-center justify-center rounded-full bg-blue-500 text-[10px] font-bold text-white shadow-sm"
        >
          {{ unreadNotificationCount > 9 ? '9+' : unreadNotificationCount }}
        </span>
      </button>

      <!-- User Avatar & Profile Dropdown -->
      <div
        v-on-click-outside="() => (showProfileDropdown = false)"
        class="relative"
      >
        <button
          class="flex items-center gap-1.5 p-0.5 rounded-full hover:ring-2 hover:ring-blue-500/40 transition-all cursor-pointer"
          type="button"
          @click="showProfileDropdown = !showProfileDropdown"
        >
          <Avatar
            :name="currentUser.name || currentUser.available_name || 'User'"
            :src="currentUser.avatar_url"
            :size="30"
            :status="
              currentStatusObj.key === 'away' ? 'busy' : currentStatusObj.key
            "
            hide-offline-status
          />
        </button>

        <!-- Profile Dropdown Menu -->
        <div
          v-if="showProfileDropdown"
          class="absolute right-0 top-full mt-1.5 w-64 rounded-lg border border-slate-800 bg-slate-900 shadow-2xl z-50 backdrop-blur-md p-1"
        >
          <!-- User info header -->
          <div class="px-3 py-2 border-b border-slate-800">
            <div class="text-xs font-semibold text-white truncate">
              {{ currentUser.name || currentUser.available_name }}
            </div>
            <div class="text-[11px] text-slate-400 truncate">
              {{ currentUser.email }}
            </div>
            <div class="mt-1 flex items-center gap-1">
              <span
                class="rounded bg-blue-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-blue-300 capitalize"
              >
                {{ currentAccount?.role || 'Agent' }}
              </span>
            </div>
          </div>

          <div class="py-1 space-y-0.5">
            <!-- Profile Settings -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-1.5 text-xs text-slate-300 hover:text-white hover:bg-white/[0.06] rounded-md text-left transition-colors"
              type="button"
              @click="navigateToProfile"
            >
              <span class="i-lucide-user size-4 text-slate-400" />
              <span>{{ $t('SIDEBAR_ITEMS.PROFILE_SETTINGS') }}</span>
            </button>

            <!-- Appearance -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-1.5 text-xs text-slate-300 hover:text-white hover:bg-white/[0.06] rounded-md text-left transition-colors"
              type="button"
              @click="openAppearance"
            >
              <span class="i-lucide-palette size-4 text-slate-400" />
              <span>{{ $t('SIDEBAR_ITEMS.APPEARANCE') }}</span>
            </button>

            <!-- Keyboard Shortcuts -->
            <button
              class="flex items-center gap-2 w-full px-2.5 py-1.5 text-xs text-slate-300 hover:text-white hover:bg-white/[0.06] rounded-md text-left transition-colors"
              type="button"
              @click="
                showProfileDropdown = false;
                emit('openKeyShortcutModal');
              "
            >
              <span class="i-lucide-keyboard size-4 text-slate-400" />
              <span>{{ $t('SIDEBAR_ITEMS.KEYBOARD_SHORTCUTS') }}</span>
            </button>

            <!-- Documentation -->
            <a
              :href="
                branding.documentationURL ||
                'https://www.chatwoot.com/hc/user-guide/en'
              "
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-2 w-full px-2.5 py-1.5 text-xs text-slate-300 hover:text-white hover:bg-white/[0.06] rounded-md text-left transition-colors"
              @click="showProfileDropdown = false"
            >
              <span class="i-lucide-book-open size-4 text-slate-400" />
              <span>{{ $t('SIDEBAR_ITEMS.DOCS') }}</span>
            </a>

            <!-- Super Admin Console -->
            <a
              v-if="isSuperAdmin"
              href="/super_admin"
              class="flex items-center gap-2 w-full px-2.5 py-1.5 text-xs text-slate-300 hover:text-white hover:bg-white/[0.06] rounded-md text-left transition-colors"
              @click="showProfileDropdown = false"
            >
              <span class="i-lucide-shield size-4 text-slate-400" />
              <span>{{ $t('SIDEBAR_ITEMS.SUPER_ADMIN_CONSOLE') }}</span>
            </a>
          </div>

          <div class="pt-1 mt-1 border-t border-slate-800">
            <button
              class="flex items-center gap-2 w-full px-2.5 py-1.5 text-xs text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 rounded-md text-left transition-colors"
              type="button"
              @click="handleLogout"
            >
              <span class="i-lucide-log-out size-4" />
              <span>{{ $t('SIDEBAR_ITEMS.LOGOUT') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>
