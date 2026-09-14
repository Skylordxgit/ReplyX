<script setup>
import { computed } from 'vue';
import CustomerDetailsDrawer from './CustomerDetailsDrawer.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import wootConstants from 'dashboard/constants/globals';

defineProps({
  currentChat: {
    required: true,
    type: Object,
  },
});

const { uiSettings, updateUISettings } = useUISettings();
const { width: windowWidth } = useWindowSize();

const isOpen = computed(() => !!uiSettings.value?.is_contact_sidebar_open);

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const closeDrawer = () => {
  if (isSmallScreen.value && isOpen.value) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    });
  }
};
</script>

<template>
  <div class="h-full">
    <div
      v-if="isOpen"
      v-on-click-outside="[
        () => closeDrawer(),
        {
          ignore: [
            'dialog.ProseMirror-prompt-backdrop',
            '[data-popover-content]',
            '[data-popover-backdrop]',
            '#conversation-details-toggle',
          ],
        },
      ]"
      class="h-full overflow-hidden flex flex-col fixed top-0 z-40 w-full max-w-sm transition-transform duration-300 ease-in-out ltr:right-0 rtl:left-0 lg:static lg:w-auto lg:max-w-none shadow-2xl lg:shadow-none"
    >
      <CustomerDetailsDrawer
        :conversation-id="currentChat.id"
        :inbox-id="currentChat.inbox_id"
        @close="closeDrawer"
      />
    </div>
  </div>
</template>
