<script setup>
import { ref, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import LimCXLogo from 'dashboard/components/limcx/LimCXLogo.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const currentPassword = ref('');
const password = ref('');
const passwordConfirmation = ref('');
const showCurrentPassword = ref(false);
const showNewPassword = ref(false);
const showConfirmPassword = ref(false);
const isSubmitting = ref(false);

const currentUser = useMapGetter('getCurrentUser');

const accountId = computed(() => {
  return Number(route.params.accountId || currentUser.value?.account_id);
});

const rules = computed(() => [
  {
    key: 'length',
    label: t('FORCE_PASSWORD_CHANGE.RULES.LENGTH', 'At least 6 characters'),
    valid: password.value.length >= 6,
  },
  {
    key: 'uppercase',
    label: t(
      'FORCE_PASSWORD_CHANGE.RULES.UPPERCASE',
      'At least 1 uppercase letter (A-Z)'
    ),
    valid: /[A-Z]/.test(password.value),
  },
  {
    key: 'lowercase',
    label: t(
      'FORCE_PASSWORD_CHANGE.RULES.LOWERCASE',
      'At least 1 lowercase letter (a-z)'
    ),
    valid: /[a-z]/.test(password.value),
  },
  {
    key: 'number',
    label: t('FORCE_PASSWORD_CHANGE.RULES.NUMBER', 'At least 1 number (0-9)'),
    valid: /[0-9]/.test(password.value),
  },
  {
    key: 'special',
    label: t(
      'FORCE_PASSWORD_CHANGE.RULES.SPECIAL',
      'At least 1 special character (!@#$%^&*...)'
    ),
    valid: /[!@#$%^&*()_+\-=[\]{}|']/.test(password.value),
  },
  {
    key: 'match',
    label: t('FORCE_PASSWORD_CHANGE.RULES.MATCH', 'Passwords match'),
    valid:
      password.value.length > 0 &&
      password.value === passwordConfirmation.value,
  },
]);

const isFormValid = computed(() => {
  return (
    currentPassword.value.trim().length > 0 && rules.value.every(r => r.valid)
  );
});

const handlePasswordChange = async () => {
  if (!isFormValid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await store.dispatch('updatePassword', {
      currentPassword: currentPassword.value,
      password: password.value,
      passwordConfirmation: passwordConfirmation.value,
    });

    useAlert(
      t(
        'FORCE_PASSWORD_CHANGE.SUCCESS_MESSAGE',
        'Password changed successfully! Welcome to Limcx.'
      )
    );

    // Navigate to dashboard
    if (accountId.value) {
      router.push({
        name: 'home',
        params: { accountId: accountId.value },
      });
    } else {
      window.location.assign('/app');
    }
  } catch (error) {
    const errorMsg =
      parseAPIErrorResponse(error) ||
      t(
        'FORCE_PASSWORD_CHANGE.ERROR_MESSAGE',
        'Failed to update password. Please verify your current temporary password.'
      );
    useAlert(errorMsg);
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div
    class="flex min-h-screen w-full flex-col items-center justify-center bg-n-brand/5 px-4 py-12 dark:bg-n-background sm:px-6 lg:px-8"
  >
    <div class="w-full max-w-md space-y-8">
      <div class="flex flex-col items-center text-center">
        <LimCXLogo size="lg" show-text class="mb-4" />
        <div
          class="mb-2 flex size-12 items-center justify-center rounded-full bg-n-brand/10 text-n-brand dark:bg-n-brand/20"
        >
          <Icon icon="i-lucide-shield-alert" class="size-6" />
        </div>
        <h1 class="text-2xl font-bold tracking-tight text-n-slate-12">
          {{ $t('FORCE_PASSWORD_CHANGE.TITLE', 'Set Your New Password') }}
        </h1>
        <p class="mt-2 text-sm text-n-slate-11">
          {{
            $t(
              'FORCE_PASSWORD_CHANGE.DESCRIPTION',
              'For your security, you must set a new secure password before accessing your workspace.'
            )
          }}
        </p>
      </div>

      <div
        class="rounded-2xl border border-n-weak bg-white p-8 shadow-xl dark:bg-n-solid-2"
      >
        <form class="space-y-5" @submit.prevent="handlePasswordChange">
          <!-- Current temporary password -->
          <div>
            <label
              class="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-n-slate-11"
            >
              {{
                $t(
                  'FORCE_PASSWORD_CHANGE.CURRENT_PASSWORD',
                  'Current Temporary Password'
                )
              }}
            </label>
            <div class="relative">
              <input
                v-model="currentPassword"
                :type="showCurrentPassword ? 'text' : 'password'"
                autocomplete="current-password"
                required
                class="w-full rounded-xl border border-n-weak bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-12 transition-all placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand/20 dark:bg-n-solid-3"
                :placeholder="
                  $t(
                    'FORCE_PASSWORD_CHANGE.CURRENT_PASSWORD_PLACEHOLDER',
                    'Enter temporary password'
                  )
                "
              />
              <button
                type="button"
                tabindex="-1"
                class="absolute inset-y-0 right-0 flex items-center px-3 text-n-slate-10 hover:text-n-slate-12"
                @click="showCurrentPassword = !showCurrentPassword"
              >
                <Icon
                  :icon="
                    showCurrentPassword ? 'i-lucide-eye-off' : 'i-lucide-eye'
                  "
                  class="size-4"
                />
              </button>
            </div>
          </div>

          <!-- New password -->
          <div>
            <label
              class="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-n-slate-11"
            >
              {{ $t('FORCE_PASSWORD_CHANGE.NEW_PASSWORD', 'New Password') }}
            </label>
            <div class="relative">
              <input
                v-model="password"
                :type="showNewPassword ? 'text' : 'password'"
                autocomplete="new-password"
                required
                class="w-full rounded-xl border border-n-weak bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-12 transition-all placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand/20 dark:bg-n-solid-3"
                :placeholder="
                  $t(
                    'FORCE_PASSWORD_CHANGE.NEW_PASSWORD_PLACEHOLDER',
                    'Enter new secure password'
                  )
                "
              />
              <button
                type="button"
                tabindex="-1"
                class="absolute inset-y-0 right-0 flex items-center px-3 text-n-slate-10 hover:text-n-slate-12"
                @click="showNewPassword = !showNewPassword"
              >
                <Icon
                  :icon="showNewPassword ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                  class="size-4"
                />
              </button>
            </div>
          </div>

          <!-- Confirm new password -->
          <div>
            <label
              class="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-n-slate-11"
            >
              {{
                $t(
                  'FORCE_PASSWORD_CHANGE.CONFIRM_PASSWORD',
                  'Confirm New Password'
                )
              }}
            </label>
            <div class="relative">
              <input
                v-model="passwordConfirmation"
                :type="showConfirmPassword ? 'text' : 'password'"
                autocomplete="new-password"
                required
                class="w-full rounded-xl border border-n-weak bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-12 transition-all placeholder:text-n-slate-8 focus:border-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand/20 dark:bg-n-solid-3"
                :placeholder="
                  $t(
                    'FORCE_PASSWORD_CHANGE.CONFIRM_PASSWORD_PLACEHOLDER',
                    'Confirm new password'
                  )
                "
              />
              <button
                type="button"
                tabindex="-1"
                class="absolute inset-y-0 right-0 flex items-center px-3 text-n-slate-10 hover:text-n-slate-12"
                @click="showConfirmPassword = !showConfirmPassword"
              >
                <Icon
                  :icon="
                    showConfirmPassword ? 'i-lucide-eye-off' : 'i-lucide-eye'
                  "
                  class="size-4"
                />
              </button>
            </div>
          </div>

          <!-- Password rules checklist -->
          <div
            class="rounded-xl border border-n-weak bg-n-alpha-1/50 p-3.5 dark:bg-n-solid-3/50"
          >
            <p class="mb-2 text-xs font-medium text-n-slate-11">
              {{
                $t(
                  'FORCE_PASSWORD_CHANGE.REQUIREMENTS_TITLE',
                  'Password requirements:'
                )
              }}
            </p>
            <ul class="space-y-1.5 text-xs">
              <li
                v-for="rule in rules"
                :key="rule.key"
                class="flex items-center gap-2 transition-colors duration-150"
                :class="
                  rule.valid
                    ? 'text-n-teal-11 dark:text-n-teal-10 font-medium'
                    : 'text-n-slate-10'
                "
              >
                <Icon
                  :icon="
                    rule.valid ? 'i-lucide-check-circle-2' : 'i-lucide-circle'
                  "
                  class="size-3.5 shrink-0"
                  :class="
                    rule.valid
                      ? 'text-n-teal-11 dark:text-n-teal-10'
                      : 'text-n-slate-8'
                  "
                />
                <span>{{ rule.label }}</span>
              </li>
            </ul>
          </div>

          <!-- Submit Button -->
          <Button
            type="submit"
            class="w-full !py-3 font-semibold"
            :label="
              $t('FORCE_PASSWORD_CHANGE.SUBMIT', 'Update Password & Continue')
            "
            :disabled="!isFormValid || isSubmitting"
            :is-loading="isSubmitting"
          />
        </form>
      </div>
    </div>
  </div>
</template>
