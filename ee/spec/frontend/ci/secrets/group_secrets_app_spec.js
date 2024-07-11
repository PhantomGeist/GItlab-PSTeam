import { shallowMount } from '@vue/test-utils';
import GroupSecretsApp from 'ee/ci/secrets/group_secrets_app.vue';

describe('GroupSecretsApp', () => {
  let wrapper;

  const props = { groupPath: '/path/to/group', groupId: '123' };

  const createComponent = () => {
    wrapper = shallowMount(GroupSecretsApp, { propsData: { ...props } });
  };

  it('renders the secrets app', () => {
    createComponent(props);

    expect(wrapper.findComponent(GroupSecretsApp).exists()).toBe(true);
  });
});
