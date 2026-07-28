function symbols=needs_u_correction(composition,varargin)
%NEEDS_U_CORRECTION Elements that trigger MP2020 Hubbard-U mixing.
if ~isa(composition,"kssolv.analysis.matgenlab.core.Composition")
    composition=kssolv.analysis.matgenlab.core.Composition(composition);
end
options=struct(u_config=[]);
options=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
    options(options,varargin);
if isempty(options.u_config) %#ok<ALIGN>
    config=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
        config_data("MP2020");
    uConfig=config.Corrections.GGAUMixingCorrections;
else,uConfig=options.u_config;end
elements=string(cellfun(@(item)item.symbol,composition.elements, ...
    "UniformOutput",false));
anions=intersect(elements,string(fieldnames(uConfig)),"stable");
cations=intersect(elements,string(fieldnames(uConfig.O)),"stable");
if isempty(anions)||isempty(cations),symbols=strings(1,0);
else,symbols=unique([cations,anions],"stable");end
end
