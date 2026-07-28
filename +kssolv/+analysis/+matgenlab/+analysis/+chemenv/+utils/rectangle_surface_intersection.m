function value=rectangle_surface_intersection(rectangle,lower,upper,varargin)
%RECTANGLE_SURFACE_INTERSECTION Area under clipped surface boundaries.
%#ok<*ALIGN>
defaults=struct(bounds_lower=[],bounds_upper=[],check=true, ...
    numpoints_check=500);
options=parseOptions(defaults,varargin);
x1=min(rectangle(1,:));x2=max(rectangle(1,:));
y1=min(rectangle(2,:));y2=max(rectangle(2,:));
if options.check
    if xor(isempty(options.bounds_lower),isempty(options.bounds_upper))
        error("KSSOLV:Matgenlab:ChemEnv:Bounds", ...
            "Bounds must be supplied for both functions.");
    end
    if ~isempty(options.bounds_lower)
        if any(options.bounds_lower~=options.bounds_upper)
            error("KSSOLV:Matgenlab:ChemEnv:Bounds", ...
                "Bounds must be identical for both functions.");
        end
        interval=options.bounds_lower;
    else,interval=[x1,x2];end
    relation=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        function_comparison(lower,upper,interval(1),interval(2), ...
        options.numpoints_check);
    if ~contains(relation,"<")
        error("KSSOLV:Matgenlab:ChemEnv:Bounds", ...
            "The lower function is not always below the upper function.");
    end
end
if isempty(options.bounds_lower)
    error("KSSOLV:Matgenlab:ChemEnv:Bounds", ...
        "Function bounds are required.");
end
if x2<options.bounds_lower(1)||x1>options.bounds_lower(2)
    value=[0,0];return
end
xmin=max(x1,options.bounds_lower(1));
xmax=min(x2,options.bounds_lower(2));
[surface,errorEstimate]=quadgk(@difference,xmin,xmax);
value=[surface,errorEstimate];
    function output=difference(input)
        low=lower(input);high=upper(input);
        output=max(0,min(high,y2)-max(low,y1));
    end
end
function output=parseOptions(output,args)
names=string(fieldnames(output));
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        name=names(strcmpi(string(args{index}),names));
        output.(char(name))=args{index+1};
    end
else
    for index=1:numel(args),output.(char(names(index)))=args{index};end
end
end
