function species=find_codopant(target,oxidationState,allowedElements)
%FIND_CODOPANT Find the allowed ion closest in radius to a target ion.
if nargin<3||isempty(allowedElements)
    elements=kssolv.analysis.matgenlab.core.Element.all();
    allowedElements=cellfun(@char,elements,"UniformOutput",false);
end
if ~isa(target,"kssolv.analysis.matgenlab.core.Species")
    target=kssolv.analysis.matgenlab.core.getElSp(target);
end
reference=target.ionic_radius;
if isnan(reference)
    error("KSSOLV:Matgenlab:FindCodopant:TargetRadius", ...
        "Target species %s has no ionic radius.",string(target));
end
candidates={};scores=[];
for symbol=reshape(string(allowedElements),1,[])
    try
        value=kssolv.analysis.matgenlab.core.Species(symbol,oxidationState);
        radius=value.ionic_radius;
        if ~isnan(radius)
            candidates{end+1}=value; %#ok<AGROW>
            scores(end+1)=abs(radius/reference-1); %#ok<AGROW>
        end
    catch
    end
end
if isempty(candidates)
    error("KSSOLV:Matgenlab:FindCodopant:NoSpecies", ...
        "No species found with oxidation state %g.",oxidationState);
end
[~,index]=min(scores);species=candidates{index};
end
