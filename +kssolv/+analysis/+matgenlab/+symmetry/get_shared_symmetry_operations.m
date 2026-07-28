function sharedOperations=get_shared_symmetry_operations( ...
        structure,pointOperations,tolerance)
%GET_SHARED_SYMMETRY_OPERATIONS Point rotations common to each site pair.
if nargin<3,tolerance=0.1;end
count=structure.num_sites;
if ~iscell(pointOperations)||numel(pointOperations)~=count
    error("KSSOLV:Matgenlab:SiteSymmetries:PointOperations", ...
        "pointOperations must contain one cell per structure site.");
end
sharedOperations=cell(count,count);
for first=1:count
    for second=1:count
        common=cell(1,0);
        for left=1:numel(pointOperations{first})
            rotation=pointOperations{first}{left}.rotation_matrix;
            matches=cellfun(@(operation)all(abs( ...
                operation.rotation_matrix-rotation)<1e-8,"all"), ...
                pointOperations{second});
            if ~any(matches),continue,end
            candidate=kssolv.analysis.matgenlab.core.SymmOp. ...
                fromRotationAndTranslation(rotation,[0,0,0],tolerance);
            if ~any(cellfun(@(operation)operation==candidate,common))
                common{end+1}=candidate; %#ok<AGROW>
            end
        end
        sharedOperations{first,second}=common;
    end
end
end
