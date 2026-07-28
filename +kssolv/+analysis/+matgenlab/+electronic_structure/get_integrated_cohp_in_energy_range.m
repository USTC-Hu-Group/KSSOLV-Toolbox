function value=get_integrated_cohp_in_energy_range(cohp,label,orbital, ...
        energyRange,relativeEFermi,summedSpinChannels)
%GET_INTEGRATED_COHP_IN_ENERGY_RANGE Difference of interpolated ICOHP values.
if nargin<3,orbital=[];end
if nargin<4,energyRange=[];end
if nargin<5||isempty(relativeEFermi),relativeEFermi=true;end
if nargin<6||isempty(summedSpinChannels),summedSpinChannels=true;end
if isempty(orbital),curve=cohp.all_cohps(char(string(label)));
else,curve=cohp.get_orbital_resolved_cohp(label,orbital);end
if isempty(curve)||isempty(curve.icohp)
    error("KSSOLV:Matgenlab:Cohp:MissingIcohp","ICOHP data are required.");
end
mapping=curve.icohp;
if summedSpinChannels&&isfield(mapping,"down")
    mapping=struct("up",mapping.up+mapping.down);
end
energies=cohp.energies;if relativeEFermi,energies=energies-cohp.efermi;end
if isempty(energyRange)
    bounds=[0,0];
elseif isscalar(energyRange)
    if relativeEFermi
        bounds=[double(energyRange),0];
    else
        bounds=[double(energyRange),cohp.efermi];
    end
else
    bounds=reshape(double(energyRange),1,2);
end
names=fieldnames(mapping);result=struct();
for ii=1:numel(names)
    upper=interp1(energies,mapping.(names{ii}),bounds(2),"spline",0);
    if isempty(energyRange),number=upper;
    else,number=upper-interp1(energies,mapping.(names{ii}),bounds(1),"spline",0);end
    result.(names{ii})=number;
end
if summedSpinChannels,value=result.up;else,value=result;end
end
