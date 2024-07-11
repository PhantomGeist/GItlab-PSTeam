import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  i18n,
  ERRORS,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';
import CustomStageEventField from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_event_field.vue';
import { customStageEvents as stageEvents } from '../../mock_data';

const formatStartEventOpts = (_events) =>
  _events
    .filter((ev) => ev.canBeStartEvent)
    .map(({ name: text, identifier: value }) => ({ text, value }));

const index = 0;
const eventType = 'stage-start-event';
const fieldLabel = i18n.FORM_FIELD_START_EVENT;
const defaultDropdownText = 'default value';
const eventsList = formatStartEventOpts(stageEvents);
const identifierError = ERRORS.START_EVENT_REQUIRED;

const defaultProps = {
  index,
  eventType,
  eventsList,
  fieldLabel,
  defaultDropdownText,
};

describe('CustomStageEventField', () => {
  function createComponent(props = {}) {
    return shallowMountExtended(CustomStageEventField, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  }

  let wrapper = null;

  const findEventField = () => wrapper.findByTestId(`custom-stage-${eventType}-${index}`);
  const findCollapsibleListbox = () => findEventField().findComponent(GlCollapsibleListbox);

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('Event collapsible listbox', () => {
    it('renders the listbox', () => {
      expect(findEventField().exists()).toBe(true);
      expect(findEventField().attributes('label')).toBe(fieldLabel);
      expect(findCollapsibleListbox().attributes('disabled')).toBeUndefined();
      expect(findCollapsibleListbox().props('toggleText')).toBe(defaultDropdownText);
    });

    it('renders each item in the event list', () => {
      expect(findCollapsibleListbox().props('items')).toBe(eventsList);
    });

    it('emits the `update-identifier` event when an event is selected', () => {
      expect(wrapper.emitted('update-identifier')).toBeUndefined();

      const firstEvent = eventsList[0];
      findCollapsibleListbox().vm.$emit('select', firstEvent.value);

      expect(wrapper.emitted('update-identifier')[0]).toEqual([firstEvent.value]);
    });

    it('sets disables the listbox when the disabled prop is set', () => {
      expect(findCollapsibleListbox().attributes('disabled')).toBeUndefined();

      wrapper = createComponent({ disabled: true });

      expect(findCollapsibleListbox().attributes('disabled')).toBeDefined();
    });
  });

  describe('with an event field error', () => {
    beforeEach(() => {
      wrapper = createComponent({
        hasIdentifierError: true,
        identifierError,
      });
    });

    it('sets the form group error state', () => {
      expect(findEventField().attributes('state')).toBe('true');
      expect(findEventField().attributes('invalid-feedback')).toBe(identifierError);
    });
  });
});
