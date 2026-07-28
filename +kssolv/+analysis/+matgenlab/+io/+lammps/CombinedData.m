classdef CombinedData < kssolv.analysis.matgenlab.io.lammps.LammpsData
    %#ok<*AGROW>
    properties
        mols; names; nums; coordinates; mols_per_data
    end
    methods
        function obj=CombinedData(list_of_molecules,list_of_names,list_of_numbers,coordinates,atom_style)
            if nargin<5, atom_style="full"; end
            xyz=coordinates{:,{'x','y','z'}}; lo=min(xyz,[],'all')-.5; hi=max(xyz,[],'all')+.5;
            box=kssolv.analysis.matgenlab.io.lammps.LammpsBox(repmat([lo hi],3,1));
            masses=table();
            for mk=1:numel(list_of_molecules)
                massPart=list_of_molecules{mk}.masses; massPart.Properties.RowNames={};
                masses=[masses;massPart];
            end
            masses.Properties.RowNames=cellstr(string(1:height(masses)));
            atoms=table(); typeShift=0; molShift=0; molsPerData=zeros(1,numel(list_of_molecules));
            for k=1:numel(list_of_molecules)
                base=list_of_molecules{k}.atoms;
                base.Properties.RowNames={};
                if ~any(strcmp(base.Properties.VariableNames,'molecule_ID')), base.molecule_ID=ones(height(base),1); end
                base.type=base.type+typeShift; base.molecule_ID=base.molecule_ID+molShift;
                molsPerData(k)=numel(unique(base.molecule_ID));
                for q=1:list_of_numbers(k)
                    copy=base; copy.molecule_ID=copy.molecule_ID+(q-1)*molsPerData(k);
                    atoms=[atoms;copy];
                end
                typeShift=typeShift+height(list_of_molecules{k}.masses);
                molShift=molShift+list_of_numbers(k)*molsPerData(k);
            end
            if height(atoms)~=height(coordinates), error("KSSOLV:Matgenlab:CombinedData:Coordinates","Atom/coordinate count mismatch."); end
            atoms{:,{'x','y','z'}}=coordinates{:,{'x','y','z'}};
            atoms.Properties.RowNames=cellstr(string(1:height(atoms)));
            forceField=containers.Map('KeyType','char','ValueType','any');
            allKeys={};
            for k=1:numel(list_of_molecules)
                if isa(list_of_molecules{k}.force_field,'containers.Map')
                    allKeys=union(allKeys,list_of_molecules{k}.force_field.keys,'stable');
                end
            end
            for keyIndex=1:numel(allKeys)
                key=allKeys{keyIndex};
                combined=table();
                for k=1:numel(list_of_molecules)
                    if isa(list_of_molecules{k}.force_field,'containers.Map')&& ...
                            isKey(list_of_molecules{k}.force_field,key)
                        part=list_of_molecules{k}.force_field(key);
                        part.Properties.RowNames={};
                        allVariables=union(combined.Properties.VariableNames, ...
                            part.Properties.VariableNames,'stable');
                        for variable=allVariables
                            if ~any(strcmp(combined.Properties.VariableNames,variable{1}))
                                combined.(variable{1})=nan(height(combined),1);
                            end
                            if ~any(strcmp(part.Properties.VariableNames,variable{1}))
                                part.(variable{1})=nan(height(part),1);
                            end
                        end
                        combined=combined(:,allVariables);
                        part=part(:,allVariables);
                        combined=[combined;part];
                    end
                end
                combined.Properties.RowNames=cellstr(string(1:height(combined)));
                forceField(key)=combined;
            end
            if forceField.Count==0, forceField=[]; end
            topology=containers.Map('KeyType','char','ValueType','any');
            topoNames={'Bonds','Angles','Dihedrals','Impropers'};
            atomOffset=0; typeOffsets=zeros(1,4);
            for k=1:numel(list_of_molecules)
                molData=list_of_molecules{k};
                for ti=1:numel(topoNames)
                    key=topoNames{ti};
                    if isa(molData.topology,'containers.Map')&&isKey(molData.topology,key)
                        base=molData.topology(key); base.Properties.RowNames={};
                        base.type=base.type+typeOffsets(ti);
                        atomColumns=startsWith(base.Properties.VariableNames,'atom');
                        collection=table();
                        for q=1:list_of_numbers(k)
                            copy=base;
                            copy{:,atomColumns}=copy{:,atomColumns}+atomOffset+(q-1)*height(molData.atoms);
                            collection=[collection;copy];
                        end
                        if isKey(topology,key), old=topology(key); old.Properties.RowNames={}; collection.Properties.RowNames={}; collection=[old;collection]; end
                        collection.Properties.RowNames=cellstr(string(1:height(collection))); topology(key)=collection;
                    end
                    coeffKey=extractBefore(key,strlength(key))+" Coeffs";
                    if isa(molData.force_field,'containers.Map')&&isKey(molData.force_field,char(coeffKey))
                        typeOffsets(ti)=typeOffsets(ti)+height(molData.force_field(char(coeffKey)));
                    end
                end
                atomOffset=atomOffset+height(molData.atoms)*list_of_numbers(k);
            end
            if topology.Count==0, topology=[]; end
            obj@kssolv.analysis.matgenlab.io.lammps.LammpsData(box,masses,atoms,[],forceField,topology,atom_style);
            obj.mols=list_of_molecules; obj.names=regexprep(string(list_of_names),'\W','_');
            obj.nums=list_of_numbers; obj.coordinates=coordinates; obj.mols_per_data=molsPerData;
        end
        function out=disassemble(obj,varargin)
            out=cell(size(obj.mols));
            for k=1:numel(obj.mols), [a,b,c]=obj.mols{k}.disassemble(varargin{:}); out{k}={a,b,c}; end
        end
        function text=get_str(obj,varargin)
            text=get_str@kssolv.analysis.matgenlab.io.lammps.LammpsData(obj,varargin{:});
            bits=strings(1,numel(obj.names));
            for k=1:numel(bits)
                if obj.mols_per_data(k)==1, bits(k)=obj.nums(k)+" "+obj.names(k);
                else, bits(k)=obj.nums(k)+"("+obj.mols_per_data(k)+") "+obj.names(k); end
            end
            lines=splitlines(string(text)); lines=[lines(1);"# "+join(bits," + ");lines(2:end)]; text=char(join(lines,newline));
        end
        function d=as_lammpsdata(obj)
            d=kssolv.analysis.matgenlab.io.lammps.LammpsData(obj.box,obj.masses,obj.atoms, ...
                obj.velocities,obj.force_field,obj.topology,obj.atom_style);
        end
    end
    methods (Static)
        function tab=parse_xyz(filename)
            lines=splitlines(string(kssolv.analysis.matgenlab.io.lammps.read_text(filename))); lines=lines(3:end); lines(lines=="")=[];
            vals=strings(numel(lines),1); xyz=zeros(numel(lines),3);
            for k=1:numel(lines), p=split(strtrim(lines(k))); vals(k)=p(1); xyz(k,:)=str2double(p(2:4)); end
            tab=table(vals,xyz(:,1),xyz(:,2),xyz(:,3),'VariableNames',{'atom','x','y','z'});
            tab.Properties.RowNames=cellstr(string(1:height(tab)));
        end
        function obj=from_files(coordinate_file,list_of_numbers,varargin)
            mols=cell(size(varargin)); names=strings(size(varargin)); styles=strings(size(varargin));
            for k=1:numel(varargin)
                mols{k}=kssolv.analysis.matgenlab.io.lammps.LammpsData.from_file(varargin{k});
                names(k)="cluster"+k; styles(k)=mols{k}.atom_style;
            end
            if numel(unique(styles))~=1, error("Files have different atom styles."); end
            obj=kssolv.analysis.matgenlab.io.lammps.CombinedData(mols,names,list_of_numbers, ...
                kssolv.analysis.matgenlab.io.lammps.CombinedData.parse_xyz(coordinate_file),styles(1));
        end
        function obj=from_lammpsdata(mols,names,list_of_numbers,coordinates,atom_style)
            styles=cellfun(@(m)string(m.atom_style),mols);
            if numel(unique(styles))~=1, error("Data have different atom_style."); end
            if nargin<5||isempty(atom_style), atom_style=styles(1); end
            if atom_style~=styles(1), error("Data have different atom_style as specified."); end
            obj=kssolv.analysis.matgenlab.io.lammps.CombinedData(mols,names,list_of_numbers,coordinates,atom_style);
        end
        function from_ff_and_topologies(varargin)
            error("KSSOLV:Matgenlab:CombinedData:Unsupported","Unsupported constructor for CombinedData objects");
        end
        function from_structure(varargin)
            error("KSSOLV:Matgenlab:CombinedData:Unsupported","Unsupported constructor for CombinedData objects");
        end
    end
end
