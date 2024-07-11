import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OrganizationSettings from '~/organizations/settings/general/components/organization_settings.vue';
import App from '~/organizations/settings/general/components/app.vue';

describe('OrganizationSettings', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(App);
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders `Organization settings` section', () => {
    expect(wrapper.findComponent(OrganizationSettings).exists()).toBe(true);
  });
});
