function axesHandle=pretty_plot(width,height,axesHandle,dpi,colorCycle)
%PRETTY_PLOT Create or style a publication-quality two-dimensional axes.
if nargin<1||isempty(width),width=8;end
if nargin<2||isempty(height),height=floor(width*(sqrt(5)-1)/2);end
if nargin<3,axesHandle=[];end
if nargin<4,dpi=[];end
if nargin<5,colorCycle=[];end
if isempty(axesHandle)
    figureHandle=figure("Visible","off","Color","white", ...
        "Units","inches","Position",[1,1,width,height]);
    if ~isempty(dpi)
        setappdata(figureHandle,"RequestedDPI",dpi);
    end
    axesHandle=axes(figureHandle);
    if isempty(colorCycle)
        colororder(axesHandle,lines(9));
    else
        colororder(axesHandle,colorCycle);
    end
else
    figureHandle=ancestor(axesHandle,"figure");
    figureHandle.Units="inches";
    position=figureHandle.Position;
    position(3:4)=[width,height];figureHandle.Position=position;
end
axesHandle.FontSize=floor(width*2.5);
axesHandle.Title.FontSize=width*4;
axesHandle.XLabel.FontSize=floor(width*3);
axesHandle.YLabel.FontSize=floor(width*3);
end
