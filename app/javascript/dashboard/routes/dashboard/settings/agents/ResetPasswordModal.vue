<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  agent: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const password = ref('');
const passwordConfirmation = ref('');
const forcePasswordChange = ref(true);
const showPassword = ref(false);
const showPasswordConfirmation = ref(false);
const isSubmitting = ref(false);

const uiFlags = useMapGetter('agents/getUIFlags');

const passwordRules = computed(() => [
  {
    key: 'length',
    label: t('AGENT_MGMT.RESET_PASSWORD.RULES.LENGTH', 'At least 6 characters'),
    valid: password.value.length >= 6,
  },
  {
    key: 'uppercase',
    label: t(
      'AGENT_MGMT.RESET_PASSWORD.RULES.UPPERCASE',
      'At least 1 uppercase letter'
    ),
    valid: /[A-Z]/.test(password.value),
  },
  {
    key: 'lowercase',
    label: t(
      'AGENT_MGMT.RESET_PASSWORD.RULES.LOWERCASE',
      'At least 1 lowercase letter'
    ),
    valid: /[a-z]/.test(password.value),
  },
  {
    key: 'number',
    label: t('AGENT_MGMT.RESET_PASSWORD.RULES.NUMBER', 'At least 1 number'),
    valid: /[0-9]/.test(password.value),
  },
  {
    key: 'special',
    label: t(
      'AGENT_MGMT.RESET_PASSWORD.RULES.SPECIAL',
      'At least 1 special character (!@#$%^&*...)'
    ),
    valid: /[!@#$%^&*()_+\-=[\]{}|']/.test(password.value),
  },
  {
    key: 'match',
    label: t('AGENT_MGMT.RESET_PASSWORD.RULES.MATCH', 'Passwords match'),
    valid:
      password.value.length > 0 &&
      password.value === passwordConfirmation.value,
  },
]);

const isFormValid = computed(() => {
  return password.value.length > 0 && passwordRules.value.every(r => r.valid);
});

const handleResetPassword = async () => {
  if (!isFormValid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await store.dispatch('agents/resetPassword', {
      id: props.agent.id,
      password: password.value,
      password_confirmation: passwordConfirmation.value,
      force_password_change: forcePasswordChange.value,
    });

    useAlert(
      t(
        'AGENT_MGMT.RESET_PASSWORD.API.SUCCESS_MESSAGE',
        'Password has been reset successfully. The agent will be prompted to change it on next login.'
      )
    );
    emit('close');
  } catch (error) {
    const errorMsg =
      parseAPIErrorResponse(error) ||
      t(
        'AGENT_MGMT.RESET_PASSWORD.API.ERROR_MESSAGE',
        'Failed to reset password.'
      );
    useAlert(errorMsg);
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        $t('AGENT_MGMT.RESET_PASSWORD.TITLE', { name: agent.name })
      "
      :header-content="
        $t(
          'AGENT_MGMT.RESET_PASSWORD.DESC',
          'Set a new temporary password for this agent. Existing sessions will be invalidated.'
        )
      "
    />
    <form
      class="flex flex-col items-start w-full space-y-4"
      @submit.prevent="handleResetPassword"
    >
      <!-- Agent info banner -->
      <div
        class="w-full flex items-center gap-3 p-3 rounded-xl border border-n-weak bg-n-alpha-1 dark:bg-n-solid-3"
      >
        <div
          class="flex size-9 items-center justify-center rounded-lg bg-n-brand/10 text-n-brand dark:bg-n-brand/20"
        >
          <Icon icon="i-lucide-key-round" class="size-4" />
        </div>
        <div class="flex flex-col min-w-0">
          <span class="text-sm font-semibold text-n-slate-12 truncate">{{
            agent.name
          }}</span>
          <span class="text-xs text-n-slate-11 truncate">{{
            agent.email
          }}</span>
        </div>
      </div>

      <!-- New Temporary Password -->
      <div class="w-full">
        <label
          class="block mb-1 text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{
            $t(
              'AGENT_MGMT.RESET_PASSWORD.NEW_PASSWORD.LABEL',
              'New Temporary Password'
            )
          }}
        </label>
        <div class="relative">
          <input
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="new-password"
            required
            class="w-full rounded-md border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none dark:bg-n-solid-3"
            :placeholder="
              $t(
                'AGENT_MGMT.RESET_PASSWORD.NEW_PASSWORD.PLACEHOLDER',
                'Enter new temporary password'
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

      <!-- Confirm Password -->
      <div class="w-full">
        <label
          class="block mb-1 text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{
            $t(
              'AGENT_MGMT.RESET_PASSWORD.CONFIRM_PASSWORD.LABEL',
              'Confirm Password'
            )
          }}
        </label>
        <div class="relative">
          <input
            v-model="passwordConfirmation"
            :type="showPasswordConfirmation ? 'text' : 'password'"
            autocomplete="new-password"
            required
            class="w-full rounded-md border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none dark:bg-n-solid-3"
            :placeholder="
              $t(
                'AGENT_MGMT.RESET_PASSWORD.CONFIRM_PASSWORD.PLACEHOLDER',
                'Confirm new password'
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

      <!-- Force password change on next login toggle -->
      <div class="flex items-center gap-2.5 py-1">
        <input
          id="resetForcePasswordChangeCheckbox"
          v-model="forcePasswordChange"
          type="checkbox"
          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
        />
        <label
          for="resetForcePasswordChangeCheckbox"
          class="text-xs font-medium text-n-slate-12 cursor-pointer select-none"
        >
          {{
            $t(
              'AGENT_MGMT.RESET_PASSWORD.FORCE_NEXT_LOGIN',
              'Force password change on next login'
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
          :label="
            $t('AGENT_MGMT.RESET_PASSWORD.SUBMIT_BUTTON', 'Reset Password')
          "
          :disabled="!isFormValid || isSubmitting || uiFlags.isUpdating"
          :is-loading="isSubmitting || uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>
