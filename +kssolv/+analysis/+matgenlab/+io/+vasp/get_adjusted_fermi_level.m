function value = get_adjusted_fermi_level(efermi,cbm,band_structure,energy_step)
%GET_ADJUSTED_FERMI_LEVEL Raise a misplaced Fermi level without crossing CBM.
if nargin < 4, energy_step = 0.01; end
value = efermi;
if ~band_structure.is_metal(), return; end
names = fieldnames(band_structure.bands);
while value < cbm
    value = value + energy_step;
    isMetal = false;
    for index = 1:numel(names)
        bands = band_structure.bands.(names{index});
        relative = bands - value;
        if any(any(relative < -1e-4, 2) & any(relative > 1e-4, 2))
            isMetal = true;
            break
        end
    end
    if ~isMetal, return; end
end
value = efermi;
end
