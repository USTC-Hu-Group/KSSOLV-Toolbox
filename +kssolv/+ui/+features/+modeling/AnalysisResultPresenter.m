classdef AnalysisResultPresenter
    %ANALYSISRESULTPRESENTER Show modeling analysis results graphically.

    methods (Static)
        function present(commandId, model, result, titleText, varargin)
            commandId = string(commandId);
            switch commandId
                case "find_adsorption_sites"
                    kssolv.ui.features.modeling.AnalysisResultPresenter. ...
                        plotAdsorptionSites(model, result, titleText);
                case "wigner_seitz_cell"
                    kssolv.ui.features.modeling.AnalysisResultPresenter. ...
                        plotWignerSeitz( ...
                        model, result, titleText, varargin{:});
                otherwise
                    if isempty(varargin)
                        msgbox(result.message, titleText, "help", "modal");
                    else
                        uialert(varargin{1}, result.message, titleText, ...
                            "Icon", "info");
                    end
            end
        end
    end

    methods (Static, Access = private)
        function plotAdsorptionSites(model, result, titleText)
            figureHandle = figure( ...
                "Name", titleText, "NumberTitle", "off", ...
                "Color", "white");
            axesHandle = axes(figureHandle);
            kssolv.analysis.matgenlab.core.plot_slab( ...
                model, axesHandle, .8, 3, 1.5, true, .2, false);
            sites = result.data;
            if isfield(sites, "all") && ~isempty(sites.all)
                operation = ...
                    kssolv.analysis.matgenlab.core.get_rot(model);
                coordinates = operation.operate(sites.all);
                hold(axesHandle, "on");
                plot(axesHandle, coordinates(:, 1), coordinates(:, 2), ...
                    "kx", "MarkerSize", 10, "LineWidth", 1.5, ...
                    "LineStyle", "none");
                hold(axesHandle, "off");
            end
            title(axesHandle, result.message, ...
                "Interpreter", "none");
        end

        function plotWignerSeitz(model, result, titleText, varargin)
            appContainer = [];
            if ~isempty(varargin)
                appContainer = varargin{1};
            end
            embedInDocument = ~isempty(appContainer) && ...
                isvalid(appContainer);
            figureHandle = figure( ...
                "Name", titleText, "NumberTitle", "off", ...
                "Color", "white", ...
                "Visible", matlab.lang.OnOffSwitchState( ...
                ~embedInDocument));
            axesHandle = axes(figureHandle);
            view(axesHandle, 3);
            axis(axesHandle, "equal");
            grid(axesHandle, "on");
            kssolv.analysis.matgenlab.electronic_structure. ...
                plot_wigner_seitz(model.lattice, axesHandle);
            xlabel(axesHandle, "x (angstrom)");
            ylabel(axesHandle, "y (angstrom)");
            zlabel(axesHandle, "z (angstrom)");
            title(axesHandle, result.message, ...
                "Interpreter", "none");
            if embedInDocument
                documentTag = "ModelingWignerSeitzCell";
                existing = appContainer.getDocument( ...
                    "Plot", documentTag);
                if ~isempty(existing)
                    existing.close();
                end
                dataPlot = ...
                    kssolv.ui.components.figuredocument.DataPlot( ...
                    figureHandle, documentTag);
                dataPlot.Display(char(titleText), false);
                if isvalid(figureHandle)
                    delete(figureHandle);
                end
            end
        end
    end
end
