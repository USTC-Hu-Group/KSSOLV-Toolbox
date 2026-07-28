classdef LightweightFormatsTest < matlab.unittest.TestCase
    methods (Test)
        function cssrMatchesFrozenPymatgen(testCase)
            structure=sampleStructure();
            cssr=kssolv.analysis.matgenlab.io.Cssr(structure);
            expected=join([ ...
                "4.2000 4.2000 4.2000", ...
                "90.00 90.00 90.00 SPGR =  1 P 1    OPT = 1", ...
                "2 0","0 Cs1 Cl1", ...
                "1 Cs 0.0000 0.0000 0.0000", ...
                "2 Cl 0.5000 0.5000 0.5000"],newline);
            testCase.verifyEqual(string(cssr),expected);
            testCase.verifyEqual(structure.to("","cssr"),expected);
            restored=kssolv.analysis.matgenlab.io.Cssr. ...
                from_str(expected).structure;
            verifyStructure(testCase,restored,structure);
            verifyStructure(testCase,kssolv.analysis.matgenlab.core. ...
                Structure.from_str(expected,"cssr"),structure);
            path=string(tempname)+".cssr.gz";
            cleanup=onCleanup(@()deleteIfPresent(path));
            cssr.write_file(path);
            restored=kssolv.analysis.matgenlab.io.Cssr. ...
                from_file(path).structure;
            verifyStructure(testCase,restored,structure);
            clear cleanup
        end

        function mcsqsMatchesFrozenPymatgen(testCase)
            structure=sampleStructure();
            writer=kssolv.analysis.matgenlab.io.Mcsqs(structure);
            expected=join([ ...
                "4.200000 0.000000 0.000000", ...
                "0.000000 4.200000 0.000000", ...
                "0.000000 0.000000 4.200000", ...
                "1.0 0.0 0.0","0.0 1.0 0.0","0.0 0.0 1.0", ...
                "0.000000 0.000000 0.000000 Cs=1", ...
                "0.500000 0.500000 0.500000 Cl=1"],newline);
            testCase.verifyEqual(writer.to_str(),expected);
            testCase.verifyEqual(structure.to("","mcsqs"),expected);
            restored=kssolv.analysis.matgenlab.io.Mcsqs. ...
                structure_from_str(expected);
            verifyStructure(testCase,restored,structure);
            parameterForm=join([ ...
                "4.2 4.2 4.2 90 90 90", ...
                "1 0 0","0 1 0","0 0 1", ...
                "0 0 0 Cs","0.5 0.5 0.5 Cl"],newline);
            restored=kssolv.analysis.matgenlab.io.Mcsqs. ...
                structure_from_str(parameterForm);
            verifyStructure(testCase,restored,structure);
        end

        function jarvisAdaptorRoundTrip(testCase)
            structure=sampleStructure();
            atoms=kssolv.analysis.matgenlab.io. ...
                JarvisAtomsAdaptor.get_atoms(structure);
            testCase.verifyEqual(atoms.elements,{'Cs','Cl'});
            testCase.verifyEqual(atoms.frac_coords,structure.frac_coords);
            restored=kssolv.analysis.matgenlab.io. ...
                JarvisAtomsAdaptor.get_structure(atoms);
            verifyStructure(testCase,restored,structure);
            cartesian=rmfield(atoms,"frac_coords");
            cartesian.coords=structure.cart_coords;
            cartesian.cartesian=true;
            restored=kssolv.analysis.matgenlab.io. ...
                JarvisAtomsAdaptor.get_structure(cartesian);
            verifyStructure(testCase,restored,structure);
        end

        function prismaticMatchesFrozenPymatgen(testCase)
            structure=sampleStructure();
            text=kssolv.analysis.matgenlab.io. ...
                Prismatic(structure,"oracle").to_str();
            expected=join(["oracle","4.2 4.2 4.2", ...
                "55 0.0 0.0 0.0 1 0.1", ...
                "17 2.1 2.1 2.1 1 0.2","-1"],newline);
            testCase.verifyEqual(text,expected);
        end

        function templateGeneratorSafelySubstitutes(testCase)
            path=string(tempname)+".in";
            cleanup=onCleanup(@()deleteIfPresent(path));
            fid=fopen(path,"w","n","UTF-8");
            fprintf(fid,"T=$TEMPERATURE\nP=${PRESSURE}\nX=$UNKNOWN\n");
            fclose(fid);
            generator=kssolv.analysis.matgenlab.io.TemplateInputGen();
            inputSet=generator.get_input_set(path, ...
                struct("TEMPERATURE",298,"PRESSURE",2),"run.in");
            testCase.verifyEqual(string(inputSet("run.in")), ...
                "T=298"+newline+"P=2"+newline+"X=$UNKNOWN"+newline);
            clear cleanup
        end

        function xrCoreShellParsingAndRoundTrip(testCase)
            fixture=fullfile(fileparts(mfilename("fullpath")), ...
                "+fixtures","+xr","EDI.xr");
            cores=kssolv.analysis.matgenlab.io.Xr.from_file(fixture);
            shells=kssolv.analysis.matgenlab.io.Xr.from_file( ...
                fixture,false);
            testCase.verifyEqual(cores.structure.num_sites,15);
            testCase.verifyEqual(shells.structure.num_sites,15);
            testCase.verifyEqual(cores.structure.reduced_formula,"SiO2");
            testCase.verifyEqual(cores.structure(6).coords, ...
                [1.29725,1.31488,6.3468],AbsTol=1e-12);
            testCase.verifyEqual(shells.structure(6).coords, ...
                [1.21428,1.23192,6.3468],AbsTol=1e-12);
            structure=sampleStructure();
            writer=kssolv.analysis.matgenlab.io.Xr(structure);
            restored=kssolv.analysis.matgenlab.io.Xr. ...
                from_str(string(writer)).structure;
            verifyStructure(testCase,restored,structure);
            path=string(tempname)+".xr.gz";
            cleanup=onCleanup(@()deleteIfPresent(path));
            writer.write_file(path);
            restored=kssolv.analysis.matgenlab.io.Xr. ...
                from_file(path).structure;
            verifyStructure(testCase,restored,structure);
            clear cleanup
        end
    end
end

function structure=sampleStructure()
structure=kssolv.analysis.matgenlab.core.Structure( ...
    kssolv.analysis.matgenlab.core.Lattice.cubic(4.2), ...
    {"Cs","Cl"},[0,0,0;.5,.5,.5], ...
    site_properties=struct("thermal_sigma",[.1,.2]));
end

function verifyStructure(testCase,actual,expected)
testCase.verifyEqual(actual.lattice.matrix,expected.lattice.matrix, ...
    AbsTol=1e-12);
testCase.verifyEqual(actual.frac_coords,expected.frac_coords, ...
    AbsTol=1e-12);
testCase.verifyEqual(cellfun(@(site)site.specie.symbol,actual.sites), ...
    cellfun(@(site)site.specie.symbol,expected.sites));
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end
