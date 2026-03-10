function run_all_tests()
%RUN_ALL_TESTS Run MATLAB unit tests and smoke validation for this project.

paths = setup_project_paths();
repoRoot = paths.repoRoot;

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
