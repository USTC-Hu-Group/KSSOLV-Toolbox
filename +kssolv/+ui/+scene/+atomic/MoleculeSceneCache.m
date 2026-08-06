classdef MoleculeSceneCache
    %MOLECULESCENECACHE Bounded cache for molecular connectivity scenes.
    methods (Static)
        function scene = build(molecule, options, requestId)
            arguments
                molecule (1,1) kssolv.analysis.matgenlab.core.IMolecule
                options (1,1) struct
                requestId string = ""
            end
            [cache, order, totalBytes] = ...
                kssolv.ui.scene.atomic.MoleculeSceneCache.storage();
            key = kssolv.ui.scene.atomic.MoleculeSceneCache. ...
                scientificKey(molecule, options);
            if isKey(cache, key)
                started = tic;
                entry = cache(key);
                scene = entry.scene;
                scene.requestId = requestId;
                scene.analysis.parameters.cacheHit = true;
                scene.analysis.elapsedMilliseconds = toc(started) * 1000;
                order(order == key) = [];
                order(end + 1) = key;
                kssolv.ui.scene.atomic.MoleculeSceneCache.storage( ...
                    cache, order, totalBytes);
                return
            end
            scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                molecule, algorithm = string(options.algorithm), ...
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
            kssolv.ui.scene.atomic.MoleculeSceneCache.storage( ...
                cache, order, totalBytes);
        end

        function clear()
            kssolv.ui.scene.atomic.MoleculeSceneCache.storage( ...
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

        function value = scientificKey(molecule, options)
            sites = molecule.sites;
            species = strings(1, molecule.num_sites);
            coordinates = zeros(molecule.num_sites, 3);
            for index = 1:molecule.num_sites
                species(index) = string(sites{index}.specie);
                coordinates(index, :) = sites{index}.coords;
            end

            topologyKey = struct();
            properties = molecule.properties;
            if isfield(properties, "topology") && ...
                    isstruct(properties.topology)
                topology = properties.topology;
                if isfield(topology, "origin")
                    topologyKey.origin = string(topology.origin);
                end
                if isfield(topology, "bonds")
                    topologyKey.bonds = double(topology.bonds);
                end
            end

            keyData = struct( ...
                "builderVersion", "AtomicSceneSpec-2.0", ...
                "algorithm", string(options.algorithm), ...
                "numSites", molecule.num_sites, ...
                "charge", molecule.charge, ...
                "spinMultiplicity", molecule.spin_multiplicity, ...
                "species", species, ...
                "coordinates", coordinates, ...
                "topology", topologyKey);
            value = kssolv.ui.util.Hash.sha256Text(jsonencode(keyData));
        end
    end
end
