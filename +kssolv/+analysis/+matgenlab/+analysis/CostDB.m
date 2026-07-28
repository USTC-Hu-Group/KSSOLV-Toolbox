classdef (Abstract) CostDB
    %COSTDB Abstract cost-entry database.
    methods (Abstract)
        entries = get_entries(obj, chemsys)
    end
end
