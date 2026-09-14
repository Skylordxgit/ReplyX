import { frontendURL } from '../../../helper/URLHelper';
import LiveQueue from './LiveQueue.vue';
import AgentWorkload from './AgentWorkload.vue';
import TeamAvailability from './TeamAvailability.vue';
import ChannelHealth from './ChannelHealth.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/operations/live-queue'),
      name: 'operations_live_queue',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: LiveQueue,
    },
    {
      path: frontendURL('accounts/:accountId/operations/agent-workload'),
      name: 'operations_agent_workload',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: AgentWorkload,
    },
    {
      path: frontendURL('accounts/:accountId/operations/team-availability'),
      name: 'operations_team_availability',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: TeamAvailability,
    },
    {
      path: frontendURL('accounts/:accountId/operations/channel-health'),
      name: 'operations_channel_health',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: ChannelHealth,
    },
  ],
};
