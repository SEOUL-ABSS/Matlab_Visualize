function run_all_tests()
%RUN_ALL_TESTS Run MATLAB unit tests for this project (R2023a compatible).

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
addpath(fullfile(repoRoot, 'tests'));

testsDir = fullfile(repoRoot, 'tests');
suite = testsuite(testsDir, 'IncludeSubfolders', true);
results = run(suite);
disp(results);

assert(all([results.Passed]), 'Some tests failed.');
end
