function motif=site_is_of_motif_type(structure,n,varargin)
%#ok<*ALIGN>
%SITE_IS_OF_MOTIF_TYPE Classify common coordination motifs.
options=struct(approach="min_dist",delta=.1,cutoff=10,thresh=[]);
options=parse(options,varargin);
thresholds=options.thresh;
if isempty(thresholds)
    thresholds=struct(qtet=.5,qoct=.5,qbcc=.5,q6=.4, ...
        qtribipyr=.8,qsqpyr=.8);
end
neighbors=kssolv.analysis.matgenlab.core.get_neighbors_of_site_with_index( ...
    structure,n,options.approach,options.delta,options.cutoff);
sites=[neighbors,{structure(n)}];
op=kssolv.analysis.matgenlab.core.LocalStructOrderParams( ...
    {"cn","tet","oct","bcc","q6","sq_pyr","tri_bipyr"});
[values,~]=op.get_order_parameters(sites,numel(sites), ...
    "indices_neighs",1:numel(neighbors));
cn=round(values(1));motif="unrecognized";matches=0;
if cn==4&&values(2)>thresholds.qtet,motif="tetrahedral";matches=matches+1;end
if cn==5&&values(6)>thresholds.qsqpyr,motif="square pyramidal";matches=matches+1;end
if cn==5&&values(7)>thresholds.qtribipyr,motif="trigonal bipyramidal";matches=matches+1;end
if cn==6&&values(3)>thresholds.qoct,motif="octahedral";matches=matches+1;end
if cn==8&&values(4)>thresholds.qbcc&&values(2)<thresholds.qtet
    motif="bcc";matches=matches+1;
end
if cn==12&&values(5)>thresholds.q6&&all(values(2:4)<thresholds.q6)
    motif="cp";matches=matches+1;
end
if matches>1,motif="multiple assignments";end
end
function output=parse(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;end
end
end
