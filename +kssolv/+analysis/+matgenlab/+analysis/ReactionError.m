classdef ReactionError < MException
    %REACTIONERROR Chemical-reaction balancing failure.
    methods
        function obj = ReactionError(message, varargin)
            obj@MException("KSSOLV:Matgenlab:Reaction:BalanceError", ...
                message, varargin{:});
        end
    end
end
