classdef SlabEntry < kssolv.analysis.matgenlab.core.ComputedStructureEntry
    %SLABENTRY Computed slab plus surface-thermodynamics metadata.
    properties
        miller_index (1,3) double = [0,0,1]
        label = []
        adsorbates cell = cell(1,0)
        clean_entry = []
        ads_entries_dict (1,1) struct = struct()
        mark = []
        color = []
    end
    properties (Dependent,SetAccess=private)
        get_unit_primitive_area
        get_monolayer
        Nads_in_slab
        Nsurfs_ads_in_slab
        surface_area
        cleaned_up_slab
        create_slab_label
    end
    methods
        function obj=SlabEntry(structure,energy,millerIndex,varargin)
            if nargin==0
                structure=kssolv.analysis.matgenlab.core.Structure( ...
                    eye(3),{"H"},[0,0,0]);
                energy=0;millerIndex=[0,0,1];emptyConstruction=true;
            else
                emptyConstruction=false;
            end
            options=struct(correction=0,parameters=struct(),data=struct(), ...
                entry_id=[],label=[],adsorbates={{}},clean_entry=[], ...
                marker=[],color=[]);
            options=parseOptions(options,varargin{:});
            obj@kssolv.analysis.matgenlab.core.ComputedStructureEntry( ...
                structure,energy,"correction",options.correction, ...
                "parameters",options.parameters,"data",options.data, ...
                "entry_id",options.entry_id);
            if emptyConstruction,return,end
            obj.miller_index=reshape(double(millerIndex),1,3);
            obj.label=options.label;obj.clean_entry=options.clean_entry;
            if isempty(options.adsorbates)
                obj.adsorbates={};
            elseif iscell(options.adsorbates)
                obj.adsorbates=reshape(options.adsorbates,1,[]);
            else
                obj.adsorbates=num2cell(options.adsorbates);
            end
            obj.mark=options.marker;obj.color=options.color;
            refs=struct();
            for index=1:numel(obj.adsorbates)
                [species,~]=obj.adsorbates{index}.composition.items();
                refs.(char(species{1}.symbol))=obj.adsorbates{index};
            end
            obj.ads_entries_dict=refs;
        end
        function data=as_dict(obj)
            data=as_dict@kssolv.analysis.matgenlab.core.ComputedStructureEntry(obj);
            data.x_module="pymatgen.analysis.surface_analysis";
            data.x_class="SlabEntry";data.miller_index=obj.miller_index;
            data.label=obj.label;
            data.adsorbates=cellfun(@(x)x.as_dict(),obj.adsorbates, ...
                "UniformOutput",false);
            if isempty(obj.clean_entry),data.clean_entry=[];
            else,data.clean_entry=obj.clean_entry.as_dict();end
        end
        function value=gibbs_binding_energy(obj,eads)
            if nargin<2,eads=false;end
            nAds=obj.Nads_in_slab;
            if isempty(obj.clean_entry)||nAds==0
                error("KSSOLV:Matgenlab:SlabEntry:Adsorbate", ...
                    "A clean entry and at least one adsorbate are required.");
            end
            reference=0;
            for index=1:numel(obj.adsorbates)
                reference=reference+obj.adsorbates{index}.energy_per_atom;
            end
            value=(obj.energy-obj.get_unit_primitive_area* ...
                obj.clean_entry.energy)/nAds-reference;
            if eads,value=value*nAds;end
        end
        function value=surface_energy(obj,ucellEntry,refEntries)
            if nargin<3||isempty(refEntries),refEntries={};end
            if ~iscell(refEntries),refEntries=num2cell(refEntries);end
            references=refEntries;
            for index=1:numel(obj.adsorbates)
                references{end+1}=obj.adsorbates{index}; %#ok<AGROW>
            end
            referenceStruct=struct();
            for index=1:numel(references)
                [species,~]=references{index}.composition.items();
                referenceStruct.(char(species{1}.symbol))=references{index};
            end
            bulkReduced=ucellEntry.composition.reduced_composition;
            [bulkSpecies,bulkAmounts]=bulkReduced.items();
            [~,formulaFactor]=ucellEntry.composition. ...
                get_integer_formula_and_factor();
            gibbsBulk=ucellEntry.energy/formulaFactor;
            constantBulkEq=0;coefficientBulkEq=struct();
            for index=1:numel(bulkSpecies)
                symbol=char(bulkSpecies{index}.symbol);
                if isfield(referenceStruct,symbol)
                    constantBulkEq=constantBulkEq+bulkAmounts(index)* ...
                        referenceStruct.(symbol).energy_per_atom;
                    coefficientBulkEq.("delu_"+string(symbol))=bulkAmounts(index);
                end
            end
            dependent="";
            for index=1:numel(bulkSpecies)
                symbol=string(bulkSpecies{index}.symbol);
                if ~isfield(referenceStruct,char(symbol)),dependent=symbol;break,end
            end
            if dependent==""
                dependent=string(bulkSpecies{end}.symbol);
                if isfield(coefficientBulkEq,"delu_"+dependent)
                    coefficientBulkEq=rmfield(coefficientBulkEq,"delu_"+dependent);
                    constantBulkEq=constantBulkEq-bulkReduced(dependent)* ...
                        referenceStruct.(char(dependent)).energy_per_atom;
                end
            end
            depAmount=bulkReduced(dependent);
            depMuConstant=(gibbsBulk-constantBulkEq)/depAmount;
            slabComp=obj.composition;
            bulkEnergyConstant=slabComp(dependent)*depMuConstant;
            bulkCoefficients=struct();
            refNames=fieldnames(referenceStruct);
            for index=1:numel(refNames)
                symbol=refNames{index};
                count=slabComp(symbol);
                bulkEnergyConstant=bulkEnergyConstant+count* ...
                    referenceStruct.(symbol).energy_per_atom;
                name="delu_"+string(symbol);
                bulkCoefficients.(name)=count;
                if isfield(coefficientBulkEq,name)
                    bulkCoefficients.(name)=bulkCoefficients.(name)- ...
                        slabComp(dependent)*coefficientBulkEq.(name)/depAmount;
                end
            end
            scale=2*obj.surface_area;
            constant=(obj.energy-bulkEnergyConstant)/scale;
            names=fieldnames(bulkCoefficients);coefficients=struct();
            for index=1:numel(names)
                coefficient=-bulkCoefficients.(names{index})/scale;
                if abs(coefficient)>1e-14,coefficients.(names{index})=coefficient;end
            end
            if isempty(fieldnames(coefficients)),value=constant;
            else
                value=kssolv.analysis.matgenlab.analysis. ...
                    SurfaceEnergyExpression(constant,coefficients);
            end
        end
        function value=get.get_unit_primitive_area(obj)
            value=obj.surface_area/obj.clean_entry.surface_area;
        end
        function value=get.get_monolayer(obj)
            value=obj.Nads_in_slab/(obj.get_unit_primitive_area* ...
                obj.Nsurfs_ads_in_slab);
        end
        function value=get.Nads_in_slab(obj)
            value=0;names=fieldnames(obj.ads_entries_dict);
            for index=1:numel(names),value=value+obj.composition(names{index});end
        end
        function value=get.Nsurfs_ads_in_slab(obj)
            sites=obj.structure.sites;weights=zeros(numel(sites),1);
            coordinates=obj.structure.frac_coords;
            for index=1:numel(sites),weights(index)=sites{index}.species.weight;end
            center=sum(coordinates.*weights,1)/sum(weights);
            top=false;bottom=false;names=string(fieldnames(obj.ads_entries_dict));
            for index=1:numel(sites)
                if any(names==string(sites{index}.species_string))
                    top=top||coordinates(index,3)>center(3);
                    bottom=bottom||coordinates(index,3)<center(3);
                end
            end
            value=double(top)+double(bottom);
        end
        function value=get.surface_area(obj)
            matrix=obj.structure.lattice.matrix;
            value=norm(cross(matrix(1,:),matrix(2,:)));
        end
        function value=get.cleaned_up_slab(obj)
            value=obj.structure.copy();
            value=value.remove_species(string(fieldnames(obj.ads_entries_dict)));
        end
        function value=get.create_slab_label(obj)
            if isfield(obj.data,"label"),value=string(obj.data.label);return,end
            value=sprintf("(%d, %d, %d) %s",obj.miller_index, ...
                string(obj.cleaned_up_slab.composition.reduced_composition));
            names=string(fieldnames(obj.ads_entries_dict));
            for index=1:numel(names),value=value+"+"+names(index);end
            if ~isempty(names),value=value+sprintf(", %.3f ML",obj.get_monolayer);end
        end
    end
    methods (Static)
        function obj=from_dict(data)
            structure=data.structure;
            if ~isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
                structure=kssolv.analysis.matgenlab.core.Structure.from_dict(structure);
            end
            ads={};
            if isfield(data,"adsorbates")&&~isempty(data.adsorbates)
                raw=data.adsorbates;if ~iscell(raw),raw=num2cell(raw);end
                ads=cellfun(@(x)decodeEntry(x),raw,"UniformOutput",false);
            end
            clean=[];
            if isfield(data,"clean_entry")&&~isempty(data.clean_entry)
                clean=kssolv.analysis.matgenlab.analysis.SlabEntry. ...
                    from_dict(data.clean_entry);
            end
            obj=kssolv.analysis.matgenlab.analysis.SlabEntry( ...
                structure,data.energy,data.miller_index, ...
                "label",fieldOr(data,"label",[]),"adsorbates",ads, ...
                "clean_entry",clean,"correction",fieldOr(data,"correction",0), ...
                "parameters",fieldOr(data,"parameters",struct()), ...
                "data",fieldOr(data,"data",struct()), ...
                "entry_id",fieldOr(data,"entry_id",[]));
        end
        function obj=from_computed_structure_entry(entry,millerIndex,varargin)
            obj=kssolv.analysis.matgenlab.analysis.SlabEntry( ...
                entry.structure,entry.energy,millerIndex,varargin{:});
        end
    end
end
function options=parseOptions(options,varargin)
names=fieldnames(options);
for index=1:2:numel(varargin)
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
function value=fieldOr(data,name,default)
if isfield(data,name),value=data.(name);else,value=default;end
end
function value=decodeEntry(data)
if isa(data,"kssolv.analysis.matgenlab.core.ComputedStructureEntry"),value=data;
else,value=kssolv.analysis.matgenlab.core.ComputedStructureEntry.from_dict(data);end
end
