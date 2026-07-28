classdef IOCoreTest < matlab.unittest.TestCase
    methods (Test)
        function inputFileReadWriteAndMSON(testCase)
            temporary=tempname;mkdir(temporary);
            cleanup=onCleanup(@()rmdir(temporary,"s"));
            source=fullfile(temporary,"source.in");
            writeText(source,"alpha"+newline+"beta");
            input=kssolv.analysis.matgenlab.io.InputFile. ...
                from_file(source);
            testCase.verifyEqual(input.get_str(),"alpha"+newline+"beta");
            destination=fullfile(temporary,"destination.in");
            input.write_file(destination);
            testCase.verifyEqual(string(fileread(destination)), ...
                "alpha"+newline+"beta");
            encoded=kssolv.analysis.matgenlab.util.encode(input);
            decoded=kssolv.analysis.matgenlab.util.decode(encoded);
            testCase.verifyClass(decoded, ...
                "kssolv.analysis.matgenlab.io.InputFile");
            testCase.verifyEqual(decoded.get_str(),input.get_str());
            clear cleanup
        end

        function inputSetMappingWriteAndArchive(testCase)
            first=kssolv.analysis.matgenlab.io.InputFile("first");
            inputs={"one.in",first;"two.in","second"};
            inputSet=kssolv.analysis.matgenlab.io.InputSet( ...
                inputs,"kwarg1",1,"kwarg2","hello");
            testCase.verifyEqual(length(inputSet),2);
            testCase.verifyEqual(inputSet("one.in").get_str(),"first");
            testCase.verifyEqual(inputSet.kwarg1,1);
            inputSet("three.in")="third";
            testCase.verifyEqual(length(inputSet),3);
            inputSet=inputSet.remove("three.in");
            testCase.verifyEqual(inputSet.keys(),{'one.in','two.in'});

            temporary=tempname;mkdir(temporary);
            cleanup=onCleanup(@()rmdir(temporary,"s"));
            inputSet.write_input(temporary);
            testCase.verifyEqual(string(fileread( ...
                fullfile(temporary,"one.in"))),"first");
            testCase.verifyEqual(string(fileread( ...
                fullfile(temporary,"two.in"))),"second");
            testCase.verifyError(@()inputSet.write_input( ...
                temporary,"overwrite",false), ...
                "KSSOLV:Matgenlab:InputSet:Exists");
            inputSet.write_input(temporary,"zip_inputs",true);
            archive=fullfile(temporary,"InputSet.zip");
            testCase.verifyTrue(isfile(archive));
            testCase.verifyFalse(isfile(fullfile(temporary,"one.in")));
            extraction=tempname;mkdir(extraction);
            extractionCleanup=onCleanup(@()rmdir(extraction,"s"));
            unzip(archive,extraction);
            testCase.verifyEqual(string(fileread( ...
                fullfile(extraction,"one.in"))),"first");
            clear extractionCleanup cleanup
        end

        function inputSetMSONAndAbstractBoundaries(testCase)
            inputSet=kssolv.analysis.matgenlab.io.InputSet( ...
                {"a",kssolv.analysis.matgenlab.io.InputFile("A"); ...
                "b","B"},"foo","bar");
            encoded=kssolv.analysis.matgenlab.util.encode(inputSet);
            decoded=kssolv.analysis.matgenlab.util.decode(encoded);
            testCase.verifyClass(decoded, ...
                "kssolv.analysis.matgenlab.io.InputSet");
            testCase.verifyEqual(decoded.foo,'bar');
            testCase.verifyEqual(decoded("a").get_str(),"A");
            testCase.verifyEqual(decoded("b"),'B');
            testCase.verifyError(@()inputSet.validate(), ...
                "KSSOLV:Matgenlab:InputSet:AbstractValidate");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.InputSet. ...
                from_directory("unused"), ...
                "KSSOLV:Matgenlab:InputSet:AbstractFromDirectory");
            generator=kssolv.analysis.matgenlab.io.InputGenerator();
            testCase.verifyError(@()generator.get_input_set(), ...
                "KSSOLV:Matgenlab:InputGenerator:Abstract");
            parseError=kssolv.analysis.matgenlab.io.ParseError("bad token");
            testCase.verifyEqual(parseError.as_exception().identifier, ...
                'KSSOLV:Matgenlab:ParseError');
        end

        function traversalAndMissingDirectoryFailClosed(testCase)
            inputSet=kssolv.analysis.matgenlab.io.InputSet( ...
                {"../escape","bad"});
            temporary=tempname;mkdir(temporary);
            cleanup=onCleanup(@()rmdir(temporary,"s"));
            testCase.verifyError(@()inputSet.write_input(temporary), ...
                "KSSOLV:Matgenlab:InputSet:UnsafePath");
            absent=tempname;
            safe=kssolv.analysis.matgenlab.io.InputSet({"a","A"});
            testCase.verifyError(@()safe.write_input( ...
                absent,"make_dir",false), ...
                "KSSOLV:Matgenlab:InputSet:MissingDirectory");
            clear cleanup
        end
    end
end

function writeText(path,text)
fileId=fopen(path,"wt","n","UTF-8");
cleanup=onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",text);
clear cleanup
end
