function structures=get_randomly_manipulated_structures( ...
        structure,manipulations,seed,nReturn)
%GET_RANDOMLY_MANIPULATED_STRUCTURES Apply unique random site manipulations.
if nargin<3||isempty(seed),seed=randi(2^31-1);end
if nargin<4,nReturn=1;end
stream=RandStream("mt19937ar","Seed",double(seed));
structures=cell(1,nReturn);seen=strings(1,0);
for output=1:nReturn
    accepted=false;
    for attempt=1:1000
        selected=zeros(0,2);replacements={};
        for group=1:numel(manipulations)
            item=manipulations{group};
            count=item{2};indices=reshape(double(item{3}),1,[]);
            unavailable=selected(:,1).';
            available=setdiff(indices,unavailable,"stable");
            if numel(available)<count
                error("KSSOLV:Matgenlab:RandomManipulation:Impossible", ...
                    "No valid manipulations remain in a site group.");
            end
            order=randperm(stream,numel(available),count);
            chosen=sort(available(order));
            selected=[selected;[chosen(:),repmat(group,count,1)]]; %#ok<AGROW>
            replacements(end+(1:count))=repmat(item(4),1,count); %#ok<AGROW>
        end
        [~,order]=sort(selected(:,1));selected=selected(order,:);
        replacements=replacements(order);
        key=join(compose("%d:%d",selected(:,1),selected(:,2)).',",");
        if ~ismember(key,seen)
            seen(end+1)=key; %#ok<AGROW>
            accepted=true;
            break
        end
    end
    if ~accepted
        error("KSSOLV:Matgenlab:RandomManipulation:Exhausted", ...
            "Could not produce another unique manipulation.");
    end
    candidate=structure.copy();remove=[];
    for index=1:size(selected,1)
        siteIndex=selected(index,1);replacement=replacements{index};
        if isempty(replacement),remove(end+1)=siteIndex; %#ok<AGROW>
        else,candidate=candidate.replace(siteIndex,replacement);end
    end
    if ~isempty(remove),candidate=candidate.remove_sites(remove);end
    structures{output}=candidate;
end
end
