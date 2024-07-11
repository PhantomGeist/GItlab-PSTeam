import _ from 'lodash';
import {
  mapTraceToTreeRoot,
  durationNanoToMs,
  formatDurationMs,
  formatTraceDuration,
  assignColorToServices,
  periodFilterToDate,
} from 'ee/tracing/components/trace_utils';

describe('trace_utils', () => {
  describe('durationNanoToMs', () => {
    it('converts a duration value from nano to ms', () => {
      expect(durationNanoToMs(1234567)).toBe(1.234567);
    });
  });

  describe('formatDurationMs', () => {
    it('formats a duration ms value', () => {
      expect(formatDurationMs(12.2934)).toBe('12.29 ms');
    });
  });

  describe('formatTraceDuration', () => {
    it('formats the trace duration nano value', () => {
      expect(formatTraceDuration(1234567)).toBe('1.23 ms');
    });
  });

  describe('assignColorToService', () => {
    it('should assign the right palette', () => {
      const trace = { duration_nane: 100000, spans: [] };
      trace.spans = _.times(31).map((i) => ({
        timestamp: '2023-08-07T15:03:32.199806Z',
        span_id: `SPAN-${i}`,
        trace_id: 'TRACE-1',
        service_name: `service-${i}`,
        operation: 'op',
        duration_nano: 100000,
        parent_span_id: '',
      }));

      expect(assignColorToServices(trace)).toEqual({
        'service-0': 'blue-500',
        'service-1': 'orange-500',
        'service-2': 'aqua-500',
        'service-3': 'green-500',
        'service-4': 'magenta-500',
        'service-5': 'blue-600',
        'service-6': 'orange-600',
        'service-7': 'aqua-600',
        'service-8': 'green-600',
        'service-9': 'magenta-600',
        'service-10': 'blue-700',
        'service-11': 'orange-700',
        'service-12': 'aqua-700',
        'service-13': 'green-700',
        'service-14': 'magenta-700',
        'service-15': 'blue-800',
        'service-16': 'orange-800',
        'service-17': 'aqua-800',
        'service-18': 'green-800',
        'service-19': 'magenta-800',
        'service-20': 'blue-900',
        'service-21': 'orange-900',
        'service-22': 'aqua-900',
        'service-23': 'green-900',
        'service-24': 'magenta-900',
        'service-25': 'blue-950',
        'service-26': 'orange-950',
        'service-27': 'aqua-950',
        'service-28': 'green-950',
        'service-29': 'magenta-950',
        // restart pallete
        'service-30': 'blue-500',
      });
    });
  });

  describe('mapTraceToTreeRoot', () => {
    it('should map a trace data to tree data and return the root node', () => {
      const trace = {
        spans: [
          {
            timestamp: '2023-08-07T15:03:53.199871Z',
            span_id: 'SPAN-3',
            trace_id: 'TRACE-1',
            service_name: 'tracegen',
            operation: 'okey-dokey',
            duration_nano: 50027500,
            parent_span_id: 'SPAN-2',
          },
          {
            timestamp: '2023-08-07T15:03:32.199871Z',
            span_id: 'SPAN-2',
            trace_id: 'TRACE-1',
            service_name: 'tracegen',
            operation: 'okey-dokey',
            duration_nano: 100055000,
            parent_span_id: 'SPAN-1',
          },
          {
            timestamp: '2023-08-07T15:03:53.199871Z',
            span_id: 'SPAN-4',
            trace_id: 'TRACE-1',
            service_name: 'fake-service-2',
            operation: 'okey-dokey',
            duration_nano: 50027500,
            parent_span_id: 'SPAN-2',
          },
          {
            timestamp: '2023-08-07T15:03:32.199806Z',
            span_id: 'SPAN-1',
            trace_id: 'TRACE-1',
            service_name: 'tracegen',
            operation: 'lets-go',
            duration_nano: 100120000,
            parent_span_id: '',
          },
        ],
        duration_nano: 3000000,
      };

      expect(mapTraceToTreeRoot(trace)).toEqual({
        durationMs: 100.12,
        operation: 'lets-go',
        service: 'tracegen',
        spanId: 'SPAN-1',
        startTimeMs: 0,
        timestamp: '2023-08-07T15:03:32.199806Z',
        children: [
          {
            durationMs: 100.055,
            operation: 'okey-dokey',
            service: 'tracegen',
            spanId: 'SPAN-2',
            startTimeMs: 0,
            timestamp: '2023-08-07T15:03:32.199871Z',
            children: [
              {
                children: [],
                durationMs: 50.0275,
                operation: 'okey-dokey',
                service: 'tracegen',
                spanId: 'SPAN-3',
                startTimeMs: 21000,
                timestamp: '2023-08-07T15:03:53.199871Z',
              },
              {
                children: [],
                durationMs: 50.0275,
                operation: 'okey-dokey',
                service: 'fake-service-2',
                spanId: 'SPAN-4',
                startTimeMs: 21000,
                timestamp: '2023-08-07T15:03:53.199871Z',
              },
            ],
          },
        ],
      });
    });
  });

  describe('periodFilterToDate', () => {
    const realDateNow = Date.now;

    const MOCK_NOW_DATE = new Date('2023-10-09 15:30:00');

    beforeEach(() => {
      global.Date.now = jest.fn().mockReturnValue(MOCK_NOW_DATE);
    });

    afterEach(() => {
      global.Date.now = realDateNow;
    });

    it('should return an empty object if period filter is not present', () => {
      const filters = {};
      expect(periodFilterToDate(filters)).toEqual({});
    });

    it('should return an empty object if the operator is not "="', () => {
      const filters = {
        period: [{ operator: '>', value: '1h' }],
      };
      expect(periodFilterToDate(filters)).toEqual({});
    });

    it('should return an empty object if period value is not a positive integer', () => {
      const filters = {
        period: [{ operator: '=', value: 'invalid' }],
      };
      expect(periodFilterToDate(filters)).toEqual({});
    });

    it('should return an empty object if unit is not "m", "h", or "d"', () => {
      const filters = {
        period: [{ operator: '=', value: '2w' }],
      };
      expect(periodFilterToDate(filters)).toEqual({});
    });

    it.each`
      periodLabel      | period   | expectedMinDate
      ${'minutes (m)'} | ${'30m'} | ${new Date('2023-10-09 15:00:00')}
      ${'hours (h)'}   | ${'2h'}  | ${new Date('2023-10-09 13:30:00')}
      ${'days (d)'}    | ${'7d'}  | ${new Date('2023-10-02 15:30:00')}
    `('should return the correct date range for $periodLabel', ({ period, expectedMinDate }) => {
      const filters = {
        period: [{ operator: '=', value: period }],
      };
      const result = periodFilterToDate(filters);
      expect(result.min).toEqual(expectedMinDate);
      expect(result.max).toEqual(MOCK_NOW_DATE);
    });
  });
});
