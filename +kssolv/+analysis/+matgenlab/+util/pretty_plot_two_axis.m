function axesHandle=pretty_plot_two_axis(x,y1,y2,varargin)
%PRETTY_PLOT_TWO_AXIS Plot two data collections against independent y axes.
options=struct("xlabel","","y1label","","y2label","", ...
    "width",8,"height",[],"dpi",300);
options=parseOptions(options,varargin{:});
if isempty(options.height)
    options.height=floor(options.width*(sqrt(5)-1)/2);
end
figureHandle=figure("Visible","off","Units","inches", ...
    "Position",[1,1,12,options.height]);
axesHandle=axes(figureHandle);styles={'-','--','-.',':'};
yyaxis(axesHandle,"left");hold(axesHandle,"on");
plotCollection(axesHandle,x,y1,[0.65,0.1,0.18],"s",styles);
xlabel(axesHandle,options.xlabel);ylabel(axesHandle,options.y1label);
yyaxis(axesHandle,"right");hold(axesHandle,"on");
plotCollection(axesHandle,x,y2,[0.15,0.35,0.65],"o",styles);
ylabel(axesHandle,options.y2label);
axesHandle.FontSize=30;
end
function plotCollection(axesHandle,x,data,color,marker,styles)
if isstruct(data)
    names=fieldnames(data);
    for index=1:numel(names)
        plot(axesHandle,x,data.(names{index}), ...
            "Color",color,"Marker",marker, ...
            "LineStyle",styles{mod(index-1,numel(styles))+1}, ...
            "DisplayName",names{index});
    end
    legend(axesHandle,"show");
elseif isa(data,"containers.Map")
    names=keys(data);
    for index=1:numel(names)
        plot(axesHandle,x,data(names{index}), ...
            "Color",color,"Marker",marker, ...
            "LineStyle",styles{mod(index-1,numel(styles))+1}, ...
            "DisplayName",names{index});
    end
    legend(axesHandle,"show");
else
    plot(axesHandle,x,data,"Color",color, ...
        "Marker",marker,"LineStyle","-");
end
end
function options=parseOptions(options,varargin)
names=fieldnames(options);
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
