classdef JDFTXPlotter
    %JDFTXPLOTTER MATLAB-native plots for JDFTx energies and bands.
    methods (Static)
        function handles = plot_scf(output, options)
            arguments
                output
                options.axes = []
            end
            target = options.axes;
            if isempty(target)
                target = axes(figure());
            end
            steps = output.elecmindata.slices;
            x = zeros(numel(steps), 1);
            y = zeros(numel(steps), 1);
            for idx = 1:numel(steps)
                x(idx) = steps{idx}.nstep;
                y(idx) = steps{idx}.e;
            end
            handles = plot(target, x, y, "-o");
            xlabel(target, "SCF iteration");
            ylabel(target, "Energy (eV)");
            grid(target, "on");
        end

        function handles = plot_bands(outputs, options)
            arguments
                outputs
                options.axes = []
                options.subtract_efermi (1, 1) logical = true
            end
            if isempty(outputs.eigenvals)
                error("KSSOLV:Matgenlab:JDFTX:MissingEigenvalues", ...
                    "Load eigenvals before plotting bands.");
            end
            target = options.axes;
            if isempty(target)
                target = axes(figure());
            end
            values = outputs.eigenvals;
            if options.subtract_efermi
                values = values - outputs.outfile.efermi;
            end
            handles = plot(target, 0:size(values, 1) - 1, values);
            xlabel(target, "State index");
            ylabel(target, "Energy (eV)");
            grid(target, "on");
        end
    end
end
