import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import settingsLocale from 'dashboard/i18n/locale/en/settings.json';
import LiveQueue from '../LiveQueue.vue';
import AgentWorkload from '../AgentWorkload.vue';
import TeamAvailability from '../TeamAvailability.vue';
import ChannelHealth from '../ChannelHealth.vue';

const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', component: { template: '<div>Home</div>' } },
    {
      path: '/app/accounts/:accountId/conversations/:conversationId',
      name: 'inbox_conversation',
      component: { template: '<div>Conversation</div>' },
    },
    {
      path: '/app/accounts/:accountId/settings/teams/new',
      name: 'settings_teams_new',
      component: { template: '<div>New Team</div>' },
    },
    {
      path: '/app/accounts/:accountId/settings/teams/:teamId/edit',
      name: 'settings_teams_edit',
      component: { template: '<div>Edit Team</div>' },
    },
  ],
});

const createMockStore = () =>
  createStore({
    getters: {
      getUnAssignedChats: () => [
        {
          id: 101,
          inbox_id: 1,
          priority: 'urgent',
          timestamp: 1700000000,
          created_at: 1700000000,
          meta: {
            sender: { name: 'Alice Customer' },
            team: { id: 1, name: 'Support' },
          },
        },
        {
          id: 102,
          inbox_id: 2,
          priority: 'low',
          timestamp: 1700000000,
          created_at: 1700000000,
          meta: { sender: { name: 'Bob Client' } },
        },
      ],
      // Conversation payloads expose the assignee/team under `meta`, matching
      // app/views/api/v1/conversations/partials/_conversation.json.jbuilder
      getAllConversations: () => [
        {
          id: 101,
          status: 'open',
          unread_count: 1,
          meta: { assignee: { id: 1 }, team: { id: 1 } },
        },
        {
          id: 102,
          status: 'pending',
          unread_count: 0,
          meta: { assignee: { id: 2 }, team: { id: 2 } },
        },
        {
          id: 103,
          status: 'open',
          unread_count: 0,
          meta: { team: { id: 1 } },
        },
      ],
      'inboxes/getInboxes': () => [
        {
          id: 1,
          name: 'Live Web Chat',
          channel_type: 'Channel::WebWidget',
          enable_auto_assignment: true,
        },
        {
          id: 2,
          name: 'WhatsApp Support',
          channel_type: 'Channel::Whatsapp',
          enable_auto_assignment: false,
        },
      ],
      'teams/getTeams': () => [
        {
          id: 1,
          name: 'Support Tier 1',
          description: 'Primary triage team',
          allow_auto_assign: true,
          members: [{ id: 1 }],
        },
        {
          id: 2,
          name: 'Billing',
          description: 'Financial inquiries',
          allow_auto_assign: false,
          members: [{ id: 2 }],
        },
      ],
      'agents/getAgents': () => [
        {
          id: 1,
          name: 'John Agent',
          email: 'john@example.com',
          role: 'agent',
          availability_status: 'online',
          confirmed: true,
        },
        {
          id: 2,
          name: 'Jane Admin',
          email: 'jane@example.com',
          role: 'administrator',
          availability_status: 'busy',
          confirmed: true,
        },
      ],
      getCurrentUser: () => ({ id: 1, name: 'John Agent' }),
      getCurrentAccountId: () => 1,
    },
    actions: {
      fetchAllConversations: vi.fn(),
      'inboxes/get': vi.fn(),
      'teams/get': vi.fn(),
      'agents/get': vi.fn(),
      assignAgent: vi.fn(),
    },
  });

// Resolve against the real shipped locale file so these specs fail if a key is
// renamed or removed, instead of silently asserting a local duplicate.
const resolveKey = key =>
  key.split('.').reduce((node, part) => node?.[part], settingsLocale);

const interpolate = (template, args = {}) =>
  Object.entries(args).reduce(
    (text, [name, value]) => text.replaceAll(`{${name}}`, value),
    template
  );

const i18nMock = {
  $t: (key, args) => {
    const value = resolveKey(key);
    return typeof value === 'string' ? interpolate(value, args) : key;
  },
};

describe('Operations Views', () => {
  it('renders LiveQueue with unassigned queue items and summary metrics', async () => {
    const store = createMockStore();
    const wrapper = mount(LiveQueue, {
      global: {
        plugins: [store, router],
        mocks: i18nMock,
        stubs: {
          TimeAgo: { template: '<span>Just now</span>' },
          Avatar: { template: '<div>Avatar</div>' },
          Dialog: { template: '<div><slot /></div>' },
        },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Live Queue');
    expect(wrapper.text()).toContain('Total in Queue');
    expect(wrapper.text()).toContain('Alice Customer');
    expect(wrapper.text()).toContain('#101');
  });

  it('renders AgentWorkload with availability breakdown and capacity metrics', async () => {
    const store = createMockStore();
    const wrapper = mount(AgentWorkload, {
      global: {
        plugins: [store, router],
        mocks: i18nMock,
        stubs: {
          Avatar: { template: '<div>Avatar</div>' },
        },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Agent Workload');
    expect(wrapper.text()).toContain('Available');
    expect(wrapper.text()).toContain('Busy');
    expect(wrapper.text()).toContain('John Agent');
    expect(wrapper.text()).toContain('Jane Admin');
  });

  it('counts agent workload from meta.assignee rather than a top level id', async () => {
    const store = createMockStore();
    const wrapper = mount(AgentWorkload, {
      global: {
        plugins: [store, router],
        mocks: i18nMock,
        stubs: { Avatar: { template: '<div>Avatar</div>' } },
      },
    });
    await flushPromises();

    // John (id 1) owns conversation 101: open + unread.
    // Jane (id 2) owns conversation 102: pending.
    // Conversation 103 is unassigned and must not be attributed to anyone.
    expect(wrapper.text()).toContain('1 / 10 chats (10%)');
    expect(wrapper.text()).toContain('0 / 10 chats (0%)');
  });

  it('renders TeamAvailability with team cards and routing settings', async () => {
    const store = createMockStore();
    const wrapper = mount(TeamAvailability, {
      global: {
        plugins: [store, router],
        mocks: i18nMock,
        stubs: {
          Avatar: { template: '<div>Avatar</div>' },
        },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Team Availability & Routing');
    expect(wrapper.text()).toContain('Support Tier 1');
    expect(wrapper.text()).toContain('Billing');
    expect(wrapper.text()).toContain('Auto-Routing On');
    // Team 1 has two open conversations (101 assigned, 103 unassigned).
    expect(wrapper.text()).toContain('Open Chats');
    expect(wrapper.text()).toContain('Unassigned');
  });

  it('renders ChannelHealth with inbox connectivity indicators', async () => {
    const store = createMockStore();
    const wrapper = mount(ChannelHealth, {
      global: {
        plugins: [store, router],
        mocks: i18nMock,
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Channel Health');
    expect(wrapper.text()).toContain('Live Web Chat');
    expect(wrapper.text()).toContain('WhatsApp Support');
    // Only real inbox configuration is surfaced. There is no live connectivity
    // signal available, so no hardcoded "Connected" status is rendered.
    expect(wrapper.text()).toContain('Auto assignment');
    expect(wrapper.text()).toContain('Enabled');
    expect(wrapper.text()).toContain('Disabled');
    expect(wrapper.text()).not.toContain('Connected');
  });
});
