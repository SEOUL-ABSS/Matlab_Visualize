function selftest_typedef_aliases()
%SELFTEST_TYPEDEF_ALIASES typedef alias/포인터 alias 회귀 점검.

tmp = [tempname '.h'];
fid = fopen(tmp, 'w');
cleanupObj = onCleanup(@() delete_if_exists(tmp)); %#ok<NASGU>

fprintf(fid, 'typedef unsigned long ULONG;\n');
fprintf(fid, 'typedef ULONG* PULONG;\n');
fprintf(fid, 'typedef unsigned short USHORT;\n');
fprintf(fid, 'typedef USHORT* PUSHORT;\n');
fprintf(fid, 'typedef _Null_terminated_ char* PSZ;\n');
fprintf(fid, 'typedef struct T { PULONG a; PUSHORT b; PSZ s; } T;\n');
fclose(fid);

schema = EthTcpServer.schemaFromHeader(tmp, 'T', 'PointerSizeBytes', 8, 'PointerMatType', 'uint64');
assert(numel(schema.fields) == 3);
assert(all([schema.fields.isPointer]));
assert(all(strcmp({schema.fields.type}, 'uint64')));
end

function delete_if_exists(p)
if exist(p, 'file') == 2
    delete(p);
end
end
