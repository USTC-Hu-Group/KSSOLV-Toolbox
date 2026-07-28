classdef TypeRegistry
    %TYPEREGISTRY Map MSON type identifiers to MATLAB classes.

    methods (Static)
        function register(msonModule, msonClass, matlabClass)
            arguments
                msonModule (1,1) string
                msonClass (1,1) string
                matlabClass (1,1) string
            end
            store = kssolv.analysis.matgenlab.internal.TypeRegistry.store();
            store(kssolv.analysis.matgenlab.internal.TypeRegistry.key( ...
                msonModule, msonClass)) = matlabClass; %#ok<NASGU>
        end

        function matlabClass = resolve(msonModule, msonClass)
            arguments
                msonModule (1,1) string
                msonClass (1,1) string
            end

            store = kssolv.analysis.matgenlab.internal.TypeRegistry.store();
            registryKey = kssolv.analysis.matgenlab.internal.TypeRegistry.key( ...
                msonModule, msonClass);
            if isKey(store, registryKey)
                matlabClass = string(store(registryKey));
                return
            end

            % Most Matgenlab classes are flattened to the first pymatgen
            % namespace component, e.g. pymatgen.core.structure.Structure
            % becomes kssolv.analysis.matgenlab.core.Structure.
            parts = split(msonModule, ".");
            if numel(parts) >= 2 && parts(1) == "pymatgen"
                namespace = parts(2);
                candidate = "kssolv.analysis.matgenlab." + namespace + "." + msonClass;
                if exist(candidate, "class") == 8
                    matlabClass = candidate;
                    store(registryKey) = matlabClass; %#ok<NASGU>
                    return
                end
                % Historical pymatgen serialized Entry classes from
                % pymatgen.entries.* before they moved to pymatgen.core.
                if namespace == "entries"
                    candidate = "kssolv.analysis.matgenlab.core." + msonClass;
                    if exist(candidate, "class") == 8
                        matlabClass = candidate;
                        store(registryKey) = matlabClass; %#ok<NASGU>
                        return
                    end
                end
                if namespace == "apps" && numel(parts) >= 3 && ...
                        parts(3) == "battery"
                    candidate = "kssolv.analysis.matgenlab.apps.battery." + ...
                        msonClass;
                    if exist(candidate, "class") == 8
                        matlabClass = candidate;
                        store(registryKey) = matlabClass; %#ok<NASGU>
                        return
                    end
                end
                if namespace == "io" && numel(parts) >= 3
                    candidate = "kssolv.analysis.matgenlab.io." + ...
                        parts(3) + "." + msonClass;
                    if exist(candidate, "class") == 8
                        matlabClass = candidate;
                        store(registryKey) = matlabClass; %#ok<NASGU>
                        return
                    end
                end
                if namespace == "alchemy"
                    candidate = "kssolv.analysis.matgenlab.alchemy." + ...
                        msonClass;
                    if exist(candidate, "class") == 8
                        matlabClass = candidate;
                        store(registryKey) = matlabClass; %#ok<NASGU>
                        return
                    end
                end
            end
            matlabClass = "";
        end

        function clear()
            kssolv.analysis.matgenlab.internal.TypeRegistry.store(true);
        end
    end

    methods (Static, Access = private)
        function registryKey = key(msonModule, msonClass)
            registryKey = char(msonModule + "::" + msonClass);
        end

        function value = store(reset)
            arguments
                reset (1,1) logical = false
            end
            persistent registry
            if reset || isempty(registry)
                registry = containers.Map("KeyType", "char", "ValueType", "char");
            end
            value = registry;
        end
    end
end
