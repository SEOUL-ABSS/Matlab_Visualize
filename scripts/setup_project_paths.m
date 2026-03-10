function paths = setup_project_paths()
%SETUP_PROJECT_PATHS Add repository src/tests/scripts folders to MATLAB path.
%   paths = setup_project_paths()
%   Returns resolved absolute paths for convenience/logging.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
paths = struct();
paths.repoRoot = repoRoot;
paths.src = fullfile(repoRoot, 'src');
paths.tests = fullfile(repoRoot, 'tests');
paths.scripts = fullfile(repoRoot, 'scripts');

addpath(genpath(paths.src));
addpath(paths.tests);
addpath(paths.scripts);
end
