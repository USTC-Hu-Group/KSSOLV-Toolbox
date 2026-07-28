function draw_network(graph,pos,ax,varargin)
%DRAW_NETWORK Draw a compact environment multigraph.
opts=parseNamed(struct(sg=[],periodicity_vectors=[]),varargin{:}); %#ok<NASGU>
hold(ax,"on");
for ii=1:numel(graph.nodes)
    plot(ax,pos(ii,1),pos(ii,2),"o","MarkerSize",10, ...
        "MarkerFaceColor",[.4 .7 1]);
    text(ax,pos(ii,1),pos(ii,2),string(graph.nodes{ii}.isite), ...
        "HorizontalAlignment","center");
end
for edge=graph.edges
    color=[0 0 0];if any(edge.delta~=0),color=[.8 0 0];end
    plot(ax,pos([edge.u edge.v],1),pos([edge.u edge.v],2), ...
        "-","Color",color);
end
axis(ax,"equal");axis(ax,"off");
end
function opts=parseNamed(opts,varargin)
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
