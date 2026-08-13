classdef AdsorbateAssembly
    %ADSORBATEASSEMBLY Combine rigid project components without fake bonds.

    properties (Constant)
        SchemaVersion = 1
    end

    methods (Static)
        function molecule = combine(components, options)
            arguments
                components (1,:) cell
                options.Offsets double = zeros(0, 3)
                options.ComponentGap (1,1) double ...
                    {mustBeFinite,mustBeNonnegative} = 2.5
            end
            if isempty(components)
                error("KSSOLV:Modeling:AdsorbateMixtureEmpty", ...
                    "An adsorbate mixture requires at least one component.");
            end
            count = numel(components);
            offsets = double(options.Offsets);
            if isempty(offsets)
                offsets = automaticOffsets(components, options.ComponentGap);
            elseif ~isequal(size(offsets), [count, 3]) || ...
                    any(~isfinite(offsets), "all")
                error("KSSOLV:Modeling:AdsorbateMixtureOffsets", ...
                    "Mixture offsets must be a finite component-count-by-3 array.");
            end

            species = strings(1, 0);
            coordinates = zeros(0, 3);
            bonds = zeros(0, 3);
            componentRanges = zeros(count, 2);
            cursor = 0;
            for index = 1:count
                component = components{index};
                requireAdsorbate(component);
                local = double(component.cart_coords);
                local = local - mean(local, 1) + offsets(index, :);
                first = cursor + 1;
                last = cursor + component.num_sites;
                componentRanges(index, :) = [first, last];
                species = [species, reshape(string(component.species), 1, [])]; %#ok<AGROW>
                coordinates = [coordinates; local]; %#ok<AGROW>
                componentBonds = topology(component);
                if ~isempty(componentBonds)
                    componentBonds(:, 1:2) = ...
                        componentBonds(:, 1:2) + cursor;
                    bonds = [bonds; componentBonds]; %#ok<AGROW>
                end
                cursor = last;
            end
            properties = struct( ...
                "topology", struct("bonds", bonds, "origin", ...
                    "adsorbate-mixture", "schemaVersion", 1), ...
                "adsorbateAssembly", struct( ...
                    "schemaVersion", ...
                        kssolv.modeling.adsorption. ...
                        AdsorbateAssembly.SchemaVersion, ...
                    "componentCount", count, ...
                    "componentRanges", componentRanges, ...
                    "offsets", offsets, ...
                    "hasIntercomponentBonds", false));
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates, charge_spin_check = false, ...
                properties = properties);
        end
    end
end

function offsets = automaticOffsets(components, gap)
offsets = zeros(numel(components), 3);
rightEdge = 0;
for index = 1:numel(components)
    component = components{index};
    requireAdsorbate(component);
    coordinates = double(component.cart_coords);
    width = max(coordinates(:, 1)) - min(coordinates(:, 1));
    if index == 1
        center = 0;
    else
        center = rightEdge + gap + width / 2;
    end
    offsets(index, 1) = center;
    rightEdge = center + width / 2;
end
offsets(:, 1) = offsets(:, 1) - mean(offsets(:, 1));
end

function requireAdsorbate(value)
if ~(isa(value, "kssolv.analysis.matgenlab.core.IMolecule") || ...
        isa(value, "kssolv.analysis.matgenlab.core.IStructure")) || ...
        value.num_sites < 1
    error("KSSOLV:Modeling:AdsorbateMixtureComponent", ...
        "Every adsorbate mixture component must be a nonempty molecule or structure.");
end
end

function bonds = topology(component)
bonds = zeros(0, 3);
if isa(component, "kssolv.analysis.matgenlab.core.IMolecule")
    bonds = kssolv.modeling.chemistry.MoleculeDiagnostics.topology(component);
elseif isfield(component.structure_properties, "topology") && ...
        isfield(component.structure_properties.topology, "bonds")
    bonds = double(component.structure_properties.topology.bonds);
end
end
