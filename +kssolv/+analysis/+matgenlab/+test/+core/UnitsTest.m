classdef UnitsTest < matlab.unittest.TestCase
    % Port of pymatgen-core v2026.7.24 tests/core/test_units.py.

    methods (Test)
        function constantsMatchCodata(testCase)
            C = kssolv.analysis.matgenlab.core.Constants;
            testCase.verifyEqual(C.e, 1.602176634e-19);
            testCase.verifyEqual(C.N_A, 6.02214076e23);
            testCase.verifyEqual(C.value("Bohr radius"), ...
                5.29177210544e-11);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.constants_value( ...
                "Boltzmann constant in eV/K"), ...
                8.617333262145179e-5);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Ha_to_eV(), ...
                27.21138624598059,RelTol=1e-15);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.bohr_to_angstrom(), ...
                0.529177210544,RelTol=1e-15);
        end

        function unitParsingAlgebraAndCanonicalization(testCase)
            Unit = @(value) kssolv.analysis.matgenlab.core.Unit(value);
            speed = Unit({ "m",1; "s",-1 });
            joule = Unit("kg m ^ 2 s ^ -2");
            testCase.verifyEqual(string(speed), "m s^-1");
            testCase.verifyEqual(length(speed), 2);
            testCase.verifyEqual(string(joule), "J");
            testCase.verifyEqual(string(speed * joule), "J m s^-1");
            testCase.verifyEqual(string(joule / speed), "J s m^-1");
            testCase.verifyEqual(string(speed / Unit("m")), "Hz");
            testCase.verifyEqual(string(speed * Unit("s")), "m");
            acceleration = speed / Unit("s");
            newton = Unit("kg") * acceleration;
            testCase.verifyEqual(string(newton * Unit("m")), "N m");
        end

        function baseUnitsAndConversions(testCase)
            Unit = @(value) kssolv.analysis.matgenlab.core.Unit(value);
            base = Unit("cm").as_base_units;
            testCase.verifyEqual(base.units, struct("m",1));
            testCase.verifyEqual(base.factor, 0.01, AbsTol=1e-15);
            base = Unit("N").as_base_units;
            testCase.verifyEqual(base.units, struct("kg",1,"m",1,"s",-2));
            testCase.verifyEqual(base.factor, 1);
            testCase.verifyEqual(Unit("cm^2").get_conversion_factor("m^2"), ...
                1e-4, RelTol=1e-14);
            testCase.verifyEqual(Unit("g").get_conversion_factor("kg"), ...
                1e-3, RelTol=1e-14);
            testCase.verifyError(@() ...
                Unit("m").get_conversion_factor("s"), ...
                "KSSOLV:Matgenlab:UnitError");
        end

        function scalarConversionsAndArithmetic(testCase)
            Energy = @(value,unit) ...
                kssolv.analysis.matgenlab.core.Energy(value,unit);
            a = Energy(1.1,"eV");
            testCase.verifyEqual(double(a.to("Ha")), ...
                0.0404242543932315, RelTol=1e-14);
            testCase.verifyEqual(double(Energy(3.14,"J").to("eV")), ...
                1.9598338493806797e19, RelTol=1e-12);
            d = Energy(1,"Ha");
            testCase.verifyEqual(double(a+d), 28.31138624598059, ...
                RelTol=1e-14);
            testCase.verifyEqual(double(a-d), -26.11138624598059, ...
                RelTol=1e-14);
            testCase.verifyEqual(a+1, 2.1, AbsTol=1e-15);
            testCase.verifyEqual(string(a/d), "1.1 eV Ha^-1");
            testCase.verifyError(@() Energy(1,"m"), ...
                "KSSOLV:Matgenlab:UnitError");
        end

        function compoundUnits(testCase)
            FWU = @(value,unit) ...
                kssolv.analysis.matgenlab.core.FloatWithUnit(value,unit);
            Time = @(value,unit) ...
                kssolv.analysis.matgenlab.core.Time(value,unit);
            Length = @(value,unit) ...
                kssolv.analysis.matgenlab.core.Length(value,unit);
            Mass = @(value,unit) ...
                kssolv.analysis.matgenlab.core.Mass(value,unit);
            acceleration = 9.81 * Length(1,"m") / Time(1,"s")^2;
            potential = Mass(1,"kg") * acceleration * Length(1,"m");
            testCase.verifyEqual(string(potential), "9.81 N m");
            formation = FWU(10,"kJ mol^-1").to("eV atom^-1");
            testCase.verifyEqual(double(formation), ...
                0.103642696562622, RelTol=1e-12);
            testCase.verifyEqual(string(formation.unit), "eV atom^-1");
            testCase.verifyError(@() formation.to("m s^-1"), ...
                "KSSOLV:Matgenlab:UnitError");
            cubic = FWU(1,"Ha^3").to("J^3");
            testCase.verifyEqual(double(cubic), 8.28672661615e-53, ...
                RelTol=2e-6);
            pressure = FWU(5,"MPa");
            testCase.verifyEqual(double(pressure.as_base_units), 5e6);
            testCase.verifyEqual(string(pressure.as_base_units.unit), "Pa");
        end

        function scalarAliasesParsingAndSupportedUnits(testCase)
            memory = ...
                kssolv.analysis.matgenlab.core.FloatWithUnit. ...
                from_str("+1.0 MB");
            testCase.verifyEqual(double(memory), 1);
            testCase.verifyEqual(memory.unit_type, "memory");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.core.FloatWithUnit.from_str("1"), ...
                "KSSOLV:Matgenlab:FloatWithUnit:MissingUnit");
            energy = kssolv.analysis.matgenlab.core.Energy(1.1,"eV");
            testCase.verifyEqual(energy.supported_units, ...
                ["eV","meV","Ha","Ry","J","kJ","kCal"]);
            memoryAlias = kssolv.analysis.matgenlab.core.Memory(1,"MB");
            testCase.verifyEqual(double(memoryAlias.to("byte")), 1024^2);
            parsedAlias = ...
                kssolv.analysis.matgenlab.core.Memory.from_str("1MB");
            testCase.verifyClass(parsedAlias, ...
                "kssolv.analysis.matgenlab.core.Memory");
        end

        function arrayArithmeticAndConversions(testCase)
            LengthArray = @(value,unit) ...
                kssolv.analysis.matgenlab.core.LengthArray(value,unit);
            TimeArray = @(value,unit) ...
                kssolv.analysis.matgenlab.core.TimeArray(value,unit);
            lengthArray = LengthArray([1,2,3],"m");
            testCase.verifyEqual(double(-lengthArray), [-1,-2,-3]);
            testCase.verifyEqual(double(lengthArray*2), [2,4,6]);
            testCase.verifyEqual(double(2*lengthArray), [2,4,6]);
            timeArray = TimeArray([3,4,5],"s");
            product = lengthArray * timeArray;
            testCase.verifyEqual(double(product), [3,8,15]);
            testCase.verifyEqual(string(product.unit), "m s");
            testCase.verifyEqual(product.unit_type, "");
            converted = lengthArray.to("km");
            testCase.verifyEqual(double(converted), [0.001,0.002,0.003], ...
                AbsTol=1e-15);
            testCase.verifyEqual(converted(2), 0.002, AbsTol=1e-15);
            testCase.verifyTrue(contains(lengthArray.conversions(), "km"));
            testCase.verifyError(@() lengthArray + timeArray, ...
                "KSSOLV:Matgenlab:UnitError");
        end

        function objectAssignmentAndMsonRoundTrip(testCase)
            scalar = kssolv.analysis.matgenlab.core.obj_with_unit(2.5,"eV");
            testCase.verifyClass(scalar, ...
                "kssolv.analysis.matgenlab.core.FloatWithUnit");
            array = kssolv.analysis.matgenlab.core.obj_with_unit([1,2,3],"m");
            testCase.verifyClass(array, ...
                "kssolv.analysis.matgenlab.core.ArrayWithUnit");
            nested = kssolv.analysis.matgenlab.core.obj_with_unit( ...
                struct("outer",struct("inner",1.0)),"eV");
            testCase.verifyClass(nested.outer.inner, ...
                "kssolv.analysis.matgenlab.core.FloatWithUnit");
            reconstructed = ...
                kssolv.analysis.matgenlab.core.FloatWithUnit. ...
                from_dict(scalar.as_dict());
            testCase.verifyEqual(double(reconstructed),double(scalar));
            testCase.verifyEqual(reconstructed.unit,scalar.unit);
            arrayRoundTrip = ...
                kssolv.analysis.matgenlab.core.ArrayWithUnit. ...
                from_dict(array.as_dict());
            testCase.verifyEqual(double(arrayRoundTrip),double(array));
            testCase.verifyEqual(arrayRoundTrip.unit,array.unit);
        end

        function unitizedFunction(testCase)
            wrapped = kssolv.analysis.matgenlab.core.unitized( ...
                "kg", @() kssolv.analysis.matgenlab.core. ...
                FloatWithUnit(5,"g"));
            result = wrapped();
            testCase.verifyEqual(double(result),0.005,AbsTol=1e-15);
            testCase.verifyEqual(string(result.unit),"kg");
        end
    end
end
