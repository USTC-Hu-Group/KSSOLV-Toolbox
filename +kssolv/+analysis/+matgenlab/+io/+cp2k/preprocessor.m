function data=preprocessor(data,directory)
if nargin<2,directory=".";end;data=string(data);
tokens=regexp(data,'(?im)^\s*@include\s+[''"]?([^''"\r\n]+)[''"]?\s*$','tokens');
for i=1:numel(tokens),name=strtrim(string(tokens{i}{1}));data=regexprep(data,'(?im)^\s*@include\s+[''"]?'+regexptranslate("escape",name)+'[''"]?\s*$',fileread(fullfile(directory,name)),'once');end
sets=regexp(data,'(?im)^\s*@set\s+(\w+)\s+(\S+)\s*$','tokens');
for i=1:numel(sets),name=string(sets{i}{1});val=string(sets{i}{2});data=regexprep(data,'(?im)^\s*@set\s+'+name+'\s+\S+\s*$','');data=regexprep(data,'\$\{?'+name+'\}?',val);end
if ~isempty(regexpi(data,'@(?:IF|ELIF)','once')),error("KSSOLV:Matgenlab:Cp2k:Conditional","Conditional preprocessor blocks are unsupported upstream.");end
end
