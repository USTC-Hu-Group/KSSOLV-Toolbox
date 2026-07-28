classdef JahnTellerAnalyzer
    %JAHNTELLERANALYZER Heuristic Jahn-Teller activity analysis.
    %#ok<*AGROW,*NOCOMMA,*ALIGN>
    methods
        function [analysis,structure]=get_analysis_and_structure(~,structure,varargin)
            defaults=struct(calculate_valences=true,guesstimate_spin=false, ...
                op_threshold=.1);
            options=kssolv.analysis.matgenlab.analysis.magnetism.internal. ...
                options(defaults,varargin);
            primitive=structure.get_primitive_structure();
            if primitive.num_sites<structure.num_sites,structure=primitive;end
            if options.calculate_valences
                analyzer=kssolv.analysis.matgenlab.core.BVAnalyzer();
                structure=analyzer.get_oxi_state_decorated_structure(structure);
            end
            symmetry=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(structure).get_symmetrized_structure();
            local=kssolv.analysis.matgenlab.core.LocalStructOrderParams( ...
                ["oct","tet"]);
            activeSites={};inactiveSites={};
            for group=1:numel(symmetry.equivalent_indices)
                indices=symmetry.equivalent_indices{group};index=indices(1);
                site=symmetry(index);specie=site.specie;
                if ~isa(specie,"kssolv.analysis.matgenlab.core.Species")|| ...
                        ~specie.is_transition_metal,continue,end
                orderParameters=local.get_order_parameters(symmetry,index);
                if orderParameters(1)>orderParameters(2)&& ...
                        orderParameters(1)>options.op_threshold
                    motif="oct";motifValue=orderParameters(1);
                elseif orderParameters(2)>options.op_threshold
                    motif="tet";motifValue=orderParameters(2);
                else
                    motif="unknown";motifValue=NaN;
                end
                if motif~="oct"&&motif~="tet"
                    inactiveSites{end+1}=struct(site_indices=indices, ... %#ok<AGROW>
                        strength="none",reason="motif='unknown'");
                    continue
                end
                spinState="unknown";
                if options.guesstimate_spin&& ...
                        isfield(site.site_properties,"magmom")
                    spinState=estimateSpin(specie,motif, ...
                        site.site_properties.magmom);
                end
                magnitude=kssolv.analysis.matgenlab.analysis.magnetism. ...
                    JahnTellerAnalyzer.get_magnitude_of_effect_from_species( ...
                    specie,spinState,motif);
                if magnitude=="none"
                    inactiveSites{end+1}=struct(site_indices=indices, ... %#ok<AGROW>
                        strength="none",reason= ...
                        "Not Jahn-Teller active for this electronic configuration.");
                    continue
                end
                ligands=kssolv.analysis.matgenlab.core. ...
                    get_neighbors_of_site_with_index(structure,index, ...
                    "approach","min_dist","delta",.15);
                lengths=cellfun(@(ligand)ligand.distance(structure(index)), ...
                    ligands);
                ligandSpecies=unique(string(cellfun(@(ligand) ...
                    string(ligand.specie),ligands,"UniformOutput",false)));
                if numel(ligandSpecies)~=1,continue,end
                trim=@(value)round(double(value),4);
                activeSites{end+1}=struct( ... %#ok<AGROW>
                    strength=magnitude,motif=motif, ...
                    motif_order_parameter=trim(motifValue), ...
                    spin_state=spinState,species=string(specie), ...
                    ligand=ligandSpecies(1), ...
                    ligand_bond_lengths=trim(lengths), ...
                    ligand_bond_length_spread=trim(max(lengths)-min(lengths)), ...
                    site_indices=indices);
            end
            if isempty(activeSites)
                analysis=struct(active=false,sites={inactiveSites});
            else
                strengths=string(cellfun(@(entry)entry.strength,activeSites, ...
                    "UniformOutput",false));
                strength="weak";if any(strengths=="strong"),strength="strong";end
                analysis=struct(active=true,strength=strength,sites={activeSites});
            end
        end
        function analysis=get_analysis(obj,structure,varargin)
            [analysis,~]=obj.get_analysis_and_structure(structure,varargin{:});
        end
        function active=is_jahn_teller_active(obj,structure,varargin)
            active=false;
            try,analysis=obj.get_analysis(structure,varargin{:});active=analysis.active;
            catch exception
                warning("KSSOLV:Matgenlab:JahnTeller:Analysis", ...
                    "Error analyzing %s: %s",structure.reduced_formula, ...
                    exception.message);
            end
        end
        function structure=tag_structure(obj,structure,varargin)
            try
                [analysis,structure]=obj.get_analysis_and_structure( ...
                    structure,varargin{:});
                flags=false(1,structure.num_sites);
                if analysis.active
                    for item=1:numel(analysis.sites)
                        flags(analysis.sites{item}.site_indices)=true;
                    end
                end
                structure=structure.add_site_property("possible_jt_active",flags);
            catch exception
                warning("KSSOLV:Matgenlab:JahnTeller:Analysis", ...
                    "Error analyzing %s: %s",structure.reduced_formula, ...
                    exception.message);
            end
        end
    end
    methods (Static)
        function magnitude=get_magnitude_of_effect_from_species( ...
                species,spinState,motif)
            magnitude="none";motif=string(motif);spinState=string(spinState);
            try,species=kssolv.analysis.matgenlab.core.get_el_sp(species);
            catch,return,end
            if ~isa(species,"kssolv.analysis.matgenlab.core.Species")|| ...
                    ~species.is_transition_metal,return,end
            d=dElectrons(species);
            [config,defaultState]=configuration(motif,d,spinState);
            if isempty(config),return,end
            if spinState==""||spinState=="unknown"|| ...
                    ~any(spinState==["high","low"])
                [config,~]=configuration(motif,d,defaultState);
            end
            magnitude=kssolv.analysis.matgenlab.analysis.magnetism. ...
                JahnTellerAnalyzer.get_magnitude_of_effect_from_spin_config( ...
                motif,config);
        end
        function magnitude=get_magnitude_of_effect_from_spin_config( ...
                motif,spinConfig)
            motif=string(motif);magnitude="none";
            if motif=="oct"
                eg=fieldValue(spinConfig,["e_g","eg"]);
                t2g=fieldValue(spinConfig,["t_2g","t2g"]);
                if mod(eg,2)~=0||mod(t2g,3)~=0,magnitude="weak";end
                if mod(eg,2)==1,magnitude="strong";end
            elseif motif=="tet"
                e=fieldValue(spinConfig,"e");
                t2=fieldValue(spinConfig,["t_2","t2"]);
                if mod(e,3)~=0||mod(t2,2)~=0,magnitude="weak";end
            end
        end
        function value=mu_so(species,motif,spinState)
            value=[];
            try
                species=kssolv.analysis.matgenlab.core.get_el_sp(species);
                if ~isa(species,"kssolv.analysis.matgenlab.core.Species")|| ...
                        ~species.is_transition_metal,return,end
                unpaired=species.get_crystal_field_spin(motif,spinState);
                value=sqrt(unpaired*(unpaired+2));
            catch,value=[];end
        end
    end
end

function value=dElectrons(species)
config=species.element.full_electronic_structure;
if size(config,1)<2||string(config{end-1,2})~="s"|| ...
        string(config{end,2})~="d"
    error("KSSOLV:Matgenlab:JahnTeller:Element", ...
        "Invalid transition-metal electronic structure.");
end
value=config{end,3}+config{end-1,3}-species.oxi_state;
if value<0||value>10
    error("KSSOLV:Matgenlab:JahnTeller:Oxidation", ...
        "Invalid oxidation state.");
end
value=round(value);
end

function [config,defaultState]=configuration(motif,d,state)
config=[];defaultState="high";motif=string(motif);state=string(state);
if motif=="oct"
    if d==5||d==7,defaultState="low";end
    if state==""||state=="unknown",state=defaultState;end
    high=[0,0;0,1;0,2;0,3;1,3;2,3;2,4;2,5;2,6;3,6;4,6];
    low=[NaN,NaN;NaN,NaN;NaN,NaN;NaN,NaN;0,4;0,5;0,6;1,6; ...
        NaN,NaN;NaN,NaN;NaN,NaN];
    row=high(d+1,:);if state=="low",row=low(d+1,:);end
    if any(isnan(row)),return,end
    config=struct(e_g=row(1),t_2g=row(2));
elseif motif=="tet"
    rows=[0,0;1,0;2,0;2,1;2,2;2,3;3,3;4,3;4,4;4,5;4,6];
    row=rows(d+1,:);config=struct(e=row(1),t_2=row(2));
end
end

function value=fieldValue(input,names)
names=reshape(string(names),1,[]);
if isa(input,"containers.Map")
    for name=names
        if isKey(input,char(name)),value=input(char(name));return,end
    end
else
    for name=names
        field=char(name);
        if isfield(input,field),value=input.(field);return,end
    end
end
error("KSSOLV:Matgenlab:JahnTeller:SpinConfig","Missing orbital population.");
end

function state=estimateSpin(species,motif,moment)
high=kssolv.analysis.matgenlab.analysis.magnetism. ...
    JahnTellerAnalyzer.mu_so(species,motif,"high");
low=kssolv.analysis.matgenlab.analysis.magnetism. ...
    JahnTellerAnalyzer.mu_so(species,motif,"low");
if isequal(high,low),state="undefined";
elseif isempty(high),state="low";
elseif isempty(low),state="high";
else
    difference=high-low;
    if moment>high||abs(moment-high)<=difference*.25,state="high";
    elseif moment<low||abs(moment-low)<=difference*.25,state="low";
    else,state="unknown";end
end
end
