function summary = run_local_validation(mode)
%RUN_LOCAL_VALIDATION Local validation helper for MATLAB 2023a users.
%   summary = RUN_LOCAL_VALIDATION()
%   summary = RUN_LOCAL_VALIDATION(mode)
%   mode: 'quick' (default) or 'full'
%
% quick:
%   - run_smoke
% full:
%   - run_smoke
%   - run_all_tests
%
% This wrapper keeps local bring-up deterministic and provides a compact
% summary struct that can be shared when reporting issues.

if nargin < 1 || isempty(mode)
    mode = 'quick';
end
mode = char(string(mode));
validatestring(mode, {'quick', 'full'}, mfilename, 'mode');

setup_project_paths();

summary = struct();
summary.mode = mode;
summary.startedAt = datetime('now');
summary.smokeOk = false;
summary.testsOk = false;
summary.lastExports = struct();
summary.message = '';

try
    state = run_smoke();
    summary.smokeOk = true;
    if isstruct(state) && isfield(state, 'last_exports')
        summary.lastExports = state.last_exports;
    end
catch err
    summary.finishedAt = datetime('now');
    summary.message = sprintf('run_smoke failed: %s', err.message);
    rethrow(err);
end

if strcmp(mode, 'full')
    try
        run_all_tests();
        summary.testsOk = true;
    catch err
        summary.finishedAt = datetime('now');
        summary.message = sprintf('run_all_tests failed: %s', err.message);
        rethrow(err);
    end
end

summary.finishedAt = datetime('now');
summary.message = 'Validation completed successfully.';

fprintf('[run_local_validation] mode=%s smokeOk=%d testsOk=%d\n', ...
    summary.mode, summary.smokeOk, summary.testsOk);
end
