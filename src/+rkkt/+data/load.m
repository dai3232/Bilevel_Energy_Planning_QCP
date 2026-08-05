function data = load(projectRoot)
%LOAD Read the controlled Excel inputs into the canonical data object.

arguments
    projectRoot (1,1) string
end

data = rkkt.data.load_project_data(projectRoot);
end
