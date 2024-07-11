import { GlModal } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import setWindowLocation from 'helpers/set_window_location_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createApolloProvider from 'helpers/mock_apollo_helper';

import BoardForm from '~/boards/components/board_form.vue';
import { formType } from '~/boards/constants';
import createBoardMutation from '~/boards/graphql/board_create.mutation.graphql';
import destroyBoardMutation from '~/boards/graphql/board_destroy.mutation.graphql';
import updateBoardMutation from '~/boards/graphql/board_update.mutation.graphql';
import eventHub from '~/boards/eventhub';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { visitUrl } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));
jest.mock('~/boards/eventhub');

Vue.use(Vuex);

const currentBoard = {
  id: 'gid://gitlab/Board/1',
  name: 'test',
  labels: [],
  milestone: {},
  assignee: {},
  iteration: {},
  iterationCadence: {},
  weight: null,
  hideBacklogList: false,
  hideClosedList: false,
};

const defaultProps = {
  canAdminBoard: false,
  currentBoard,
  currentPage: '',
};

describe('BoardForm', () => {
  let wrapper;
  let requestHandlers;

  const findModal = () => wrapper.findComponent(GlModal);
  const findModalActionPrimary = () => findModal().props('actionPrimary');
  const findForm = () => wrapper.findByTestId('board-form');
  const findFormWrapper = () => wrapper.findByTestId('board-form-wrapper');
  const findDeleteConfirmation = () => wrapper.findByTestId('delete-confirmation-message');
  const findInput = () => wrapper.find('#board-new-name');

  const setBoardMock = jest.fn();

  const store = new Vuex.Store({
    actions: {
      setBoard: setBoardMock,
    },
  });

  const defaultHandlers = {
    createBoardMutationHandler: jest.fn().mockResolvedValue({
      data: {
        createBoard: {
          board: { id: '1' },
          errors: [],
        },
      },
    }),
    destroyBoardMutationHandler: jest.fn().mockResolvedValue({
      data: {
        destroyBoard: {
          board: { id: '1' },
        },
      },
    }),
    updateBoardMutationHandler: jest.fn().mockResolvedValue({
      data: {
        updateBoard: { board: { id: 'gid://gitlab/Board/321', webPath: 'test-path' }, errors: [] },
      },
    }),
  };

  const createMockApolloProvider = (handlers = {}) => {
    Vue.use(VueApollo);
    requestHandlers = handlers;

    return createApolloProvider([
      [createBoardMutation, handlers.createBoardMutationHandler],
      [destroyBoardMutation, handlers.destroyBoardMutationHandler],
      [updateBoardMutation, handlers.updateBoardMutationHandler],
    ]);
  };

  const createComponent = ({ props, provide, handlers = defaultHandlers } = {}) => {
    wrapper = shallowMountExtended(BoardForm, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: { ...defaultProps, ...props },
      provide: {
        boardBaseUrl: 'root',
        isGroupBoard: true,
        isProjectBoard: false,
        ...provide,
      },
      store,
      attachTo: document.body,
    });
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  describe('when user can not admin the board', () => {
    beforeEach(() => {
      createComponent({
        props: { currentPage: formType.new },
      });
    });

    it('hides modal footer when user is not a board admin', () => {
      expect(findModal().attributes('hide-footer')).toBeDefined();
    });

    it('displays board scope title', () => {
      expect(findModal().attributes('title')).toBe('Board scope');
    });

    it('does not display a form', () => {
      expect(findForm().exists()).toBe(false);
    });
  });

  describe('when user can admin the board', () => {
    beforeEach(() => {
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.new },
      });
    });

    it('shows modal footer when user is a board admin', () => {
      expect(findModal().attributes('hide-footer')).toBeUndefined();
    });

    it('displays a form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('focuses an input field', () => {
      expect(document.activeElement).toBe(wrapper.vm.$refs.name);
    });
  });

  describe('when creating a new board', () => {
    describe('on non-scoped-board', () => {
      beforeEach(() => {
        createComponent({
          props: { canAdminBoard: true, currentPage: formType.new },
        });
      });

      it('clears the form', () => {
        expect(findInput().element.value).toBe('');
      });

      it('shows a correct title about creating a board', () => {
        expect(findModal().attributes('title')).toBe('Create new board');
      });

      it('passes correct primary action text and variant', () => {
        expect(findModalActionPrimary().text).toBe('Create board');
        expect(findModalActionPrimary().attributes.variant).toBe('confirm');
      });

      it('does not render delete confirmation message', () => {
        expect(findDeleteConfirmation().exists()).toBe(false);
      });

      it('renders form wrapper', () => {
        expect(findFormWrapper().exists()).toBe(true);
      });
    });

    describe('when submitting a create event', () => {
      const fillForm = () => {
        findInput().value = 'Test name';
        findInput().trigger('input');
        findInput().trigger('keyup.enter', { metaKey: true });
      };

      it('does not call API if board name is empty', async () => {
        createComponent({
          props: { canAdminBoard: true, currentPage: formType.new },
        });
        findInput().trigger('keyup.enter', { metaKey: true });

        await waitForPromises();

        expect(requestHandlers.createBoardMutationHandler).not.toHaveBeenCalled();
      });

      it('calls a correct GraphQL mutation and sets board in state', async () => {
        createComponent({
          props: { canAdminBoard: true, currentPage: formType.new },
        });

        fillForm();

        await waitForPromises();

        expect(requestHandlers.createBoardMutationHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            name: 'test',
          }),
        });

        await waitForPromises();
        expect(setBoardMock).toHaveBeenCalledTimes(1);
      });

      it('sets error in state if GraphQL mutation fails', async () => {
        createComponent({
          props: { canAdminBoard: true, currentPage: formType.new },
          handlers: {
            ...defaultHandlers,
            createBoardMutationHandler: jest.fn().mockRejectedValue('Houston, we have a problem'),
          },
        });

        fillForm();

        await waitForPromises();

        expect(requestHandlers.createBoardMutationHandler).toHaveBeenCalled();

        await waitForPromises();
        expect(setBoardMock).not.toHaveBeenCalled();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });

      describe('when Apollo boards FF is on', () => {
        it('calls a correct GraphQL mutation and emits addBoard event when creating a board', async () => {
          createComponent({
            props: { canAdminBoard: true, currentPage: formType.new },
            provide: { isApolloBoard: true },
          });

          fillForm();

          await waitForPromises();

          expect(requestHandlers.createBoardMutationHandler).toHaveBeenCalledWith({
            input: expect.objectContaining({
              name: 'test',
            }),
          });

          await waitForPromises();
          expect(wrapper.emitted('addBoard')).toHaveLength(1);
        });
      });
    });
  });

  describe('when editing a board', () => {
    describe('on non-scoped-board', () => {
      beforeEach(() => {
        createComponent({
          props: { canAdminBoard: true, currentPage: formType.edit },
        });
      });

      it('clears the form', () => {
        expect(findInput().element.value).toEqual(currentBoard.name);
      });

      it('shows a correct title about creating a board', () => {
        expect(findModal().attributes('title')).toBe('Edit board');
      });

      it('passes correct primary action text and variant', () => {
        expect(findModalActionPrimary().text).toBe('Save changes');
        expect(findModalActionPrimary().attributes.variant).toBe('confirm');
      });

      it('does not render delete confirmation message', () => {
        expect(findDeleteConfirmation().exists()).toBe(false);
      });

      it('renders form wrapper', () => {
        expect(findFormWrapper().exists()).toBe(true);
      });
    });

    it('calls GraphQL mutation with correct parameters when issues are not grouped', async () => {
      setWindowLocation('https://test/boards/1');
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.edit },
      });

      findInput().trigger('keyup.enter', { metaKey: true });

      await waitForPromises();

      expect(requestHandlers.updateBoardMutationHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          id: currentBoard.id,
        }),
      });

      await waitForPromises();
      expect(setBoardMock).toHaveBeenCalledTimes(1);
      expect(global.window.location.href).not.toContain('?group_by=epic');
    });

    it('calls GraphQL mutation with correct parameters when issues are grouped by epic', async () => {
      setWindowLocation('https://test/boards/1?group_by=epic');
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.edit },
      });

      findInput().trigger('keyup.enter', { metaKey: true });

      await waitForPromises();

      expect(requestHandlers.updateBoardMutationHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          id: currentBoard.id,
        }),
      });

      await waitForPromises();
      expect(setBoardMock).toHaveBeenCalledTimes(1);
      expect(global.window.location.href).toContain('?group_by=epic');
    });

    it('sets error in state if GraphQL mutation fails', async () => {
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.edit },
        handlers: {
          ...defaultHandlers,
          updateBoardMutationHandler: jest.fn().mockRejectedValue('Houston, we have a problem'),
        },
      });

      findInput().trigger('keyup.enter', { metaKey: true });

      await waitForPromises();

      expect(requestHandlers.updateBoardMutationHandler).toHaveBeenCalled();

      await waitForPromises();
      expect(setBoardMock).not.toHaveBeenCalled();
      expect(cacheUpdates.setError).toHaveBeenCalled();
    });

    describe('when Apollo boards FF is on', () => {
      it('calls a correct GraphQL mutation and emits updateBoard event when updating a board', async () => {
        setWindowLocation('https://test/boards/1');

        createComponent({
          props: { canAdminBoard: true, currentPage: formType.edit },
          provide: { isApolloBoard: true },
        });
        findInput().trigger('keyup.enter', { metaKey: true });

        await waitForPromises();

        expect(requestHandlers.updateBoardMutationHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            id: currentBoard.id,
          }),
        });

        await waitForPromises();
        expect(eventHub.$emit).toHaveBeenCalledTimes(1);
        expect(eventHub.$emit).toHaveBeenCalledWith('updateBoard', {
          id: 'gid://gitlab/Board/321',
          webPath: 'test-path',
        });
      });
    });
  });

  describe('when deleting a board', () => {
    it('passes correct primary action text and variant', () => {
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.delete },
      });
      expect(findModalActionPrimary().text).toBe('Delete');
      expect(findModalActionPrimary().attributes.variant).toBe('danger');
    });

    it('renders delete confirmation message', () => {
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.delete },
      });
      expect(findDeleteConfirmation().exists()).toBe(true);
    });

    it('calls a correct GraphQL mutation and redirects to correct page after deleting board', async () => {
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.delete },
      });
      findModal().vm.$emit('primary');

      await waitForPromises();

      expect(requestHandlers.destroyBoardMutationHandler).toHaveBeenCalledWith({
        id: currentBoard.id,
      });

      await waitForPromises();
      expect(visitUrl).toHaveBeenCalledWith('root');
    });

    it('dispatches `setError` action when GraphQL mutation fails', async () => {
      createComponent({
        props: { canAdminBoard: true, currentPage: formType.delete },
        handlers: {
          ...defaultHandlers,
          destroyBoardMutationHandler: jest.fn().mockRejectedValue('Houston, we have a problem'),
        },
      });
      jest.spyOn(store, 'dispatch').mockImplementation(() => {});

      findModal().vm.$emit('primary');

      await waitForPromises();

      expect(requestHandlers.destroyBoardMutationHandler).toHaveBeenCalled();

      await waitForPromises();
      expect(visitUrl).not.toHaveBeenCalled();
      expect(cacheUpdates.setError).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Failed to delete board. Please try again.',
        }),
      );
    });
  });
});
