<script setup>
import { computed, onMounted, ref } from 'vue';
import format from 'date-fns/format';
import parseISO from 'date-fns/parseISO';
import BarChart from 'shared/components/charts/BarChart.vue';

const stats = ref(null);
const failed = ref(false);

const loading = computed(() => !stats.value && !failed.value);

const fetchStats = async () => {
  try {
    const response = await fetch(window.location.pathname, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    stats.value = await response.json();
  } catch {
    failed.value = true;
  }
};

onMounted(fetchStats);

const chartAriaLabel = 'Conversations created by day';

const chartData = computed(() => {
  const sourceData = stats.value?.chartData || [];
  return {
    categories: sourceData.map(([label]) => format(parseISO(label), 'dd-MMM')),
    series: [
      {
        id: 'conversations',
        label: 'Conversations',
        color: '#2563eb',
        data: sourceData.map(([, value]) => value),
      },
    ],
  };
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text --
    The super admin bundle is mounted standalone and does not install vue-i18n,
    so $t is unavailable here and copy must stay inline. -->
  <div class="w-full min-h-full bg-slate-50/50 p-6 md:p-8 space-y-8">
    <!-- Header -->
    <header
      class="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-200"
    >
      <div>
        <div class="flex items-center gap-2 mb-1">
          <span
            class="inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold bg-blue-100 text-blue-800"
          >
            Limcx Platform
          </span>
          <span class="text-xs text-slate-500 font-mono">
            v{{ stats?.version || '4.17.1' }}
          </span>
        </div>
        <h1
          id="page-title"
          class="text-2xl font-bold text-slate-900 tracking-tight"
        >
          Super Admin Console
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">
          Real-time workspace monitoring, agent telemetry & infrastructure
          health.
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <a
          href="/super_admin/accounts/new"
          class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold shadow-sm transition-colors"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 4v16m8-8H4"
            />
          </svg>
          New Workspace
        </a>
        <a
          href="/super_admin/users/new"
          class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-white hover:bg-slate-50 text-slate-700 border border-slate-300 text-xs font-semibold shadow-sm transition-colors"
        >
          <svg
            class="w-4 h-4 text-slate-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
            />
          </svg>
          New User
        </a>
        <a
          href="/super_admin/instance_status"
          class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg bg-white hover:bg-slate-50 text-slate-700 border border-slate-300 text-xs font-semibold shadow-sm transition-colors"
        >
          <svg
            class="w-4 h-4 text-slate-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          System Health
        </a>
      </div>
    </header>

    <!-- Top KPI Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Workspaces Card -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex flex-col justify-between"
      >
        <div class="flex items-center justify-between">
          <span
            class="text-xs font-semibold uppercase tracking-wider text-slate-500"
          >
            Workspaces
          </span>
          <span class="p-2 rounded-lg bg-blue-50 text-blue-600">
            <svg
              class="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
              />
            </svg>
          </span>
        </div>
        <div class="mt-4">
          <div
            v-if="loading"
            class="h-8 w-24 bg-slate-200 animate-pulse rounded"
          />
          <div v-else class="text-3xl font-bold text-slate-900 tracking-tight">
            {{ stats?.accountsCount || '0' }}
          </div>
          <div class="flex items-center gap-2 mt-2 text-xs text-slate-600">
            <span
              class="inline-flex items-center gap-1 font-medium text-emerald-600"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500" />
              {{ stats?.accountsActive || '0' }} active
            </span>
            <span
              v-if="stats?.accountsSuspended > 0"
              class="text-amber-600 font-medium"
            >
              • {{ stats?.accountsSuspended }} suspended
            </span>
          </div>
        </div>
        <a
          href="/super_admin/accounts"
          class="mt-4 text-xs font-medium text-blue-600 hover:text-blue-700 inline-flex items-center gap-1"
        >
          Manage Workspaces &rarr;
        </a>
      </div>

      <!-- Users & Agents Card -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex flex-col justify-between"
      >
        <div class="flex items-center justify-between">
          <span
            class="text-xs font-semibold uppercase tracking-wider text-slate-500"
          >
            Platform Users
          </span>
          <span class="p-2 rounded-lg bg-indigo-50 text-indigo-600">
            <svg
              class="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
              />
            </svg>
          </span>
        </div>
        <div class="mt-4">
          <div
            v-if="loading"
            class="h-8 w-24 bg-slate-200 animate-pulse rounded"
          />
          <div v-else class="text-3xl font-bold text-slate-900 tracking-tight">
            {{ stats?.usersCount || '0' }}
          </div>
          <div class="flex items-center gap-2 mt-2 text-xs text-slate-600">
            <span
              class="inline-flex items-center gap-1 font-medium text-emerald-600"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500" />
              {{ stats?.usersOnline || '0' }} online now
            </span>
            <span>• {{ stats?.usersActive30d || '0' }} active (30d)</span>
          </div>
        </div>
        <a
          href="/super_admin/users"
          class="mt-4 text-xs font-medium text-indigo-600 hover:text-indigo-700 inline-flex items-center gap-1"
        >
          View All Users &rarr;
        </a>
      </div>

      <!-- Conversations Card -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex flex-col justify-between"
      >
        <div class="flex items-center justify-between">
          <span
            class="text-xs font-semibold uppercase tracking-wider text-slate-500"
          >
            Conversations
          </span>
          <span class="p-2 rounded-lg bg-violet-50 text-violet-600">
            <svg
              class="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
              />
            </svg>
          </span>
        </div>
        <div class="mt-4">
          <div
            v-if="loading"
            class="h-8 w-24 bg-slate-200 animate-pulse rounded"
          />
          <div v-else class="text-3xl font-bold text-slate-900 tracking-tight">
            {{ stats?.conversationsCount || '0' }}
          </div>
          <div class="flex items-center gap-2 mt-2 text-xs text-slate-600">
            <span class="font-medium text-violet-600">
              {{ stats?.conversationsToday || '0' }} today
            </span>
            <span>• {{ stats?.conversationsOpen || '0' }} open</span>
          </div>
        </div>
        <span class="mt-4 text-xs font-medium text-slate-400">
          Estimated across all workspaces
        </span>
      </div>

      <!-- Inboxes & Channel Errors Card -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex flex-col justify-between"
      >
        <div class="flex items-center justify-between">
          <span
            class="text-xs font-semibold uppercase tracking-wider text-slate-500"
          >
            Inboxes & Channels
          </span>
          <span class="p-2 rounded-lg bg-emerald-50 text-emerald-600">
            <svg
              class="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
              />
            </svg>
          </span>
        </div>
        <div class="mt-4">
          <div
            v-if="loading"
            class="h-8 w-24 bg-slate-200 animate-pulse rounded"
          />
          <div v-else class="text-3xl font-bold text-slate-900 tracking-tight">
            {{ stats?.inboxesCount || '0' }}
          </div>
          <div class="flex items-center gap-2 mt-2 text-xs">
            <span
              v-if="stats?.inboxesReauthCount > 0"
              class="inline-flex items-center gap-1 font-semibold text-rose-600"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-rose-500 animate-ping" />
              {{ stats?.inboxesReauthCount }} require re-auth
            </span>
            <span v-else class="text-emerald-600 font-medium">
              ✓ All channels connected
            </span>
          </div>
        </div>
        <a
          href="/super_admin/settings"
          class="mt-4 text-xs font-medium text-emerald-600 hover:text-emerald-700 inline-flex items-center gap-1"
        >
          Channel Settings &rarr;
        </a>
      </div>
    </div>

    <!-- Middle Section: Queue Health + Background Workers -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Queue Health -->
      <div
        class="bg-white rounded-xl p-6 border border-slate-200 shadow-sm space-y-4"
      >
        <div
          class="flex items-center justify-between pb-3 border-b border-slate-100"
        >
          <h2
            class="text-sm font-bold text-slate-900 uppercase tracking-wider flex items-center gap-2"
          >
            <span class="w-2 h-2 rounded-full bg-blue-500" />
            Live Queue & Routing Health
          </h2>
          <span class="text-xs text-slate-400">Global aggregation</span>
        </div>

        <div class="grid grid-cols-3 gap-4">
          <div class="p-4 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xs font-medium text-slate-500">Open Tickets</div>
            <div class="text-2xl font-bold text-slate-900 mt-1">
              {{ stats?.conversationsOpen || '0' }}
            </div>
            <div class="text-xxs text-slate-400 mt-0.5">
              Active across workspaces
            </div>
          </div>
          <div class="p-4 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xs font-medium text-slate-500">Unassigned</div>
            <div class="text-2xl font-bold text-amber-600 mt-1">
              {{ stats?.conversationsUnassigned || '0' }}
            </div>
            <div class="text-xxs text-slate-400 mt-0.5">
              Pending agent allocation
            </div>
          </div>
          <div class="p-4 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xs font-medium text-slate-500">Agents Online</div>
            <div class="text-2xl font-bold text-emerald-600 mt-1">
              {{ stats?.usersOnline || '0' }}
            </div>
            <div class="text-xxs text-slate-400 mt-0.5">
              Available for routing
            </div>
          </div>
        </div>
      </div>

      <!-- Workers & Jobs (Sidekiq) -->
      <div
        class="bg-white rounded-xl p-6 border border-slate-200 shadow-sm space-y-4"
      >
        <div
          class="flex items-center justify-between pb-3 border-b border-slate-100"
        >
          <h2
            class="text-sm font-bold text-slate-900 uppercase tracking-wider flex items-center gap-2"
          >
            <span class="w-2 h-2 rounded-full bg-emerald-500" />
            Background Workers & Jobs (Sidekiq)
          </h2>
          <a
            href="/monitoring/sidekiq"
            target="_blank"
            class="text-xs text-blue-600 hover:text-blue-700 font-medium"
          >
            Sidekiq UI &rarr;
          </a>
        </div>

        <div class="grid grid-cols-4 gap-3">
          <div class="p-3 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xxs font-medium text-slate-500 uppercase">
              Enqueued
            </div>
            <div class="text-lg font-bold text-slate-900 mt-0.5">
              {{ stats?.sidekiq?.enqueued ?? '0' }}
            </div>
          </div>
          <div class="p-3 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xxs font-medium text-slate-500 uppercase">
              Processed
            </div>
            <div class="text-lg font-bold text-emerald-600 mt-0.5">
              {{ stats?.sidekiq?.processed ?? '0' }}
            </div>
          </div>
          <div class="p-3 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xxs font-medium text-slate-500 uppercase">
              Failed
            </div>
            <div
              class="text-lg font-bold mt-0.5"
              :class="
                stats?.sidekiq?.failed > 0 ? 'text-rose-600' : 'text-slate-900'
              "
            >
              {{ stats?.sidekiq?.failed ?? '0' }}
            </div>
          </div>
          <div class="p-3 rounded-lg bg-slate-50 border border-slate-100">
            <div class="text-xxs font-medium text-slate-500 uppercase">
              Retries / Dead
            </div>
            <div
              class="text-lg font-bold mt-0.5"
              :class="
                stats?.sidekiq?.retry_size > 0 || stats?.sidekiq?.dead_size > 0
                  ? 'text-amber-600'
                  : 'text-slate-900'
              "
            >
              {{
                (stats?.sidekiq?.retry_size || 0) +
                ' / ' +
                (stats?.sidekiq?.dead_size || 0)
              }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Infrastructure Telemetry Row -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <!-- Database Health -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex items-center justify-between"
      >
        <div class="space-y-1">
          <div
            class="text-xs font-semibold text-slate-500 uppercase tracking-wider"
          >
            PostgreSQL Database
          </div>
          <div class="flex items-center gap-2">
            <span
              class="w-2.5 h-2.5 rounded-full"
              :class="stats?.postgres?.alive ? 'bg-emerald-500' : 'bg-rose-500'"
            />
            <span class="text-sm font-bold text-slate-900">
              {{
                stats?.postgres?.alive ? 'Healthy & Connected' : 'Disconnected'
              }}
            </span>
          </div>
          <div class="text-xs text-slate-500">
            Pool: {{ stats?.postgres?.connections_in_use || 0 }} in use /
            {{ stats?.postgres?.pool_size || 5 }} max
          </div>
        </div>
        <span class="p-3 rounded-xl bg-slate-50 text-slate-600">
          <svg
            class="w-6 h-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"
            />
          </svg>
        </span>
      </div>

      <!-- Redis Cache & Broker -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex items-center justify-between"
      >
        <div class="space-y-1">
          <div
            class="text-xs font-semibold text-slate-500 uppercase tracking-wider"
          >
            Redis Cache & Broker
          </div>
          <div class="flex items-center gap-2">
            <span
              class="w-2.5 h-2.5 rounded-full"
              :class="stats?.redis?.alive ? 'bg-emerald-500' : 'bg-rose-500'"
            />
            <span class="text-sm font-bold text-slate-900">
              {{
                stats?.redis?.alive
                  ? 'Connected (v' + (stats?.redis?.version || '') + ')'
                  : 'Unavailable'
              }}
            </span>
          </div>
          <div class="text-xs text-slate-500">
            Memory: {{ stats?.redis?.used_memory || 'N/A' }} •
            {{ stats?.redis?.connected_clients || 0 }} clients
          </div>
        </div>
        <span class="p-3 rounded-xl bg-slate-50 text-slate-600">
          <svg
            class="w-6 h-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            />
          </svg>
        </span>
      </div>

      <!-- Storage & Blobs -->
      <div
        class="bg-white rounded-xl p-5 border border-slate-200 shadow-sm flex items-center justify-between"
      >
        <div class="space-y-1">
          <div
            class="text-xs font-semibold text-slate-500 uppercase tracking-wider"
          >
            Storage & Attachments
          </div>
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-full bg-emerald-500" />
            <span class="text-sm font-bold text-slate-900">
              {{ stats?.storage?.total_size || '0 B' }} Total
            </span>
          </div>
          <div class="text-xs text-slate-500">
            Provider: {{ stats?.storage?.service || 'Local' }} •
            {{ stats?.storage?.count || 0 }} files
          </div>
        </div>
        <span class="p-3 rounded-xl bg-slate-50 text-slate-600">
          <svg
            class="w-6 h-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
            />
          </svg>
        </span>
      </div>
    </div>

    <!-- 30-Day Activity Chart -->
    <div
      class="bg-white rounded-xl p-6 border border-slate-200 shadow-sm space-y-4"
    >
      <div
        class="flex items-center justify-between pb-3 border-b border-slate-100"
      >
        <div>
          <h2 class="text-base font-bold text-slate-900">
            30-Day Platform Activity Trend
          </h2>
          <p class="text-xs text-slate-500">
            Total conversation volume across all workspaces over time
          </p>
        </div>
        <span class="text-xs text-slate-400 font-mono">Daily aggregate</span>
      </div>

      <div v-if="loading" class="h-64 rounded-lg bg-slate-100 animate-pulse" />
      <div v-else-if="!failed" class="w-full min-w-0">
        <BarChart
          :data="chartData"
          :height="360"
          timeseries
          :aria-label="chartAriaLabel"
        />
      </div>
    </div>
  </div>
</template>
