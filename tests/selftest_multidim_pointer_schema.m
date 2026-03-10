function selftest_multidim_pointer_schema()
%SELFTEST_MULTIDIM_POINTER_SCHEMA 다차원 배열/포인터 스키마 점검.

tmp = [tempname '.h'];
fid = fopen(tmp, 'w');
cleanupObj = onCleanup(@() delete_if_exists(tmp)); %#ok<NASGU>

fprintf(fid, '#define N1 2\n');
fprintf(fid, '#define N2 3\n');
fprintf(fid, 'typedef struct M {\n');
fprintf(fid, '  uint16_t a[N1][N2];\n');
fprintf(fid, '  uint8_t* ptrs[4];\n');
fprintf(fid, '} M;\n');
fclose(fid);

schema = EthTcpServer.schemaFromHeader(tmp, 'M', 'PointerSizeBytes', 8, 'PointerMatType', 'uint64');
fn = {schema.fields.name};
fa = schema.fields(strcmp(fn,'a'));
fp = schema.fields(strcmp(fn,'ptrs'));
assert(isequal(fa.shape, [2 3]));
assert(isequal(fp.shape, [4]));
assert(fp.isPointer);
end

function delete_if_exists(p)
if exist(p, 'file') == 2
    delete(p);
end
end
