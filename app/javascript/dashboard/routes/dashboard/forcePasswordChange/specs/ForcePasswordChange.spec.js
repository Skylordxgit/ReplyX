import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import ForcePasswordChange from '../Index.vue';
import forcePasswordChangeLocale from 'dashboard/i18n/locale/en/forcePasswordChange.json';

const resolveKey = (key, fallback) => {
  const value = key
    .split('.')
    .reduce((node, part) => node?.[part], forcePasswordChangeLocale);
  return typeof value === 'string' ? value : fallback || key;
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (k, f) => resolveKey(k, f) }),
}));

const mockPush = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: mockPush }),
}));

const mockDispatch = vi.fn();
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mockDispatch }),
  useMapGetter: getter => {
    if (getter === 'getCurrentUser') {
      return { value: { id: 1, account_id: 1, force_password_change: true } };
    }
    return { value: null };
  },
}));

const mockAlert = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: msg => mockAlert(msg),
}));

describe('ForcePasswordChange.vue', () => {
  let wrapper;

  beforeEach(() => {
    vi.clearAllMocks();
    wrapper = mount(ForcePasswordChange, {
      global: {
        mocks: {
          $t: (k, f) => resolveKey(k, f),
        },
        stubs: {
          LimCXLogo: { template: '<div class="limcx-logo-stub"></div>' },
          Icon: { template: '<i class="icon-stub"></i>' },
          Button: {
            props: ['label', 'disabled', 'isLoading'],
            template:
              '<button :disabled="disabled" type="submit">{{ label }}</button>',
          },
        },
      },
    });
  });

  it('renders the form with required inputs and disabled submit button by default', () => {
    expect(wrapper.text()).toContain('Set Your New Password');
    const inputs = wrapper.findAll('input');
    expect(inputs.length).toBe(3); // current, new, confirm
    const submitBtn = wrapper.find('button[type="submit"]');
    expect(submitBtn.attributes('disabled')).toBeDefined();
  });

  it('enables submit button only when all password rules and current password are satisfied', async () => {
    const inputs = wrapper.findAll('input');
    const currentInput = inputs[0];
    const newInput = inputs[1];
    const confirmInput = inputs[2];

    await currentInput.setValue('TempPass123!');
    await newInput.setValue('NewSecure123!');
    await confirmInput.setValue('NewSecure123!');
    await flushPromises();

    const submitBtn = wrapper.find('button[type="submit"]');
    expect(submitBtn.attributes('disabled')).toBeUndefined();
  });

  it('calls updatePassword action and redirects to dashboard upon submit', async () => {
    mockDispatch.mockResolvedValue({});

    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('TempPass123!');
    await inputs[1].setValue('NewSecure123!');
    await inputs[2].setValue('NewSecure123!');
    await flushPromises();

    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();

    expect(mockDispatch).toHaveBeenCalledWith('updatePassword', {
      currentPassword: 'TempPass123!',
      password: 'NewSecure123!',
      passwordConfirmation: 'NewSecure123!',
    });
    expect(mockPush).toHaveBeenCalledWith({
      name: 'home',
      params: { accountId: 1 },
    });
    expect(mockAlert).toHaveBeenCalled();
  });
});
