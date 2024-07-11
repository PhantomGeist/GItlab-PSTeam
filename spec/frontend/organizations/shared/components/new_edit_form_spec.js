import { GlButton, GlInputGroupText, GlTruncate } from '@gitlab/ui';

import NewEditForm from '~/organizations/shared/components/new_edit_form.vue';
import { FORM_FIELD_NAME, FORM_FIELD_ID, FORM_FIELD_PATH } from '~/organizations/shared/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('NewEditForm', () => {
  let wrapper;

  const defaultProvide = {
    organizationsPath: '/-/organizations',
    rootUrl: 'http://127.0.0.1:3000/',
  };

  const defaultPropsData = {
    loading: false,
  };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = mountExtended(NewEditForm, {
      attachTo: document.body,
      provide: defaultProvide,
      propsData: {
        ...defaultPropsData,
        ...propsData,
      },
    });
  };

  const findNameField = () => wrapper.findByLabelText('Organization name');
  const findIdField = () => wrapper.findByLabelText('Organization ID');
  const findUrlField = () => wrapper.findByLabelText('Organization URL');
  const submitForm = async () => {
    await wrapper.findByRole('button', { name: 'Create organization' }).trigger('click');
  };

  it('renders `Organization name` field', () => {
    createComponent();

    expect(findNameField().exists()).toBe(true);
  });

  it('renders `Organization URL` field', () => {
    createComponent();

    expect(wrapper.findComponent(GlInputGroupText).findComponent(GlTruncate).props('text')).toBe(
      'http://127.0.0.1:3000/-/organizations/',
    );
    expect(findUrlField().exists()).toBe(true);
  });

  describe('when `fieldsToRender` prop is set', () => {
    beforeEach(() => {
      createComponent({ propsData: { fieldsToRender: [FORM_FIELD_ID] } });
    });

    it('only renders provided fields', () => {
      expect(findNameField().exists()).toBe(false);
      expect(findIdField().exists()).toBe(true);
      expect(findUrlField().exists()).toBe(false);
    });
  });

  describe('when `initialFormValues` prop is set', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          fieldsToRender: [FORM_FIELD_NAME, FORM_FIELD_ID, FORM_FIELD_PATH],
          initialFormValues: {
            [FORM_FIELD_NAME]: 'Foo bar',
            [FORM_FIELD_ID]: 1,
            [FORM_FIELD_PATH]: 'foo-bar',
          },
        },
      });
    });

    it('sets initial values for fields', () => {
      expect(findNameField().element.value).toBe('Foo bar');
      expect(findIdField().element.value).toBe('1');
      expect(findUrlField().element.value).toBe('foo-bar');
    });
  });

  it('renders `Organization ID` field as disabled', () => {
    createComponent({ propsData: { fieldsToRender: [FORM_FIELD_ID] } });

    expect(findIdField().attributes('disabled')).toBe('disabled');
  });

  describe('when form is submitted without filling in required fields', () => {
    beforeEach(async () => {
      createComponent();
      await submitForm();
    });

    it('shows error messages', () => {
      expect(wrapper.findByText('Organization name is required.').exists()).toBe(true);
      expect(wrapper.findByText('Organization URL is required.').exists()).toBe(true);
    });
  });

  describe('when form is submitted successfully', () => {
    beforeEach(async () => {
      createComponent();

      await findNameField().setValue('Foo bar');
      await findUrlField().setValue('foo-bar');
      await submitForm();
    });

    it('emits `submit` event with form values', () => {
      expect(wrapper.emitted('submit')).toEqual([[{ name: 'Foo bar', path: 'foo-bar' }]]);
    });
  });

  describe('when `Organization URL` has not been manually set', () => {
    beforeEach(async () => {
      createComponent();

      await findNameField().setValue('Foo bar');
      await submitForm();
    });

    it('sets `Organization URL` when typing in `Organization name`', () => {
      expect(findUrlField().element.value).toBe('foo-bar');
    });
  });

  describe('when `Organization URL` has been manually set', () => {
    beforeEach(async () => {
      createComponent();

      await findUrlField().setValue('foo-bar-baz');
      await findNameField().setValue('Foo bar');
      await submitForm();
    });

    it('does not modify `Organization URL` when typing in `Organization name`', () => {
      expect(findUrlField().element.value).toBe('foo-bar-baz');
    });
  });

  describe('when `Organization URL` field is not rendered', () => {
    beforeEach(async () => {
      createComponent({
        propsData: {
          fieldsToRender: [FORM_FIELD_NAME, FORM_FIELD_ID],
          initialFormValues: {
            [FORM_FIELD_NAME]: 'Foo bar',
            [FORM_FIELD_ID]: 1,
            [FORM_FIELD_PATH]: 'foo-bar',
          },
        },
      });

      await findNameField().setValue('Foo bar baz');
      await submitForm();
    });

    it('does not modify `Organization URL` when typing in `Organization name`', () => {
      expect(wrapper.emitted('submit')).toEqual([
        [{ name: 'Foo bar baz', id: 1, path: 'foo-bar' }],
      ]);
    });
  });

  describe('when `loading` prop is `true`', () => {
    beforeEach(() => {
      createComponent({ propsData: { loading: true } });
    });

    it('shows button with loading icon', () => {
      expect(wrapper.findComponent(GlButton).props('loading')).toBe(true);
    });
  });

  describe('when `showCancelButton` prop is `false`', () => {
    beforeEach(() => {
      createComponent({ propsData: { showCancelButton: false } });
    });

    it('does not show cancel button', () => {
      expect(wrapper.findByRole('link', { name: 'Cancel' }).exists()).toBe(false);
    });
  });

  describe('when `showCancelButton` prop is `true`', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows cancel button', () => {
      expect(wrapper.findByRole('link', { name: 'Cancel' }).attributes('href')).toBe(
        defaultProvide.organizationsPath,
      );
    });
  });

  describe('when `submitButtonText` prop is not set', () => {
    beforeEach(() => {
      createComponent();
    });

    it('defaults to `Create organization`', () => {
      expect(wrapper.findByRole('button', { name: 'Create organization' }).exists()).toBe(true);
    });
  });

  describe('when `submitButtonText` prop is set', () => {
    beforeEach(() => {
      createComponent({ propsData: { submitButtonText: 'Save changes' } });
    });

    it('uses it for submit button', () => {
      expect(wrapper.findByRole('button', { name: 'Save changes' }).exists()).toBe(true);
    });
  });
});
