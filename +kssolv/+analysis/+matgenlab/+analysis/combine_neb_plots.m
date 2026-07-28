function combined=combine_neb_plots(analyses,arranged,reversePlot)
%COMBINE_NEB_PLOTS Join compatible NEB segments into one reaction path.
if nargin<2||isempty(arranged),arranged=false;end
if nargin<3||isempty(reversePlot),reversePlot=false;end
matcher=kssolv.analysis.matgenlab.analysis.StructureMatcher();
energies=analyses{1}.energies;
structures=analyses{1}.structures;
forces=analyses{1}.forces;
coordinates=analyses{1}.r;
for index=2:numel(analyses)
    next=analyses{index};
    matched=matcher.fit(structures{1},next.structures{1})|| ...
        matcher.fit(structures{1},next.structures{end})|| ...
        matcher.fit(structures{end},next.structures{1})|| ...
        matcher.fit(structures{end},next.structures{end});
    if ~matched
        error("KSSOLV:Matgenlab:NEBAnalysis:Unmatched", ...
            "No matched structures for connection.");
    end
    differences=[abs(energies(1)-next.energies(1)), ...
        abs(energies(1)-next.energies(end)), ...
        abs(energies(end)-next.energies(1)), ...
        abs(energies(end)-next.energies(end))];
    [~,which]=min(differences);
    if arranged
        energies=[energies(1:end-1), ...
            mean([energies(end),next.energies(1)]), ...
            next.energies(2:end)];
        structures=[structures,next.structures(2:end)]; %#ok<AGROW>
        forces=[forces,next.forces(2:end)]; %#ok<AGROW>
        coordinates=[coordinates,next.r(2:end)+coordinates(end)]; %#ok<AGROW>
    elseif which==1
        energies=[fliplr(energies(2:end)),next.energies];
        structures=[fliplr(structures(2:end)),next.structures];
        forces=[fliplr(forces(2:end)),next.forces];
        left=fliplr(coordinates(end)-coordinates(2:end));
        coordinates=[left,next.r+left(end)];
    elseif which==2
        energies=[next.energies,energies(2:end)];
        structures=[next.structures,structures(2:end)];
        forces=[next.forces,forces(2:end)];
        coordinates=[next.r,coordinates(2:end)+next.r(end)];
    elseif which==3
        energies=[energies,next.energies(2:end)]; %#ok<AGROW>
        structures=[structures,next.structures(2:end)]; %#ok<AGROW>
        forces=[forces,next.forces(2:end)]; %#ok<AGROW>
        coordinates=[coordinates,next.r(2:end)+coordinates(end)]; %#ok<AGROW>
    else
        energies=[energies,fliplr(next.energies(1:end-1))]; %#ok<AGROW>
        structures=[structures,fliplr(next.structures(1:end-1))]; %#ok<AGROW>
        forces=[forces,fliplr(next.forces(1:end-1))]; %#ok<AGROW>
        tail=fliplr(next.r(end)-next.r(1:end-1))+coordinates(end);
        coordinates=[coordinates,tail]; %#ok<AGROW>
    end
end
if reversePlot
    coordinates=fliplr(coordinates(end)-coordinates);
    energies=fliplr(energies);forces=fliplr(forces);
    structures=fliplr(structures);
end
combined=kssolv.analysis.matgenlab.analysis.NEBAnalysis( ...
    coordinates,energies,forces,structures);
end
