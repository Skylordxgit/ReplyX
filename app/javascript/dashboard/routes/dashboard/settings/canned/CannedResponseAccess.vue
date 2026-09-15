<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

import Select from 'dashboard/components-next/select/Select.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const accessScope = defineModel('accessScope', {
  type: String,
  default: 'everyone',
});
const allowedTeamIds = defineModel('allowedTeamIds', {
  type: Array,
  default: () => [],
});
const allowedUserIds = defineModel('allowedUserIds', {
  type: Array,
  default: () => [],
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const accessOptions = computed(() => [
  { value: 'everyone', label: t('CANNED_MGMT.ACCESS.OPTIONS.EVERYONE') },
  {
    value: 'specific_teams',
    label: t('CANNED_MGMT.ACCESS.OPTIONS.SPECIFIC_TEAMS'),
  },
  {
    value: 'specific_users',
    label: t('CANNED_MGMT.ACCESS.OPTIONS.SPECIFIC_USERS'),
  },
  { value: 'only_me', label: t('CANNED_MGMT.ACCESS.OPTIONS.ONLY_ME') },
]);
const teamOptions = computed(() =>
  getters['teams/getTeams'].value.map(team => ({
    value: team.id,
    label: team.name,
  }))
);
const userOptions = computed(() =>
  getters['agents/getVerifiedAgents'].value.map(user => ({
    value: user.id,
    label: user.name || user.email,
  }))
);

onMounted(() => {
  Promise.all([store.dispatch('teams/get'), store.dispatch('agents/get')]);
});
</script>

<template>
  <div class="flex flex-col gap-2 mb-4">
    <label class="mb-0 text-sm font-medium text-n-slate-12">
      {{ t('CANNED_MGMT.ACCESS.LABEL') }}
    </label>
    <Select
      v-model="accessScope"
      :options="accessOptions"
      :aria-label="t('CANNED_MGMT.ACCESS.LABEL')"
      class="!w-full [&>select]:w-full"
    />

    <div v-if="accessScope === 'specific_teams'" class="flex flex-col gap-1">
      <label class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('CANNED_MGMT.ACCESS.TEAMS.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="allowedTeamIds"
        :options="teamOptions"
        :placeholder="t('CANNED_MGMT.ACCESS.TEAMS.PLACEHOLDER')"
        :search-placeholder="t('CANNED_MGMT.ACCESS.TEAMS.SEARCH')"
        :empty-state="t('CANNED_MGMT.ACCESS.TEAMS.EMPTY')"
      />
    </div>

    <div v-if="accessScope === 'specific_users'" class="flex flex-col gap-1">
      <label class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('CANNED_MGMT.ACCESS.USERS.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="allowedUserIds"
        :options="userOptions"
        :placeholder="t('CANNED_MGMT.ACCESS.USERS.PLACEHOLDER')"
        :search-placeholder="t('CANNED_MGMT.ACCESS.USERS.SEARCH')"
        :empty-state="t('CANNED_MGMT.ACCESS.USERS.EMPTY')"
      />
    </div>
  </div>
</template>
