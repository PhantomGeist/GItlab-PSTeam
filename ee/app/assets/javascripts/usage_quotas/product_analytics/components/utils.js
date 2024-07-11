/**
 * Validator for the projectsUsageData property
 */
export const projectsUsageDataValidator = (items) => {
  return (
    Array.isArray(items) &&
    items.every(
      ({ name, currentEvents, previousEvents }) =>
        typeof name === 'string' &&
        typeof currentEvents === 'number' &&
        typeof previousEvents === 'number',
    )
  );
};
