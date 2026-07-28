function value=get_effective_csm(nbSet,cnMap,se,additionalInfo, ...
    symmetryMeasureType,maxEffectiveCsm,ratioFunction) %#ok<INUSD>
%GET_EFFECTIVE_CSM Ratio-weighted CSM for a neighbor set.
envs=se.ce_list{nbSet.isite}(cnMap(1));
if cnMap(2)>numel(envs)||isempty(envs{cnMap(2)}),value=100;return,end
geometries=envs{cnMap(2)}.minimum_geometries( ...
    "symmetry_measure_type",symmetryMeasureType, ...
    "max_csm",maxEffectiveCsm);
csms=zeros(1,numel(geometries));
for ii=1:numel(geometries)
    csms(ii)=geometries{ii}{2}.other_symmetry_measures. ...
        (char(symmetryMeasureType));
end
if isempty(csms),value=100;else,value=ratioFunction.mean_estimator(csms);end
end
