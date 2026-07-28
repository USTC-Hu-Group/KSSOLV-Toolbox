function ax=plot_brillouin_zone(lattice,lines,labels,varargin)
%PLOT_BRILLOUIN_ZONE Plot reciprocal-space line segments and labels.
if nargin<2||isempty(lines),lines={};end
if nargin<3||isempty(labels)
    labels=containers.Map("KeyType","char","ValueType","any");
end
fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
for index=1:numel(lines)
    segment=lines{index};
    if iscell(segment),segment=cell2mat(segment(:));end
    cartesian=double(segment)*lattice.matrix;
    plot3(ax,cartesian(:,1),cartesian(:,2),cartesian(:,3), ...
        "-o",varargin{:});
end
if isa(labels,"containers.Map")
    keys=labels.keys;
    for index=1:numel(keys)
        point=reshape(double(labels(keys{index})),1,3)*lattice.matrix;
        text(ax,point(1),point(2),point(3),keys{index});
    end
elseif isstruct(labels)
    keys=fieldnames(labels);
    for index=1:numel(keys)
        point=reshape(double(labels.(keys{index})),1,3)*lattice.matrix;
        text(ax,point(1),point(2),point(3),keys{index});
    end
end
axis(ax,"equal");grid(ax,"on");hold(ax,"off");
end
