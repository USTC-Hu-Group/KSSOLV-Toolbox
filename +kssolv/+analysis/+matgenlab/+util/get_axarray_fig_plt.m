function [axesArray,figureHandle,plotModule]=get_axarray_fig_plt( ...
        axesArray,nrows,ncols,sharex,sharey,squeeze,varargin)
%GET_AXARRAY_FIG_PLT Return or construct an array of subplot axes.
if nargin<2||isempty(nrows),nrows=1;end
if nargin<3||isempty(ncols),ncols=1;end
if nargin<4,sharex=false;end
if nargin<5,sharey=false;end
if nargin<6,squeeze=true;end
if isempty(axesArray)
    figureHandle=figure("Visible","off");
    axesArray=gobjects(nrows,ncols);
    for index=1:nrows*ncols
        axesArray(index)=subplot(nrows,ncols,index, ...
            "Parent",figureHandle);
    end
else
    axesArray=reshape(axesArray,nrows,ncols);
    figureHandle=ancestor(axesArray(1),"figure");
end
if sharex&&numel(axesArray)>1,linkaxes(axesArray(:),"x");end
if sharey&&numel(axesArray)>1,linkaxes(axesArray(:),"y");end
if squeeze&&(nrows==1||ncols==1),axesArray=axesArray(:).';end
if squeeze&&isscalar(axesArray),axesArray=axesArray(1);end
plotModule="MATLAB graphics";
if ~isempty(varargin)
    % subplot_kw, gridspec_kw and figure kwargs have no direct shared type.
end
end
