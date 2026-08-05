function fig = newFigure(name,interactive)
%NEWFIGURE Create a validation figure with explicit visibility.

arguments
    name (1,1) string
    interactive (1,1) logical
end

visibility = "off";
if interactive
    visibility = "on";
end
fig = figure("Name",name,"NumberTitle","off", ...
    "Color","w","Visible",visibility,"Position",[100,100,980,720]);
end
