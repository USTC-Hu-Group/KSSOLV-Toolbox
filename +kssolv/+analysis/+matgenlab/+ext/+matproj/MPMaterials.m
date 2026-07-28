classdef MPMaterials
    %MPMATERIALS Collection of Materials Project document endpoints.

    properties
        summary
        core
        elasticity
        phonon
        eos
        similarity
        xas
        grain_boundaries
        electronic_structure
        tasks
        substrates
        surface_properties
        robocrys
        synthesis
        magnetism
        insertion_electrodes
        conversion_electrodes
        oxidation_states
        provenance
        alloys
        absorption
        chemenv
        bonds
        piezoelectric
        dielectric
    end

    methods
        function obj = MPMaterials(rester)
            names = kssolv.analysis.matgenlab.ext.matproj.MPRester. ...
                MATERIALS_DOCS;
            for index = 1:numel(names)
                name = char(names(index));
                obj.(name) = kssolv.analysis.matgenlab.ext.matproj. ...
                    MPDocumentEndpoint(rester, names(index));
            end
        end
    end
end
