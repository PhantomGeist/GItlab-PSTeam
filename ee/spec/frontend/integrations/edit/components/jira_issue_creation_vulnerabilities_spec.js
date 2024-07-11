import { GlAlert, GlBadge, GlCollapsibleListbox } from '@gitlab/ui';
import { within } from '@testing-library/dom';
import { mount, shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import JiraIssueCreationVulnerabilities, {
  i18n,
} from 'ee/integrations/edit/components/jira_issue_creation_vulnerabilities.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { createStore } from '~/integrations/edit/store';
import { billingPlans, billingPlanNames } from '~/integrations/constants';

describe('JiraIssueCreationVulnerabilities', () => {
  let store;
  let wrapper;

  const defaultProps = {
    initialIssueTypeId: '10000',
  };

  const TEST_JIRA_ISSUE_TYPES = [
    { id: '1', name: 'issue', description: 'issue' },
    { id: '2', name: 'bug', description: 'bug' },
    { id: '3', name: 'epic', description: 'epic' },
  ];

  const createComponent = (mountFn) => ({ isInheriting = false, props } = {}) => {
    store = createStore({
      defaultState: isInheriting ? {} : undefined,
    });

    return extendedWrapper(
      mountFn(JiraIssueCreationVulnerabilities, {
        store,
        propsData: { ...defaultProps, ...props },
      }),
    );
  };

  const createShallowComponent = createComponent(shallowMount);
  const createFullComponent = createComponent(mount);

  const withinComponent = () => within(wrapper.element);
  const findHiddenInput = (name) => wrapper.find(`input[name="service[${name}]"]`);
  const findEnableJiraVulnerabilities = () => wrapper.findByTestId('enable-jira-vulnerabilities');
  const findIssueTypeSection = () => wrapper.findByTestId('issue-type-section');
  const findIssueTypeListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findIssueTypeLabel = () => wrapper.findComponent('label');
  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findFetchIssueTypeButton = () => wrapper.findByTestId('fetch-issue-types');
  const findFetchErrorAlert = () => wrapper.findComponent(GlAlert);
  const setEnableJiraVulnerabilitiesChecked = (isChecked) =>
    findEnableJiraVulnerabilities().vm.$emit('input', isChecked);

  describe('content', () => {
    beforeEach(() => {
      wrapper = createFullComponent();
    });

    it('contains a heading', () => {
      expect(withinComponent().getByText(i18n.checkbox.label)).not.toBe(null);
    });

    it('contains a GlBadge', () => {
      expect(findGlBadge().exists()).toBe(true);
      expect(findGlBadge().text()).toMatchInterpolatedText(billingPlanNames[billingPlans.ULTIMATE]);
    });

    it('contains a more detailed description', () => {
      expect(withinComponent().getByText(i18n.checkbox.description)).not.toBe(null);
    });

    describe('when Jira issue creation is enabled', () => {
      beforeEach(async () => {
        await findEnableJiraVulnerabilities().setChecked();
      });

      it('shows a reason why the issue type is needed', () => {
        expect(withinComponent().getByText(i18n.issueTypeSelect.description)).not.toBe(null);
      });
    });
  });

  describe('"Enable Jira issue creation from vulnerabilities" checkbox', () => {
    beforeEach(() => {
      wrapper = createShallowComponent();
    });

    it.each([true, false])(
      'toggles the hidden "vulnerabilities_enabled" input value',
      async (isChecked) => {
        await setEnableJiraVulnerabilitiesChecked(isChecked);
        expect(findHiddenInput('vulnerabilities_enabled').attributes('value')).toBe(`${isChecked}`);
      },
    );

    it.each([true, false])('toggles the Jira issue-type selection section', async (isChecked) => {
      await setEnableJiraVulnerabilitiesChecked(isChecked);
      expect(findIssueTypeSection().exists()).toBe(isChecked);
    });

    describe('when isInheriting = true', () => {
      beforeEach(() => {
        wrapper = createShallowComponent({ isInheriting: true });
      });

      it('disables the checkbox', () => {
        expect(findEnableJiraVulnerabilities().attributes('disabled')).toBeDefined();
      });
    });
  });

  describe('when showFullFeature is off', () => {
    beforeEach(() => {
      wrapper = createShallowComponent({ props: { showFullFeature: false } });
    });

    it('does not show the issue type section', () => {
      expect(findIssueTypeSection().exists()).toBe(false);
    });
  });

  describe('Jira issue type listbox', () => {
    describe('with no Jira issues fetched', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent();
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('receives the correct props', () => {
        expect(findIssueTypeListbox().props()).toMatchObject({
          disabled: true,
          loading: false,
          toggleText: i18n.issueTypeSelect.defaultText,
        });
      });

      it('does not contain any listbox items', () => {
        expect(findIssueTypeListbox().props('items')).toHaveLength(0);
      });

      it('sets the correct initial value to a hidden issuetype field', () => {
        expect(findHiddenInput('vulnerabilities_issuetype').attributes('value')).toBe(
          defaultProps.initialIssueTypeId,
        );
      });

      it('renders the label for the issue type listbox', () => {
        expect(findIssueTypeLabel().text()).toBe('Jira issue type');
      });
    });

    describe('with Jira issues fetching in progress', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent();
        store.state.isLoadingJiraIssueTypes = true;
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('receives the correct props', () => {
        expect(findIssueTypeListbox().props()).toMatchObject({
          disabled: true,
          loading: true,
        });
      });
    });

    describe('with Jira issues fetched', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent({ props: { projectKey: 'TES' } });
        store.state.jiraIssueTypes = TEST_JIRA_ISSUE_TYPES;
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('receives the correct props', () => {
        expect(findIssueTypeListbox().props()).toMatchObject({
          disabled: false,
          loading: false,
        });
      });

      it('sets the correct initial value to a hidden issuetype field', () => {
        expect(findHiddenInput('vulnerabilities_issuetype').attributes('value')).toBe(
          defaultProps.initialIssueTypeId,
        );
      });

      it('contains a listbox item for each issue type', () => {
        expect(findIssueTypeListbox().props('items')).toHaveLength(TEST_JIRA_ISSUE_TYPES.length);
      });

      it("doesn't set the initial item if it doesn't exist in the listbox", () => {
        expect(findIssueTypeListbox().props('selected')).toBe(null);
      });

      it('selects the correct item if it exists in the listbox', async () => {
        const defaultIssueType = { id: defaultProps.initialIssueTypeId, name: 'default' };
        store.state.jiraIssueTypes = [...TEST_JIRA_ISSUE_TYPES, defaultIssueType];
        await nextTick();
        expect(findIssueTypeListbox().props('selected')).toBe(defaultIssueType.id);
        expect(findIssueTypeListbox().props('toggleText')).toBe(defaultIssueType.name);
      });

      it.each(TEST_JIRA_ISSUE_TYPES)(
        'shows the selected issue name and updates the hidden input',
        async (issue) => {
          findIssueTypeListbox().vm.$emit('select', issue.id);
          await nextTick();
          expect(findHiddenInput('vulnerabilities_issuetype').attributes('value')).toBe(issue.id);
          expect(findIssueTypeListbox().props('toggleText')).toBe(issue.name);
        },
      );
    });

    describe('with Jira issue fetch failure', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent();
        store.state.loadingJiraIssueTypesErrorMessage = 'something went wrong';
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('shows an error message', () => {
        expect(findFetchErrorAlert().exists()).toBe(true);
      });
    });
  });

  describe('fetch Jira issue types button', () => {
    beforeEach(async () => {
      wrapper = createShallowComponent({ props: { projectKey: null } });
      await setEnableJiraVulnerabilitiesChecked(true);
    });

    it('has a help text', () => {
      expect(findFetchIssueTypeButton().attributes('title')).toBe(i18n.fetchIssueTypesButtonLabel);
    });

    it('emits "fetch-issues-clicked" when clicked', async () => {
      expect(wrapper.emitted('request-jira-issue-types')).toBe(undefined);
      await findFetchIssueTypeButton().vm.$emit('click');
      expect(wrapper.emitted('request-jira-issue-types')).toHaveLength(1);
    });
  });

  describe('Jira project key prop', () => {
    describe('with no Jira project key', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent({ props: { projectKey: null } });
        await setEnableJiraVulnerabilitiesChecked(true);
      });

      it('shows a warning message telling the user to enter a valid project key', () => {
        expect(withinComponent().getByText(i18n.projectKeyWarnings.missing)).not.toBe(null);
      });
    });

    describe('with fetched issue types and Jira project key changing', () => {
      beforeEach(async () => {
        wrapper = createShallowComponent({ props: { projectKey: 'INITIAL' } });
        await setEnableJiraVulnerabilitiesChecked(true);
        findFetchIssueTypeButton().vm.$emit('click');
        wrapper.setProps({ projectKey: 'CHANGED' });
      });

      it('shows a warning message telling the user to refetch the issues list', () => {
        expect(withinComponent().getByText(i18n.projectKeyWarnings.changed)).not.toBe(null);
      });
    });
  });
});
