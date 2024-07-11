/**
 * Maps a GraphQL response containing two sets of projects (for current / prev months)
 * into a single array of projects, with the current/prev counts mapped onto each project.
 * Fills in a `0` count if a project exists in one set but not the other.
 */
export const mapProjectsUsageResponse = (data) => {
  const projectHasProductAnalyticsEnabled = (project) =>
    project.productAnalyticsEventsStored !== null;

  const currentUsage = data.current.projects.nodes.filter(projectHasProductAnalyticsEnabled);
  const previousUsage = data.previous.projects.nodes.filter(projectHasProductAnalyticsEnabled);

  const combinedUsage = new Map(
    currentUsage.map((project) => {
      const { __typename, productAnalyticsEventsStored, ...projectWithoutCount } = project;
      return [
        project.id,
        {
          ...projectWithoutCount,
          currentEvents: productAnalyticsEventsStored,
          previousEvents: 0,
        },
      ];
    }),
  );

  previousUsage.forEach((project) => {
    const { __typename, productAnalyticsEventsStored, ...projectWithoutCount } = project;
    combinedUsage.set(project.id, {
      ...projectWithoutCount,
      currentEvents: combinedUsage.get(project.id)?.currentEvents || 0,
      previousEvents: productAnalyticsEventsStored,
    });
  });

  return Array.from(combinedUsage, ([, project]) => project);
};
