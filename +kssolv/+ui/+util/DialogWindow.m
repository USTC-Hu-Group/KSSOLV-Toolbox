classdef DialogWindow
    %DIALOGWINDOW Present fully built windows without a visible relocation.

    methods (Static)
        function showCentered(figureHandle)
            arguments
                figureHandle (1,1) matlab.ui.Figure
            end
            if string(figureHandle.Visible) ~= "off"
                error("KSSOLV:UI:DialogAlreadyVisible", ...
                    "A dialog must remain hidden until it is centered.");
            end
            movegui(figureHandle, "center");
            figureHandle.Visible = "on";
        end
    end
end
