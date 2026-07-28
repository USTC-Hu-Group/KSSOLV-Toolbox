classdef AflowPrototypeMatcher
    %AFLOWPROTOTYPEMATCHER Match structures to the frozen AFLOW library.

    properties (SetAccess=private)
        initial_ltol (1,1) double
        initial_stol (1,1) double
        initial_angle_tol (1,1) double
    end

    properties (Access=private)
        library cell
    end

    methods
        function obj=AflowPrototypeMatcher(varargin)
            options=struct("initial_ltol",0.2,"initial_stol",0.3, ...
                "initial_angle_tol",5);
            options=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
                options(options,varargin);
            obj.initial_ltol=double(options.initial_ltol);
            obj.initial_stol=double(options.initial_stol);
            obj.initial_angle_tol=double(options.initial_angle_tol);
            if any(~isfinite([obj.initial_ltol,obj.initial_stol, ...
                    obj.initial_angle_tol]))|| ...
                    obj.initial_ltol<=0||obj.initial_stol<=0|| ...
                    obj.initial_angle_tol<=0
                error("KSSOLV:Matgenlab:Prototypes:Tolerances", ...
                    "Matcher tolerances must be finite positive scalars.");
            end
            obj.library= ...
                kssolv.analysis.matgenlab.analysis.prototypes. ...
                AflowPrototypeMatcher.cachedLibrary();
        end

        function tags=get_prototypes(obj,structure)
            reduced=obj.preprocessStructure(structure);
            lengthTolerance=obj.initial_ltol;
            siteTolerance=obj.initial_stol;
            angleTolerance=obj.initial_angle_tol;
            tags=obj.matchPrototype(reduced,lengthTolerance, ...
                siteTolerance,angleTolerance);
            while numel(tags)>1
                lengthTolerance=0.8*lengthTolerance;
                siteTolerance=0.8*siteTolerance;
                angleTolerance=0.8*angleTolerance;
                tags=obj.matchPrototype(reduced,lengthTolerance, ...
                    siteTolerance,angleTolerance);
                if lengthTolerance<0.01,break,end
            end
        end
    end

    methods (Access=private)
        function tags=matchPrototype(obj,reduced,ltol,stol,angleTol)
            matcher=kssolv.analysis.matgenlab.core.StructureMatcher( ...
                ltol,stol,angleTol,true);
            tags=cell(1,0);
            for index=1:numel(obj.library)
                candidate=obj.library{index};
                if candidate.structure.num_sites~=reduced.num_sites
                    continue
                end
                if matcher.fit_anonymous(candidate.structure,reduced,true,true)
                    tags{end+1}=candidate.record; %#ok<AGROW>
                end
            end
        end
    end

    methods (Static,Access=private)
        function structure=preprocessStructure(structure)
            structure=structure.get_reduced_structure("niggli");
            structure=structure.get_primitive_structure();
        end

        function library=cachedLibrary()
            persistent cached
            if isempty(cached)
                raw=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
                    load_data("aflow");
                cached=cell(1,numel(raw));
                for index=1:numel(raw)
                    structure=kssolv.analysis.matgenlab.core.Structure. ...
                        from_dict(raw(index).snl);
                    structure=kssolv.analysis.matgenlab.analysis.prototypes. ...
                        AflowPrototypeMatcher.preprocessStructure(structure);
                    cached{index}=struct("structure",structure, ...
                        "record",raw(index));
                end
            end
            library=cached;
        end
    end
end
