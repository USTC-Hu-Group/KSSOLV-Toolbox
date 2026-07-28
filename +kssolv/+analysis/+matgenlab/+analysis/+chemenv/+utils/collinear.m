function value=collinear(first,second,varargin)
%COLLINEAR Tolerance-scaled triangle-area collinearity test.
third=[];tolerance=.25;
if ~isempty(varargin),third=varargin{1};end
if numel(varargin)>1,tolerance=varargin{2};end
if isempty(third)
    area=.5*norm(cross(first,second));
    distances=sort([norm(second-first),norm(first),norm(second)]);
else
    area=.5*norm(cross(first-third,second-third));
    distances=sort([norm(second-first),norm(third-first),norm(third-second)]);
end
value=area<tolerance*.5*distances(1)*distances(2);
end
