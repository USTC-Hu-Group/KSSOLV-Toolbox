function test_prototypes_matlab()
%TEST_PROTOTYPES_MATLAB Frozen pymatgen prototype parity regression.
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
oracle=jsondecode(fileread(fullfile(root,"dev","matgenlab","oracles", ...
    "prototypes_2026.7.24.json")));
import kssolv.analysis.matgenlab.analysis.prototypes.*
import kssolv.analysis.matgenlab.core.*
import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer

% Frozen upstream utility oracles.
assert(get_prototype_formula_from_composition(Composition("Ce2Al3GaPd4"))== ...
    "A3B2CD4");
assert(get_prototype_formula_from_composition(Composition("YbNiO3"))=="AB3C");
assert(get_prototype_formula_from_composition(Composition("K2NaAlF6"))=="AB6C2D");
assert(get_anonymous_formula_from_prototype_formula("AB")=="AB");
assert(get_anonymous_formula_from_prototype_formula("A2B")=="AB2");
assert(get_anonymous_formula_from_prototype_formula("A3B2CD4")=="AB2C3D4");
assert(get_formula_from_protostructure_label( ...
    "AB3C_oP20_62_c_cd_a:Ni-O-Yb")=="NiO3Yb");
assert(count_wyckoff_positions( ...
    "ABC6D2_mC40_15_e_e_3f_f:Ca-Fe-O-Si")==6);
assert(count_wyckoff_positions( ...
    "A6B11CD7_aP50_2_6i_ac10i_i_7i:C-H-N-O")==26);
assert(count_wyckoff_positions("foo_bar_47_abc_A_b:X-Y-Z")==5);
assert(count_distinct_wyckoff_letters( ...
    "ABC6D2_mC40_15_e_e_3f_f:Ca-Fe-O-Si")==2);
assert(count_crystal_dof("ABC6D2_mC40_15_e_e_3f_f:Ca-Fe-O-Si")==18);
assert(count_crystal_sites("ABC6D2_mC40_15_e_e_3f_f:Ca-Fe-O-Si")==40);
splitValue=split_alpha_numeric("12ab3c");
assert(isequal(splitValue.alpha,["ab","c"]));
assert(isequal(splitValue.numeric,["12","3"]));
lookup=struct("x1",struct("a",4,"b",8));
assert(count_values_for_wyckoff(["a","b"],["2","1"],1,lookup)==16);

for index=1:numel(oracle.prototype_cases)
    testCase=oracle.prototype_cases(index);
    assert(get_prototype_from_protostructure(testCase.label)== ...
        testCase.prototype);
end
for index=1:numel(oracle.assignment_cases)
    testCase=oracle.assignment_cases(index);
    actual=get_protostructures_from_aflow_label_and_composition( ...
        testCase.aflow,Composition(testCase.composition));
    expected=reshape(string(testCase.labels),1,[]);
    assert(isequal(sort(actual),sort(expected)));
    for label=actual
        assert(get_prototype_from_protostructure(label)==testCase.aflow);
    end
end

% Official simple structures and exact upstream labels.
structures=simpleStructures();
for index=1:numel(structures)
    expected=string(oracle.simple_labels(index));
    actual=get_protostructure_label_from_spglib(structures{index});
    assert(actual==expected,"Unexpected spglib label: "+actual);
    assert(get_protostructure_label(structures{index},"spglib")==expected);
    assert(get_protostructure_label_from_moyopy(structures{index})==expected);
end
analyzer=SpacegroupAnalyzer(structures{1},0.1,5);
assert(get_protostructure_label_from_spg_analyzer(analyzer)== ...
    string(oracle.simple_labels(1)));

% Official U2Pa4Tc6 precision-recovery edge case.
edge=edgeStructure();
coarse=SpacegroupAnalyzer(edge,0.1,5);
assert(get_protostructure_label_from_spg_analyzer(coarse)== ...
    string(oracle.edge_invalid));
verifyError(@()get_protostructure_label_from_spg_analyzer(coarse,true), ...
    "KSSOLV:Matgenlab:Prototypes:InvalidMultiplicities");
assert(get_protostructure_label_from_spglib( ...
    edge,false,0.1,[])==string(oracle.edge_invalid));
assert(get_protostructure_label_from_spglib(edge)== ...
    string(oracle.edge_recovered));

% Frozen data and matcher integration.
library=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    load_data("aflow");
assert(numel(library)==288);
matcher=AflowPrototypeMatcher();
prototype=Structure.from_dict(library(1).snl);
matches=matcher.get_prototypes(prototype);
assert(isscalar(matches));
assert(string(matches{1}.tags.aflow)=="AB_hP6_154_a_b");
assert(string(matches{1}.tags.mineral)=="Cinnabar");

% Optional/external upstream boundaries are explicit and stable.
fakeAflow=createFakeAflow();
fakeCleanup=onCleanup(@()delete(fakeAflow));
assert(get_protostructure_label_from_aflow( ...
    structures{1},false,fakeAflow)==string(oracle.simple_labels(1)));
clear fakeCleanup
verifyError(@()get_protostructure_label_from_aflow( ...
    structures{1},false,"/definitely/missing/aflow"), ...
    "KSSOLV:Matgenlab:Prototypes:AflowNotFound");
verifyError(@()get_random_structure_for_protostructure( ...
    "AB_cP2_221_a_b:Cl-Cs"), ...
    "KSSOLV:Matgenlab:Prototypes:PyXtalUnavailable");
generated=get_random_structure_for_protostructure( ...
    "AB_cP2_221_a_b:Cl-Cs","seed",7, ...
    "backend",@(request)fakePyXtal(request,structures{2}));
assert(generated==structures{2});
verifyError(@()get_protostructure_label(structures{1},"invalid"), ...
    "KSSOLV:Matgenlab:Prototypes:Method");

fprintf("test_prototypes_matlab: all checks passed.\n");
end

function structures=simpleStructures()
import kssolv.analysis.matgenlab.core.Lattice
import kssolv.analysis.matgenlab.core.Structure
structures=cell(1,6);
structures{1}=Structure([2,2,0;0,2,2;2,0,2], ...
    {"Na","Cl"},[0,0,0;.5,.5,.5]);
structures{2}=Structure(4*eye(3),{"Cs","Cl"},[0,0,0;.5,.5,.5]);
structures{3}=Structure([2,2,0;0,2,2;2,0,2], ...
    {"Zn","O"},[0,0,0;.25,.25,.25]);
lattice=Lattice.from_parameters(3.8227,3.8227,6.2607,90,90,120);
structures{4}=Structure(lattice,{"Zn","O","Zn","O"}, ...
    [1/3,2/3,0;2/3,1/3,.3748;2/3,1/3,.5;1/3,2/3,.8748]);
structures{5}=Structure(3.9*eye(3),{"Sr","Ti","O","O","O"}, ...
    [0,0,0;.5,.5,.5;.5,.5,0;.5,0,.5;0,.5,.5]);
structures{6}=Structure(5.76*eye(3), ...
    {"Al","Fe","Fe","Fe","Al","Fe","Fe","Fe"}, ...
    [0,0,0;.25,.25,.25;.5,.5,0;.75,.75,.25;0,.5,.5; ...
    .25,.75,.75;.5,0,.5;.75,.25,.75]);
end

function structure=edgeStructure()
import kssolv.analysis.matgenlab.core.Structure
lattice=[5.989671,0.00015953,7.795e-05; ...
    0.00021958,8.25008569,-0.03720131; ...
    -2.99487801,-4.14847393,5.20632921];
species={"U","U","Pa","Pa","Pa","Pa", ...
    "Tc","Tc","Tc","Tc","Tc","Tc"};
coordinates=[ ...
    .49997316,.25000333,.50000537; ...
    .50002684,.74999667,.49999463; ...
    .16664895,.91662717,.83327202; ...
    .16662875,.41663202,.83327108; ...
    .83337125,.58336798,.16672892; ...
    .83335105,.08337283,.16672798; ...
    .00000051,.74999811,.99999918; ...
    .99999949,.25000189,.00000082; ...
    .49999907,.74998284,.99999871; ...
    0,0,.5;0,.5,.5; ...
    .50000093,.25001716,.00000129];
structure=Structure(lattice,species,coordinates);
end

function verifyError(action,identifier)
try
    action();
catch exception
    assert(string(exception.identifier)==identifier);
    return
end
error("KSSOLV:Matgenlab:Tests:ExpectedError", ...
    "Expected error %s was not raised.",identifier);
end

function structure=fakePyXtal(request,structure)
assert(request.protostructure_label=="AB_cP2_221_a_b:Cl-Cs");
assert(request.kwargs.seed==7);
end

function path=createFakeAflow()
path=string(tempname);
handle=fopen(path,"w");
assert(handle>=0);
cleanup=onCleanup(@()fclose(handle));
fprintf(handle,"#!/bin/sh\n");
fprintf(handle,"cat >/dev/null\n");
fprintf(handle,"printf '");
fprintf(handle,'{"aflow_prototype_label":"AB_cF8_225_a_b"}');
fprintf(handle,"'\n");
clear cleanup
[status,~]=system("chmod 700 "+path);
assert(status==0);
end
