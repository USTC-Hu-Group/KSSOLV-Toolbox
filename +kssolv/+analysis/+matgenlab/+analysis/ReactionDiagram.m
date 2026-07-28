classdef ReactionDiagram < handle
    %#ok<*ALIGN,*AGROW,*MSNU>
    %REACTIONDIAGRAM Analyze reactions along a two-compound tie line.
    properties
        entry1
        entry2
        rxn_entries cell=cell(1,0)
        labels cell=cell(0,2)
        all_entries cell=cell(1,0)
        pd
        tolerance (1,1) double=1e-4
        float_format (1,1) string="%.4f"
    end
    methods
        function obj=ReactionDiagram(entry1,entry2,allEntries,varargin)
            options=struct(tol=1e-4,float_fmt="%.4f");options=parseOptions(options,varargin);
            if ~iscell(allEntries),allEntries=num2cell(allEntries);end
            obj.entry1=entry1;obj.entry2=entry2;obj.all_entries=allEntries;
            obj.tolerance=options.tol;obj.float_format=string(options.float_fmt);
            symbols=union(entry1.composition.chemical_system_set, ...
                entry2.composition.chemical_system_set,"stable");
            vector1=atomicVector(entry1.composition,symbols);
            vector2=atomicVector(entry2.composition,symbols);
            reduced1=entry1.composition.reduced_composition;
            reduced2=entry2.composition.reduced_composition;
            obj.pd=kssolv.analysis.matgenlab.analysis.PhaseDiagram( ...
                [allEntries,{entry1,entry2}]);
            terminals=[entry1.reduced_formula,entry2.reduced_formula];
            done=zeros(0,2);reactions={};
            for facet=obj.pd.facets
                if numel(facet{1})<2,continue,end
                faces=nchoosek(facet{1},numel(facet{1})-1);
                for row=1:size(faces,1)
                    faceEntries=obj.pd.qhull_entries(faces(row,:));
                    if any(ismember(cellfun(@(x)x.reduced_formula,faceEntries),terminals)),continue,end
                    matrix=zeros(numel(symbols),numel(faceEntries)+1);
                    for ii=1:numel(faceEntries)
                        matrix(:,ii)=atomicVector(faceEntries{ii}.composition,symbols);
                    end
                    matrix(:,end)=vector2-vector1;
                    if size(matrix,1)~=size(matrix,2)||rcond(matrix)<1e-12,continue,end
                    coefficients=matrix\vector2;x=coefficients(end);
                    if any(coefficients < -obj.tolerance)|| ...
                            abs(sum(coefficients(1:end-1))-1)>obj.tolerance|| ...
                            x<=obj.tolerance||x>=1-obj.tolerance,continue,end
                    c1=x/reduced1.num_atoms;c2=(1-x)/reduced2.num_atoms;
                    factor=1/(c1+c2);c1=c1*factor;c2=c2*factor;
                    if any(all(abs(done-[c1,c2])<1e-8,2)),continue,end
                    done(end+1,:)=[c1,c2]; %#ok<AGROW>
                    energy=-(x*entry1.energy_per_atom+(1-x)*entry2.energy_per_atom);
                    products=strings(1,0);decomposition=cell(0,2);
                    for ii=1:numel(faceEntries)
                        coefficient=coefficients(ii);
                        if coefficient<=obj.tolerance,continue,end
                        reduced=faceEntries{ii}.composition.reduced_composition;
                        products(end+1)=sprintf(obj.float_format, ...
                            coefficient/reduced.num_atoms*factor)+" "+reduced.reduced_formula; %#ok<AGROW>
                        decomposition(end+1,:)={faceEntries{ii},coefficient}; %#ok<AGROW>
                        energy=energy+coefficient*faceEntries{ii}.energy_per_atom;
                    end
                    reactionString=sprintf(obj.float_format,c1)+" "+reduced1.reduced_formula+ ...
                        " + "+sprintf(obj.float_format,c2)+" "+reduced2.reduced_formula+ ...
                        " -> "+strjoin(products," + ");
                    composition=(entry1.composition.fractional_composition*x)+ ...
                        (entry2.composition.fractional_composition*(1-x));
                    reactionEntry=kssolv.analysis.matgenlab.analysis.PDEntry( ...
                        composition,energy,"attribute",reactionString);
                    reactionEntry.decomposition=decomposition;
                    reactions{end+1}=reactionEntry; %#ok<AGROW>
                end
            end
            if ~isempty(reactions)
                [~,order]=sort(cellfun(@(x)x.name,reactions),"descend");reactions=reactions(order);
            end
            obj.labels=cell(numel(reactions),2);
            for ii=1:numel(reactions)
                reactions{ii}.name=string(ii);
                obj.labels(ii,:)={string(ii),reactions{ii}.attribute};
            end
            obj.rxn_entries=reactions;
        end
        function value=get_compound_pd(obj)
            first=kssolv.analysis.matgenlab.analysis.PDEntry(obj.entry1.composition,0);
            second=kssolv.analysis.matgenlab.analysis.PDEntry(obj.entry2.composition,0);
            value=kssolv.analysis.matgenlab.analysis.CompoundPhaseDiagram( ...
                [obj.rxn_entries,{first,second}], ...
                {first.composition.reduced_composition,second.composition.reduced_composition},false);
        end
    end
end

function value=atomicVector(composition,symbols)
value=zeros(numel(symbols),1);
for ii=1:numel(symbols),value(ii)=composition.get_atomic_fraction(symbols(ii));end
end
function output=parseOptions(output,input)
names=fieldnames(output);position=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&&any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{position})=input{ii};position=position+1;ii=ii+1;end
end
end
