function value = diffraction_data(name)
%DIFFRACTION_DATA Load immutable, generated diffraction coefficients.
persistent xray neutron
switch string(name)
    case "xray"
        if isempty(xray)
            here = fileparts(mfilename("fullpath"));
            xray = jsondecode(fileread(fullfile( ...
                here, "+data", "atomic_scattering_params.json")));
        end
        value = xray;
    case "neutron"
        if isempty(neutron)
            here = fileparts(mfilename("fullpath"));
            neutron = jsondecode(fileread(fullfile( ...
                here, "+data", "neutron_scattering_length.json")));
        end
        value = neutron;
    otherwise
        error("KSSOLV:Matgenlab:Diffraction:Data", ...
            "Unknown diffraction table '%s'.", name);
end
end
