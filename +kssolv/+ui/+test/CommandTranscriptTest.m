classdef CommandTranscriptTest < matlab.unittest.TestCase
    methods (Test)
        function ignoresEmptyContentDeltas(testCase)
            transcript=kssolv.ui.util.CommandTranscript();
            for emptyContent={[], '', "", strings(0,0)}
                transcript.append('tokens',emptyContent{1});
            end
            state=transcript.snapshot();
            testCase.verifyEmpty(state.Records);
            transcript.append('tokens','answer');
            transcript.append('tokens',[]);
            transcript.append('tokens',' continued');
            state=transcript.snapshot();
            testCase.verifyEqual(state.Records{1}.Data,'answer continued');
        end

        function retainsCommandResultsAndRemoteMarkers(testCase)
            transcript=kssolv.ui.util.CommandTranscript();
            transcript.recordCommand('x=6*7',true);
            transcript.append('result','42');
            state=transcript.snapshot();
            testCase.verifyEqual(state.Commands,{'x=6*7'});
            testCase.verifyTrue(state.Records{1}.Remote);
            testCase.verifyEqual(state.Records{2}.Data,'42');
            testCase.verifyFalse(state.Truncated);
        end

        function mergesTokensWithoutLosingThinkBoundaries(testCase)
            transcript=kssolv.ui.util.CommandTranscript();
            transcript.recordCommand('$ hello');
            for text=["<think>","reason ","one","</think>","answer ","two"]
                transcript.append('tokens',text);
            end
            state=transcript.snapshot();
            testCase.verifyEqual(cellfun(@(r)r.Data,state.Records,UniformOutput=false), ...
                {'$ hello','<think>','reason one','</think>','answer two'});
        end

        function clearRetainsRecallAndDoesNotResurrectOutput(testCase)
            transcript=kssolv.ui.util.CommandTranscript();
            transcript.recordCommand('x=42');
            transcript.append('result','42');
            transcript.recordCommand('clc;');
            state=transcript.snapshot();
            testCase.verifyEmpty(state.Records);
            testCase.verifyEqual(state.Commands,{'x=42','clc;'});
            transcript.recordCommand('x');
            transcript.append('result','42');
            state=transcript.snapshot();
            testCase.verifyNumElements(state.Records,2);
        end

        function boundsStateWithoutRecallingPartialCommands(testCase)
            transcript=kssolv.ui.util.CommandTranscript(12);
            transcript.recordCommand('old');
            transcript.append('result','old result');
            transcript.recordCommand('new');
            transcript.append('tokens','abcdefghijklmnop');
            state=transcript.snapshot();
            testCase.verifyTrue(state.Truncated);
            testCase.verifyLessThanOrEqual(sum(cellfun(@(r)numel(r.Data),state.Records)),12);
            transcript.recordCommand(repmat('x',1,20));
            state=transcript.snapshot();
            testCase.verifyEqual(state.Commands,{'old','new'});
        end

        function snapshotRemainsIndependentOfLaterOutput(testCase)
            transcript=kssolv.ui.util.CommandTranscript();
            transcript.recordCommand('$ hello');
            transcript.append('tokens','first');
            previous=transcript.snapshot();
            transcript.append('tokens',' second');
            testCase.verifyEqual(previous.Records{2}.Data,'first');
            state=transcript.snapshot();
            testCase.verifyEqual(state.Records{2}.Data,'first second');
        end
    end
end
