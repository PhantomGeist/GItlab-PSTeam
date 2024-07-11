import { nextTick } from 'vue';
import { GridStack } from 'gridstack';
import { RouterLinkStub } from '@vue/test-utils';
import { GlLink, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CustomizableDashboard from 'ee/vue_shared/components/customizable_dashboard/customizable_dashboard.vue';
import PanelsBase from 'ee/vue_shared/components/customizable_dashboard/panels_base.vue';
import DateRangeFilter from 'ee/vue_shared/components/customizable_dashboard/filters/date_range_filter.vue';
import {
  GRIDSTACK_MARGIN,
  GRIDSTACK_CSS_HANDLE,
  GRIDSTACK_CELL_HEIGHT,
  GRIDSTACK_MIN_ROW,
} from 'ee/vue_shared/components/customizable_dashboard/constants';
import { loadCSSFile } from '~/lib/utils/css_utils';
import waitForPromises from 'helpers/wait_for_promises';
import {
  filtersToQueryParams,
  buildDefaultDashboardFilters,
} from 'ee/vue_shared/components/customizable_dashboard/utils';
import UrlSync, { HISTORY_REPLACE_UPDATE_METHOD } from '~/vue_shared/components/url_sync.vue';
import AvailableVisualizationsDrawer from 'ee/vue_shared/components/customizable_dashboard/dashboard_editor/available_visualizations_drawer.vue';
import { NEW_DASHBOARD } from 'ee/analytics/analytics_dashboards/constants';
import {
  TEST_VISUALIZATION,
  TEST_EMPTY_DASHBOARD_SVG_PATH,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { dashboard, builtinDashboard, mockDateRangeFilterChangePayload } from './mock_data';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

const mockGridSetStatic = jest.fn();
jest.mock('gridstack', () => ({
  GridStack: {
    init: jest.fn(() => {
      return {
        on: jest.fn(),
        destroy: jest.fn(),
        makeWidget: jest.fn(),
        setStatic: mockGridSetStatic,
        removeWidget: jest.fn(),
      };
    }),
  },
}));

jest.mock('~/lib/utils/css_utils', () => ({
  loadCSSFile: jest.fn(),
}));

describe('CustomizableDashboard', () => {
  let wrapper;

  const sentryError = new Error('Network error');

  const $router = {
    push: jest.fn(),
  };

  const createWrapper = (
    props = {},
    loadedDashboard = dashboard,
    provide = {},
    routeParams = {},
  ) => {
    const loadDashboard = { ...loadedDashboard };

    wrapper = shallowMountExtended(CustomizableDashboard, {
      propsData: {
        initialDashboard: loadDashboard,
        availableVisualizations: {
          loading: true,
          hasError: false,
          visualizations: [],
        },
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
        GlSprintf,
      },
      mocks: {
        $router,
        $route: {
          params: routeParams,
        },
      },
      provide: {
        dashboardEmptyStateIllustrationPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        ...provide,
      },
    });
  };

  const findDashboardTitle = () => wrapper.findByTestId('dashboard-title');
  const findEditModeTitle = () => wrapper.findByTestId('edit-mode-title');
  const findGridStackPanels = () => wrapper.findAllByTestId('grid-stack-panel');
  const findPanels = () => wrapper.findAllComponents(PanelsBase);
  const findPanelById = (panelId) => wrapper.find(`#${panelId}`);
  const findEditButton = () => wrapper.findByTestId('dashboard-edit-btn');
  const findAddVisualizationButton = () => wrapper.findByTestId('add-visualization-button');
  const findTitleInput = () => wrapper.findByTestId('dashboard-title-input');
  const findTitleFormGroup = () => wrapper.findByTestId('dashboard-title-form-group');
  const findDescriptionInput = () => wrapper.findByTestId('dashboard-description-input');
  const findSaveButton = () => wrapper.findByTestId('dashboard-save-btn');
  const findCancelButton = () => wrapper.findByTestId('dashboard-cancel-edit-btn');
  const findFilters = () => wrapper.findByTestId('dashboard-filters');
  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const findVisualizationDrawer = () => wrapper.findComponent(AvailableVisualizationsDrawer);
  const findDashboardDescription = () => wrapper.findByTestId('dashboard-description');
  const findDashboardHelpLink = () => wrapper.findByTestId('dashboard-help-link');

  const enterDashboardTitle = async (title, titleValidationError = '') => {
    await findTitleInput().vm.$emit('input', title);
    await wrapper.setProps({ titleValidationError });
  };

  const enterDashboardDescription = async (description) => {
    await findDescriptionInput().vm.$emit('input', description);
  };

  describe('when being created and an error occurs while loading the CSS', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
      loadCSSFile.mockRejectedValue(sentryError);

      createWrapper();
    });

    it('reports the error to sentry', async () => {
      await waitForPromises();
      expect(Sentry.captureException.mock.calls[0][0]).toStrictEqual(sentryError);
    });
  });

  describe('when mounted updates', () => {
    let wrapperLimited;
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      wrapperLimited = document.createElement('div');
      wrapperLimited.classList.add('container-fluid', 'container-limited');
      document.body.appendChild(wrapperLimited);

      createWrapper();
    });

    afterEach(() => {
      document.body.removeChild(wrapperLimited);
    });

    it('body container', () => {
      expect(document.querySelectorAll('.container-fluid.not-container-limited').length).toBe(1);
    });

    it('body container after destroy', () => {
      wrapper.destroy();

      expect(document.querySelectorAll('.container-fluid.not-container-limited').length).toBe(0);
      expect(document.querySelectorAll('.container-fluid.container-limited').length).toBe(1);
    });
  });

  describe('default behaviour', () => {
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper({}, dashboard);
    });

    it('sets up GridStack', () => {
      expect(GridStack.init).toHaveBeenCalledWith({
        alwaysShowResizeHandle: true,
        staticGrid: true,
        animate: false,
        margin: GRIDSTACK_MARGIN,
        handle: GRIDSTACK_CSS_HANDLE,
        cellHeight: GRIDSTACK_CELL_HEIGHT,
        minRow: GRIDSTACK_MIN_ROW,
      });
    });

    it.each(
      dashboard.panels.map((panel, index) => [
        panel.title,
        panel.visualization,
        panel.gridAttributes,
        panel.queryOverrides,
        index,
      ]),
    )(
      'should render the panel for %s',
      (title, visualization, gridAttributes, queryOverrides, index) => {
        expect(findPanels().at(index).props()).toMatchObject({
          title,
          visualization,
          // The panel component defaults `queryOverrides` to {} when falsy
          queryOverrides: queryOverrides || {},
        });

        expect(findGridStackPanels().at(index).attributes()).toMatchObject({
          'gs-id': expect.stringContaining('panel-'),
          'gs-h': `${gridAttributes.height}`,
          'gs-w': `${gridAttributes.width}`,
        });
      },
    );

    it('shows the dashboard title', () => {
      expect(findDashboardTitle().text()).toBe('Analytics Overview');
    });

    it('shows the dashboard description', () => {
      expect(findDashboardDescription().text()).toBe('This is a dashboard');
    });

    it('does not show the edit mode page title', () => {
      expect(findEditModeTitle().exists()).toBe(false);
    });

    it('does not show the "edit" or "cancel" button', () => {
      expect(findEditButton().exists()).toBe(false);
      expect(findCancelButton().exists()).toBe(false);
    });

    it('does not show the title input', () => {
      expect(findTitleInput().exists()).toBe(false);
    });

    it('does not show the description input', () => {
      expect(findDescriptionInput().exists()).toBe(false);
    });

    it('does not show the filters', () => {
      expect(findFilters().exists()).toBe(false);
    });

    it('does not sync filters with the URL', () => {
      expect(findUrlSync().exists()).toBe(false);
    });

    it('does not show a dashboard documentation link', () => {
      expect(findDashboardDescription().findComponent(GlLink).exists()).toBe(false);
    });
  });

  describe('when a dashboard has no description', () => {
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper({}, { ...dashboard, description: undefined });
    });

    it('does not show the dashboard description', () => {
      expect(findDashboardDescription().exists()).toBe(false);
    });
  });

  describe('when the slug is "value_stream_dashboard"', () => {
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper({}, { ...builtinDashboard, slug: 'value_stream_dashboard' });
    });

    it('shows a "Learn more" link to the VSD user docs', () => {
      expect(findDashboardHelpLink().text()).toBe('Learn more');
      expect(findDashboardHelpLink().attributes('href')).toBe(
        '/help/user/analytics/value_streams_dashboard',
      );
    });
  });

  describe('when the combinedAnalyticsDashboardsEditor feature flag is enabled', () => {
    describe('with a built-in dashboard', () => {
      beforeEach(() => {
        loadCSSFile.mockResolvedValue();

        createWrapper({}, builtinDashboard, {
          glFeatures: { combinedAnalyticsDashboardsEditor: true },
        });
      });

      it('does not show the edit button', () => {
        expect(findEditButton().exists()).toBe(false);
      });
    });

    describe('with a custom dashboard', () => {
      beforeEach(() => {
        loadCSSFile.mockResolvedValue();

        createWrapper({}, dashboard, { glFeatures: { combinedAnalyticsDashboardsEditor: true } });
      });

      it('shows the Edit Button', () => {
        expect(findEditButton().exists()).toBe(true);
      });

      describe('when mounted with the $route.editing param', () => {
        beforeEach(() => {
          createWrapper(
            {},
            dashboard,
            { glFeatures: { combinedAnalyticsDashboardsEditor: true } },
            { editing: true },
          );
        });

        it('render the visualization drawer in edit mode', () => {
          expect(findVisualizationDrawer().exists()).toBe(true);
        });
      });

      describe('when editing', () => {
        let windowDialogSpy;
        let beforeUnloadEvent;

        beforeEach(() => {
          beforeUnloadEvent = new Event('beforeunload');
          windowDialogSpy = jest.spyOn(beforeUnloadEvent, 'returnValue', 'set');

          findEditButton().vm.$emit('click');
        });

        afterEach(() => {
          windowDialogSpy.mockRestore();
        });

        it('sets the grid to non-static mode', () => {
          expect(mockGridSetStatic).toHaveBeenCalledWith(false);
        });

        it('shows the edit mode page title', () => {
          expect(findEditModeTitle().text()).toBe('Edit your dashboard');
        });

        it('does not show the dashboard title header', () => {
          expect(findDashboardTitle().exists()).toBe(false);
        });

        it('shows the Save button', () => {
          expect(findSaveButton().props('loading')).toBe(false);
        });

        it('updates grid panels when their values change', async () => {
          const gridPanel = findGridStackPanels().at(0);

          await wrapper.vm.updatePanelWithGridStackItem({
            id: gridPanel.attributes('id'),
            x: 10,
            y: 20,
            w: 30,
            h: 40,
          });

          expect(gridPanel.attributes()).toMatchObject({
            'gs-h': '40',
            'gs-w': '30',
            'gs-x': '10',
            'gs-y': '20',
          });
        });

        it('shows an input element with the title as value', () => {
          expect(findTitleInput().attributes()).toMatchObject({
            value: 'Analytics Overview',
            required: '',
          });
        });

        it('shows an input element with the description as value', () => {
          expect(findDescriptionInput().attributes('value')).toBe('This is a dashboard');
        });

        it('emits an event when title is edited', async () => {
          await enterDashboardTitle('New Title');

          expect(wrapper.emitted('title-input')[0]).toContain('New Title');
        });

        it('saves the dashboard changes when the "save" button is clicked', async () => {
          await enterDashboardTitle('New Title');

          await findSaveButton().vm.$emit('click');

          expect(wrapper.emitted('save')).toMatchObject([
            [
              'analytics_overview',
              {
                ...dashboard,
                title: 'New Title',
              },
            ],
          ]);
        });

        it('shows the "cancel" button', () => {
          expect(findCancelButton().exists()).toBe(true);
        });

        describe('and the "cancel" button is clicked with no changes made', () => {
          afterEach(() => {
            confirmAction.mockReset();
          });

          beforeEach(() => {
            confirmAction.mockReturnValue(new Promise(() => {}));

            return findCancelButton().vm.$emit('click');
          });

          it('does not show the confirm dialog', () => {
            expect(confirmAction).not.toHaveBeenCalled();
          });

          it('disables the edit state', () => {
            expect(findEditModeTitle().exists()).toBe(false);
          });

          it('sets the grid to static mode', () => {
            expect(mockGridSetStatic).toHaveBeenCalledWith(true);
          });
        });

        it('does not show the confirmation dialog when the "beforeunload" is emitted', () => {
          window.dispatchEvent(beforeUnloadEvent);

          expect(windowDialogSpy).not.toHaveBeenCalled();
        });

        describe('and changed were made', () => {
          beforeEach(() => {
            return findVisualizationDrawer().vm.$emit('select', [TEST_VISUALIZATION()]);
          });

          it('shows the browser confirmation dialog when the "beforeunload" is emitted', () => {
            window.dispatchEvent(beforeUnloadEvent);

            expect(windowDialogSpy).toHaveBeenCalledWith(
              'Are you sure you want to lose unsaved changes?',
            );
          });

          describe('and the "cancel" button is clicked', () => {
            afterEach(() => {
              confirmAction.mockReset();
            });

            it('shows confirm modal when the title was changed', async () => {
              confirmAction.mockReturnValue(new Promise(() => {}));

              await findCancelButton().vm.$emit('click');

              expect(confirmAction).toHaveBeenCalledWith(
                'Are you sure you want to cancel editing this dashboard?',
                {
                  cancelBtnText: 'Continue editing',
                  primaryBtnText: 'Discard changes',
                },
              );
            });

            it('resets the dashboard if the user confirms', async () => {
              confirmAction.mockResolvedValue(true);

              await findCancelButton().vm.$emit('click');
              await waitForPromises();

              expect(GridStack.init).toHaveBeenCalledTimes(2);
              expect(findPanels()).toHaveLength(dashboard.panels.length);
            });

            it('does nothing if the user opts to keep editing', async () => {
              confirmAction.mockResolvedValue(false);

              await findCancelButton().vm.$emit('click');
              await waitForPromises();

              expect(GridStack.init).toHaveBeenCalledTimes(1);
              expect(findPanels()).toHaveLength(dashboard.panels.length + 1);
            });
          });
        });

        it('does not show the "edit" button', () => {
          expect(findEditButton().exists()).toBe(false);
        });

        it('shows the visualization drawer', () => {
          expect(findVisualizationDrawer().props()).toMatchObject({
            visualizations: {},
            loading: true,
            open: false,
          });
        });

        it('closes the drawer when the visualization drawer emits "close"', async () => {
          await findVisualizationDrawer().vm.$emit('close');

          expect(findVisualizationDrawer().props('open')).toBe(false);
        });

        it('closes the drawer when a visualization is selected', async () => {
          await findVisualizationDrawer().vm.$emit('select', [TEST_VISUALIZATION()]);

          expect(findVisualizationDrawer().props('open')).toBe(false);
        });

        it('add a new panel when a visualization is selected', async () => {
          expect(findPanels()).toHaveLength(2);

          const visualization = TEST_VISUALIZATION();
          await findVisualizationDrawer().vm.$emit('select', [visualization]);
          await nextTick();

          const updatedPanels = findPanels();
          expect(updatedPanels).toHaveLength(3);
          expect(updatedPanels.at(-1).props('visualization')).toMatchObject(visualization);
        });
      });
    });
  });

  describe('when the date range filter is enabled and configured', () => {
    const defaultFilters = buildDefaultDashboardFilters('');

    describe('by default', () => {
      beforeEach(() => {
        loadCSSFile.mockResolvedValue();

        createWrapper({ showDateRangeFilter: true, syncUrlFilters: true, defaultFilters });
      });

      it('shows the date range filter and passes the default options and filters', () => {
        expect(findDateRangeFilter().props()).toMatchObject({
          startDate: defaultFilters.startDate,
          endDate: defaultFilters.endDate,
          defaultOption: defaultFilters.dateRangeOption,
          dateRangeLimit: 0,
        });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          query: filtersToQueryParams(defaultFilters),
        });
      });

      it('sets the panel filters to the default date range', () => {
        expect(findPanels().at(0).props().filters).toStrictEqual(defaultFilters);
      });

      it('updates the panel filters when the date range is changed', async () => {
        await findDateRangeFilter().vm.$emit('change', mockDateRangeFilterChangePayload);

        expect(findPanels().at(0).props().filters).toStrictEqual(mockDateRangeFilterChangePayload);
      });
    });

    describe.each([0, 12, 31])('when given a date range limit of %d', (dateRangeLimit) => {
      beforeEach(() => {
        loadCSSFile.mockResolvedValue();

        createWrapper({
          showDateRangeFilter: true,
          syncUrlFilters: true,
          defaultFilters,
          dateRangeLimit,
        });
      });

      it('passes the date range limit to the date range filter', () => {
        expect(findDateRangeFilter().props()).toMatchObject({
          dateRangeLimit,
        });
      });
    });
  });

  describe('when a dashboard is new and the editing feature flag is enabled', () => {
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper(
        {
          isNewDashboard: true,
        },
        NEW_DASHBOARD(),
        { glFeatures: { combinedAnalyticsDashboardsEditor: true } },
      );
    });

    it('routes to the dashboard listing page when "cancel" is clicked', async () => {
      await findCancelButton().vm.$emit('click');

      expect($router.push).toHaveBeenCalledWith('/');
    });

    describe('and the "cancel" button is clicked with changes made', () => {
      afterEach(() => {
        confirmAction.mockReset();
      });

      beforeEach(() => {
        return findVisualizationDrawer().vm.$emit('select', [TEST_VISUALIZATION()]);
      });

      it('shows a confirmation modal for new dashboards', async () => {
        confirmAction.mockReturnValue(new Promise(() => {}));

        await findCancelButton().vm.$emit('click');

        expect(confirmAction).toHaveBeenCalledWith(
          'Are you sure you want to cancel creating this dashboard?',
          {
            cancelBtnText: 'Continue creating',
            primaryBtnText: 'Discard changes',
          },
        );
      });

      it('routes to the dashboard listing if the user confirms', async () => {
        confirmAction.mockResolvedValue(true);

        await findCancelButton().vm.$emit('click');
        await waitForPromises();

        expect($router.push).toHaveBeenCalledWith('/');
      });

      it('does nothing if the user opts to keep creating', async () => {
        confirmAction.mockResolvedValue(false);

        await findCancelButton().vm.$emit('click');
        await waitForPromises();

        expect($router.push).not.toHaveBeenCalled();
        expect(GridStack.init).toHaveBeenCalledTimes(1);
        expect(findPanels()).toHaveLength(NEW_DASHBOARD().panels.length + 1);
      });
    });

    it('shows the new dashboard page title', () => {
      expect(findEditModeTitle().text()).toBe('Create your dashboard');
    });

    it('shows the "Add visualization" button', () => {
      expect(findAddVisualizationButton().text()).toBe('Add visualization');
    });

    it('does not show the filters', () => {
      expect(findDateRangeFilter().exists()).toBe(false);
    });

    describe('and the user clicks on the "Add visualization" button', () => {
      beforeEach(() => {
        return findAddVisualizationButton().trigger('click');
      });

      it('opens the drawer', () => {
        expect(findVisualizationDrawer().props('open')).toBe(true);
      });

      it('closes the drawer when the user clicks on the same button again', async () => {
        await findAddVisualizationButton().trigger('click');

        expect(findVisualizationDrawer().props('open')).toBe(false);
      });
    });

    describe('when saving', () => {
      describe('and there is no title nor visualizations', () => {
        beforeEach(async () => {
          findTitleInput().element.focus = jest.fn();

          await findSaveButton().vm.$emit('click');
          await wrapper.setProps({ titleValidationError: 'This field is required.' });
        });

        it('does not save the dashboard', () => {
          expect(wrapper.emitted('save')).toBeUndefined();
        });

        it('shows the invalid state on the title input', () => {
          expect(findTitleFormGroup().attributes('state')).toBe(undefined);
          expect(findTitleFormGroup().attributes('invalid-feedback')).toBe(
            'This field is required.',
          );

          expect(findTitleInput().attributes('state')).toBe(undefined);
        });

        it('sets focus on the dashboard title input', () => {
          expect(findTitleInput().element.focus).toHaveBeenCalled();
        });

        describe('and a user then inputs a title', () => {
          beforeEach(async () => {
            await enterDashboardTitle('New Title');
          });

          it('shows title input as valid', () => {
            expect(findTitleFormGroup().attributes('state')).toBe('true');
            expect(findTitleInput().attributes('state')).toBe('true');
          });
        });
      });

      describe('and there is a title but no visualizations', () => {
        beforeEach(async () => {
          await enterDashboardTitle('New Title');
          await findSaveButton().vm.$emit('click');
        });

        it('does not save the dashboard', () => {
          expect(wrapper.emitted('save')).toBeUndefined();
        });

        it('shows an alert', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: 'Add a visualization' });
        });

        describe('and the component is destroyed', () => {
          beforeEach(() => {
            wrapper.destroy();

            return nextTick();
          });

          it('dismisses the alert', () => {
            expect(mockAlertDismiss).toHaveBeenCalled();
          });
        });

        describe('and saved is clicked after a visualization has been added', () => {
          beforeEach(async () => {
            await findVisualizationDrawer().vm.$emit('select', [TEST_VISUALIZATION()]);

            await findSaveButton().vm.$emit('click');
          });

          it('dismisses the alert', () => {
            expect(mockAlertDismiss).toHaveBeenCalled();
          });
        });
      });

      describe('and there is a title and visualizations', () => {
        beforeEach(async () => {
          await enterDashboardTitle('New Title');

          await findVisualizationDrawer().vm.$emit('select', [TEST_VISUALIZATION()]);

          await findSaveButton().vm.$emit('click');
        });

        it('shows title input as valid', () => {
          expect(findTitleFormGroup().attributes('state')).toBe('true');
          expect(findTitleInput().attributes('state')).toBe('true');
        });

        it('does not show an alert', () => {
          expect(mockAlertDismiss).not.toHaveBeenCalled();
        });

        it('saves the dashboard with a new a slug', () => {
          expect(wrapper.emitted('save')).toStrictEqual([
            [
              'new_title',
              {
                slug: 'new_title',
                title: 'New Title',
                description: '',
                panels: [expect.any(Object)],
                userDefined: true,
              },
            ],
          ]);
        });
      });

      describe('and there is a title, visualizations and a description', () => {
        beforeEach(async () => {
          await enterDashboardTitle('New Title');
          await findVisualizationDrawer().vm.$emit('select', [TEST_VISUALIZATION()]);

          await enterDashboardDescription('New description');

          await findSaveButton().vm.$emit('click');
        });

        it('saves the dashboard with a new description', () => {
          expect(wrapper.emitted('save')).toStrictEqual([
            [
              'new_title',
              {
                slug: 'new_title',
                title: 'New Title',
                description: 'New description',
                panels: [expect.any(Object)],
                userDefined: true,
              },
            ],
          ]);
        });
      });
    });
  });

  describe('when saving while editing and the editor is enabled', () => {
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper({ isSaving: true }, dashboard, {
        glFeatures: { combinedAnalyticsDashboardsEditor: true },
      });

      findEditButton().vm.$emit('click');
    });

    it('shows the Save button as loading', () => {
      expect(findSaveButton().props('loading')).toBe(true);
    });
  });

  describe('changes saved', () => {
    it.each`
      editing  | changesSaved | newState
      ${true}  | ${true}      | ${false}
      ${true}  | ${false}     | ${true}
      ${false} | ${true}      | ${false}
      ${false} | ${false}     | ${false}
    `(
      'when editing="$editing" and changesSaved="$changesSaved" the new editing state is "$newState',
      async ({ editing, changesSaved, newState }) => {
        createWrapper({ changesSaved, isNewDashboard: editing }, dashboard, {
          glFeatures: { combinedAnalyticsDashboardsEditor: true },
        });

        await nextTick();

        expect(findEditModeTitle().exists()).toBe(newState);
      },
    );
  });

  describe('when panel emits "delete" event', () => {
    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper();
    });

    it('should remove the panel from the dashboard', async () => {
      const gridPanel = findGridStackPanels().at(0);
      const panelId = gridPanel.attributes('id');
      const panel = gridPanel.findComponent(PanelsBase);

      expect(findPanels()).toHaveLength(2);
      expect(findPanelById(panelId).exists()).toBe(true);

      panel.vm.$emit('delete', { id: panelId });
      await nextTick();

      expect(findPanels()).toHaveLength(1);
      expect(findPanelById(panelId).exists()).toBe(false);
    });
  });

  describe('when editing a custom dashboard with no panels', () => {
    const dashboardWithoutPanels = {
      ...dashboard,
      panels: [],
    };

    beforeEach(() => {
      loadCSSFile.mockResolvedValue();

      createWrapper({}, dashboardWithoutPanels, {
        glFeatures: { combinedAnalyticsDashboardsEditor: true },
      });

      return findEditButton().vm.$emit('click');
    });

    it('does not validate the presence of panels when saving', async () => {
      await findSaveButton().vm.$emit('click');

      expect(createAlert).not.toHaveBeenCalled();

      expect(wrapper.emitted('save')).toStrictEqual([
        [dashboardWithoutPanels.slug, dashboardWithoutPanels],
      ]);
    });
  });

  // TODO: Move this along with all the dialog logic to analytics dashboard.
  // This is planned as part of the larger refactor to simplify this component.
  // https://gitlab.com/gitlab-org/gitlab/-/issues/426550
  describe('confirmDiscardIfChanged', () => {
    beforeAll(() => {
      confirmAction.mockResolvedValue(false);
    });

    afterAll(() => {
      confirmAction.mockReset();
    });

    describe.each`
      isSaving | changesMade | expected
      ${true}  | ${true}     | ${true}
      ${false} | ${true}     | ${false}
      ${true}  | ${false}    | ${true}
      ${false} | ${false}    | ${true}
    `(
      'when isSaving=$isSaving and changesMade=$changesMade',
      ({ isSaving, changesMade, expected }) => {
        beforeEach(async () => {
          loadCSSFile.mockResolvedValue();

          createWrapper({ isSaving }, dashboard, {
            glFeatures: { combinedAnalyticsDashboardsEditor: true },
          });

          await findEditButton().vm.$emit('click');

          if (changesMade) await enterDashboardTitle('New Title');
        });

        it(`it returns ${expected}`, async () => {
          // This only gets called from AnalyticsDashboard so we need to test
          // the method directly here since it's not called in the component.
          expect(await wrapper.vm.confirmDiscardIfChanged()).toBe(expected);
        });
      },
    );
  });
});
