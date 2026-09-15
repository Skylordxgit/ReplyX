import CannedResponseAPI from 'dashboard/api/cannedResponse';
import CannedResponses from '../../cannedResponse';
import * as types from '../../../mutation-types';

vi.mock('dashboard/api/cannedResponse');

describe('#getCannedResponse', () => {
  it('always fetches the user-scoped response list from the API', async () => {
    CannedResponseAPI.get.mockResolvedValue({ data: [{ id: 1 }] });
    const commit = vi.fn();

    await CannedResponses.actions.getCannedResponse({ commit });

    expect(CannedResponseAPI.get).toHaveBeenCalledWith();
    expect(commit).toHaveBeenCalledWith(types.default.SET_CANNED, [{ id: 1 }]);
  });
});
