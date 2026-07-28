classdef RuntimeUtilitiesTest < matlab.unittest.TestCase
    methods (Test)
        function dueCollectorIsSafeIdentity(testCase)
            collector=kssolv.analysis.matgenlab.util. ...
                InactiveDueCreditCollector();
            testCase.verifyFalse(collector.active);
            original=@(value)value+1;
            decorator=collector.dcite("10.1000/example");
            restored=decorator(original);
            testCase.verifyEqual(restored(2),3);
            testCase.verifyEqual(string(collector), ...
                "InactiveDueCreditCollector()");
        end

        function scopedRuntimeGuardsRestoreState(testCase)
            original=getenv("PYTHONWARNINGS");
            cleanup=kssolv.analysis.matgenlab.util. ...
                set_python_warnings("ignore");
            testCase.verifyEqual(getenv("PYTHONWARNINGS"),'ignore');
            clear cleanup
            testCase.verifyEqual(getenv("PYTHONWARNINGS"),original);

            marker=string(tempname);
            markerCleanup=onCleanup(@()deleteIfPresent(marker));
            cleanup=kssolv.analysis.matgenlab.util. ...
                tqdm_joblib(@()touch(marker));
            testCase.verifyFalse(isfile(marker));
            clear cleanup
            testCase.verifyTrue(isfile(marker));
            clear markerCleanup
        end

        function cleanLinesAndMicroPyawk(testCase)
            lines=kssolv.analysis.matgenlab.util.clean_lines( ...
                ["  alpha # comment"," ","  beta  "]);
            testCase.verifyEqual(lines,["alpha","beta"]);
            path=string(tempname)+".txt";
            cleanup=onCleanup(@()deleteIfPresent(path));
            fid=fopen(path,"w");
            fprintf(fid,"E=10\nskip\nE=7\n");
            fclose(fid);
            rules={'E=(\d+)',[],@accumulate};
            output=kssolv.analysis.matgenlab.util. ...
                micro_pyawk(path,rules,struct("total",0));
            testCase.verifyEqual(output.total,17);
            clear cleanup
        end

        function materialScienceTestHelpers(testCase)
            helper=kssolv.analysis.matgenlab.util.MatSciTest();
            structure=helper.get_structure("Graphite");
            testCase.verifyEqual(structure.reduced_formula,"C");
            helper.assert_str_content_equal("a b"+newline+"c","abc");
            composition=kssolv.analysis.matgenlab.core.Composition("Li2O");
            text=helper.assert_msonable(composition);
            testCase.verifyGreaterThan(strlength(text),0);
            testCase.verifyClass(jsondecode(text),"struct");
            restored=helper.serialize_with_pickle(42,[4,5]);
            testCase.verifyEqual(restored,{42,42});
            alias=kssolv.analysis.matgenlab.util.PymatgenTest();
            testCase.verifyClass(alias, ...
                "kssolv.analysis.matgenlab.util.PymatgenTest");
        end
    end
end

function output=accumulate(output,match)
output.total=output.total+str2double(match.tokens{1});
end

function touch(path)
fid=fopen(path,"w");
if fid>=0,fclose(fid);end
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end
