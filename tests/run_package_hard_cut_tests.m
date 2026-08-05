function results = run_package_hard_cut_tests()
%RUN_PACKAGE_HARD_CUT_TESTS Run the fixed package-only architecture tests.

root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
results = runtests(fullfile(root,"tests","unit", ...
    "test_package_hard_cut.m"));
assert(all([results.Passed]),"rkkt:hardCut:TestFailure", ...
    "One or more package hard-cut tests failed.");
end
