function [axesHandle,figureHandle]=get_ax_fig(axesHandle,varargin)
%GET_AX_FIG Return supplied axes or create a new hidden figure and axes.
if nargin<1,axesHandle=[];end
if isempty(axesHandle)
    figureHandle=figure("Visible","off");
    applyFigureOptions(figureHandle,varargin{:});
    axesHandle=axes(figureHandle);
else
    figureHandle=ancestor(axesHandle,"figure");
end
end
function applyFigureOptions(figureHandle,varargin)
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    name=char(string(varargin{index}));
    if isprop(figureHandle,name)
        figureHandle.(name)=varargin{index+1};
    end
end
end
