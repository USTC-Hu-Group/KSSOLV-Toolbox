classdef LobsterPlotter
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERPLOTTER Native MATLAB plots for parsed LOBSTER data.
    methods (Static)
        function handles = plot_coxx(reader, options)
            arguments
                reader
                options.axes = []
                options.indices = []
                options.data_type (1,1) string = "coxx"
                options.spins = []
                options.energy_zero (1,1) string = "fermi"
            end
            axesValue = options.axes;
            if isempty(axesValue), axesValue = axes(); end
            indices = options.indices;
            if isempty(indices), indices = 0:numel(reader.interactions)-1; end
            columns = reader.interaction_indices_to_data_indices_mapping( ...
                indices, options.spins, options.data_type);
            energies = reader.energies;
            if options.energy_zero == "fermi", energies = energies - reader.efermi_value; end
            handles = plot(axesValue, energies, reader.data(:, columns + 1), ...
                "LineWidth", 1.2);
            xlabel(axesValue, "Energy (eV)");
            ylabel(axesValue, upper(options.data_type));
            grid(axesValue, "on");
        end
        function handles = plot_bwdf(reader, options)
            arguments
                reader
                options.axes = []
            end
            axesValue = options.axes;
            if isempty(axesValue), axesValue = axes(); end
            centersValue = cell2mat(reader.centers);
            values = reader.bwdf.up;
            if isfield(reader.bwdf, "down"), values(:, 2) = reader.bwdf.down; end
            handles = plot(axesValue, centersValue, values, "LineWidth", 1.2);
            xlabel(axesValue, "Bond length");
            ylabel(axesValue, "BWDF");
            grid(axesValue, "on");
        end
        function handles = plot_dos(reader, options)
            arguments
                reader
                options.axes = []
            end
            axesValue = options.axes;
            if isempty(axesValue), axesValue = axes(); end
            energies = reader.energies - reader.efermi;
            values = reader.total_dos.densities.up(:);
            if isfield(reader.total_dos.densities, "down")
                values(:, 2) = -reader.total_dos.densities.down(:);
            end
            handles = plot(axesValue, energies, values, "LineWidth", 1.2);
            xlabel(axesValue, "E - E_F (eV)");
            ylabel(axesValue, "DOS");
            grid(axesValue, "on");
        end
    end
end
