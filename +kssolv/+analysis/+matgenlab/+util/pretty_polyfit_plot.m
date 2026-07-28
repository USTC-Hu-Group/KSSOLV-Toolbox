function axesHandle=pretty_polyfit_plot(x,y,degree,varargin)
%PRETTY_POLYFIT_PLOT Plot observations with a least-squares polynomial fit.
if nargin<3||isempty(degree),degree=1;end
options=struct("xlabel","","ylabel","","width",8,"height",[], ...
    "ax",[],"dpi",[],"color_cycle",[]);
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    name=lower(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};
    else
        error("matgenlab:plotting:UnknownOption", ...
            "Unknown plotting option '%s'.",name);
    end
end
axesHandle=kssolv.analysis.matgenlab.util.pretty_plot( ...
    options.width,options.height,options.ax,options.dpi, ...
    options.color_cycle);
coefficients=polyfit(double(x),double(y),degree);
fitX=linspace(min(x),max(x),200);
hold(axesHandle,"on");
plot(axesHandle,fitX,polyval(coefficients,fitX),"k--");
plot(axesHandle,x,y,"o");hold(axesHandle,"off");
xlabel(axesHandle,options.xlabel);ylabel(axesHandle,options.ylabel);
end
