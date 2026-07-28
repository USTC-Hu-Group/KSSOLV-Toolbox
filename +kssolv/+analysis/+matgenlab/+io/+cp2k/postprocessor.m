function value=postprocessor(data)
%#ok<*ALIGN>
s=replace(strtrim(string(data))," ","_");lo=lower(s);
if ismember(lo,["false","no","f"]),value=false;
elseif lo=="none",value=[];
elseif ismember(lo,["true","yes","t"]),value=true;
elseif ~isempty(regexp(s,'^-?\d+$','once')),value=str2double(s);
elseif ~isempty(regexp(s,'^[+\-]?(?=.)(?:0|[1-9]\d*)?(?:\.\d*)?(?:\d[eEdD][+\-]?\d+)?$','once')),value=str2double(replace(replace(s,"D","E"),"d","e"));
elseif ~isempty(regexp(s,'^\*+$','once')),value=NaN;
else,value=s;end
end
