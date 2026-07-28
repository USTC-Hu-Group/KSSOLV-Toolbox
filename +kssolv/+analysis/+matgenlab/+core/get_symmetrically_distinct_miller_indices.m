function uniqueMillers=get_symmetrically_distinct_miller_indices( ...
        structure,maxIndex,varargin)
%GET_SYMMETRICALLY_DISTINCT_MILLER_INDICES Unique hkl representatives.
returnHkil=false;
if ~isempty(varargin)
    if isscalar(varargin),returnHkil=logical(varargin{1});
    else,returnHkil=logical(varargin{2});end
end
range=maxIndex:-1:-maxIndex;
candidates=zeros((2*maxIndex+1)^3-1,3);
next=0;
% Match itertools.product(range, range, range): h changes slowest and l
% changes fastest.  Representative choice and public ordering depend on
% this stable enumeration.
for h=range
    for k=range
        for l=range
            if h==0&&k==0&&l==0,continue,end
            next=next+1;candidates(next,:)=[h,k,l];
        end
    end
end
[~,order]=sort(max(abs(candidates),[],2),"ascend");
candidates=candidates(order,:);
analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure);
crystalSystem=analyzer.get_crystal_system();
trigonal=crystalSystem=="trigonal";
if trigonal
    transformation=analyzer. ...
        get_conventional_to_primitive_transformation_matrix();
    millerCandidates=zeros(size(candidates));
    for index=1:size(candidates,1)
        millerCandidates(index,:)= ...
            kssolv.analysis.matgenlab.core.hkl_transformation( ...
            transformation,candidates(index,:));
    end
    primitive=analyzer.get_primitive_standard_structure();
    operations=primitive.lattice.get_recp_symmetry_operation();
else
    millerCandidates=candidates;
    operations=structure.lattice.get_recp_symmetry_operation();
end
families=containers.Map("KeyType","char","ValueType","logical");
rows=zeros(0,3);
for index=1:size(candidates,1)
    hkl=reduceHkl(millerCandidates(index,:));
    keys=strings(numel(operations),1);
    transformed=zeros(numel(operations),3);
    for opIndex=1:numel(operations)
        transformed(opIndex,:)=reduceHkl(round( ...
            operations{opIndex}.apply_rotation_only(hkl)));
        keys(opIndex)=sprintf("%d,%d,%d",transformed(opIndex,:));
    end
    sortedKeys=sort(keys);
    family=char(join(sortedKeys,";"));
    if ~isKey(families,family)
        families(family)=true;
        if trigonal
            rows(end+1,:)=reduceHkl(candidates(index,:)); %#ok<AGROW>
        else
            rows(end+1,:)=hkl; %#ok<AGROW>
        end
    end
end
if returnHkil && any(crystalSystem==["trigonal","hexagonal"])
    rows=[rows(:,1),rows(:,2),-rows(:,1)-rows(:,2),rows(:,3)];
end
uniqueMillers=num2cell(rows,2).';
end
function value=reduceHkl(value)
divisor=gcd(gcd(abs(value(1)),abs(value(2))),abs(value(3)));
if divisor>0,value=value/divisor;end
end
