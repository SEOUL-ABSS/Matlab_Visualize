function selftest_strip_preprocessor_and_schema()
%SELFTEST_STRIP_PREPROCESSOR_AND_SCHEMA #pragma once/define 전처리 회귀 점검.

tmp = [tempname '.h'];
fid = fopen(tmp, 'w');
cleanupObj = onCleanup(@() delete_if_exists(tmp)); %#ok<NASGU>

fprintf(fid, '#pragma once\n');
fprintf(fid, '#define N 4\n');
fprintf(fid, '#ifdef X\n');
fprintf(fid, 'typedef struct A { uint32_t a[N]; } A;\n');
fprintf(fid, '#endif\n');
fclose(fid);

schema = EthTcpServer.schemaFromHeader(tmp, 'A');
assert(strcmp(schema.name, 'A'));
assert(numel(schema.fields) == 1);
assert(strcmp(schema.fields(1).name, 'a'));
assert(isequal(schema.fields(1).shape, [4]));
end

function delete_if_exists(p)
if exist(p, 'file') == 2
    delete(p);
end
end
