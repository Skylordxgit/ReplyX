import { mount } from '@vue/test-utils';
import { describe, it, expect } from 'vitest';
import AgentReportsCharts from '../AgentReportsCharts.vue';

describe('AgentReportsCharts.vue', () => {
  const reportMetrics = [
    {
      id: 1,
      name: 'Agent One',
      closedCount: 120,
      currentWorkload: 15,
      avgFirstResponseTime: 45,
      avgReplyTime: 90,
      avgResolutionTime: 300,
      csatScore: 95.5,
    },
    {
      id: 2,
      name: 'Agent Two',
      closedCount: 80,
      currentWorkload: 10,
      avgFirstResponseTime: 60,
      avgReplyTime: 120,
      avgResolutionTime: 400,
      csatScore: 90.0,
    },
  ];

  const agents = [
    { id: 1, name: 'Agent One' },
    { id: 2, name: 'Agent Two' },
  ];

  it('renders all 6 metric chart cards with correct aggregate values', () => {
    const wrapper = mount(AgentReportsCharts, {
      props: { reportMetrics, agents },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    expect(wrapper.text()).toContain('200'); // total closed: 120 + 80
    expect(wrapper.text()).toContain('25'); // total workload: 15 + 10
    expect(wrapper.text()).toContain('92.8%'); // average csat: (95.5 + 90) / 2
  });

  it('emits drilldown event when clicking closed chats card', async () => {
    const wrapper = mount(AgentReportsCharts, {
      props: { reportMetrics, agents },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    const cards = wrapper.findAll('.cursor-pointer');
    // Card 4 is Closed Chats
    await cards[3].trigger('click');

    expect(wrapper.emitted('drilldown')).toBeTruthy();
    expect(wrapper.emitted('drilldown')[0][0].metric).toBe('resolutions_count');
    expect(wrapper.emitted('drilldown')[0][0].bucketValue).toBe(200);
  });
});
