function value=spline_functions(lowerPoints,upperPoints,varargin)
%SPLINE_FUNCTIONS Interpolating lower and upper spline handles.
degree=3;
if ~isempty(varargin)
    if ischar(varargin{1})||isstring(varargin{1}),degree=varargin{2};
    else,degree=varargin{1};end
end
if degree==3
    lowerPP=spline(lowerPoints(:,1),lowerPoints(:,2));
    upperPP=spline(upperPoints(:,1),upperPoints(:,2));
    value=struct(lower=@(input)ppval(lowerPP,input), ...
        upper=@(input)ppval(upperPP,input));
else
    lowerCoefficients=polyfit(lowerPoints(:,1),lowerPoints(:,2),degree);
    upperCoefficients=polyfit(upperPoints(:,1),upperPoints(:,2),degree);
    value=struct(lower=@(input)polyval(lowerCoefficients,input), ...
        upper=@(input)polyval(upperCoefficients,input));
end
end
