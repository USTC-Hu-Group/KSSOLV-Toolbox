function equivalent=get_symmetrically_equivalent_miller_indices( ...
        structure,millerIndex,varargin)
%GET_SYMMETRICALLY_EQUIVALENT_MILLER_INDICES Reciprocal-space hkl family.
options=struct("return_hkil",true,"system","");
for index=1:2:numel(varargin)
    options.(char(string(varargin{index})))=varargin{index+1};
end
hkl=reshape(double(millerIndex),1,[]);
hkl=[hkl(1),hkl(2),hkl(end)];
maximum=max(abs(double(millerIndex)));
if strlength(string(options.system))==0
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure);
    system=analyzer.get_crystal_system();
else
    analyzer=[];
    system=lower(string(options.system));
end
if system=="trigonal"
    if isempty(analyzer)
        analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
            SpacegroupAnalyzer(structure);
    end
    primitive=analyzer.get_primitive_standard_structure();
    operations=primitive.lattice.get_recp_symmetry_operation();
else
    operations=structure.lattice.get_recp_symmetry_operation();
end
rows=hkl;
range=maximum:-1:-maximum;
for first=range
    for second=range
        for third=range
            candidate=[first,second,third];
            if isequal(candidate,hkl)||~any(candidate),continue,end
            if inFamily(candidate,rows,operations)
                rows(end+1,:)=candidate; %#ok<AGROW>
            elseif all(maximum>abs(candidate)) && ...
                    ~any(all(rows==candidate,2)) && ...
                    inFamily(maximum*candidate,rows,operations)
                rows(end+1,:)=candidate; %#ok<AGROW>
            end
        end
    end
end
if options.return_hkil&&any(system==["hexagonal","trigonal"])
    rows=[rows(:,1),rows(:,2),-rows(:,1)-rows(:,2),rows(:,3)];
end
equivalent=num2cell(rows,2).';
end

function value=inFamily(miller,families,operations)
value=false;
for index=1:numel(operations)
    transformed=round(operations{index}.operate(miller));
    if any(all(families==transformed,2))
        value=true;
        return
    end
end
end
