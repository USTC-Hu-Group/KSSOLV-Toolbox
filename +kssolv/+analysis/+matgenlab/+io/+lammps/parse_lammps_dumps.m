function dumps=parse_lammps_dumps(file_pattern)
%PARSE_LAMMPS_DUMPS Parse one or multiple LAMMPS dump snapshots.
listing=dir(file_pattern);
if isempty(listing), dumps={}; return; end
paths=fullfile({listing.folder},{listing.name});
if numel(paths)>1
    nums=nan(size(paths));
    for k=1:numel(paths)
        t=regexp(paths{k},'([0-9]+)$','tokens','once');
        if ~isempty(t), nums(k)=str2double(t{1}); end
    end
    [~,order]=sortrows([isnan(nums(:)),nums(:)]);
    paths=paths(order);
end
dumps={};
for p=1:numel(paths)
    text=kssolv.analysis.matgenlab.io.lammps.read_text(paths{p});
    starts=regexp(text,'ITEM: TIMESTEP','start');
    stops=[starts(2:end)-1,numel(text)];
    for k=1:numel(starts)
        dumps{end+1}=kssolv.analysis.matgenlab.io.lammps. ...
            LammpsDump.from_str(text(starts(k):stops(k))); %#ok<AGROW>
    end
end
end
