classdef GeometryParameterProviderTest < matlab.unittest.TestCase
    %GEOMETRYPARAMETERPROVIDERTEST Traceable ideal-geometry parameters.

    methods (Test)
        function resolvesTypedBondOrders(testCase)
            single = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond("C", "O", 1);
            double = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond("O", "C", 2);
            oxygenHydrogen = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond("O", "H", 1);

            testCase.verifyEqual(single.value, 1.43, "AbsTol", 1e-12);
            testCase.verifyEqual(double.value, 1.23, "AbsTol", 1e-12);
            testCase.verifyEqual(oxygenHydrogen.value, 0.96, "AbsTol", 1e-12);
            testCase.verifyEqual(single.source, ...
                "frozen-pymatgen-bond-lengths");
            testCase.verifyFalse(single.fallback);
            testCase.verifyFalse(single.isEnergyModel);
        end

        function aromaticParametersAreExplicit(testCase)
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond("C", "C", 1.5);
            testCase.verifyEqual(parameter.value, 1.397, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(parameter.source, ...
                "kssolv-aromatic-bond-parameters-v1");
            testCase.verifyFalse(parameter.fallback);
        end

        function missingTypedParameterReportsFallback(testCase)
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.bond("Xe", "Xe", 1);
            testCase.verifyTrue(parameter.fallback);
            testCase.verifyEqual(parameter.source, "atomic-radius-fallback");
            testCase.verifyGreaterThan(parameter.value, 0);
            testCase.verifyNotEmpty(parameter.message);
        end

        function atomTypingIsExplicitAndTraceable(testCase)
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.atom("C", [1.5, 1.5, 1]);
            testCase.verifyEqual(parameter.atomType, "C.sp2-aromatic");
            testCase.verifyEqual(parameter.coordination, 3);
            testCase.verifyEqual(parameter.source, ...
                "kssolv-valence-typing-rules-v2");
            testCase.verifyFalse(parameter.fallback);
        end

        function constructionBondTableIsTraceableAndOrderStable(testCase)
            parameters = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.constructionBonds( ...
                ["C", "O", "C"], ["O", "C"], [1, 2]);
            testCase.verifyNumElements(parameters, 6);
            keys = string({parameters.firstElement}) + "|" + ...
                string({parameters.secondElement}) + "|" + ...
                string([parameters.bondOrder]);
            testCase.verifyEqual(numel(unique(keys)), numel(keys));
            carbonOxygen = parameters( ...
                string({parameters.firstElement}) == "C" & ...
                string({parameters.secondElement}) == "O" & ...
                [parameters.bondOrder] == 1);
            testCase.verifyEqual(carbonOxygen.value, 1.43, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(carbonOxygen.unit, "angstrom");
            testCase.verifyEqual(carbonOxygen.parameterSet, ...
                "kssolv-generic-mm-parameters-v2");
            testCase.verifyEqual(carbonOxygen.source, ...
                "frozen-pymatgen-bond-lengths");
            testCase.verifyFalse(carbonOxygen.fallback);
        end

        function angleTorsionAndNonbondedParametersAreAuditable(testCase)
            angle = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.angle("H", "O", "H", [1, 1]);
            torsion = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.torsion( ...
                "C", "C", "C", "C", 1);
            nonbonded = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.nonbonded("H", "H");

            testCase.verifyEqual(angle.value, 104.5, "AbsTol", 1e-12);
            testCase.verifyEqual(angle.unit, "degree");
            testCase.verifyGreaterThan(angle.forceConstant, 0);
            testCase.verifyEqual(torsion.periodicity, 3);
            testCase.verifyEqual(torsion.forceConstantUnit, "kJ/mol");
            testCase.verifyGreaterThan(nonbonded.cutoff, 0);
            testCase.verifyEqual(nonbonded.source, ...
                "kssolv-short-range-repulsion-v2");
            testCase.verifyEqual(angle.schemaVersion, 2);
            testCase.verifyEqual(angle.parameterSet, ...
                "kssolv-generic-mm-parameters-v2");
        end
    end
end
