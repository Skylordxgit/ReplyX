/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }

  resetPassword(agentId, data) {
    return axios.post(`${this.url}/${agentId}/reset_password`, {
      agent: data,
    });
  }
}

export default new Agents();
