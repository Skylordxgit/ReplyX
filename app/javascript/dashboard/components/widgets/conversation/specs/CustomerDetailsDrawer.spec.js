import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { describe, it, expect, vi } from 'vitest';
import CustomerDetailsDrawer from '../CustomerDetailsDrawer.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

describe('CustomerDetailsDrawer.vue', () => {
  const currentChat = {
    id: 42,
    status: 'open',
    priority: 'high',
    inbox_id: 1,
    meta: {
      sender: { id: 101, identifier: 'cust_101' },
      channel: 'Channel::WebWidget',
      team: { id: 2, name: 'Support' },
      assignee: { id: 5, name: 'Agent Smith', email: 'smith@matrix.com' },
      participants: [{ id: 6, name: 'Agent Neo' }],
    },
    custom_attributes: {
      category: 'Billing',
      tier: 'Enterprise',
    },
    additional_attributes: {
      utm_source: 'google',
    },
    messages: [
      { id: 1, content: 'Customer public message', private: false },
      {
        id: 2,
        content: 'Internal private note on this session',
        private: true,
        sender: { name: 'Agent Smith' },
        created_at: 1700000000,
      },
    ],
  };

  const contact = {
    id: 101,
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    phone_number: '+1234567890',
    locale: 'en',
    created_at: 1680000000,
    last_activity_at: 1700000000,
    additional_attributes: {
      screen_name: 'adalove',
      city: 'London',
      country: 'UK',
      timezone: 'Europe/London',
    },
    custom_attributes: {
      icx_username: 'ada_icx',
    },
  };

  const createTestStore = () => {
    return createStore({
      getters: {
        getSelectedChat: () => currentChat,
        getCurrentUser: () => ({ id: 1, name: 'Admin' }),
        'contacts/getContact': () => () => contact,
        'inboxes/getInboxes': () => [
          { id: 1, name: 'Website Chat', channel_type: 'Channel::WebWidget' },
        ],
        'teams/getTeams': () => [{ id: 2, name: 'Support' }],
        'agents/getAgents': () => [
          { id: 5, name: 'Agent Smith', email: 'smith@matrix.com' },
          { id: 6, name: 'Agent Neo', email: 'neo@matrix.com' },
        ],
        'inboxAssignableAgents/getAssignableAgents': () => () => [
          { id: 5, name: 'Agent Smith', email: 'smith@matrix.com' },
          { id: 6, name: 'Agent Neo', email: 'neo@matrix.com' },
        ],
        'conversationLabels/getConversationLabels': () => () => [
          'vip',
          'billing',
        ],
        'labels/getLabels': () => [{ title: 'vip' }, { title: 'billing' }],
        'integrations/getIntegration': () => () => ({ enabled: false }),
        'contactConversations/getContactConversation': () => () => [],
        'contactConversations/getUIFlags': () => ({ isFetching: false }),
        getCurrentAccountId: () => 1,
        'accounts/getAccount': () => () => ({ id: 1, features: {} }),
        'accounts/isFeatureEnabledonAccount': () => () => false,
      },
      actions: {
        'contacts/show': vi.fn(),
        'contactConversations/get': vi.fn(),
        'agents/get': vi.fn(),
        'teams/get': vi.fn(),
        'inboxes/get': vi.fn(),
        toggleStatus: vi.fn(),
        assignPriority: vi.fn(),
        assignAgent: vi.fn(),
        assignTeam: vi.fn(),
        setCurrentChatTeam: vi.fn(),
        createMessage: vi.fn(),
      },
    });
  };

  it('renders customer top profile details correctly', () => {
    const store = createTestStore();
    const wrapper = mount(CustomerDetailsDrawer, {
      props: { conversationId: 42, inboxId: 1 },
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
        },
        stubs: {
          ConversationLabels: true,
          ContactConversations: true,
          LinearIssuesList: true,
        },
      },
    });

    expect(wrapper.text()).toContain('Ada Lovelace');
    expect(wrapper.text()).toContain('@adalove');
    expect(wrapper.text()).toContain('ICX: ada_icx');
    expect(wrapper.text()).toContain('#vip');
    expect(wrapper.text()).toContain('#billing');
  });

  it('displays conversation details and private notes in information tab', () => {
    const store = createTestStore();
    const wrapper = mount(CustomerDetailsDrawer, {
      props: { conversationId: 42, inboxId: 1 },
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
        },
        stubs: {
          ConversationLabels: true,
          ContactConversations: true,
          LinearIssuesList: true,
        },
      },
    });

    expect(wrapper.text()).toContain('#42');
    expect(wrapper.text()).toContain('Billing');
    expect(wrapper.text()).toContain('Website Chat');
    expect(wrapper.text()).toContain('CONTACT_PANEL.DRAWER.PRIVATE_NOTES: 1');
    expect(wrapper.text()).toContain('Internal private note on this session');
    expect(wrapper.text()).toContain('Agent Smith');
  });

  it('switches to contact info tab and renders email, phone, location', async () => {
    const store = createTestStore();
    const wrapper = mount(CustomerDetailsDrawer, {
      props: { conversationId: 42, inboxId: 1 },
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
        },
        stubs: {
          ConversationLabels: true,
          ContactConversations: true,
          LinearIssuesList: true,
        },
      },
    });

    const tabButtons = wrapper.findAll('button');
    const contactInfoBtn = tabButtons.find(
      b => b.text() === 'CONTACT_PANEL.CONTACT_INFO_TAB'
    );
    if (contactInfoBtn) {
      await contactInfoBtn.trigger('click');
    }

    expect(wrapper.text()).toContain('ada@example.com');
    expect(wrapper.text()).toContain('+1234567890');
    expect(wrapper.text()).toContain('London, UK');
    expect(wrapper.text()).toContain('Europe/London');
  });

  it('switches to other tab and renders custom attributes and utm campaign', async () => {
    const store = createTestStore();
    const wrapper = mount(CustomerDetailsDrawer, {
      props: { conversationId: 42, inboxId: 1 },
      global: {
        plugins: [store],
        mocks: {
          $t: key => key,
        },
        stubs: {
          ConversationLabels: true,
          ContactConversations: true,
          LinearIssuesList: true,
        },
      },
    });

    const otherBtn = wrapper
      .findAll('button')
      .find(b => b.text() === 'CONTACT_PANEL.OTHER_TAB');
    if (otherBtn) {
      await otherBtn.trigger('click');
    }

    expect(wrapper.text()).toContain('Enterprise');
    expect(wrapper.text()).toContain('google');
  });
});
