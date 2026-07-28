function [axesHandle,figureHandle]=get_ax3d_fig(axesHandle,varargin)
%GET_AX3D_FIG Return supplied axes or create three-dimensional axes.
if nargin<1,axesHandle=[];end
if isempty(axesHandle)
    figureHandle=figure("Visible","off");
    for index=1:2:numel(varargin)
        if index==numel(varargin),break,end
        name=char(string(varargin{index}));
        if isprop(figureHandle,name)
            figureHandle.(name)=varargin{index+1};
        end
    end
    axesHandle=axes(figureHandle);view(axesHandle,3);
else
    figureHandle=ancestor(axesHandle,"figure");
end
end
