classdef LammpsInputFile
    %#ok<*ALIGN,*ISCL>
    %LAMMPSINPUTFILE Stage-aware LAMMPS input script model.
    properties
        stages struct = struct("stage_name",{},"commands",{})
    end
    properties (Dependent)
        stages_names
        nstages
        ncomments
    end
    methods
        function obj=LammpsInputFile(stages)
            if nargin>0 && ~isempty(stages), obj.stages=stages; end
            if numel(unique(obj.stages_names))~=obj.nstages
                error("KSSOLV:Matgenlab:LammpsInputFile:StageNames", ...
                    "Stage names should be unique.");
            end
        end
        function v=get.stages_names(obj)
            if isempty(obj.stages), v=strings(1,0);
            else, v=string({obj.stages.stage_name}); end
        end
        function v=get.nstages(obj), v=numel(obj.stages); end
        function v=get.ncomments(obj)
            v=0;
            for k=1:obj.nstages
                c=obj.stages(k).commands;
                if isempty(c), continue; end
                iscomm=startsWith(strtrim(string(c(:,1))),"#");
                if all(iscomm), v=v+1; else, v=v+sum(iscomm); end
            end
        end
        function out=get_args(obj,command,stage_name)
            if nargin<3||isempty(stage_name), selected=obj.stages_names;
            else, selected=string(stage_name); end
            out={};
            for k=1:obj.nstages
                if any(obj.stages(k).stage_name==selected)
                    c=obj.stages(k).commands;
                    for j=1:size(c,1)
                        if string(c{j,1})==string(command), out{end+1}=c{j,2}; end %#ok<AGROW>
                    end
                end
            end
            if isempty(out), out={}; elseif numel(out)==1, out=out{1}; end
        end
        function tf=contains_command(obj,command,stage_name)
            if nargin<3, args=obj.get_args(command); else, args=obj.get_args(command,stage_name); end
            tf=~isempty(args);
        end
        function obj=set_args(obj,command,argument,stage_name,how)
            if nargin<4||isempty(stage_name), selected=obj.stages_names;
            else, selected=string(stage_name); end
            if nargin<5, how="all"; end
            allWanted=string(how)=="all";
            if string(how)=="first", wanted=1;
            elseif allWanted, wanted=[];
            else, wanted=double(how)+1; end
            occurrence=0;
            for k=1:obj.nstages
                if any(obj.stages(k).stage_name==selected)
                    for j=1:size(obj.stages(k).commands,1)
                        if string(obj.stages(k).commands{j,1})==string(command)
                            occurrence=occurrence+1;
                            if allWanted||any(occurrence==wanted)
                                obj.stages(k).commands{j,2}=char(string(argument));
                            end
                        end
                    end
                end
            end
        end
        function obj=add_stage(obj,stage,commands,stage_name,after_stage)
            if nargin<2, stage=[]; end
            if nargin<3, commands=[]; end
            if nargin<4||isempty(stage_name), stage_name=""; end
            if nargin<5, after_stage=[]; end
            if ~isempty(stage)
                new=stage;
            else
                if strlength(stage_name)==0
                    nums=regexp(obj.stages_names,'^Stage ([0-9]+)$','tokens','once');
                    vals=cellfun(@(x)0,cellstr(obj.stages_names));
                    for q=1:numel(nums), if ~isempty(nums{q}), vals(q)=str2double(nums{q}{1}); end, end
                    stage_name="Stage "+string(max([vals 0])+1);
                end
                new=struct("stage_name",char(stage_name),"commands",{{}});
                new.commands=obj.parseCommands(commands);
            end
            if any(obj.stages_names==string(new.stage_name))
                error("KSSOLV:Matgenlab:LammpsInputFile:DuplicateStage","Stage name already present.");
            end
            if isempty(after_stage), idx=obj.nstages+1;
            elseif isnumeric(after_stage), idx=after_stage+2;
            else
                found=find(obj.stages_names==string(after_stage),1);
                if isempty(found), error("KSSOLV:Matgenlab:LammpsInputFile:Stage","Unknown stage."); end
                idx=found+1;
            end
            obj.stages=[obj.stages(1:idx-1),new,obj.stages(idx:end)];
        end
        function obj=remove_stage(obj,name)
            k=find(obj.stages_names==string(name),1);
            if isempty(k), error("KSSOLV:Matgenlab:LammpsInputFile:Stage","Unknown stage."); end
            obj.stages(k)=[];
        end
        function obj=rename_stage(obj,name,newName)
            if any(obj.stages_names==string(newName))
                error("KSSOLV:Matgenlab:LammpsInputFile:DuplicateStage","Stage name already present.");
            end
            k=find(obj.stages_names==string(name),1);
            if isempty(k), error("KSSOLV:Matgenlab:LammpsInputFile:Stage","Unknown stage."); end
            obj.stages(k).stage_name=char(newName);
        end
        function obj=merge_stages(obj,names)
            names=string(names); idx=find(ismember(obj.stages_names,names));
            if isempty(idx), return; end
            commands=cell(0,2);
            for k=idx, commands=[commands;obj.stages(k).commands]; end %#ok<AGROW>
            merged=struct("stage_name",char("Merge of: "+join(names,", ")), ...
                "commands",{commands});
            first=idx(1); obj.stages(idx)=[]; obj.stages=[obj.stages(1:first-1),merged,obj.stages(first:end)];
        end
        function obj=add_commands(obj,stage_name,commands)
            k=find(obj.stages_names==string(stage_name),1);
            if isempty(k), error("KSSOLV:Matgenlab:LammpsInputFile:Stage","Unknown stage."); end
            obj.stages(k).commands=[obj.stages(k).commands;obj.parseCommands(commands)];
        end
        function obj=remove_command(obj,command,stage_name,remove_empty_stages)
            if nargin<3||isempty(stage_name), names=obj.stages_names; else, names=string(stage_name); end
            if nargin<4, remove_empty_stages=true; end
            keepStage=true(1,obj.nstages);
            for k=1:obj.nstages
                if ismember(string(obj.stages(k).stage_name),names)
                    c=obj.stages(k).commands;
                    c(string(c(:,1))==string(command),:)=[];
                    obj.stages(k).commands=c;
                    if isempty(c)&&remove_empty_stages, keepStage(k)=false; end
                end
            end
            obj.stages=obj.stages(keepStage);
        end
        function obj=append(obj,other)
            added=other.stages;
            for k=1:numel(added)
                old=string(added(k).stage_name);
                t=regexp(old,'^(Stage|Comment) ([0-9]+)$','tokens','once');
                if ~isempty(t)
                    if t{1}=="Stage", n=obj.nstages; else, n=obj.ncomments; end
                    added(k).stage_name=char(t{1}+" "+string(str2double(t{2})+n));
                elseif any(obj.stages_names==old)
                    added(k).stage_name=char("Stage "+string(obj.nstages+k)+" (previously "+old+")");
                end
            end
            obj.stages=[obj.stages added];
        end
        function text=get_str(obj,ignore_comments,keep_stages)
            if nargin<2, ignore_comments=false; end
            if nargin<3, keep_stages=true; end
            text="# LAMMPS input generated from LammpsInputFile with pymatgen v2026.7.24"+newline;
            if ~keep_stages, text=text+newline; end
            for k=1:obj.nstages
                name=string(obj.stages(k).stage_name);
                if keep_stages
                    if ~contains(name,"Comment")&&obj.nstages>1, text=text+newline+"# "+name+newline;
                    else, text=text+newline; end
                end
                c=obj.stages(k).commands;
                for j=1:size(c,1)
                    if ~(ignore_comments&&contains(string(c{j,1}),"#"))
                        text=text+string(c{j,1})+" "+strtrim(string(c{j,2}))+newline;
                    end
                end
            end
            text=char(text);
        end
        function write_file(obj,filename,ignore_comments,keep_stages)
            if nargin<3, ignore_comments=false; end
            if nargin<4, keep_stages=true; end
            fid=fopen(filename,'w'); cleanup=onCleanup(@()fclose(fid));
            fwrite(fid,obj.get_str(ignore_comments,keep_stages));
        end
    end
    methods (Static)
        function obj=from_str(contents,ignore_comments,keep_stages)
            if nargin<2, ignore_comments=false; end
            if nargin<3, keep_stages=false; end
            text=regexprep(char(contents),'&[ \t]*\r?\n[ \t]*','');
            lines=splitlines(string(strtrim(text)));
            lines=regexprep(lines,'^\s+|\s+$','');
            lines(startsWith(lines,"# LAMMPS input generated from LammpsInputFile"))=[];
            lines(lines=="#")=[];
            if ignore_comments, lines(startsWith(lines,"#"))=[]; end
            if ~keep_stages
                cuts=[0;find(lines=="");numel(lines)+1]; merged=strings(0,1);
                foundCommands=false;
                for z=1:numel(cuts)-1
                    block=lines(cuts(z)+1:cuts(z+1)-1);
                    if isempty(block), continue; end
                    comments=startsWith(block,"#");
                    if all(comments), continue; end
                    if ~foundCommands && comments(1)
                        block(1)=[]; % first command-block comment is its header
                    end
                    foundCommands=true; merged=[merged;block]; %#ok<AGROW>
                end
                lines=merged;
                obj=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile();
                obj=obj.add_stage([],lines,"Stage 1");
                return
            end
            cut=[0;find(lines=="");numel(lines)+1]; obj=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile();
            blockNo=0;
            for q=1:numel(cut)-1
                block=lines(cut(q)+1:cut(q+1)-1); if isempty(block), continue; end
                blockNo=blockNo+1;
                iscomm=startsWith(block,"#");
                if all(iscomm)
                    name="Comment "+string(obj.ncomments+1);
                    cmds=[repmat({'#'},numel(block),1),cellstr(strtrim(extractAfter(block,1)))];
                    obj.stages(end+1)=struct("stage_name",char(name),"commands",{cmds});
                elseif iscomm(1)
                    n=find(~iscomm,1)-1;
                    name=strtrim(join(strtrim(extractAfter(block(1:n),1))," "));
                    obj=obj.add_stage([],block(n+1:end),name);
                else
                    obj=obj.add_stage([],block,"Stage "+string(blockNo));
                end
            end
        end
        function obj=from_file(path,ignore_comments,keep_stages)
            if nargin<2, ignore_comments=false; end
            if nargin<3, keep_stages=false; end
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsInputFile.from_str( ...
                kssolv.analysis.matgenlab.io.lammps.read_text(path),ignore_comments,keep_stages);
        end
    end
    methods (Access=private)
        function c=parseCommands(~,commands)
            if isempty(commands), c=cell(0,2); return; end
            if isstruct(commands)
                names=fieldnames(commands); c=cell(numel(names),2);
                for k=1:numel(names), c{k,1}=names{k}; c{k,2}=char(string(commands.(names{k}))); end
                return
            end
            lines=string(commands); lines=lines(:); c=cell(numel(lines),2);
            for k=1:numel(lines)
                line=strtrim(lines(k));
                if startsWith(line,"#"), c{k,1}='#'; c{k,2}=char(strtrim(extractAfter(line,1)));
                else
                    parts=split(line); parts(parts=="")=[];
                    c{k,1}=char(parts(1));
                    if numel(parts)==1, c{k,2}='';
                    else, c{k,2}=char(join(parts(2:end)," ")); end
                end
            end
        end
    end
end
