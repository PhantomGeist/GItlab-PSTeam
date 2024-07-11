import { createWrapper } from '@vue/test-utils';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initWorkspacesApp } from 'ee/remote_development/init_workspaces_app';
import WorkspaceList from 'ee/remote_development/pages/list.vue';

jest.mock('~/lib/logger');

describe('ee/remote_development/init_workspaces_app', () => {
  let wrapper;

  beforeEach(() => {
    setHTMLFixture(`<div id='js-workspaces'></div>`);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('initWorkspacesApp - integration', () => {
    beforeEach(() => {
      wrapper = createWrapper(initWorkspacesApp());
    });

    it('renders list state', () => {
      expect(wrapper.findComponent(WorkspaceList).exists()).toBe(true);
    });
  });

  describe('initWorkspacesApp - when mounting element not found', () => {
    it('returns null', () => {
      document.body.innerHTML = '<div>Look ma! Code!</div>';

      expect(initWorkspacesApp()).toBeNull();
    });
  });
});
