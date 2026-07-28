function output=find_translations(first,second)
%FIND_TRANSLATIONS Find value-preserving bijections between two mappings.
firstNames=fieldnames(first);secondNames=fieldnames(second);
if numel(firstNames)~=numel(secondNames)
    output={};return
end
firstValues=cellfun(@(name)first.(name),firstNames);
secondValues=cellfun(@(name)second.(name),secondNames);
if ~isequal(sort(firstValues),sort(secondValues))
    output={};return
end
output=backtrack(1,false(size(secondNames)),struct());
    function results=backtrack(index,used,mapping)
        if index>numel(firstNames),results={mapping};return,end
        results={};
        for candidate=1:numel(secondNames)
            if ~used(candidate)&& ...
                    second.(secondNames{candidate})== ...
                    first.(firstNames{index})
                next=used;next(candidate)=true;
                mapped=mapping;
                mapped.(firstNames{index})=secondNames{candidate};
                additions=backtrack(index+1,next,mapped);
                results=[results,additions]; %#ok<AGROW>
            end
        end
    end
end
