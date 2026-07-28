function value=compute_average_oxidation_state(site)
%COMPUTE_AVERAGE_OXIDATION_STATE Occupancy-weighted site oxidation state.
try
    [species,occupancies]=site.species.items();
    values=zeros(size(occupancies));
    for index=1:numel(species)
        values(index)=species{index}.oxi_state*occupancies(index);
    end
    if all(isfinite(values)),value=sum(values);return,end
catch
end
try
    value=site.charge;
    if isfinite(value),return,end
catch
end
try
    properties=site.properties;
    if isfield(properties,"charge")
        value=double(properties.charge);
        if isscalar(value)&&isfinite(value),return,end
    end
catch
end
error("KSSOLV:Matgenlab:Ewald:MissingCharge", ...
    "Ewald summation can only be performed on structures that are " + ...
    "either oxidation state decorated or have site charges.");
end
