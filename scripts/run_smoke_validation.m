function run_smoke_validation()
%RUN_SMOKE_VALIDATION Execute smoke flow and assert expected artifacts exist.

setup_project_paths();
state = run_smoke();

requiredFields = {'figurePng', 'resultMat', 'snapshotMat', 'summaryCsv'};
for i = 1:numel(requiredFields)
    fieldName = requiredFields{i};
    assert(isfield(state, 'last_exports') && isfield(state.last_exports, fieldName), ...
        'run_smoke_validation:MissingExportField', 'Missing state.last_exports.%s', fieldName);

    filePath = state.last_exports.(fieldName);
    assert(~isempty(filePath), ...
        'run_smoke_validation:EmptyExportPath', 'Export path for %s is empty', fieldName);
    assert(exist(filePath, 'file') == 2, ...
        'run_smoke_validation:MissingExportFile', 'Expected export file does not exist: %s', filePath);
end

assert(~isempty(state.event_log), 'run_smoke_validation:NoEvents', 'Expected non-empty event log after smoke run.');
end
