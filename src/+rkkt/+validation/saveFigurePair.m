function saveFigurePair(fig,figPath,pngPath)
%SAVEFIGUREPAIR Save one validation figure as FIG and PNG.

arguments
    fig (1,1) matlab.ui.Figure
    figPath (1,1) string
    pngPath (1,1) string
end

savefig(fig,figPath);
exportgraphics(fig,pngPath,"Resolution",200);
end
