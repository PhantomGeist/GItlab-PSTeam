import { GlTable, GlLabel } from '@gitlab/ui';
import MetricsTable from 'ee/metrics/list/metrics_table.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockMetrics } from './mock_data';

describe('MetricsTable', () => {
  let wrapper;

  const mountComponent = ({ metrics = mockMetrics } = {}) => {
    wrapper = mountExtended(MetricsTable, {
      propsData: {
        metrics,
      },
    });
  };

  const getRows = () => wrapper.findComponent(GlTable).findAll(`[data-testid="metric-row"]`);

  it('renders metrics as table', () => {
    mountComponent();

    const rows = getRows();
    expect(rows.length).toBe(mockMetrics.length);
    mockMetrics.forEach((m, i) => {
      const row = getRows().at(i);
      expect(row.find(`[data-testid="metric-name"]`).text()).toBe(m.name);
      expect(row.find(`[data-testid="metric-description"]`).text()).toBe(m.description);
      expect(row.find(`[data-testid="metric-type"]`).text()).toBe(m.type);
    });
  });

  describe('label', () => {
    it.each([
      ['COUNTER', '#6699cc'],
      ['GAUGE', '#cd5b45'],
      ['HISTOGRAM', '#009966'],
      ['EXPONENTIAL HISTOGRAM', '#ed9121'],
      ['unknown', '#808080'],
    ])('sets the proper label when metric type is %s', (type, expectedColor) => {
      mountComponent({
        metrics: [{ name: 'a metric', description: 'a description', type }],
      });
      const label = wrapper.findComponent(GlLabel);
      expect(label.props('backgroundColor')).toBe(expectedColor);
      expect(label.props('title')).toBe(type);
    });
  });

  it('renders the empty state when no metrics are provided', () => {
    mountComponent({ metrics: [] });

    expect(getRows().length).toBe(1);

    const row = getRows().at(0);
    expect(row.text()).toContain('No metrics to display');

    const link = row.findComponent({ name: 'GlLink' });
    expect(link.text()).toBe('Check again');

    link.trigger('click');
    expect(wrapper.emitted('reload')).toHaveLength(1);
  });
});
