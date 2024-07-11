import { shallowMount } from '@vue/test-utils';
import ProjectSecretsApp from 'ee/ci/secrets/project_secrets_app.vue';

describe('ProjectSecretsApp', () => {
  let wrapper;

  const props = { projectPath: '/path/to/project', projectId: '123' };

  const createComponent = () => {
    wrapper = shallowMount(ProjectSecretsApp, { propsData: { ...props } });
  };

  it('renders the secrets app', () => {
    createComponent(props);

    expect(wrapper.findComponent(ProjectSecretsApp).exists()).toBe(true);
  });
});
