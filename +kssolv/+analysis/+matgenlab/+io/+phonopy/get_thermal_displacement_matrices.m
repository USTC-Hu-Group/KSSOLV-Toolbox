function result=get_thermal_displacement_matrices(yamlPath,structurePath)
%GET_THERMAL_DISPLACEMENT_MATRICES Read phonopy thermal displacement YAML.
if nargin<1||isempty(yamlPath)
    yamlPath="thermal_displacement_matrices.yaml";
end
if nargin<2||isempty(structurePath),structurePath="POSCAR";end
data=kssolv.analysis.matgenlab.util.yaml_load(yamlPath);
structure=kssolv.analysis.matgenlab.core.Structure. ...
    from_file(structurePath,"poscar");
records=kssolv.analysis.matgenlab.io.phonopy.phonopy_records( ...
    kssolv.analysis.matgenlab.io.phonopy.phonopy_field( ...
    data,"thermal_displacement_matrices"));
result=cell(1,numel(records));
for index=1:numel(records)
    record=records{index};
    cart=kssolv.analysis.matgenlab.io.phonopy. ...
        phonopy_field(record,"displacement_matrices");
    cif=kssolv.analysis.matgenlab.io.phonopy. ...
        phonopy_field(record,"displacement_matrices_cif");
    temperature=kssolv.analysis.matgenlab.io.phonopy. ...
        phonopy_field(record,"temperature");
    result{index}=kssolv.analysis.matgenlab.phonon. ...
        ThermalDisplacementMatrices(cart,structure,temperature,cif);
end
end
