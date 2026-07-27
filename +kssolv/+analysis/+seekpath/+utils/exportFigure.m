function exportFigure(baseName, options)
%EXPORTFIGURE Export the current figure into specified formats.
%
% This function saves the current figure (gcf) based on user-specified options.
% The user can specify formats such as .fig, .png, .pdf, etc.
%
% Input:
% baseName - The base file name (string or char), including or excluding a path.
% options  - A structure or name-value pairs with the following fields:
%            'Formats' (default: ["fig", "png", "pdf"]): File formats to export.
%            'Resolution' (default: 300): Resolution for raster formats (e.g., .png).
%
% Example:
% plot(rand(10,1));
% kssolv.analysis.seekpath.utils.exportFigure('output/myPlot', 'Formats', ["png", "pdf"], 'Resolution', 600);

arguments
    baseName (1,1) string {mustBeNonempty}
    options.Formats (1,:) string = ["fig", "png", "pdf"]
    options.Resolution (1,1) double {mustBePositive} = 600
end

% Ensure the directory exists
outputDir = fileparts(baseName);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end

% Export figure based on specified formats
for format = options.Formats
    switch lower(format)
        case "fig"
            saveas(gcf, baseName + ".fig");
        case "png"
            exportgraphics(gcf, baseName + ".png", ...
                'BackgroundColor', 'none', 'Resolution', options.Resolution);
        case "pdf"
            exportgraphics(gcf, baseName + ".pdf", ...
                'ContentType', 'vector', 'BackgroundColor', 'none');
        case "eps"
            exportgraphics(gcf, baseName + ".eps", ...
                'ContentType', 'vector', 'BackgroundColor', 'none');
        case "svg"
            exportgraphics(gcf, baseName + ".svg", ...
                'ContentType', 'vector', 'BackgroundColor', 'none');
        otherwise
            warning('Unsupported format: %s. Skipping.', format);
    end
end

fprintf('Figure exported to formats: %s in %s.\n', ...
    strjoin(options.Formats, ', '), outputDir);
end
