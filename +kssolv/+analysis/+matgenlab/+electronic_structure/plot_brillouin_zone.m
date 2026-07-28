function fig=plot_brillouin_zone(lattice,varargin)
%PLOT_BRILLOUIN_ZONE Plot lattice vectors, BZ skeleton, paths and points.
options=struct(lines=[],labels=[],kpoints=[],fold=false, ...
    coords_are_cartesian=false,ax=[]);options=parseOptions(options,varargin);
[fig,ax]=kssolv.analysis.matgenlab.electronic_structure. ...
    plot_lattice_vectors(lattice,options.ax);
kssolv.analysis.matgenlab.electronic_structure.plot_wigner_seitz(lattice,ax);
if ~isempty(options.lines)
    lines=options.lines;if ~iscell(lines),lines={lines};end
    for ii=1:numel(lines),kssolv.analysis.matgenlab.electronic_structure. ...
            plot_path(lines{ii},lattice,options.coords_are_cartesian,ax);end
end
if ~isempty(options.labels)
    kssolv.analysis.matgenlab.electronic_structure.plot_labels( ...
        options.labels,lattice,options.coords_are_cartesian,ax);
    map=asMap(options.labels);points=cell2mat(cellfun(@(k)reshape(map(k),1,3), ...
        map.keys,"UniformOutput",false).');
    kssolv.analysis.matgenlab.electronic_structure.plot_points( ...
        points,lattice,options.coords_are_cartesian,false,ax);
end
if ~isempty(options.kpoints),kssolv.analysis.matgenlab.electronic_structure. ...
        plot_points(options.kpoints,lattice,options.coords_are_cartesian,options.fold,ax);end
axis(ax,"equal");axis(ax,"off");view(ax,3);
end
function value=asMap(input),if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end,end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
