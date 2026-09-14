import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import AddAgent from '../AddAgent.vue';
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
      return { value: { isCreating: false } };
    }
    if (getter === 'customRole/getCustomRoles') {
      return { value: [] };
    }
    return { value: null };
  },
}));

const mockAlert = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: msg => mockAlert(msg),
}));

describe('AddAgent.vue password support', () => {
  let wrapper;

  beforeEach(() => {
    vi.clearAllMocks();
    wrapper = mount(AddAgent, {
      global: {
        mocks: {
          $t: (k, f) => resolveKey(k, f),
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

  it('renders password and confirm password inputs when admin sets manual password', async () => {
    const nameInput = wrapper.find('input[type="text"]');
    const emailInput = wrapper.find('input[type="email"]');
    const passwordInput = wrapper.find('input[type="password"]');

    await nameInput.setValue('John Agent');
    await emailInput.setValue('john@example.com');
    await passwordInput.setValue('TempPass123!');
    await flushPromises();

    // Confirm password input and checklist appear
    const passwordInputs = wrapper.findAll('input[type="password"]');
    expect(passwordInputs.length).toBe(2);
    expect(wrapper.text()).toContain('Force password change on first login');
  });

  it('dispatches agent creation with password and force_password_change payload', async () => {
    mockDispatch.mockResolvedValue({});

    const nameInput = wrapper.find('input[type="text"]');
    const emailInput = wrapper.find('input[type="email"]');
    await nameInput.setValue('John Agent');
    await emailInput.setValue('john@example.com');

    const passwordInput = wrapper.findAll('input[type="password"]')[0];
    await passwordInput.setValue('TempPass123!');
    await flushPromises();

    const confirmInput = wrapper.findAll('input[type="password"]')[1];
    await confirmInput.setValue('TempPass123!');
    await flushPromises();

    await wrapper.find('form').trigger('submit.prevent');
    await flushPromises();

    expect(mockDispatch).toHaveBeenCalledWith('agents/create', {
      name: 'John Agent',
      email: 'john@example.com',
      role: 'agent',
      password: 'TempPass123!',
      password_confirmation: 'TempPass123!',
      force_password_change: true,
    });
    expect(wrapper.emitted('close')).toBeTruthy();
  });
});
