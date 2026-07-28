function dimensionality=get_dimensionality_cheon(structureRaw,varargin)
%GET_DIMENSIONALITY_CHEON Classify cluster scaling in periodic supercells.
options=struct("tolerance",.45,"ldict",[], ...
    "standardize",true,"larger_cell",false);
options=parseOptions(options,varargin);
if options.standardize
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structureRaw);
    structure=analyzer.get_conventional_standard_structure();
else
    structure=structureRaw.copy();
end
firstConnected=kssolv.analysis.matgenlab.analysis. ...
    find_connected_atoms(structure,options.tolerance,options.ldict);
[maxFirst,minFirst]=kssolv.analysis.matgenlab.analysis. ...
    find_clusters(structure,firstConnected);
factor=2;
if options.larger_cell,factor=3;end
expanded=structure.copy();
expanded=expanded.make_supercell(eye(3)*factor,true,true);
expandedConnected=kssolv.analysis.matgenlab.analysis. ...
    find_connected_atoms(expanded,options.tolerance,options.ldict);
[maxExpanded,minExpanded]=kssolv.analysis.matgenlab.analysis. ...
    find_clusters(expanded,expandedConnected);
if ~options.larger_cell&&minExpanded==1
    dimensionality="intercalated ion";return
end
if minExpanded==minFirst
    if maxExpanded==maxFirst,dimensionality="0D";
    else,dimensionality="intercalated molecule";end
    return
end
dimension=log(double(maxExpanded)/maxFirst)/log(factor);
if abs(dimension-round(dimension))<1e-10
    dimensionality=string(round(dimension))+"D";return
end
if options.larger_cell
    dimensionality=missing;return
end
expanded=structure.copy();
expanded=expanded.make_supercell(eye(3)*3,true,true);
thirdConnected=kssolv.analysis.matgenlab.analysis. ...
    find_connected_atoms(expanded,options.tolerance,options.ldict);
[maxThird,minThird]=kssolv.analysis.matgenlab.analysis. ...
    find_clusters(expanded,thirdConnected);
if minThird==minExpanded
    if maxThird==maxExpanded,dimensionality="0D";
    else,dimensionality="intercalated molecule";end
    return
end
dimension=log(double(maxThird)/maxFirst)/log(3);
if abs(dimension-round(dimension))<1e-10
    dimensionality=string(round(dimension))+"D";
else
    dimensionality=missing;
end
end

function output=parseOptions(output,input)
names=fieldnames(output);position=1;index=1;
while index<=numel(input)
    if (ischar(input{index})||isstring(input{index}))&& ...
            any(strcmpi(string(input{index}),string(names)))
        match=find(strcmpi(string(input{index}),string(names)),1);
        output.(names{match})=input{index+1};index=index+2;
    else
        output.(names{position})=input{index};
        position=position+1;index=index+1;
    end
end
end
