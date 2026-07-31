classdef PackmolRunner
    properties
        mols; param_list; input_file; control_params; output_file; bin
        executor=[]
    end
    methods
        function obj=PackmolRunner(mols,param_list,input_file,tolerance,filetype,control_params,auto_box,output_file,bin,executor)
            if nargin<3, input_file='pack.inp'; end
            if nargin<4, tolerance=2; end
            if nargin<5, filetype='xyz'; end
            if nargin<6||isempty(control_params), control_params=struct('maxit',20,'nloop',600); end
            if nargin<7, auto_box=true; end
            if nargin<8, output_file='packed.xyz'; end
            if nargin<9, bin='packmol'; end
            if nargin>=10, obj.executor=executor; end
            obj.mols=mols; obj.param_list=param_list; obj.input_file=input_file; obj.bin=bin;
            control_params.tolerance=tolerance; control_params.filetype=filetype;
            [~,base]=fileparts(output_file);
            control_params.output=char(string(base)+"."+string(filetype));
            obj.output_file=control_params.output; obj.control_params=control_params;
            if auto_box
                volume=0;
                for k=1:numel(mols), span=max(range(mols{k}.cart_coords,1))+2; volume=volume+span^3*param_list{k}.number; end
                side=volume^(1/3);
                for k=1:numel(param_list), obj.param_list{k}.inside_box=[0 0 0 side side side]; end
            end
        end
        function mol=run(obj,site_property)
            td=tempname; mkdir(td); cleanup=onCleanup(@()rmdir(td,'s'));
            inp=fullfile(td,obj.input_file); fid=fopen(inp,'w');
            fields=fieldnames(obj.control_params);
            for k=1:numel(fields), fprintf(fid,'%s %s\n',strrep(fields{k},'_',' '),obj.format(obj.control_params.(fields{k}))); end
            for k=1:numel(obj.mols)
                moleculeFile=fullfile(td,sprintf('%d.%s',k-1,obj.control_params.filetype));
                if strcmp(obj.control_params.filetype,'pdb')
                    obj.write_pdb(obj.mols{k},moleculeFile,[],k);
                else
                    obj.writeXYZ(obj.mols{k},moleculeFile);
                end
                fprintf(fid,'\nstructure %s\n',moleculeFile); p=fieldnames(obj.param_list{k});
                for j=1:numel(p), fprintf(fid,'  %s %s\n',strrep(p{j},'_',' '),obj.format(obj.param_list{k}.(p{j}))); end
                fprintf(fid,'end structure\n');
            end
            fclose(fid); old=pwd; cd(td); restore=onCleanup(@()cd(old));
            if isempty(obj.executor)
                executor = @kssolv.analysis.packmol.native_executor;
            else
                executor = obj.executor;
            end
            request=struct("command",string(obj.bin), ...
                "stdin_path",string(obj.input_file), ...
                "stdin",string(fileread(obj.input_file)), ...
                "output_path",string(obj.output_file), ...
                "working_directory",string(td));
            result=executor(request);
            if ~isstruct(result)
                result=struct("status",0,"stdout",string(result), ...
                    "stderr","");
            end
            if ~isfield(result,"status"), result.status=0; end
            if ~isfield(result,"stdout"), result.stdout=""; end
            if ~isfield(result,"stderr"), result.stderr=""; end
            outputPath=fullfile(td,char(string(obj.output_file)));
            if isfield(result,"output_text")
                fid=fopen(outputPath,'w');
                fileCleanup=onCleanup(@()fclose(fid));
                fwrite(fid,char(string(result.output_text)));
                clear fileCleanup
            end
            if result.status~=0||~isfile(outputPath)
                error("KSSOLV:Matgenlab:PackmolRunner:Run", ...
                    "Packmol execution failed: %s",string(result.stderr));
            end
            if strcmp(obj.control_params.filetype,'pdb')
                mol=obj.restore_site_properties(site_property, outputPath);
            else
                mol=obj.readXYZ(outputPath);
            end
            copyfile(outputPath,fullfile(old,obj.output_file));
        end
        function mol=convert_obatoms_to_molecule(~,atoms,residue_name,site_property) %#ok<INUSD>
            z=arrayfun(@(a)a.atomicnum,atoms); coords=vertcat(atoms.coords);
            mol=kssolv.analysis.matgenlab.core.Molecule(num2cell(z),coords);
        end
        function mol=restore_site_properties(obj,site_property,filename)
            if nargin<2||isempty(site_property), site_property='ff_map'; end
            if nargin<3||isempty(filename), filename=obj.output_file; end
            if ~strcmp(obj.control_params.filetype,'pdb')
                error("KSSOLV:Matgenlab:PackmolRunner:PDB","Site properties can only be restored for PDB files.");
            end
            lines=splitlines(string(fileread(filename)));
            lines=lines(startsWith(lines,"ATOM")|startsWith(lines,"HETATM"));
            species=strings(numel(lines),1); coords=zeros(numel(lines),3);
            props=cell(numel(lines),1); residueIds=strings(numel(lines),1);
            counters=containers.Map('KeyType','char','ValueType','double');
            for k=1:numel(lines)
                line=char(pad(lines(k),80,'right'));
                symbol=strtrim(line(77:78));
                if isempty(symbol), symbol=regexprep(strtrim(line(13:16)),'[^A-Za-z]',''); end
                species(k)=symbol; coords(k,:)=[str2double(line(31:38)),str2double(line(39:46)),str2double(line(47:54))];
                residue=strtrim(line(18:20)); residueIds(k)=residue;
                token=regexp(residue,'ml(\d+)','tokens','once');
                if isempty(token), continue; end
                molIndex=str2double(token{1}); key=char(residue);
                if ~isKey(counters,key), counters(key)=0; end
                siteIndex=mod(counters(key),obj.mols{molIndex}.num_sites)+1; counters(key)=counters(key)+1;
                refProps=obj.mols{molIndex}.site_properties;
                if isfield(refProps,site_property), values=refProps.(site_property); props{k}=values(siteIndex); end
            end
            siteProperties=struct();
            if any(~cellfun(@isempty,props)), siteProperties.(site_property)=props; end
            mol=kssolv.analysis.matgenlab.core.Molecule(cellstr(species),coords,site_properties=siteProperties);
        end
    end
    methods (Static)
        function write_pdb(mol,filename,name,num)
            if nargin<3||isempty(name), name='ml1'; end
            if nargin<4||isempty(num), num=1; end
            fid=fopen(filename,'w'); cleanup=onCleanup(@()fclose(fid));
            for k=1:mol.num_sites
                s=mol.sites{k}; fprintf(fid,'HETATM%5d %-2s   %-3s A%4d    %8.3f%8.3f%8.3f  1.00  0.00          %2s\n', ...
                    k,s.specie.symbol,name,num,s.coords,s.specie.symbol);
            end
            fprintf(fid,'END\n');
        end
    end
    methods (Static,Access=private)
        function s=format(v)
            if isnumeric(v), s=strjoin(compose('%g',v),' '); else, s=char(string(v)); end
        end
        function writeXYZ(mol,file)
            fid=fopen(file,'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%d\n\n',mol.num_sites);
            for k=1:mol.num_sites, s=mol.sites{k}; fprintf(fid,'%s %.12g %.12g %.12g\n',s.specie.symbol,s.coords); end
        end
        function mol=readXYZ(file)
            lines=splitlines(string(fileread(file))); n=str2double(lines(1)); species=cell(n,1); coords=zeros(n,3);
            for k=1:n, p=split(strtrim(lines(k+2))); species{k}=char(p(1)); coords(k,:)=str2double(p(2:4)); end
            mol=kssolv.analysis.matgenlab.core.Molecule(species,coords);
        end
    end
end
