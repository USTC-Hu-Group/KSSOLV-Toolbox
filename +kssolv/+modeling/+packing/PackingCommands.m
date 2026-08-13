classdef PackingCommands
    %PACKINGCOMMANDS Command adapters for amorphous/confinement construction.
    methods (Static)
        function ids=commandIds()
            ids=["construct_amorphous";"pack_mixture";"build_confined_layer"; ...
                "pack_into_existing_box";"pack_around_nanoparticle"];
        end
        function value=supports(id)
            value=any(kssolv.modeling.packing.PackingCommands.commandIds()==string(id));
        end
        function result=execute(model,id,p)
            import kssolv.modeling.ParameterUtils
            intoExisting=any(string(id)==[ ...
                "pack_into_existing_box","pack_around_nanoparticle"]);
            if intoExisting
                components=ParameterUtils.get(p,"components",cell(1,0));
            else
                components=ParameterUtils.get(p,"components",{model});
            end
            if isfield(p,"otherComponents") && intoExisting
                components=p.otherComponents;
                if ~iscell(components), components={components}; end
            elseif isfield(p,"otherComponents")
                extra=p.otherComponents;
                if ~iscell(extra), extra={extra}; end
                components=[{model},extra];
            end
            rawCounts=double(ParameterUtils.get(p,"counts", ...
                ParameterUtils.get(p,"compositionValues", ...
                ParameterUtils.get(p,"moleculeCount",20))));
            mode=string(ParameterUtils.get(p,"compositionMode","count"));
            total=double(ParameterUtils.get(p,"totalMolecules",sum(rawCounts)));
            counts=kssolv.modeling.packing.CompositionCalculator.counts( ...
                components,rawCounts,mode,total);
            density=double(ParameterUtils.get(p,"density",1));
            seed=double(ParameterUtils.get(p,"seed",1));
            tolerance=double(ParameterUtils.get(p,"tolerance",1.2));
            atomLimit=double(ParameterUtils.get(p,"atomLimit",100000));
            arguments=struct("density",density,"seed",seed, ...
                "tolerance",tolerance,"atomLimit",atomLimit);
            arguments.batchSize=double(ParameterUtils.get(p,"batchSize",100));
            arguments.densityRamp=double(ParameterUtils.get( ...
                p,"densityRamp",zeros(1,0)));
            if isfield(p,"cancelFcn"), arguments.cancelFcn=p.cancelFcn; end
            if isfield(p,"progressFcn"), arguments.progressFcn=p.progressFcn; end
            if string(id)=="build_confined_layer"
                arguments.axis=double(ParameterUtils.get(p, ...
                    "confinementAxis",ParameterUtils.get(p,"axis",3)));
                arguments.region=double(ParameterUtils.get(p,"region",[]));
            end
            if intoExisting
                arguments=rmfield(arguments,"density");
                if string(id)=="pack_around_nanoparticle"
                    center=mean(model.cart_coords,1);
                    clearance=double(ParameterUtils.get(p,"clearance",1.2));
                    radius=max(vecnorm(model.cart_coords-center,2,2))+clearance;
                    arguments.exclusionCenter=center;
                    arguments.exclusionRadius=radius;
                end
            end
            names=fieldnames(arguments); pairs=cell(1,2*numel(names));
            for index=1:numel(names)
                pairs{2*index-1}=names{index}; pairs{2*index}=arguments.(names{index});
            end
            if intoExisting
                [packed,info]=kssolv.modeling.packing.PackingBuilder.packInto( ...
                    model,components,counts,pairs{:});
            else
                [packed,info]=kssolv.modeling.packing.PackingBuilder.pack( ...
                    components,counts,pairs{:});
            end
            result=struct("model",packed,"changed",true, ...
                "message","Molecules packed (not equilibrated).","analysis",info);
        end
    end
end
