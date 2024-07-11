/* eslint-disable import/export */
export * from '~/diffs/store/getters';

// Returns the code quality degradations for a specific line of a given file
export const fileLineCodequality = (state) => (file, line) => {
  const fileDiff = state.codequalityDiff.files?.[file] || [];
  const lineDiff = fileDiff.filter((violation) => violation.line === line);
  return lineDiff;
};

// Returns the SAST degradations for a specific line of a given file
export const fileLineSast = (state) => (file, line) => {
  const lineDiff = [];

  state?.sastDiff?.added?.map((e) => {
    const startLine = parseInt(e.location.startLine, 10);
    if (e.location.file === file && startLine === line) {
      lineDiff.push({
        line: startLine,
        description: e.description,
        severity: e.severity.toLowerCase(),
      });
    }
    return e;
  });
  return lineDiff;
};
