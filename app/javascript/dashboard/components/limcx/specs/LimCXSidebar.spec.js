import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import LimCXSidebar from '../LimCXSidebar.vue';

const ROUTE_NAMES = [
  'home',
  'inbox_view',
  'conversation_participating',
  'conversation_unattended',
  'conversation_mentions',
  'contacts_dashboard_index',
  'operations_live_queue',
  'operations_agent_workload',
  'operations_team_availability',
  'operations_channel_health',
  'agent_reports_index',
  'team_reports_index',
  'inbox_reports_index',
  'inbox_dashboard',
  'settings_inbox_new',
  'settings_teams_list',
  'agent_list',
  'automation_list',
  'canned_list',
  'portals_index',
  'account_overview_reports',
  'general_settings_index',
  'folder_conversations',
];

const createTestRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: ROUTE_NAMES.map(name => ({
      path: `/${name}`,
      name,
      component: { template: `<div>${name}</div>` },
    })),
  });

const createMockStore = ({ role = 'agent', inboxes = [] } = {}) =>
  createStore({
    state: {},
    getters: {
      getUISettings: () => ({
        sidebar_collapsed: false,
      }),
      getCurrentUser: () => ({
        id: 1,
        name: 'Test Agent',
        email: 'agent@example.com',
        accounts: [{ id: 1, name: 'Main Workspace', role }],
      }),
      getCurrentAccountId: () => 1,
      'notifications/getUnreadCount': () => 5,
      'conversationUnreadCounts/getAllUnreadCount': () => 12,
      'conversationUnreadCounts/getParticipatingUnreadCount': () => 3,
      'conversationUnreadCounts/getUnattendedUnreadCount': () => 4,
      'conversationUnreadCounts/getMentionsUnreadCount': () => 2,
      'conversationUnreadCounts/getFolderUnreadCount': () => () => 0,
      'conversationUnreadCounts/getInboxUnreadCount': () => () => 1,
      'inboxes/getInboxes': () => inboxes,
      'customViews/getConversationCustomViews': () => [],
    },
    actions: {
      updateUISettings: vi.fn(),
      'labels/get': vi.fn(),
      'inboxes/get': vi.fn(),
      'notifications/unReadCount': vi.fn(),
      'teams/get': vi.fn(),
      'attributes/get': vi.fn(),
      'customViews/get': vi.fn(),
      'conversationUnreadCounts/get': vi.fn(),
    },
  });

describe('LimCXSidebar', () => {
  it('renders core navigation items and unread badges', async () => {
    const store = createMockStore({ role: 'agent' });
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXSidebar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('SIDEBAR.INBOX');
    expect(wrapper.text()).toContain('SIDEBAR.MY_CHATS');
    expect(wrapper.text()).toContain('SIDEBAR.UNATTENDED_CONVERSATIONS');
    expect(wrapper.text()).toContain('SIDEBAR.MENTIONED_CONVERSATIONS');
    expect(wrapper.text()).toContain('SIDEBAR.SAVED_VIEWS');
    expect(wrapper.text()).toContain('SIDEBAR.CUSTOMERS');

    // Unread count check
    expect(wrapper.text()).toContain('5'); // notification unread
    expect(wrapper.text()).toContain('3'); // participating
    expect(wrapper.text()).toContain('4'); // unattended
  });

  it('hides admin-only sections for agent role', async () => {
    const store = createMockStore({ role: 'agent' });
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXSidebar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    expect(wrapper.text()).not.toContain('SIDEBAR.MANAGEMENT');
    expect(wrapper.text()).not.toContain('SIDEBAR.WORKFLOWS');
    expect(wrapper.text()).not.toContain('SIDEBAR.SETTINGS');
  });

  it('shows management and admin sections for administrator role', async () => {
    const store = createMockStore({ role: 'administrator' });
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXSidebar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('SIDEBAR.MANAGEMENT');
    expect(wrapper.text()).toContain('SIDEBAR.TEAMS');
    expect(wrapper.text()).toContain('SIDEBAR.AGENTS');
    expect(wrapper.text()).toContain('SIDEBAR.WORKFLOWS');
    expect(wrapper.text()).toContain('SIDEBAR.SETTINGS');
  });

  it('shows connected channels for agents and hides unconfigured channels', async () => {
    const inboxes = [
      { id: 10, name: 'WhatsApp Sales', channel_type: 'Channel::Whatsapp' },
    ];
    const store = createMockStore({ role: 'agent', inboxes });
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXSidebar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('SIDEBAR.CHANNELS');
    expect(wrapper.text()).toContain('SIDEBAR.WHATSAPP');
    // Agent without Telegram inbox won't see Telegram
    expect(wrapper.text()).not.toContain('SIDEBAR.TELEGRAM');
  });
});
