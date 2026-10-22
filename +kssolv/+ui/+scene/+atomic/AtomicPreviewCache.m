classdef AtomicPreviewCache
    %ATOMICPREVIEWCACHE Small, content-keyed cache of atoms-first scenes.
    methods (Static)
        function scene = build(model, options, requestId)
            arguments
                model
                options (1,1) struct
                requestId (1,1) string = ""
            end
            % Large previews are built once for opening, without spending
            % time serializing a cache key for speculative/oversized data.
            if model.num_sites > 1000
                scene = kssolv.ui.scene.atomic.AtomicPreviewCache.compile(model, options, requestId);
                return
            end
            persistent entries order totalBytes
            if isempty(entries)
                entries = containers.Map('KeyType', 'char', 'ValueType', 'any');
                order = strings(1, 0);
                totalBytes = 0;
            end
            key = kssolv.ui.util.Hash.sha256Text(jsonencode(struct( ...
                'model', model.as_dict(), 'options', options)));
            if isKey(entries, key)
                entry = entries(key);
                scene = entry.scene;
                scene.requestId = requestId;
                order(order == key) = [];
                order(end + 1) = key;
                return
            end
            scene = kssolv.ui.scene.atomic.AtomicPreviewCache.compile(model, options, requestId);
            allocation = whos('scene');
            while ~isempty(order) && (numel(order) >= 4 || ...
                    totalBytes + allocation.bytes > 20 * 1024 * 1024)
                oldest = entries(order(1));
                totalBytes = totalBytes - oldest.bytes;
                remove(entries, order(1));
                order(1) = [];
            end
            if allocation.bytes <= 20 * 1024 * 1024
                entries(key) = struct('scene', scene, 'bytes', allocation.bytes);
                order(end + 1) = key;
                totalBytes = totalBytes + allocation.bytes;
            end
        end
    end
    methods (Static, Access = private)
        function scene = compile(model, options, requestId)
            if isa(model, 'kssolv.analysis.matgenlab.core.IMolecule')
                scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                    model, algorithm = options.algorithm, ...
                    includeConnectivity = false, requestId = requestId);
            else
                scene = kssolv.ui.scene.atomic.CrystalSceneBuilder.build( ...
                    model, algorithm = options.algorithm, cell = options.cell, ...
                    repeat = options.repeat, includeConnectivity = false, ...
                    includePolyhedra = false, requestId = requestId);
            end
        end
    end
end
