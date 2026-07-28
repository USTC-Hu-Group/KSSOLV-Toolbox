function value=compute_environments(configuration,varargin)
%COMPUTE_ENVIRONMENTS Compute ChemEnv results from a supplied structure.
opts=parseNamed(struct(structure=[],strategy=[],valences="undefined"), ...
    varargin{:});
if isempty(opts.structure)&&isprop(configuration,"structure")
    opts.structure=configuration.structure;
end
if isempty(opts.structure)
    error("KSSOLV:Matgenlab:ChemEnv:StructureRequired", ...
        "A structure must be supplied for non-interactive computation.");
end
finder=kssolv.analysis.matgenlab.analysis.chemenv. ...
    coordination_environments.LocalGeometryFinder();
finder.setup_parameters();
if isempty(opts.strategy)
    opts.strategy=kssolv.analysis.matgenlab.analysis.chemenv. ...
        coordination_environments.MultiWeightsChemenvStrategy. ...
        stats_article_weights_parameters();
end
value=finder.compute_coordination_environments(opts.structure, ...
    "strategy",opts.strategy,"valences",opts.valences);
end
function opts=parseNamed(opts,varargin)
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
