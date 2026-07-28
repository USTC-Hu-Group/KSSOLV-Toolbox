classdef VolumetricData < ...
        kssolv.analysis.matgenlab.io.vasp.VolumetricData
    %VOLUMETRICDATA Common volumetric-data API shared by simulation formats.

    methods
        function obj = VolumetricData(structure, data, options)
            arguments
                structure
                data (1,1) struct
                options.distance_matrix = struct()
                options.data_aug (1,1) struct = struct()
            end
            obj@kssolv.analysis.matgenlab.io.vasp.VolumetricData( ...
                structure, data, ...
                distance_matrix = options.distance_matrix, ...
                data_aug = options.data_aug);
        end

        function output = copy(obj)
            output = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData( ...
                    obj.structure, obj.data, data_aug = obj.data_aug);
            output.name = obj.name;
        end
    end

    methods (Static)
        function obj = from_hdf5(filename, varargin)
            base = kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                from_hdf5(filename, varargin{:});
            obj = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData( ...
                    base.structure, base.data, data_aug = base.data_aug);
            obj.name = base.name;
        end

        function obj = from_cube(filename)
            base = kssolv.analysis.matgenlab.io.vasp.VolumetricData. ...
                from_cube(filename);
            obj = ...
                kssolv.analysis.matgenlab.io.common.VolumetricData( ...
                    base.structure, base.data, data_aug = base.data_aug);
            obj.name = base.name;
        end
    end
end
