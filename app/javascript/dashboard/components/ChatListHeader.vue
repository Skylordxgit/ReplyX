<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useI18n } from 'vue-i18n';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
]);

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

const quickFilters = computed(() => [
  { key: 'channel', label: t('SIDEBAR.CHANNELS') },
  { key: 'team', label: t('SIDEBAR.TEAMS') },
  { key: 'status', label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT') },
  { key: 'label', label: t('SIDEBAR.LABELS') },
  { key: 'priority', label: t('FILTER.ATTRIBUTES.PRIORITY') },
]);

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div
    class="flex flex-col gap-2.5 px-3 py-3 border-b border-slate-800/60 bg-slate-950/60"
    :class="{
      'border-slate-700/80': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center justify-center min-w-0">
        <h1
          class="text-sm font-semibold truncate text-slate-100"
          :title="pageTitle"
        >
          {{ pageTitle }}
        </h1>
        <span
          v-if="
            allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
          "
          class="px-2 py-0.5 my-0.5 mx-1.5 rounded-md capitalize bg-slate-800 text-[11px] font-medium text-slate-300 shrink-0"
          :title="String(allCount)"
        >
          {{ formattedAllCount }}
        </span>
        <span
          v-if="!hasAppliedFiltersOrActiveFolders"
          class="px-2 py-0.5 my-0.5 mx-1.5 rounded-md capitalize bg-blue-500/15 text-[11px] font-medium text-blue-300 shrink-0"
        >
          {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
        </span>
      </div>
      <div class="flex items-center gap-1">
        <template v-if="hasAppliedFilters && !hasActiveFolders">
          <div class="relative">
            <NextButton
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
              icon="i-lucide-save"
              slate
              xs
              faded
              @click="emit('addFolders')"
            />
            <div
              id="saveFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
            icon="i-lucide-circle-x"
            ruby
            faded
            xs
            @click="emit('resetFilters')"
          />
        </template>
        <template v-if="hasActiveFolders">
          <div class="relative">
            <NextButton
              id="toggleConversationFilterButton"
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
              icon="i-lucide-pen-line"
              slate
              xs
              faded
              @click="emit('filtersModal')"
            />
            <div
              id="conversationFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
            icon="i-lucide-trash-2"
            ruby
            xs
            faded
            @click="emit('deleteFolders')"
          />
        </template>
        <div v-else class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
            icon="i-lucide-list-filter"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <ConversationBasicFilter
          v-if="!hasAppliedFiltersOrActiveFolders"
          :is-on-expanded-layout="isOnExpandedLayout"
          @change-filter="onBasicFilterChange"
        />
        <SwitchLayout
          :is-on-expanded-layout="isOnExpandedLayout"
          @toggle="toggleConversationLayout"
        />
      </div>
    </div>

    <!-- Search Conversations Trigger Button -->
    <button
      class="flex items-center w-full gap-2 px-2.5 text-xs text-left rounded-lg h-8 text-slate-400 border border-slate-800 bg-slate-900/90 hover:border-blue-500/40 hover:bg-slate-900 transition-colors"
      type="button"
      @click="emit('filtersModal')"
    >
      <span class="i-lucide-search size-3.5 text-slate-400 shrink-0" />
      <span class="truncate">{{
        $t('FILTER.SEARCH_PLACEHOLDER') || 'Search conversations...'
      }}</span>
    </button>

    <!-- Quick Filters Row -->
    <div class="flex items-center gap-1.5 overflow-x-auto no-scrollbar py-0.5">
      <button
        v-for="filter in quickFilters"
        :key="filter.key"
        class="rounded-md border border-slate-800 bg-slate-900/80 px-2 py-0.5 text-[11px] font-medium text-slate-300 hover:text-white hover:border-slate-700 shrink-0 transition-colors"
        type="button"
        @click="emit('filtersModal')"
      >
        {{ filter.label }}
      </button>
    </div>
  </div>
</template>
