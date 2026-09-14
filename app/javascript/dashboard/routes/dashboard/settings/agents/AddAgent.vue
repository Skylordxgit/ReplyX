<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, email } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const agentName = ref('');
const agentEmail = ref('');
const selectedRoleId = ref('agent');
const agentPassword = ref('');
const agentPasswordConfirmation = ref('');
const forcePasswordChange = ref(true);
const showPassword = ref(false);
const showPasswordConfirmation = ref(false);

const rules = {
  agentName: { required },
  agentEmail: { required, email },
  selectedRoleId: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  agentEmail,
  selectedRoleId,
});

const passwordRules = computed(() => [
  {
    key: 'length',
    label: t('AGENT_MGMT.ADD.PASSWORD_RULES.LENGTH', 'At least 6 characters'),
    valid: agentPassword.value.length >= 6,
  },
  {
    key: 'uppercase',
    label: t(
      'AGENT_MGMT.ADD.PASSWORD_RULES.UPPERCASE',
      'At least 1 uppercase letter'
    ),
    valid: /[A-Z]/.test(agentPassword.value),
  },
  {
    key: 'lowercase',
    label: t(
      'AGENT_MGMT.ADD.PASSWORD_RULES.LOWERCASE',
      'At least 1 lowercase letter'
    ),
    valid: /[a-z]/.test(agentPassword.value),
  },
  {
    key: 'number',
    label: t('AGENT_MGMT.ADD.PASSWORD_RULES.NUMBER', 'At least 1 number'),
    valid: /[0-9]/.test(agentPassword.value),
  },
  {
    key: 'special',
    label: t(
      'AGENT_MGMT.ADD.PASSWORD_RULES.SPECIAL',
      'At least 1 special character (!@#$%^&*...)'
    ),
    valid: /[!@#$%^&*()_+\-=[\]{}|']/.test(agentPassword.value),
  },
  {
    key: 'match',
    label: t('AGENT_MGMT.ADD.PASSWORD_RULES.MATCH', 'Passwords match'),
    valid:
      agentPassword.value.length > 0 &&
      agentPassword.value === agentPasswordConfirmation.value,
  },
]);

const isPasswordProvided = computed(() => agentPassword.value.length > 0);
const isPasswordValid = computed(() => {
  if (!isPasswordProvided.value) return true;
  return passwordRules.value.every(r => r.valid);
});

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const addAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid || !isPasswordValid.value) return;

  try {
    const payload = {
      name: agentName.value,
      email: agentEmail.value,
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
    }

    if (isPasswordProvided.value) {
      payload.password = agentPassword.value;
      payload.password_confirmation = agentPasswordConfirmation.value;
      payload.force_password_change = forcePasswordChange.value;
    }

    await store.dispatch('agents/create', payload);
    useAlert(t('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    const {
      response: {
        data: {
          error: errorResponse = '',
          attributes: attributes = [],
          message: attrError = '',
        } = {},
      } = {},
    } = error;

    let errorMessage = '';
    if (error?.response?.status === 422 && !attributes.includes('base')) {
      errorMessage = t('AGENT_MGMT.ADD.API.EXIST_MESSAGE');
    } else {
      errorMessage = t('AGENT_MGMT.ADD.API.ERROR_MESSAGE');
    }
    useAlert(errorResponse || attrError || errorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.ADD.TITLE')"
      :header-content="$t('AGENT_MGMT.ADD.DESC')"
    />
    <form
      class="flex flex-col items-start w-full space-y-3"
      @submit.prevent="addAgent"
    >
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentEmail.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.EMAIL.LABEL') }}
          <input
            v-model="agentEmail"
            type="email"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.EMAIL.PLACEHOLDER')"
            @input="v$.agentEmail.$touch"
          />
        </label>
      </div>

      <!-- Password section -->
      <div class="w-full pt-2 border-t border-n-weak">
        <label
          class="block mb-1 text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{
            $t(
              'AGENT_MGMT.ADD.FORM.PASSWORD.LABEL',
              'Temporary Password (Optional)'
            )
          }}
        </label>
        <div class="relative">
          <input
            v-model="agentPassword"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="new-password"
            class="w-full rounded-md border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none dark:bg-n-solid-3"
            :placeholder="
              $t(
                'AGENT_MGMT.ADD.FORM.PASSWORD.PLACEHOLDER',
                'Set temporary password for agent'
              )
            "
          />
          <button
            type="button"
            tabindex="-1"
            class="absolute inset-y-0 right-0 flex items-center px-3 text-n-slate-10 hover:text-n-slate-12"
            @click="showPassword = !showPassword"
          >
            <Icon
              :icon="showPassword ? 'i-lucide-eye-off' : 'i-lucide-eye'"
              class="size-4"
            />
          </button>
        </div>
      </div>

      <div v-if="isPasswordProvided" class="w-full">
        <label
          class="block mb-1 text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{
            $t('AGENT_MGMT.ADD.FORM.CONFIRM_PASSWORD.LABEL', 'Confirm Password')
          }}
        </label>
        <div class="relative">
          <input
            v-model="agentPasswordConfirmation"
            :type="showPasswordConfirmation ? 'text' : 'password'"
            autocomplete="new-password"
            class="w-full rounded-md border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none dark:bg-n-solid-3"
            :placeholder="
              $t(
                'AGENT_MGMT.ADD.FORM.CONFIRM_PASSWORD.PLACEHOLDER',
                'Confirm temporary password'
              )
            "
          />
          <button
            type="button"
            tabindex="-1"
            class="absolute inset-y-0 right-0 flex items-center px-3 text-n-slate-10 hover:text-n-slate-12"
            @click="showPasswordConfirmation = !showPasswordConfirmation"
          >
            <Icon
              :icon="
                showPasswordConfirmation ? 'i-lucide-eye-off' : 'i-lucide-eye'
              "
              class="size-4"
            />
          </button>
        </div>
      </div>

      <!-- Password checklist -->
      <div
        v-if="isPasswordProvided"
        class="w-full rounded-lg border border-n-weak bg-n-alpha-1/40 p-3 dark:bg-n-solid-3/40"
      >
        <p class="mb-1.5 text-xs font-medium text-n-slate-11">
          {{
            $t(
              'FORCE_PASSWORD_CHANGE.REQUIREMENTS_TITLE',
              'Password requirements:'
            )
          }}
        </p>
        <div class="grid grid-cols-2 gap-1.5 text-xs">
          <div
            v-for="rule in passwordRules"
            :key="rule.key"
            class="flex items-center gap-1.5"
            :class="
              rule.valid
                ? 'text-n-teal-11 dark:text-n-teal-10 font-medium'
                : 'text-n-slate-10'
            "
          >
            <Icon
              :icon="rule.valid ? 'i-lucide-check-circle-2' : 'i-lucide-circle'"
              class="size-3 shrink-0"
              :class="rule.valid ? 'text-n-teal-11' : 'text-n-slate-8'"
            />
            <span class="truncate">{{ rule.label }}</span>
          </div>
        </div>
      </div>

      <!-- Force password change on first login toggle -->
      <div v-if="isPasswordProvided" class="flex items-center gap-2.5 py-1">
        <input
          id="forcePasswordChangeCheckbox"
          v-model="forcePasswordChange"
          type="checkbox"
          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
        />
        <label
          for="forcePasswordChangeCheckbox"
          class="text-xs font-medium text-n-slate-12 cursor-pointer select-none"
        >
          {{
            $t(
              'AGENT_MGMT.ADD.FORM.FORCE_PASSWORD_CHANGE.LABEL',
              'Force password change on first login'
            )
          }}
        </label>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || !isPasswordValid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
