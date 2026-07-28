function output=site_weighted_spectrum(spectra,numSamples)
%SITE_WEIGHTED_SPECTRUM Average site spectra by symmetry multiplicity.
if nargin<2||isempty(numSamples),numSamples=500;end
if ~iscell(spectra),spectra=num2cell(spectra);end
matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
groups=matcher.group_structures( ...
    cellfun(@(spectrum)spectrum.structure,spectra, ...
    UniformOutput=false));
if numel(groups)>1
    error("KSSOLV:Matgenlab:XAS:Structures", ...
        "The input structures mismatch.");
end
elements=cellfun(@(spectrum)string( ...
    spectrum.absorbing_element.symbol),spectra);
edges=cellfun(@(spectrum)spectrum.edge,spectra);
indices=cellfun(@(spectrum)spectrum.absorbing_index, ...
    spectra,UniformOutput=false);
if numel(unique(elements))~=1||numel(unique(edges))~=1
    error("KSSOLV:Matgenlab:XAS:Metadata", ...
        "Spectra must share absorbing element and edge.");
end
if any(cellfun(@isempty,indices))|| ...
        isscalar(unique(cell2mat(indices)))
    error("KSSOLV:Matgenlab:XAS:SiteSpectra", ...
        "At least two distinct site-wise spectra are required.");
end
analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(spectra{1}.structure);
symmetrized=analyzer.get_symmetrized_structure();
lower=max(cellfun(@(spectrum)min(spectrum.x),spectra));
upper=min(cellfun(@(spectrum)max(spectrum.x),spectra));
x=linspace(lower,upper,numSamples).';
multiplicities=zeros(1,numel(spectra));
values=zeros(numSamples,numel(spectra));
for index=1:numel(spectra)
    spectrum=spectra{index};
    sites=symmetrized.find_equivalent_sites( ...
        symmetrized.sites{spectrum.absorbing_index});
    multiplicities(index)=numel(sites);
    values(:,index)=interp1( ...
        spectrum.x,spectrum.y,x,"spline",0);
end
y=values*(multiplicities(:)/sum(multiplicities));
last=spectra{end};
output=kssolv.analysis.matgenlab.analysis.XAS( ...
    x,y,symmetrized,last.absorbing_element,last.edge,last.spectrum_type);
end
