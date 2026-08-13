classdef CrystalSceneCache
    %CRYSTALSCENECACHE Bounded cache for expensive connectivity scenes.
    methods (Static)
        function scene = build(structure, options, requestId)
            arguments
                structure (1,1) kssolv.analysis.matgenlab.core.IStructure
                options (1,1) struct
                requestId string = ""
            end
            [cache, order, totalBytes] = ...
                kssolv.ui.scene.atomic.CrystalSceneCache.storage();
            keyData = struct( ...
                "builderVersion", "crystal-visible-set-2", ...
                "structure", structure.as_dict(), ...
                "options", options);
            key = kssolv.ui.util.Hash.sha256Text(jsonencode(keyData));
            if isKey(cache, key)
                started = tic;
                entry = cache(key);
                scene = entry.scene;
                scene.requestId = requestId;
                scene.analysis.parameters.cacheHit = true;
                scene.analysis.elapsedMilliseconds = toc(started) * 1000;
                order(order == key) = [];
                order(end + 1) = key;
                kssolv.ui.scene.atomic.CrystalSceneCache.storage( ...
                    cache, order, totalBytes);
                return
            end
            scene = kssolv.ui.scene.atomic.CrystalSceneBuilder.build( ...
                structure, ...
                algorithm = string(options.algorithm), ...
                cell = string(options.cell), ...
                repeat = double(options.repeat), ...
                includeConnectivity = true, ...
                includePolyhedra = true, ...
                includeBoundaryAtoms = true, ...
                includeBondedOutside = true, ...
                requestId = requestId);
            scene.analysis.parameters.cacheHit = false;
            allocation = whos("scene");
            incomingBytes = allocation.bytes;
            while ~isempty(order) && ...
                    (numel(order) >= 6 || ...
                    totalBytes + incomingBytes > 80 * 1024 * 1024)
                oldest = order(1);
                oldestEntry = cache(oldest);
                totalBytes = totalBytes - oldestEntry.bytes;
                remove(cache, oldest);
                order(1) = [];
            end
            if incomingBytes <= 80 * 1024 * 1024
                cache(key) = struct("scene", scene, "bytes", incomingBytes);
                order(end + 1) = key;
                totalBytes = totalBytes + incomingBytes;
            end
            kssolv.ui.scene.atomic.CrystalSceneCache.storage( ...
                cache, order, totalBytes);
        end

        function clear()
            kssolv.ui.scene.atomic.CrystalSceneCache.storage( ...
                containers.Map("KeyType", "char", "ValueType", "any"), ...
                strings(1, 0), 0);
        end
    end

    methods (Static, Access = private)
        function [cache, order, totalBytes] = storage(varargin)
            persistent sceneCache cacheOrder cacheBytes
            if isempty(sceneCache)
                sceneCache = containers.Map( ...
                    "KeyType", "char", "ValueType", "any");
                cacheOrder = strings(1, 0);
                cacheBytes = 0;
            end
            if nargin == 3
                sceneCache = varargin{1};
                cacheOrder = varargin{2};
                cacheBytes = varargin{3};
            end
            cache = sceneCache;
            order = cacheOrder;
            totalBytes = cacheBytes;
        end

    end
end
