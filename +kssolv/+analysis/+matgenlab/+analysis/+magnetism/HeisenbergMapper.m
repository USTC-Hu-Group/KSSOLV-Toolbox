classdef HeisenbergMapper < handle
    %HEISENBERGMAPPER Map magnetic total energies to a Heisenberg Hamiltonian.
    %#ok<*ALIGN>
    properties
        ordered_structures_ cell
        energies_ double
        ordered_structures cell
        energies double
        cutoff (1,1) double
        tol (1,1) double
        sgraphs cell
        unique_site_ids
        wyckoff_ids
        nn_interactions
        dists (1,1) struct
        ex_mat table
        ex_params
    end
    methods
        function obj=HeisenbergMapper(structures,energies,cutoff,tol)
            if nargin<3,cutoff=0;end
            if nargin<4,tol=.02;end
            if ~iscell(structures),structures=num2cell(structures);end
            obj.ordered_structures_=structures;obj.energies_=double(energies);
            screened=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergScreener(structures,energies,false);
            obj.ordered_structures=screened.screened_structures;
            obj.energies=screened.screened_energies;
            obj.cutoff=cutoff;obj.tol=tol;
            obj.sgraphs=cell(1,numel(obj.ordered_structures));
            if cutoff
                strategy=kssolv.analysis.matgenlab.core.MinimumDistanceNN( ...
                    "cutoff",cutoff,"get_all_sites",true);
            else
                strategy=kssolv.analysis.matgenlab.core.MinimumDistanceNN();
            end
            for index=1:numel(obj.ordered_structures)
                obj.sgraphs{index}=kssolv.analysis.matgenlab.core. ...
                    StructureGraph.from_local_env_strategy( ...
                    obj.ordered_structures{index},strategy);
            end
            if numel(obj.sgraphs)<2
                error("KSSOLV:Matgenlab:Heisenberg:Orderings", ...
                    "At least two unique magnetic orderings are required.");
            end
            [obj.unique_site_ids,obj.wyckoff_ids]= ...
                uniqueSites(obj.ordered_structures{1});
            obj.buildNeighborDictionary();
            obj.buildExchangeMatrix();
        end
        function exParams=get_exchange(obj)
            names=string(obj.ex_mat.Properties.VariableNames);
            jNames=names(names~="E");
            if numel(jNames)<3
                exParams=containers.Map({"<J>"},{obj.estimate_exchange()});
                obj.ex_params=exParams;return
            end
            H=obj.ex_mat{:,cellstr(jNames)};
            energy=obj.ex_mat{:,"E"};
            values=H\energy;values(2:end)=1000*values(2:end);
            exParams=containers.Map(cellstr(jNames),num2cell(values.'));
            obj.ex_params=exParams;
        end
        function [fm,afm,fmEnergy,afmEnergy]=get_low_energy_orderings(obj)
            fm=[];afm=[];fmEnergy=0;afmEnergy=0;
            magMin=Inf;magMax=.001;fmMin=0;afmMin=0;
            for index=1:numel(obj.ordered_structures)
                structure=obj.ordered_structures{index};energy=obj.energies(index);
                analyzer=kssolv.analysis.matgenlab.analysis.magnetism. ...
                    CollinearMagneticStructureAnalyzer(structure, ...
                    "threshold",0,"make_primitive",false);
                moments=numericMoments(structure);
                if analyzer.ordering== ...
                        kssolv.analysis.matgenlab.analysis.magnetism. ...
                        Ordering.FM&&energy<fmMin
                    fm=structure;fmEnergy=energy;fmMin=energy;
                    magMax=abs(sum(moments));
                end
                if analyzer.ordering== ...
                        kssolv.analysis.matgenlab.analysis.magnetism. ...
                        Ordering.AFM&&energy<afmMin
                    afm=structure;afmEnergy=energy;afmMin=energy;
                    magMin=abs(sum(moments));
                end
            end
            if isempty(fm)||isempty(afm)
                for index=1:numel(obj.ordered_structures)
                    structure=obj.ordered_structures{index};
                    energy=obj.energies(index);total=abs(sum(numericMoments(structure)));
                    if total>magMax
                        fm=structure;fmEnergy=energy;magMax=total;
                    end
                    if total<magMin||(total==0&&magMin==0&&energy<afmMin)
                        afm=structure;afmEnergy=energy;magMin=total;afmMin=energy;
                    end
                end
            end
            fm=kssolv.analysis.matgenlab.analysis.magnetism. ...
                CollinearMagneticStructureAnalyzer(fm,"threshold",0, ...
                "make_primitive",false). ...
                get_structure_with_only_magnetic_atoms(false);
            afm=kssolv.analysis.matgenlab.analysis.magnetism. ...
                CollinearMagneticStructureAnalyzer(afm,"threshold",0, ...
                "make_primitive",false). ...
                get_structure_with_only_magnetic_atoms(false);
        end
        function average=estimate_exchange(obj,fm,afm,fmEnergy,afmEnergy)
            if nargin<5||isempty(fm)||isempty(afm)|| ...
                    isempty(fmEnergy)||isempty(afmEnergy)
                [fm,afm,fmEnergy,afmEnergy]=obj.get_low_energy_orderings(); %#ok<ASGLU>
            end
            meanMoment=mean(abs(numericMoments(fm)));
            if meanMoment<1
                warning("KSSOLV:Matgenlab:Heisenberg:SmallMoments", ...
                    "Local magnetic moments are smaller than 1 Bohr magneton.");
            end
            average=1000*(afmEnergy-fmEnergy)/(meanMoment^2);
        end
        function temperature=get_mft_temperature(obj,jAverage)
            boltzmann=.0861733;n=numel(obj.unique_site_ids.keys());
            if n==1,temperature=2*abs(jAverage)/(3*boltzmann);return,end
            if isempty(obj.ex_params),obj.get_exchange();end
            omega=zeros(n);
            names=obj.ex_params.keys();
            for index=1:numel(names)
                name=string(names{index});
                if name=="E0"||name=="<J>",continue,end
                tokens=split(name,"-");
                if numel(tokens)<3,continue,end
                first=str2double(tokens(1))+1;second=str2double(tokens(2))+1;
                value=obj.ex_params(names{index});
                omega(first,second)=omega(first,second)+value;
                omega(second,first)=omega(second,first)+value;
            end
            temperature=max(eig(omega*2/(3*boltzmann)));
            if temperature>1500
                warning("KSSOLV:Matgenlab:Heisenberg:HighTemperature", ...
                    "Mean-field temperature exceeds the sensible range.");
            end
        end
        function graph=get_interaction_graph(obj,filename)
            if nargin<2,filename="";end
            if isempty(obj.ex_params),obj.get_exchange();end
            graph=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_empty_graph(obj.ordered_structures{1}, ...
                "edge_weight_name","exchange_constant", ...
                "edge_weight_units","meV");
            source=obj.sgraphs{1};
            for index=1:source.structure.num_sites
                connections=source.get_connected_sites(index);
                for item=1:numel(connections)
                    connected=connections{item};
                    value=obj.exchangeFor(index,connected.index,connected.dist);
                    graph.add_edge(index,connected.index, ...
                        "to_jimage",connected.jimage,"weight",value, ...
                        "warn_duplicates",false);
                end
            end
            if strlength(string(filename))>0
                filename=string(filename);
                if ~endsWith(filename,".json"),filename=filename+".json";end
                fid=fopen(filename,"w");
                if fid<0,error("KSSOLV:Matgenlab:Heisenberg:File", ...
                        "Could not open '%s'.",filename);end
                cleanup=onCleanup(@()fclose(fid));
                fwrite(fid,kssolv.analysis.matgenlab.util.encode(graph.as_dict()));
            end
        end
        function model=get_heisenberg_model(obj)
            if isempty(obj.ex_params),obj.get_exchange();end
            model=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergModel(obj.ordered_structures_{1}.reduced_formula, ...
                obj.ordered_structures,obj.energies,obj.cutoff,obj.tol, ...
                obj.sgraphs,obj.unique_site_ids,obj.wyckoff_ids, ...
                obj.nn_interactions,obj.dists,obj.ex_mat,obj.ex_params, ...
                obj.estimate_exchange(),obj.get_interaction_graph());
        end
    end
    methods (Access=private)
        function buildNeighborDictionary(obj)
            labels=["nn","nnn","nnnn"];allDistances=[];
            keys=obj.unique_site_ids.keys();
            for index=1:numel(keys)
                sites=parseGroup(keys{index});
                connected=obj.sgraphs{1}.get_connected_sites(sites(1));
                distances=unique(round(cellfun(@(item)item.dist,connected),2));
                allDistances=[allDistances,distances(1:min(3,end))]; %#ok<AGROW>
            end
            allDistances=sort(unique(allDistances));
            remove=false(size(allDistances));
            for index=1:numel(allDistances)-1
                if abs(allDistances(index)-allDistances(index+1))<obj.tol
                    remove(index+1)=true;
                end
            end
            allDistances=allDistances(~remove);
            allDistances=[allDistances,zeros(1,max(0,3-numel(allDistances)))];
            allDistances=allDistances(1:3);
            obj.dists=struct(nn=allDistances(1),nnn=allDistances(2), ...
                nnnn=allDistances(3));
            interactions=struct();
            for label=labels
                interactions.(label)=containers.Map("KeyType","double", ...
                    "ValueType","double");
            end
            for index=1:numel(keys)
                sites=parseGroup(keys{index});firstId=obj.unique_site_ids(keys{index});
                connected=obj.sgraphs{1}.get_connected_sites(sites(1));
                for item=1:numel(connected)
                    neighbor=connected{item};secondId=siteIdentifier( ...
                        obj.unique_site_ids,neighbor.index);
                    distance=round(neighbor.dist,2);
                    for label=labels
                        if abs(distance-obj.dists.(label))<=obj.tol
                            interactions.(label)(firstId)=secondId;break
                        end
                    end
                end
            end
            obj.nn_interactions=interactions;
        end
        function buildExchangeMatrix(obj)
            labels=["nn","nnn","nnnn"];columns=["E","E0"];
            for label=labels
                map=obj.nn_interactions.(label);keys=map.keys();
                for index=1:numel(keys)
                    first=keys{index};second=map(first);
                    forward=string(first)+"-"+string(second)+"-"+label;
                    reverse=string(second)+"-"+string(first)+"-"+label;
                    if ~any(columns==forward)&&~any(columns==reverse)
                        columns(end+1)=forward; %#ok<AGROW>
                    end
                end
            end
            columns=columns(1:min(numel(columns),numel(obj.sgraphs)+1));
            jColumns=columns(~ismember(columns,["E","E0"]));
            if numel(jColumns)<2
                obj.ex_mat=array2table(zeros(0,numel(columns)), ...
                    "VariableNames",cellstr(columns));return
            end
            rows=zeros(0,numel(columns));
            order="";
            for graphIndex=1:numel(obj.sgraphs)
                graph=obj.sgraphs{graphIndex};row=zeros(1,numel(columns));
                moments=numericMoments(graph.structure);
                for site=1:graph.structure.num_sites
                    first=siteIdentifier(obj.unique_site_ids,site);
                    connected=graph.get_connected_sites(site);
                    for item=1:numel(connected)
                        neighbor=connected{item};
                        second=siteIdentifier(obj.unique_site_ids,neighbor.index);
                        candidateOrder=neighborOrder(obj,round(neighbor.dist,2));
                        % Frozen pymatgen carries the last recognized shell
                        % across borderline distances. Retaining that behavior
                        % is required for numerical compatibility of fitted J.
                        if strlength(candidateOrder)>0,order=candidateOrder;end
                        forward=string(first)+"-"+string(second)+order;
                        reverse=string(second)+"-"+string(first)+order;
                        column=find(columns==forward|columns==reverse,1);
                        if ~isempty(column)
                            row(column)=row(column)-moments(site)* ...
                                moments(neighbor.index);
                        end
                    end
                end
                jIndices=find(ismember(columns,jColumns));
                if isempty(rows)||~ismember(row(jIndices),rows(:,jIndices),"rows")
                    row(columns=="E")=obj.energies(graphIndex);rows(end+1,:)=row; %#ok<AGROW>
                end
            end
            rows(:,ismember(columns,jColumns))= ...
                rows(:,ismember(columns,jColumns))/2;
            rows(:,columns=="E0")=1;
            zeroColumns=all(rows==0,1);
            firstZero=find(zeroColumns,1);
            if ~isempty(firstZero)
                rows(:,firstZero)=[];columns(firstZero)=[];
            end
            count=min(size(rows,1),numel(columns)-1);
            rows=rows(1:count,:);
            obj.ex_mat=array2table(rows,"VariableNames",cellstr(columns));
        end
        function value=exchangeFor(obj,first,second,distance)
            first=siteIdentifier(obj.unique_site_ids,first);
            second=siteIdentifier(obj.unique_site_ids,second);
            order=neighborOrder(obj,distance);
            forward=char(string(first)+"-"+string(second)+order);
            reverse=char(string(second)+"-"+string(first)+order);
            value=0;
            if isKey(obj.ex_params,forward),value=obj.ex_params(forward);
            elseif isKey(obj.ex_params,reverse),value=obj.ex_params(reverse);end
            if isKey(obj.ex_params,"<J>")&&order=="-nn"
                value=obj.ex_params("<J>");
            end
        end
    end
end

function [ids,wyckoff]=uniqueSites(structure)
plain=kssolv.analysis.matgenlab.analysis.magnetism. ...
    CollinearMagneticStructureAnalyzer(structure,"make_primitive",false, ...
    "threshold",0).get_nonmagnetic_structure(false);
if isfield(plain.site_properties,"wyckoff")
    plain=plain.remove_site_property("wyckoff");
end
symm=kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(plain).get_symmetrized_structure();
ids=containers.Map("KeyType","char","ValueType","double");
wyckoff=containers.Map("KeyType","double","ValueType","char");
for index=1:numel(symm.equivalent_indices)
    key=join(string(symm.equivalent_indices{index}),",");
    ids(char(key))=index-1;wyckoff(index-1)=char(symm.wyckoff_symbols(index));
end
end
function sites=parseGroup(key),sites=str2double(split(string(key),",")).';end
function value=siteIdentifier(map,index)
names=map.keys();
for item=1:numel(names)
    if any(parseGroup(names{item})==index),value=map(names{item});return,end
end
error("KSSOLV:Matgenlab:Heisenberg:Site","Site has no symmetry identifier.");
end
function moments=numericMoments(structure)
raw=structure.site_properties.magmom;
if iscell(raw),moments=cellfun(@double,raw);
else,moments=reshape(double(raw),1,[]);end
end
function order=neighborOrder(obj,distance)
order="";
if abs(distance-obj.dists.nn)<=obj.tol,order="-nn";
elseif abs(distance-obj.dists.nnn)<=obj.tol,order="-nnn";
elseif abs(distance-obj.dists.nnnn)<=obj.tol,order="-nnnn";end
end
