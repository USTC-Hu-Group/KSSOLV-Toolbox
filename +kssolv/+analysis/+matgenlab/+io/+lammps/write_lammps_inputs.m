function write_lammps_inputs(output_dir,script_template,settings,data,script_filename,make_dir_if_not_present,varargin)
%WRITE_LAMMPS_INPUTS Render template and write/copy associated data.
if nargin<3||isempty(settings), settings=struct(); end
if nargin<4, data=[]; end
if nargin<5||isempty(script_filename), script_filename='in.lammps'; end
if nargin<6, make_dir_if_not_present=true; end
if ~isfolder(output_dir)
    if make_dir_if_not_present, mkdir(output_dir); else, error("Output directory does not exist."); end
end
script=string(script_template); names=fieldnames(settings);
for k=1:numel(names)
    value=settings.(names{k});
    if iscell(value)||numel(value)>1, value=join(string(value)," "); end
    script=regexprep(script,'\$\{?'+string(names{k})+'\}?',string(value));
end
fid=fopen(fullfile(output_dir,script_filename),'w'); cleanup=onCleanup(@()fclose(fid));
fwrite(fid,char(script)); clear cleanup
token=regexp(script,'(?m)^\s*read_data\s+(\S+)','tokens','once');
if isempty(data)||isempty(token), return; end
target=fullfile(output_dir,token{1});
if ischar(data)||isstring(data), copyfile(data,target);
else, data.write_file(target,varargin{:}); end
end
