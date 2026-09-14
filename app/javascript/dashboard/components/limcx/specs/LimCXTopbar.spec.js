import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import LimCXTopbar from '../LimCXTopbar.vue';

const createTestRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', name: 'home', component: { template: '<div>Home</div>' } },
      {
        path: '/inbox-view',
        name: 'inbox_view',
        component: { template: '<div>Inbox View</div>' },
      },
      {
        path: '/search',
        name: 'search',
        component: { template: '<div>Search</div>' },
      },
      {
        path: '/profile',
        name: 'profile_settings_index',
        component: { template: '<div>Profile</div>' },
      },
    ],
  });

const createMockStore = ({ availability = 'online' } = {}) =>
  createStore({
    state: {},
    getters: {
      getUISettings: () => ({}),
      getCurrentUser: () => ({
        id: 1,
        name: 'Alex Johnson',
        email: 'alex@example.com',
        available_name: 'Alex',
        accounts: [
          { id: 1, name: 'Workspace A', role: 'administrator' },
          { id: 2, name: 'Workspace B', role: 'agent' },
        ],
      }),
      getCurrentAccountId: () => 1,
      getCurrentUserAvailability: () => availability,
      'notifications/getUnreadCount': () => 7,
    },
    actions: {
      updateAvailability: vi.fn(),
    },
  });

describe('LimCXTopbar', () => {
  it('renders search bar, availability selector, notifications, and avatar', async () => {
    const store = createMockStore();
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXTopbar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('TOPBAR.SEARCH_PLACEHOLDER');
    expect(wrapper.text()).toContain('TOPBAR.STATUS_AVAILABLE');
    expect(wrapper.text()).toContain('7'); // unread notification count
  });

  it('updates availability status on selecting a different status', async () => {
    const store = createMockStore({ availability: 'online' });
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXTopbar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    // Open availability dropdown
    const statusBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('TOPBAR.STATUS_AVAILABLE'));
    await statusBtn.trigger('click');

    // Click 'Busy' option
    const busyBtn = wrapper
      .findAll('button')
      .find(b => b.text().includes('TOPBAR.STATUS_BUSY'));
    await busyBtn.trigger('click');

    expect(wrapper.text()).toContain('TOPBAR.STATUS_BUSY');
  });

  it('navigates to notifications on clicking notification bell', async () => {
    const store = createMockStore();
    const router = createTestRouter();
    await router.push('/');
    await router.isReady();

    const wrapper = mount(LimCXTopbar, {
      global: {
        plugins: [store, router],
      },
    });
    await flushPromises();

    const bellBtn = wrapper.find('button[title="TOPBAR.NOTIFICATIONS"]');
    await bellBtn.trigger('click');
    await flushPromises();

    expect(router.currentRoute.value.name).toBe('inbox_view');
  });
});
