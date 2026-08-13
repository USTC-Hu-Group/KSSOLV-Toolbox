classdef DialogWindowTest < matlab.unittest.TestCase
    %DIALOGWINDOWTEST Centering is complete before the first visible frame.

    methods (Test)
        function centeredWindowDoesNotMoveAfterPresentation(testCase)
            figureHandle = uifigure("Visible", "off", ...
                "Position", [100, 100, 520, 340]);
            cleanup = onCleanup(@()deleteIfValid(figureHandle));

            kssolv.ui.util.DialogWindow.showCentered(figureHandle);
            firstVisiblePosition = figureHandle.Position;
            drawnow;
            pause(0.5);
            drawnow;

            testCase.verifyEqual(figureHandle.Position, ...
                firstVisiblePosition, "AbsTol", 1, ...
                "The window moved after its first visible frame.");
            clear cleanup
        end

        function visibleWindowCannotBeCenteredLate(testCase)
            figureHandle = uifigure("Visible", "on");
            cleanup = onCleanup(@()deleteIfValid(figureHandle));
            testCase.verifyError(@() ...
                kssolv.ui.util.DialogWindow.showCentered(figureHandle), ...
                "KSSOLV:UI:DialogAlreadyVisible");
            clear cleanup
        end
    end
end

function deleteIfValid(value)
if ~isempty(value) && isvalid(value), delete(value); end
end
