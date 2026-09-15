import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import CannedResponseAccess from '../CannedResponseAccess.vue';
import cannedMgmtLocale from 'dashboard/i18n/locale/en/cannedMgmt.json';

const resolveKey = (key, fallback) => {
  const value = key
    .split('.')
    .reduce((node, part) => node?.[part], cannedMgmtLocale);
  return typeof value === 'string' ? value : fallback || key;
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (k, f) => resolveKey(k, f) }),
}));

const mockDispatch = vi.fn().mockResolvedValue([]);
const teamsList = [
  { id: 1, name: 'Support Team' },
  { id: 2, name: 'Sales Team' },
];
const agentsList = [
  { id: 10, name: 'John Doe', email: 'john@example.com' },
  { id: 20, name: 'Jane Smith', email: 'jane@example.com' },
];

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mockDispatch }),
  useStoreGetters: () => ({
    'teams/getTeams': { value: teamsList },
    'agents/getVerifiedAgents': { value: agentsList },
  }),
}));

describe('CannedResponseAccess.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders access scope selector with all 4 options', async () => {
    const wrapper = mount(CannedResponseAccess, {
      props: {
        accessScope: 'everyone',
        allowedTeamIds: [],
        allowedUserIds: [],
      },
      global: {
        mocks: {
          $t: (k, f) => resolveKey(k, f),
        },
        stubs: {
          TagMultiSelectComboBox: true,
        },
      },
    });

    await flushPromises();
    expect(mockDispatch).toHaveBeenCalledWith('teams/get');
    expect(mockDispatch).toHaveBeenCalledWith('agents/get');

    const select = wrapper.find('select');
    expect(select.exists()).toBe(true);

    const options = select.findAll('option');
    expect(options.length).toBe(4);
    expect(options[0].attributes('value')).toBe('everyone');
    expect(options[1].attributes('value')).toBe('specific_teams');
    expect(options[2].attributes('value')).toBe('specific_users');
    expect(options[3].attributes('value')).toBe('only_me');
  });

  it('shows team multi-select only when specific_teams is selected', async () => {
    const wrapper = mount(CannedResponseAccess, {
      props: {
        accessScope: 'specific_teams',
        allowedTeamIds: [1],
        allowedUserIds: [],
      },
      global: {
        mocks: {
          $t: (k, f) => resolveKey(k, f),
        },
        stubs: {
          TagMultiSelectComboBox: true,
        },
      },
    });

    await flushPromises();
    expect(wrapper.text()).toContain('Teams');
    expect(
      wrapper.findComponent({ name: 'TagMultiSelectComboBox' }).exists()
    ).toBe(true);
  });

  it('shows user multi-select only when specific_users is selected', async () => {
    const wrapper = mount(CannedResponseAccess, {
      props: {
        accessScope: 'specific_users',
        allowedTeamIds: [],
        allowedUserIds: [10],
      },
      global: {
        mocks: {
          $t: (k, f) => resolveKey(k, f),
        },
        stubs: {
          TagMultiSelectComboBox: true,
        },
      },
    });

    await flushPromises();
    expect(wrapper.text()).toContain('Users');
    expect(
      wrapper.findComponent({ name: 'TagMultiSelectComboBox' }).exists()
    ).toBe(true);
  });
});
