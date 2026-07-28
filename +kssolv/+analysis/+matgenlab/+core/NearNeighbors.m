classdef NearNeighbors
    %#ok<*ALIGN,*AGROW>
    %NEARNEIGHBORS Base interface and shared operations for neighbor strategies.
    properties
        structures_allowed (1,1) logical=false
        molecules_allowed (1,1) logical=false
        extend_structure_molecules (1,1) logical=false
    end
    methods
        function value=get_cn(obj,structure,n,varargin)
            options=struct(use_weights=false,on_disorder="take_majority_strict");
            options=parseOptions(options,varargin);
            structure=obj.handleDisorder(structure,options.on_disorder);
            info=obj.get_nn_info(structure,n);
            if options.use_weights
                value=sum(cellfun(@(item)item.weight,info));
            else,value=numel(info);end
        end
        function value=get_cn_dict(obj,structure,n,varargin)
            options=struct(use_weights=false);options=parseOptions(options,varargin);
            info=obj.get_nn_info(structure,n);value=struct();
            for ii=1:numel(info)
                key=matlab.lang.makeValidName(char(info{ii}.site.species_string));
                amount=1;if options.use_weights,amount=info{ii}.weight;end
                if isfield(value,key),value.(key)=value.(key)+amount;
                else,value.(key)=amount;end
            end
        end
        function value=get_nn(obj,structure,n)
            value=cellfun(@(item)item.site,obj.get_nn_info(structure,n), ...
                "UniformOutput",false);
        end
        function value=get_weights_of_nn_sites(obj,structure,n)
            value=cellfun(@(item)item.weight,obj.get_nn_info(structure,n));
        end
        function value=get_nn_images(obj,structure,n)
            info=obj.get_nn_info(structure,n);
            value=cellfun(@(item)item.image,info,"UniformOutput",false);
        end
        function value=get_nn_info(~,~,~) %#ok<STOUT>
            error("KSSOLV:Matgenlab:NearNeighbors:Abstract", ...
                "get_nn_info must be implemented by a neighbor strategy.");
        end
        function value=get_all_nn_info(obj,structure)
            value=cell(1,structure.num_sites);
            for ii=1:structure.num_sites,value{ii}=obj.get_nn_info(structure,ii);end
        end
        function value=get_nn_shell_info(obj,structure,site_idx,shell)
            if shell<1||shell~=fix(shell)
                error("KSSOLV:Matgenlab:NearNeighbors:Shell", ...
                    "Shell must be a positive integer.");
            end
            allInfo=obj.get_all_nn_info(structure);
            value=obj.shell(allInfo,site_idx,shell,zeros(0,4),[0,0,0]);
            for ii=1:numel(value)
                original=structure(value{ii}.site_index);
                if isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
                    value{ii}.site=kssolv.analysis.matgenlab.core.PeriodicSite( ...
                        original.species,original.frac_coords+value{ii}.image, ...
                        structure.lattice,properties=original.site_properties, ...
                        label=original.label);
                else
                    value{ii}.site=kssolv.analysis.matgenlab.core.Site( ...
                        original.species,original.coords, ...
                        properties=original.site_properties,label=original.label);
                end
            end
        end
        function value=get_bonded_structure(obj,structure,varargin)
            options=struct(decorate=false,weights=true,edge_properties=false, ...
                on_disorder="take_majority_strict");
            options=parseOptions(options,varargin);
            if isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
                structure=obj.handleDisorder(structure,options.on_disorder);
                value=kssolv.analysis.matgenlab.core.StructureGraph. ...
                    from_local_env_strategy(structure,obj, ...
                    "weights",options.weights, ...
                    "edge_properties",options.edge_properties);
                if options.decorate
                    order=cell(1,structure.num_sites);
                    for ii=1:structure.num_sites
                        order{ii}=obj.get_local_order_parameters(structure,ii);
                    end
                    value.structure=value.structure.add_site_property( ...
                        "order_parameters",order);
                    value.set_node_attributes();
                end
            else
                value=kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                    from_local_env_strategy(structure,obj);
                if options.decorate
                    order=cell(1,structure.num_sites);
                    for ii=1:structure.num_sites
                        order{ii}=obj.get_local_order_parameters(structure,ii);
                    end
                    value.molecule=value.molecule.add_site_property( ...
                        "order_parameters",order);
                    value.set_node_attributes();
                end
            end
        end
        function value=get_local_order_parameters(obj,structure,n)
            cn=obj.get_cn(structure,n);
            [names,types,parameters]=coordinationParameters(round(cn));
            if isempty(names),value=struct();return,end
            op=kssolv.analysis.matgenlab.core.LocalStructOrderParams( ...
                types,"parameters",parameters);
            localSites=[{structure(n)},obj.get_nn(structure,n)];
            values=op.get_order_parameters(localSites,1, ...
                "indices_neighs",2:numel(localSites));
            value=struct();
            for ii=1:numel(types)
                value.(matlab.lang.makeValidName(names{ii}))=values(ii);
            end
        end
        function tf=eq(obj,other)
            tf=isa(other,class(obj));
            if ~tf,return,end
            first=struct(obj);second=struct(other);
            tf=isequaln(first,second);
        end
        function tf=ne(obj,other),tf=~eq(obj,other);end
        function text=char(obj)
            parts=split(string(class(obj)),".");text=char(parts(end)+"()");
        end
    end
    methods (Access=protected)
        function info=makeInfo(~,neighbor,weight)
            image=[0,0,0];index=neighbor.index;
            if isa(neighbor,"kssolv.analysis.matgenlab.core.PeriodicNeighbor")
                image=neighbor.image;
            end
            info=struct(site=neighbor,image=image,weight=double(weight), ...
                site_index=index);
        end
        function value=shell(obj,allInfo,index,shell,previous,currentImage)
            marker=[index,currentImage];
            previous=[previous;marker];
            possible=allInfo{index};allowed={};
            for ii=1:numel(possible)
                step=possible{ii};step.image=step.image+currentImage;
                if ~ismember([step.site_index,step.image],previous,"rows")
                    allowed{end+1}=step;
                end
            end
            if shell==1,value=allowed;return,end
            value={};
            for ii=1:numel(allowed)
                terminal=obj.shell(allInfo,allowed{ii}.site_index,shell-1, ...
                    previous,allowed{ii}.image);
                for jj=1:numel(terminal)
                    terminal{jj}.weight=terminal{jj}.weight*allowed{ii}.weight;
                    key=[terminal{jj}.site_index,terminal{jj}.image];
                    match=find(cellfun(@(item)isequal( ...
                        [item.site_index,item.image],key),value),1);
                    if isempty(match)
                        value{end+1}=terminal{jj};
                    else
                        value{match}.weight=value{match}.weight+terminal{jj}.weight;
                    end
                end
            end
        end
        function structure=handleDisorder(~,structure,mode)
            if structure.is_ordered,return,end
            mode=string(mode);
            if mode=="error"
                error("KSSOLV:Matgenlab:NearNeighbors:Disordered", ...
                    "Disordered structures are unsupported with on_disorder='error'.");
            end
            if ~startsWith(mode,"take_")
                error("KSSOLV:Matgenlab:NearNeighbors:DisorderMode", ...
                    "Unexpected on_disorder option '%s'.",mode);
            end
            drop=[];
            for ii=1:structure.num_sites
                site=structure(ii);[species,amounts]=site.species.items();
                [maximum,which]=max(amounts);
                if maximum<=.5&&mode=="take_majority_strict"
                    error("KSSOLV:Matgenlab:NearNeighbors:NoMajority", ...
                        "Site %d has no majority species.",ii);
                elseif maximum<=.5&&mode=="take_majority_drop"
                    drop(end+1)=ii;
                else
                    structure=structure.replace(ii,species{which});
                end
            end
            if ~isempty(drop),structure=structure.remove_sites(drop);end
        end
    end
end

function [names,types,parameters]=coordinationParameters(cn)
names={};types={};parameters={};
switch cn
    case 2
        names={"L-shaped","water-like","bent 120 degrees", ...
            "bent 150 degrees","linear"};
        types=repmat({"bent"},1,5);
        targets=[.5,.5802777777777778,.666666666667,.833333333333333,1];
        widths=[15.15,13.95,13.25,12.45,8.667];
        parameters=arrayfun(@(ii)struct(TA=targets(ii),IGW_TA=widths(ii)), ...
            1:5,"UniformOutput",false);
    case 3
        names={"trigonal planar","trigonal non-coplanar","T-shaped"};
        types={"tri_plan_max","tet_max","T"};
        parameters={[],struct(TA=.6081734479693927,IGW_TA=18.33, ...
            fac_AA=1.5,exp_cos_AA=2),[]};
    case 4
        names={"square co-planar","tetrahedral", ...
            "rectangular see-saw-like","see-saw-like","trigonal pyramidal"};
        types={"sq_plan_max","tet_max","see_saw_rect","tri_bipyr","tri_pyr"};
        parameters={[],[],[],struct(min_SPP=2.356194490192345, ...
            IGW_EP=15.75,IGW_SPP=12.75,fac_AA=1.5, ...
            exp_cos_AA=2,w_SPP=1),[]};
    case 5
        names={"pentagonal planar","square pyramidal","trigonal bipyramidal"};
        types={"pent_plan_max","sq_pyr","tri_bipyr"};parameters={[],[],[]};
    case 6
        names={"hexagonal planar","octahedral","pentagonal pyramidal"};
        types={"hex_plan_max","oct_max","pent_pyr"};parameters={[],[],[]};
    case 7
        names={"hexagonal pyramidal","pentagonal bipyramidal"};
        types={"hex_pyr","pent_bipyr"};parameters={[],[]};
    case 8
        names={"body-centered cubic","hexagonal bipyramidal"};
        types={"bcc","hex_bipyr"};parameters={[],[]};
    case 12
        names={"cuboctahedral"};types={"cuboct_max"};parameters={[]};
end
end

function output=parseOptions(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else
        output.(names{pos})=input{ii};ii=ii+1;pos=pos+1;
    end
end
end
