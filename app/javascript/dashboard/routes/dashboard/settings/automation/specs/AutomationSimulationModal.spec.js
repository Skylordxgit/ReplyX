import { mount, flushPromises } from '@vue/test-utils';
import { vi } from 'vitest';
import automationLocale from 'dashboard/i18n/locale/en/automation.json';
import AutomationSimulationModal from '../AutomationSimulationModal.vue';

// Resolve against the real shipped locale file so these specs fail if a key is
// renamed or removed, instead of silently asserting a local duplicate.
const resolveKey = key =>
  key.split('.').reduce((node, part) => node?.[part], automationLocale);

const interpolate = (template, args = {}) =>
  Object.entries(args).reduce(
    (text, [name, value]) => text.replaceAll(`{${name}}`, value),
    template
  );

const translate = (key, args) => {
  const value = resolveKey(key);
  return typeof value === 'string' ? interpolate(value, args) : key;
};

// The component resolves trace copy through `useI18n()` in the setup block,
// so the composable needs the same dictionary as the template helper.
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: translate }),
}));

const i18nMock = { $t: translate };

const mountModal = automation =>
  mount(AutomationSimulationModal, {
    props: { automation },
    global: {
      mocks: i18nMock,
      stubs: {
        Dialog: { template: '<div><slot /></div>' },
        NextButton: {
          props: ['label'],
          template: '<button @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const runSimulation = async wrapper => {
  await wrapper.find('button').trigger('click');
  await flushPromises();
};

describe('AutomationSimulationModal', () => {
  const mockAutomation = {
    id: 1,
    name: 'VIP Auto-Triage',
    event_name: 'message_created',
    conditions: [
      {
        attribute_key: 'priority',
        filter_operator: 'equal_to',
        values: ['urgent'],
      },
    ],
    actions: [
      { action_name: 'assign_team', action_params: [1] },
      {
        action_name: 'send_message',
        action_params: ['We received your request.'],
      },
      {
        action_name: 'add_private_note',
        action_params: ['VIP routing executed'],
      },
    ],
  };

  it('renders simulation modal with dry-run controls', async () => {
    const wrapper = mountModal(mockAutomation);
    await flushPromises();

    expect(wrapper.text()).toContain('Test Inputs');
    expect(wrapper.text()).toContain('Run Simulation');
  });

  it('executes safe simulation and suppresses customer-facing communications', async () => {
    const wrapper = mountModal(mockAutomation);
    await flushPromises();
    await runSimulation(wrapper);

    expect(wrapper.text()).toContain('Execution Trace');
    expect(wrapper.text()).toContain('Trigger evaluated');
    expect(wrapper.text()).toContain(
      'Customer-facing action suppressed. Nothing was sent.'
    );
    expect(wrapper.text()).toContain('Dry run only. No data was changed.');
    expect(wrapper.text()).toContain('Simulation complete');
  });

  it('reports a match when the simulated conversation satisfies the conditions', async () => {
    // Default simulated priority is `urgent`, matching the rule.
    const wrapper = mountModal(mockAutomation);
    await flushPromises();
    await runSimulation(wrapper);

    expect(wrapper.text()).toContain('Rule matched');
    expect(wrapper.text()).toContain('1 of 1 condition(s) matched.');
  });

  it('reports no match and skips actions when a condition fails', async () => {
    const wrapper = mountModal(mockAutomation);
    await flushPromises();

    // Switch the simulated priority away from `urgent` so the rule cannot match.
    const prioritySelect = wrapper.findAll('select')[1];
    await prioritySelect.setValue('low');
    await runSimulation(wrapper);

    expect(wrapper.text()).toContain('Rule did not match');
    expect(wrapper.text()).toContain(
      'Actions were skipped because the conditions did not match.'
    );
    // Actions must not be reported as executed when the rule does not match.
    expect(wrapper.text()).not.toContain('Dry run only. No data was changed.');
  });

  it('evaluates contains conditions against the sample message', async () => {
    const wrapper = mountModal({
      ...mockAutomation,
      conditions: [
        {
          attribute_key: 'content',
          filter_operator: 'contains',
          values: ['refund'],
        },
      ],
    });
    await flushPromises();

    await wrapper.find('input[type="text"]').setValue('I want a refund please');
    await runSimulation(wrapper);

    expect(wrapper.text()).toContain('Rule matched');
  });
});
