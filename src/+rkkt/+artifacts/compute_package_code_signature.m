function value = compute_package_code_signature(projectRoot)
%COMPUTE_PACKAGE_CODE_SIGNATURE Hash the ordered rkkt MATLAB source tree.

arguments
    projectRoot (1,1) string
end
projectRoot = canonical_path(projectRoot);
packageRoot = fullfile(projectRoot,"src","+rkkt");
assert(isfolder(packageRoot),"rkkt:runs:PackageRoot", ...
    "The rkkt package directory does not exist: %s",packageRoot);
files = dir(fullfile(packageRoot,"**","*.m"));
files = files(~[files.isdir]);
assert(~isempty(files),"rkkt:runs:PackageFiles", ...
    "The rkkt package contains no MATLAB source files.");

relativePath = strings(numel(files),1);
sha256 = strings(numel(files),1);
for k = 1:numel(files)
    absolute = canonical_path(fullfile(files(k).folder,files(k).name));
    relativePath(k) = replace(extractAfter(absolute, ...
        strlength(projectRoot)+1),"\","/");
    sha256(k) = rkkt.data.compute_sha256_file(absolute);
end
[relativePath,order] = sort(relativePath);
sha256 = sha256(order);
value = sha256_text(strjoin(relativePath+"="+lower(sha256),newline));
end

function value = sha256_text(textValue)
digest = java.security.MessageDigest.getInstance("SHA-256");
bytes = unicode2native(char(textValue),"UTF-8");
byteVector = typecast(uint8(bytes(:)),"int8");
digest.update(byteVector,0,int32(numel(byteVector)));
digestBytes = mod(double(digest.digest()),256);
value = lower(join(compose("%02x",digestBytes),""));
value = reshape(value,1,1);
end

function value = canonical_path(pathValue)
value = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
end
