import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import { GlBreadcrumb } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { sidebarState } from '~/super_sidebar/constants';
import SuperSidebarToggle from '~/super_sidebar/components/super_sidebar_toggle.vue';
import NewTopLevelGroupAlert from '~/groups/components/new_top_level_group_alert.vue';
import getUserCalloutsQuery from '~/graphql_shared/queries/get_user_callouts.query.graphql';
import WelcomePage from '~/vue_shared/new_namespace/components/welcome.vue';
import NewNamespacePage from '~/vue_shared/new_namespace/new_namespace_page.vue';

Vue.use(VueApollo);

describe('Experimental new project creation app', () => {
  let wrapper;

  const findSuperSidebarToggle = () => wrapper.findComponent(SuperSidebarToggle);
  const findBreadcrumbs = () => wrapper.findComponent(GlBreadcrumb);
  const findActivePanelTemplate = () => wrapper.findByTestId('active-panel-template');
  const findTopLevelGroupAlert = () => wrapper.findComponent(NewTopLevelGroupAlert);
  const findWelcomePage = () => wrapper.findComponent(WelcomePage);

  const DEFAULT_PROPS = {
    title: 'Create something',
    initialBreadcrumbs: [{ text: 'Something', href: '#' }],
    panels: [
      {
        name: 'panel1',
        selector: '#some-selector1',
        title: 'panel title',
        details: 'details1',
        description: 'description1',
        detailProps: { parentGroupName: '' },
      },
    ],
    persistenceKey: 'DEMO-PERSISTENCE-KEY',
  };

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      mount(NewNamespacePage, {
        propsData: {
          ...DEFAULT_PROPS,
          ...props,
        },
        apolloProvider: createMockApollo([[getUserCalloutsQuery, {}]]),
      }),
    );
  };

  describe('SuperSidebarToggle', () => {
    let originalGon;

    beforeEach(() => {
      originalGon = window.gon;
      window.gon = { use_new_navigation: true };
      sidebarState.isCollapsed = true;
    });

    afterEach(() => {
      window.gon = originalGon;
    });

    it('shows sidebar toggle', () => {
      createComponent();

      expect(findSuperSidebarToggle().exists()).toBe(true);
    });

    describe('when is not new navigation', () => {
      it('does not show sidebar toggle', () => {
        window.gon = { use_new_navigation: false };

        createComponent();

        expect(findSuperSidebarToggle().exists()).toBe(false);
      });
    });

    describe('when is not collapsed', () => {
      it('does not show sidebar toggle', () => {
        sidebarState.isCollapsed = false;

        createComponent();

        expect(findSuperSidebarToggle().exists()).toBe(false);
      });
    });
  });

  it('shows breadcrumbs', () => {
    createComponent();

    expect(findBreadcrumbs().exists()).toBe(true);
  });

  describe('active panel', () => {
    beforeEach(() => {
      setHTMLFixture(`<div id="some-selector1"></div>`);
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('shows active panel', () => {
      createComponent({ jumpToLastPersistedPanel: true });

      const wrapperText = wrapper.text();

      expect(findActivePanelTemplate().exists()).toBe(true);
      expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].title);
      expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].details);

      expect(findTopLevelGroupAlert().exists()).toBe(false);

      expect(findWelcomePage().exists()).toBe(false);
    });

    it('shows top level group alert', () => {
      createComponent({ jumpToLastPersistedPanel: true, isSaas: true });

      expect(findTopLevelGroupAlert().exists()).toBe(true);
    });

    describe('when child panel', () => {
      it('does not show top level group alert', () => {
        createComponent({
          jumpToLastPersistedPanel: true,
          isSaas: true,
          panels: [{ selector: '#some-selector1', detailProps: { parentGroupName: 'parent1' } }],
        });

        expect(findTopLevelGroupAlert().exists()).toBe(false);
      });
    });
  });

  it('shows welcome page', () => {
    createComponent();

    const wrapperText = wrapper.text();

    expect(findWelcomePage().exists()).toBe(true);
    expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].title);
    expect(wrapperText).toContain(DEFAULT_PROPS.panels[0].description);

    expect(findActivePanelTemplate().exists()).toBe(false);
  });
});
