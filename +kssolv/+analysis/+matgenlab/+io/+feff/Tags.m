classdef Tags < handle
 %#ok<*AGROW,*ISCL,*FXSETA>
 %TAGS Ordered FEFF control-tag mapping.
 properties(Access=private),data struct=struct();order string=strings(0,1);end
 methods
  function obj=Tags(params),if nargin<1||isempty(params),return,end;if isa(params,class(obj)),params=params.to_struct();end;n=fieldnames(params);for i=1:numel(n),obj.put(n{i},params.(n{i}),false);end,end
  function value=to_struct(obj),value=obj.data;end
  function value=has(obj,key),value=any(strcmpi(obj.order,string(key)));end
  function value=get(obj,key,default),if nargin<3,default=[];end;name=obj.resolve(key);if strlength(name)==0,value=default;else,value=obj.data.(char(name));end,end
  function value=set(obj,key,val),obj.put(key,val,true);value=obj;end
  function value=remove(obj,key),name=obj.resolve(key);if strlength(name)>0,obj.data=rmfield(obj.data,char(name));obj.order(obj.order==name)=[];end;value=obj;end
  function value=keys(obj),value=obj.order;end
  function value=get_str(obj,sort_keys,pretty)
   if nargin<2,sort_keys=false;end;if nargin<3,pretty=false;end;names=obj.order;if sort_keys,names=sort(names);end;lines=strings(0,1);
   for name=reshape(names,1,[]),v=obj.data.(char(name));
    if name=="IONS",if ~iscell(v),v=num2cell(v,2);end;for i=1:numel(v),row=v{i};lines(end+1)=sprintf("ION %g %.4f",row(1),row(2));end
    elseif isstruct(v)&&ismember(name,["ELNES","EXELFS"])
     lines(end+1)=name+" "+stringify(v.ENERGY);beam=split(stringify(v.BEAM_ENERGY));lines(end+1)=join(beam," ");
     if numel(beam)>1&&str2double(beam(2))==0&&isfield(v,"BEAM_DIRECTION"),lines(end+1)=stringify(v.BEAM_DIRECTION);elseif numel(beam)>2,beam(3)="0";lines(end)=join(beam," ");end
     lines(end+1)=stringify(v.ANGLES);lines(end+1)=stringify(v.MESH);lines(end+1)=stringify(v.POSITION);
    else,lines(end+1)=name+" "+stringify(v);
    end
   end
   if pretty
    widths=zeros(1,numel(lines));for i=1:numel(lines),tok=split(lines(i));widths(i)=strlength(tok(1));end;w=max(widths);for i=1:numel(lines),tok=split(lines(i));if numel(tok)>1,lines(i)=pad(tok(1),w,"right")+" "+join(tok(2:end)," ");end,end
   end
   value=char(join(lines,newline));
  end
  function value=char(obj),value=obj.get_str();end
  function value=string(obj),value=string(obj.get_str());end
  function value=write_file(obj,filename),if nargin<2,filename="PARAMETERS";end;fid=fopen(filename,"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s\n",obj.get_str());value=string(filename);end
  function value=diff(obj,other),same=struct();different=struct();all=unique([obj.order,other.order],"stable");for key=all,a=obj.get(key,"__DEFAULT__");b=other.get(key,"__DEFAULT__");if isequal(a,b),same.(char(key))=a;else,different.(char(key))=struct("FEFF_TAGS1",a,"FEFF_TAGS2",b);end,end;value=struct("Different",different,"Same",same);end
  function value=as_dict(obj),value=obj.data;value.x_module="pymatgen.io.feff.inputs";value.x_class="Tags";end
  function value=eq(a,b),value=isa(b,class(a))&&isequal(a.data,b.data);end
  function value=subsref(obj,s)
   if strcmp(s(1).type,"()")&&numel(s(1).subs)==1,value=obj.get(s(1).subs{1});if isempty(value)&&~obj.has(s(1).subs{1}),error("KSSOLV:Matgenlab:Feff:Tag","Unknown FEFF tag.");end;if numel(s)>1,value=builtin("subsref",value,s(2:end));end
   else,value=builtin("subsref",obj,s);end
  end
  function obj=subsasgn(obj,s,value),if strcmp(s(1).type,"()")&&numel(s(1).subs)==1,obj.set(s(1).subs{1},value);else,obj=builtin("subsasgn",obj,s,value);end,end
 end
 methods(Access=private)
  function put(obj,key,val,process),key=upper(strtrim(string(key)));name=matlab.lang.makeValidName(key);if process&&(ischar(val)||isstring(val)),val=kssolv.analysis.matgenlab.io.feff.Tags.proc_val(key,val);end;if ~isfield(obj.data,name),obj.order(end+1)=string(name);end;obj.data.(name)=val;end
  function name=resolve(obj,key),idx=find(strcmpi(obj.order,string(matlab.lang.makeValidName(string(key)))),1);if isempty(idx),name="";else,name=obj.order(idx);end,end
 end
 methods(Static)
  function obj=from_dict(d),metadata={'x_module','x_class','x_version','@module','@class'};drop=intersect(fieldnames(d),metadata);if ~isempty(drop),d=rmfield(d,drop);end;obj=kssolv.analysis.matgenlab.io.feff.Tags(d);end
  function obj=from_file(filename)
   if nargin<1,filename="feff.inp";end;text=kssolv.analysis.matgenlab.io.feff.feff_read_text(filename);raw=splitlines(string(text));lines=strings(0,1);for line=reshape(raw,1,[]),line=strtrim(line);if strlength(line)>0&&~startsWith(line,"*")&&~startsWith(line,"#"),lines(end+1)=line;end,end
   obj=kssolv.analysis.matgenlab.io.feff.Tags();i=1;
   while i<=numel(lines)
    tok=split(lines(i));key=upper(tok(1));if ~ismember(key,kssolv.analysis.matgenlab.io.feff.VALID_FEFF_TAGS()),i=i+1;continue,end
    if ismember(key,["ATOMS","POTENTIALS","END","TITLE"]),i=i+1;continue,end
    val=strtrim(extractAfter(lines(i),strlength(tok(1))));
    if ismember(key,["ELNES","EXELFS"])
     e=struct("ENERGY",char(val));if i+1>numel(lines),break,end;e.BEAM_ENERGY=char(lines(i+1));beam=sscanf(char(lines(i+1)),"%f").';j=i+2;if numel(beam)>1&&beam(2)==0,e.BEAM_DIRECTION=char(lines(j));j=j+1;end;e.ANGLES=char(lines(j));e.MESH=char(lines(j+1));e.POSITION=char(lines(j+2));obj.put(key,e,false);i=j+3;continue
    end
    obj.put(key,kssolv.analysis.matgenlab.io.feff.Tags.proc_val(key,val),false);i=i+1;
   end
  end
  function value=proc_val(key,val)
   key=upper(string(key));val=strtrim(string(val));if key=="CIF",m=regexp(val,'\w+\.cif','match','once');if isempty(m),value=char(val);else,value=string(m);end;return,end
   floats=["S02","EXAFS","RPATH"];nonLists=["ELNES","EXELFS","COREHOLE","EDGE","CIF","OPCONS","RECIPROCAL"];
   if ismember(key,floats),value=str2double(val);if isnan(value),value=capitalize(val);end;return,end
   if ~ismember(key,nonLists)
    tokens=split(val);nums=[];ok=true;for token=reshape(tokens,1,[]),rep=regexp(token,'^(\d+)\*([-+\d.Ee]+)$','tokens','once');if ~isempty(rep),x=str2double(rep{2});nums=[nums,repmat(x,1,str2double(rep{1}))];else,x=str2double(token);if isnan(x),ok=false;break,end;nums(end+1)=x;end,end;if ok,value=nums;return,end
   end
   value=capitalize(val);
  end
 end
end
function value=stringify(v),if isnumeric(v),value=join(string(v)," ");elseif iscell(v),value=join(string([v{:}])," ");else,value=string(v);end,end
function value=capitalize(v),v=lower(string(v));if strlength(v)>0,value=upper(extractBefore(v,2))+extractAfter(v,1);else,value=v;end,end
