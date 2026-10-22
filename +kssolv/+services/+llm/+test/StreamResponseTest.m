classdef StreamResponseTest < matlab.unittest.TestCase
    methods (Test)
        function disconnectedPartialReplyIsRejected(testCase)
            text = 'data: {"choices":[{"delta":{"content":"partial"},"finish_reason":null}]}';
            testCase.verifyError(@() testCase.check(text), ...
                'KSSOLV:LLM:IncompleteStream');
        end

        function finalChoiceCompletesWithoutDoneMarker(testCase)
            testCase.check('data: {"choices":[{"delta":{},"finish_reason":"stop"}]}');
        end

        function toolCallsCompleteWithoutText(testCase)
            testCase.check('data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}');
        end

        function doneMarkerCompletesStream(testCase)
            testCase.check(sprintf(': heartbeat\r\ndata: [DONE]\r\n\r\n'));
        end

        function tokenLimitDoesNotCommitTruncatedReply(testCase)
            testCase.verifyError(@() testCase.check( ...
                'data: {"choices":[{"delta":{},"finish_reason":"length"}]}'), ...
                'KSSOLV:LLM:IncompleteStream');
        end

        function incompleteJsonAndEmptyBodyAreRejected(testCase)
            testCase.verifyError(@() testCase.check('data: {"choices":['), ...
                'KSSOLV:LLM:IncompleteStream');
            testCase.verifyError(@() testCase.check(''), ...
                'KSSOLV:LLM:IncompleteStream');
        end

        function ordinaryJsonAndHttpErrorsKeepTheirExistingHandling(~)
            validate = @kssolv.services.llm.internal.validateStreamResponse;
            validate(struct('StatusCode', "OK", 'Body', ...
                struct('Data', struct('choices', []))));
            validate(struct('StatusCode', "Unauthorized", 'Body', ...
                struct('Data', uint8('not SSE'))));
        end
    end

    methods (Static, Access = private)
        function check(text)
            response = struct('StatusCode', "OK", 'Body', ...
                struct('Data', unicode2native(text, 'UTF-8')));
            kssolv.services.llm.internal.validateStreamResponse(response);
        end
    end
end
