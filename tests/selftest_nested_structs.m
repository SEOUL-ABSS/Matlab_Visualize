function selftest_nested_structs()
%SELFTEST_NESTED_STRUCTS 중첩 구조체 파싱/스키마 생성 점검.

tmp = [tempname '.h'];
fid = fopen(tmp, 'w');
cleanupObj = onCleanup(@() delete_if_exists(tmp)); %#ok<NASGU>

fprintf(fid, 'typedef struct Inner {\n');
fprintf(fid, '  uint16_t x;\n');
fprintf(fid, '  uint8_t  y[3];\n');
fprintf(fid, '} Inner;\n');
fprintf(fid, 'typedef struct Outer {\n');
fprintf(fid, '  Inner inner;\n');
fprintf(fid, '  uint32_t z;\n');
fprintf(fid, '} Outer;\n');
fclose(fid);

schema = EthTcpServer.schemaFromHeader(tmp, 'Outer', 'FlattenStructs', true);
names = {schema.fields.name};
assert(any(strcmp(names, 'inner_x')));
assert(any(strcmp(names, 'inner_y')));
assert(any(strcmp(names, 'z')));
end

function delete_if_exists(p)
if exist(p, 'file') == 2
    delete(p);
end
end
