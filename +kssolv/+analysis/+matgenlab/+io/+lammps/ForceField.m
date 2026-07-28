classdef ForceField < kssolv.analysis.matgenlab.util.MSONable
    %#ok<*ALIGN,*ISCL>
    properties
        mass_info
        nonbond_coeffs
        topo_coeffs
        masses table
        force_field=[]
        maps
    end
    methods
        function obj=ForceField(mass_info,nonbond_coeffs,topo_coeffs)
            if nargin<2, nonbond_coeffs=[]; end
            if nargin<3, topo_coeffs=[]; end
            obj.mass_info=mass_info; obj.nonbond_coeffs=nonbond_coeffs; obj.topo_coeffs=topo_coeffs;
            n=size(mass_info,1); mass=zeros(n,1); atomMap=containers.Map('KeyType','char','ValueType','double');
            for k=1:n
                v=mass_info{k,2};
                if ischar(v)||isstring(v), v=kssolv.analysis.matgenlab.core.Element(v).atomic_mass;
                elseif isa(v,'kssolv.analysis.matgenlab.core.Element'), v=v.atomic_mass; end
                mass(k)=double(v); obj.mass_info{k,2}=mass(k); atomMap(char(string(mass_info{k,1})))=k;
            end
            obj.masses=table(mass,'VariableNames',{'mass'}); obj.masses.Properties.RowNames=cellstr(string(1:n));
            obj.maps=containers.Map('KeyType','char','ValueType','any'); obj.maps('Atoms')=atomMap;
            ff=containers.Map('KeyType','char','ValueType','any');
            if ~isempty(nonbond_coeffs)
                arr=double(nonbond_coeffs); names=arrayfun(@(x)sprintf('coeff%d',x),1:size(arr,2),'UniformOutput',false);
                if size(arr,1)==n
                    t=array2table(arr,'VariableNames',names); t.Properties.RowNames=cellstr(string(1:n)); ff('Pair Coeffs')=t;
                elseif size(arr,1)==n*(n+1)/2
                    ids=nchoosek(repelem(1:n,2),2); ids=unique(sort(ids,2),'rows'); ids=ids(ids(:,1)<=ids(:,2),:);
                    t=array2table([ids arr],'VariableNames',[{'id1','id2'},names]); ff('PairIJ Coeffs')=t;
                else, error("KSSOLV:Matgenlab:ForceField:Nonbond","Invalid number of nonbond rows."); end
            end
            if ~isempty(topo_coeffs)
                if isa(topo_coeffs,'containers.Map'), keys=topo_coeffs.keys;
                else, keys=fieldnames(topo_coeffs); end
                for q=1:numel(keys)
                    key=keys{q}; if isa(topo_coeffs,'containers.Map'), entries=topo_coeffs(key); else, entries=topo_coeffs.(key); end
                    if ~iscell(entries), entries=num2cell(entries); end
                    data=cell(numel(entries),1);
                    auxiliary=containers.Map('KeyType','char','ValueType','any');
                    typeMap=containers.Map('KeyType','char','ValueType','double');
                    for j=1:numel(entries)
                        e=entries{j}; data{j}=e.coeffs;
                        entryFields=fieldnames(e);
                        for ef=1:numel(entryFields)
                            field=entryFields{ef};
                            if ismember(field,{'coeffs','types'}), continue; end
                            if isKey(auxiliary,field), values=auxiliary(field); else, values=cell(numel(entries),1); end
                            values{j}=e.(field); auxiliary(field)=values;
                        end
                        if isfield(e,'types')
                            tuples=e.types; if ~iscell(tuples), tuples={tuples}; end
                            if iscell(tuples)&&~isempty(tuples)&&~iscell(tuples{1}), tuples={tuples}; end
                            for it=1:numel(tuples)
                                tuple=tuples{it}; if iscell(tuple)&&numel(tuple)==1&&iscell(tuple{1}), tuple=tuple{1}; end
                                labels=string(tuple(:))';
                                typeMap(char(join(labels,'|')))=j;
                                typeMap(char(join(fliplr(labels),'|')))=j;
                                if startsWith(key,'Improper')&&numel(labels)==4
                                    typeMap(char(join(labels([1 3 2 4]),'|')))=j;
                                    typeMap(char(join(labels([4 2 3 1]),'|')))=j;
                                end
                            end
                        end
                    end
                    maxc=max(cellfun(@numel,data)); a=nan(numel(data),maxc);
                    for j=1:numel(data), a(j,1:numel(data{j}))=data{j}; end
                    names=arrayfun(@(x)sprintf('coeff%d',x),1:maxc,'UniformOutput',false);
                    t=array2table(a,'VariableNames',names); t.Properties.RowNames=cellstr(string(1:height(t)));
                    pretty=regexprep(strrep(key,'_',' '),'\s+',' ');
                    pretty=regexprep(pretty,'(?<!\s)Coeffs$', ...
                        ' Coeffs');
                    ff(pretty)=t;
                    auxiliaryKeys=auxiliary.keys;
                    for ak=1:numel(auxiliaryKeys)
                        auxValues=auxiliary(auxiliaryKeys{ak});
                        maxAux=max(cellfun(@numel,auxValues)); auxArray=nan(numel(auxValues),maxAux);
                        for j=1:numel(auxValues), auxArray(j,1:numel(auxValues{j}))=auxValues{j}; end
                        auxNames=arrayfun(@(x)sprintf('coeff%d',x),1:maxAux,'UniformOutput',false);
                        auxTable=array2table(auxArray,'VariableNames',auxNames);
                        auxTable.Properties.RowNames=cellstr(string(1:height(auxTable)));
                        auxPretty=regexprep(strrep(auxiliaryKeys{ak}, ...
                            '_',' '),'\s+',' ');
                        auxPretty=regexprep(auxPretty, ...
                            '(?<!\s)Coeffs$',' Coeffs');
                        ff(auxPretty)=auxTable;
                    end
                    plural=regexprep(pretty,' Coeffs$','s');
                    obj.maps(plural)=typeMap;
                end
            end
            if ff.Count>0, obj.force_field=ff; end
        end
        function to_file(obj,filename)
            rows=cell(size(obj.mass_info,1),1);
            for k=1:numel(rows), rows{k}=obj.mass_info(k,:); end
            d=struct('mass_info',{rows}, ...
                'nonbond_coeffs',obj.nonbond_coeffs, ...
                'topo_coeffs',obj.topo_coeffs);
            fid=fopen(filename,'w'); cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(d,PrettyPrint=true));
        end
        function d=asDict(obj)
            d=struct('mass_info',{obj.mass_info},'nonbond_coeffs',obj.nonbond_coeffs,'topo_coeffs',obj.topo_coeffs);
        end
    end
    methods (Static)
        function obj=from_file(filename)
            try
                d=kssolv.analysis.matgenlab.util.yaml_load(filename);
            catch
                d=jsondecode(fileread(filename));
            end
            obj=kssolv.analysis.matgenlab.io.lammps.ForceField.from_dict(d);
        end
        function obj=from_dict(d)
            mi=d.mass_info;
            if iscell(mi)&&size(mi,2)==1&&all(cellfun(@iscell,mi))
                rows=mi; mi=cell(numel(rows),2);
                for k=1:numel(rows)
                    row=rows{k}; mi{k,1}=row{1};
                    value=row{2}; if iscell(value), value=value{1}; end
                    mi{k,2}=value;
                end
            elseif iscell(mi)&&size(mi,2)==1&&mod(numel(mi),2)==0
                mi=reshape(mi,[],2);
            elseif isnumeric(mi), mi=num2cell(mi); end
            topo=[]; if isfield(d,'topo_coeffs'), topo=d.topo_coeffs; end
            non=[]; if isfield(d,'nonbond_coeffs'), non=d.nonbond_coeffs; end
            obj=kssolv.analysis.matgenlab.io.lammps.ForceField(mi,non,topo);
        end
    end
end
