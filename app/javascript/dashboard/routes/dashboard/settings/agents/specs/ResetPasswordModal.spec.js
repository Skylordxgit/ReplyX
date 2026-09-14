import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import ResetPasswordModal from '../ResetPasswordModal.vue';
import agentMgmtLocale from 'dashboard/i18n/locale/en/agentMgmt.json';

const resolveKey = (key, fallback) => {
  const value = key
    .split('.')
    .reduce((node, part) => node?.[part], agentMgmtLocale);
  return typeof value === 'string' ? value : fallback || key;
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (k, f) => resolveKey(k, f) }),
}));

const mockDispatch = vi.fn();
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mockDispatch }),
  useMapGetter: getter => {
    if (getter === 'agents/getUIFlags') {
      return { value: { isUpdating: false } };
    }
    return { value: null };
  },
}));

const mockAlert = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: msg => mockAlert(msg),
}));

describe('ResetPasswordModal.vue', () => {
  const mockAgent = {
    id: 42,
    name: 'Sarah Connor',
    email: 'sarah@example.com',
  };

  let wrapper;

  beforeEach(() => {
    vi.clearAllMocks();
    wrapper = mount(ResetPasswordModal, {
      props: {
        agent: mockAgent,
      },
      global: {
        mocks: {
          $t: (k, f) => {
            if (typeof f === 'object' && f?.name) {
              return `Reset Password - ${f.name}`;
            }
            return resolveKey(k, f);
          },
        },
        stubs: {
          WootModalHeader: {
            props: ['headerTitle', 'headerContent'],
            template:
              '<div class="modal-header"><h1>{{ headerTitle }}</h1><p>{{ headerContent }}</p></div>',
          },
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

  it('renders agent details and password input fields', () => {
    expect(wrapper.text()).toContain('Sarah Connor');
    expect(wrapper.text()).toContain('sarah@example.com');
    const inputs = wrapper.findAll('input[type="password"]');
    expect(inputs.length).toBe(2);
  });

  it('submits reset password action with force_password_change as true by default', async () => {
    mockDispatch.mockResolvedValue({});

    const passwordInput = wrapper.findAll('input[type="password"]')[0];
    const confirmInput = wrapper.findAll('input[type="password"]')[1];

    await passwordInput.setValue('NewAdminTemp123!');
    await confirmInput.setValue('NewAdminTemp123!');
    await flushPromises();

    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();

    expect(mockDispatch).toHaveBeenCalledWith('agents/resetPassword', {
      id: 42,
      password: 'NewAdminTemp123!',
      password_confirmation: 'NewAdminTemp123!',
      force_password_change: true,
    });
    expect(wrapper.emitted('close')).toBeTruthy();
    expect(mockAlert).toHaveBeenCalled();
  });
});
