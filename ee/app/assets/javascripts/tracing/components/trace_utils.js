import { s__, sprintf } from '~/locale';

// See https://design.gitlab.com/data-visualization/color/#categorical-data
const SPAN_COLOR_WEIGHT = ['500', '600', '700', '800', '900', '950'];
const SPAN_COLOR_PALETTE = ['blue', 'orange', 'aqua', 'green', 'magenta'];

export function durationNanoToMs(durationNano) {
  return durationNano / 1000000;
}

export function formatDurationMs(durationMs) {
  return sprintf(s__('Tracing|%{ms} ms'), { ms: durationMs.toFixed(2) });
}

export function formatTraceDuration(durationNano) {
  return formatDurationMs(durationNanoToMs(durationNano));
}

function createPalette() {
  const palette = [];
  SPAN_COLOR_WEIGHT.forEach((w) => {
    SPAN_COLOR_PALETTE.forEach((c) => {
      palette.push(`${c}-${w}`);
    });
  });
  return palette;
}

export function assignColorToServices(trace) {
  const services = Array.from(new Set(trace.spans.map((s) => s.service_name)));

  const palette = createPalette();

  const serviceToColor = {};
  services.forEach((s, i) => {
    serviceToColor[s] = palette[i % palette.length];
  });

  return serviceToColor;
}

const timestampToMs = (ts) => new Date(ts).getTime();

export function mapTraceToTreeRoot(trace) {
  const nodes = {};

  const rootSpan = trace.spans.find((s) => s.parent_span_id === '');
  if (!rootSpan) return undefined;

  const spanToNode = (span) => ({
    startTimeMs: timestampToMs(span.timestamp) - timestampToMs(rootSpan.timestamp),
    timestamp: span.timestamp,
    spanId: span.span_id,
    operation: span.operation,
    service: span.service_name,
    durationMs: durationNanoToMs(span.duration_nano),
    children: [],
  });

  // We need to loop twice here because we don't want to assume that parent nodes appear
  // in the list before children nodes
  trace.spans.forEach((s) => {
    nodes[s.span_id] = spanToNode(s);
  });
  trace.spans.forEach((s) => {
    const node = nodes[s.span_id];
    const parentId = s.parent_span_id;
    if (nodes[parentId]) {
      nodes[parentId].children.push(node);
    }
  });
  return nodes[rootSpan.span_id];
}

/**
 * Return the data range for the given filter period matching the type: { period: [ {operator: '=', value: string} ] }
 * Accepted values are numbers followed by the unit 'm', 'h', 'd', e.g. '5m', '3h', '7d'
 *
 *  e.g. filters: { period: [ {operator: '=', value: '5m'} ] }
 *      returns: { min: Date(_now - 5min_), max: Date(_now_) }
 *
 * @param {Object} filters The filters object, containing the 'period' filter
 * @returns {{max: Date, min: Date}|{}} where max, min are Date objects representing the period range
 *  It returns {} if the period filter does not represent any range (invalid range, etc)
 */
export const periodFilterToDate = (filters) => {
  let timePeriod;
  if (filters?.period?.[0]?.operator === '=') {
    timePeriod = filters.period[0].value;
  }
  if (!timePeriod) return {};

  const maxMs = Date.now();
  let minMs;
  const periodValue = parseInt(timePeriod.slice(0, -1), 10);
  if (Number.isNaN(periodValue) || periodValue <= 0) return {};

  const unit = timePeriod[timePeriod.length - 1];
  switch (unit) {
    case 'm':
      minMs = periodValue * 60 * 1000;
      break;
    case 'h':
      minMs = periodValue * 60 * 1000 * 60;
      break;
    case 'd':
      minMs = periodValue * 60 * 1000 * 60 * 24;
      break;
    default:
      return {};
  }
  return { min: new Date(maxMs - minMs), max: new Date(maxMs) };
};
