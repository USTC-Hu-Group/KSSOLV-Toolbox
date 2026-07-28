classdef NwInput < kssolv.analysis.matgenlab.util.MSONable
    %NWINPUT Complete NWChem input for one molecule and multiple tasks.
    properties
        tasks (1,:) cell
        directives (1,:) cell = cell(1,0)
        geometry_options (1,:) string = ["units","angstroms"]
        symmetry_options = []
        memory_options = []
    end
    properties (Dependent)
        molecule
    end
    properties (Access=private)
        mol
    end
    methods
        function obj=NwInput(molecule,tasks,directives, ...
                geometryOptions,symmetryOptions,memoryOptions)
            if nargin<3||isempty(directives),directives={};end
            if nargin<4||isempty(geometryOptions)
                geometryOptions=["units","angstroms"];
            end
            if nargin<5,symmetryOptions=[];end
            if nargin<6,memoryOptions=[];end
            if ~iscell(tasks),tasks=num2cell(tasks);end
            if ~iscell(directives),directives=num2cell(directives,2);end
            obj.mol=molecule;obj.tasks=reshape(tasks,1,[]);
            obj.directives=reshape(directives,1,[]);
            obj.geometry_options=reshape(string(geometryOptions),1,[]);
            if ~isempty(symmetryOptions)
                obj.symmetry_options=reshape(string(symmetryOptions),1,[]);
            end
            if ~isempty(memoryOptions)
                obj.memory_options=string(memoryOptions);
            end
        end
        function value=get.molecule(obj),value=obj.mol;end
        function value=char(obj)
            lines=strings(1,0);
            if ~isempty(obj.memory_options)
                lines(end+1)="memory "+string(obj.memory_options);
            end
            for index=1:numel(obj.directives)
                item=obj.directives{index};
                if iscell(item),item=string(item);end
                lines(end+1)=string(item(1))+" "+string(item(2)); %#ok<AGROW>
            end
            lines(end+1)="geometry "+join(obj.geometry_options," ");
            if ~isempty(obj.symmetry_options)
                lines(end+1)=" symmetry "+join(obj.symmetry_options," ");
            end
            for index=1:obj.mol.num_sites
                site=obj.mol.sites{index};
                lines(end+1)=" "+string(site.specie.symbol)+" "+ ...
                    pyFloat(site.coords(1))+" "+pyFloat(site.coords(2))+ ...
                    " "+pyFloat(site.coords(3)); %#ok<AGROW>
            end
            lines(end+1)="end"+newline;
            value=char(join(lines,newline)+newline);
            for index=1:numel(obj.tasks)
                value=[value,char(obj.tasks{index}),newline,newline]; %#ok<AGROW>
            end
        end
        function value=string(obj),value=string(char(obj));end
        function write_file(obj,filename)
            [file,message]=fopen(filename,"w");
            if file<0
                error("KSSOLV:Matgenlab:NWChem:Write", ...
                    "Cannot open '%s': %s",filename,message);
            end
            cleanup=onCleanup(@()fclose(file));
            fprintf(file,"%s",char(obj));clear cleanup
        end
        function writeFile(obj,filename),obj.write_file(filename);end
        function value=as_dict(obj)
            value=struct("mol",obj.mol.as_dict(), ...
                "tasks",{cellfun(@(item)item.as_dict(),obj.tasks, ...
                "UniformOutput",false)}, ...
                "directives",{cellfun(@(item)cellstr(string(item)), ...
                obj.directives,"UniformOutput",false)}, ...
                "geometry_options",obj.geometry_options, ...
                "symmetry_options",obj.symmetry_options, ...
                "memory_options",obj.memory_options);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(value)
            molecule=kssolv.analysis.matgenlab.core.Molecule. ...
                from_dict(value.mol);
            tasks=value.tasks;if ~iscell(tasks),tasks=num2cell(tasks);end
            tasks=cellfun(@(item) ...
                kssolv.analysis.matgenlab.io.nwchem.NwTask. ...
                from_dict(item),tasks,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.io.nwchem.NwInput( ...
                molecule,tasks,value.directives,value.geometry_options, ...
                value.symmetry_options,value.memory_options);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwInput.from_dict(value);
        end
        function obj=from_str(text)
            lines=splitlines(strip(string(text)));
            directives={};tasks={};charge=[];spin=[];title=[];
            basis=struct();basisOption="cartesian";molecule=[];
            theoryDirectives=struct();geometryOptions=[];
            symmetryOptions=[];memoryOptions=[];index=1;
            while index<=numel(lines)
                line=strip(lines(index));index=index+1;
                if strlength(line)==0,continue,end
                tokens=split(line);tokens=tokens(strlength(tokens)>0);
                head=lower(tokens(1));
                if head=="geometry"
                    geometryOptions=tokens(2:end);species={};
                    coordinates=zeros(0,3);symmetryOptions=[];
                    while index<=numel(lines)
                        line=strip(lines(index));index=index+1;
                        if strlength(line)==0,continue,end
                        tokens=split(line);tokens=tokens(strlength(tokens)>0);
                        if lower(tokens(1))=="end",break
                        elseif lower(tokens(1))=="symmetry"
                            symmetryOptions=tokens(2:end);
                        else
                            species{end+1}=char(tokens(1)); %#ok<AGROW>
                            coordinates(end+1,:)=str2double(tokens(2:4)); %#ok<AGROW>
                        end
                    end
                    molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                        species,coordinates,charge_spin_check=false);
                elseif head=="charge"
                    charge=str2double(tokens(2));
                elseif head=="title"
                    title=extractBetween(line,'"','"');
                    if isempty(title),title=strip(extractAfter(line,5));end
                elseif head=="basis"
                    if numel(tokens)>1,basisOption=tokens(2);end
                    basis=struct();
                    while index<=numel(lines)
                        line=strip(lines(index));index=index+1;
                        if lower(line)=="end",break,end
                        tokens=split(line);tokens=tokens(strlength(tokens)>0);
                        basis.(tokens(1))=erase(tokens(end),'"');
                    end
                elseif any(head== ...
                        kssolv.analysis.matgenlab.io.nwchem.NwTask.theories)
                    theory=head;directivesForTheory=struct();
                    while index<=numel(lines)
                        line=strip(lines(index));index=index+1;
                        if lower(line)=="end",break,end
                        tokens=split(line);tokens=tokens(strlength(tokens)>0);
                        directivesForTheory.(tokens(1))=tokens(end);
                        if lower(tokens(1))=="mult"
                            spin=str2double(tokens(2));
                        end
                    end
                    theoryDirectives.(theory)=directivesForTheory;
                elseif head=="task"
                    theory=lower(tokens(2));operation=lower(tokens(3));
                    if isempty(spin),spin=1;end
                    current=struct();
                    if isfield(theoryDirectives,theory)
                        current=theoryDirectives.(theory);
                    end
                    tasks{end+1}=kssolv.analysis.matgenlab.io.nwchem. ...
                        NwTask(charge,spin,basis,basisOption,title, ...
                        theory,operation,current,struct()); %#ok<AGROW>
                elseif head=="memory"
                    memoryOptions=join(tokens(2:end)," ");
                else
                    directives{end+1}=cellstr(tokens).'; %#ok<AGROW>
                end
            end
            obj=kssolv.analysis.matgenlab.io.nwchem.NwInput( ...
                molecule,tasks,directives,geometryOptions, ...
                symmetryOptions,memoryOptions);
        end
        function obj=fromString(text)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwInput.from_str(text);
        end
        function obj=from_file(filename)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwInput. ...
                from_str(fileread(filename));
        end
        function obj=fromFile(filename)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwInput. ...
                from_file(filename);
        end
    end
end

function value=pyFloat(number)
value=string(sprintf("%.15g",number));
if number==fix(number),value=value+".0";end
end
