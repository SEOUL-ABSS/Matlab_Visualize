function run_all_tests()
%RUN_ALL_TESTS Run MATLAB unit tests and smoke validation for this project.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
addpath(fullfile(repoRoot, 'tests'));
addpath(fullfile(repoRoot, 'scripts'));

testsDir = fullfile(repoRoot, 'tests');
suite = testsuite(testsDir, 'IncludeSubfolders', true);
results = run(suite);
disp(results);

assert(all([results.Passed]), 'Some tests failed.');

% Minimal architecture smoke validation (includes export path assertions).
run_smoke_validation();

% TCP/schema self-tests
selftest_strip_preprocessor_and_schema();
selftest_nested_structs();
selftest_typedef_aliases();
selftest_multidim_pointer_schema();
end
