function value = gitCommit()
%GITCOMMIT Return the repository HEAD recorded by validation metadata.

root = rkkt.projectRoot();
command = "git -C """+root+""" rev-parse HEAD";
[status,output] = system(command);
value = lower(strip(string(output)));
assert(status==0 && ~isempty(regexp(char(value), ...
    "^[0-9a-f]{40}$","once")),"rkkt:validation:GitCommit", ...
    "Could not read the repository HEAD.");
end
