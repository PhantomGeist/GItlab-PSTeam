export const extractNamespaceData = (data = {}) => {
  if (!data.project && !data.group) {
    return null;
  }

  return data.project ? data.project : data.group;
};
