classdef Cp2kInput < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*AGROW>
 methods
  function obj=Cp2kInput(name,subsections,varargin),if nargin<1,name="CP2K_INPUT";end;if nargin<2,subsections=struct();end;obj@kssolv.analysis.matgenlab.io.cp2k.Section(name,"subsections",subsections,varargin{:});end
  function value=get_str(obj),lines=strings(0,1);n=fieldnames(obj.subsections);for i=1:numel(n),s=obj.subsections.(n{i});if isa(s,"kssolv.analysis.matgenlab.io.cp2k.SectionList"),for j=1:numel(s.sections),lines(end+1)=string(s.sections{j}.get_str());end;else,lines(end+1)=string(s.get_str());end,end;value=char(join(lines,""));end
  function write_file(obj,input_filename,output_dir,make_dir),if nargin<2,input_filename="cp2k.inp";end;if nargin<3,output_dir=".";end;if nargin<4,make_dir=true;end;if make_dir&&~isfolder(output_dir),mkdir(output_dir);end;fid=fopen(fullfile(output_dir,input_filename),"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s",obj.get_str());end
 end
 methods(Static)
  function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.cp2k.Section.from_dict(d);if ~isa(obj,"kssolv.analysis.matgenlab.io.cp2k.Cp2kInput"),root=kssolv.analysis.matgenlab.io.cp2k.Cp2kInput();root.subsections=obj.subsections;root.keywords=obj.keywords;obj=root;end,end
  function obj=from_file(filename),text=kssolv.analysis.matgenlab.io.cp2k.preprocessor(fileread(filename),fileparts(filename));obj=kssolv.analysis.matgenlab.io.cp2k.Cp2kInput.from_str(text);end
  function obj=from_str(text),obj=kssolv.analysis.matgenlab.io.cp2k.Cp2kInput.from_lines(splitlines(string(text)));end
  function obj=from_lines(lines)
   obj=kssolv.analysis.matgenlab.io.cp2k.Cp2kInput();stack={obj};comments=strings(0,1);
   for raw=reshape(string(lines),1,[])
    line=strtrim(raw);if strlength(line)==0,continue,end
    if startsWith(line,"!")||startsWith(line,"#"),comments(end+1)=strtrim(extractAfter(line,1));continue,end
    bang=strfind(line,"!");desc=[];if ~isempty(bang),desc=strtrim(extractAfter(line,bang(1)));line=strtrim(extractBefore(line,bang(1)));end
    if startsWith(upper(line),"&END"),stack(end)=[];continue,end
    if startsWith(line,"&")
     parts=split(strtrim(extractAfter(line,1)));sec=kssolv.analysis.matgenlab.io.cp2k.Section(parts(1),"section_parameters",parts(2:end),"description",chooseDesc(desc,comments));comments=strings(0,1);parent=stack{end};old=parent.get_section(sec.name);
     if isempty(old),parent.insert(sec);elseif isa(old,"kssolv.analysis.matgenlab.io.cp2k.SectionList"),old.append(sec);else,parent.subsections.(matlab.lang.makeValidName(sec.name))=kssolv.analysis.matgenlab.io.cp2k.SectionList({old,sec});end;stack{end+1}=sec;continue
    end
    kw=kssolv.analysis.matgenlab.io.cp2k.Keyword.from_str(line,chooseDesc(desc,comments));comments=strings(0,1);parent=stack{end};old=parent.get_keyword(kw.name);if isempty(old),parent.setitem(kw.name,kw);elseif isa(old,"kssolv.analysis.matgenlab.io.cp2k.KeywordList"),old.append(kw);else,parent.setitem(kw.name,kssolv.analysis.matgenlab.io.cp2k.KeywordList({old,kw}));end
   end
  end
 end
end
function d=chooseDesc(a,b),if ~isempty(a),d=a;elseif ~isempty(b),d=char(join(b," "));else,d=[];end,end
