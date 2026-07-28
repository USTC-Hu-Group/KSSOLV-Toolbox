classdef PhononInventoryTest < matlab.unittest.TestCase
    % Resolve every frozen phonon inventory row to tested MATLAB coverage.

    methods (Test)
        function frozenInventoryLedgerIsComplete(testCase)
            inventory=fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev","matgenlab","inventory","api.csv");
            options=detectImportOptions(inventory,"TextType","string");
            rows=readtable(inventory,options);
            rows=rows(startsWith(rows.module,"pymatgen.phonon"),:);
            testCase.verifyEqual(height(rows),139);

            recognized=false(height(rows),1);
            for index=1:height(rows)
                qualified=split(rows.qualname(index),".");
                if rows.module(index)=="pymatgen.phonon"
                    if rows.qualname(index)=="annotations"
                        recognized(index)=true;
                    else
                        target="kssolv.analysis.matgenlab.phonon."+ ...
                            rows.qualname(index);
                        recognized(index)=exist(target,"class")==8 || ...
                            ~isempty(which(target));
                    end
                    continue
                end
                className=qualified(1);
                target="kssolv.analysis.matgenlab.phonon."+className;
                if rows.kind(index)=="function"
                    recognized(index)=~isempty(which(target));
                elseif rows.kind(index)=="class"
                    recognized(index)=exist(target,"class")==8;
                elseif rows.kind(index)=="method"
                    recognized(index)=any(string(methods(char(target)))== ...
                        qualified(2)) || ...
                        any(string(properties(char(target)))==qualified(2));
                elseif rows.kind(index)=="property"
                    recognized(index)=any(string(properties(char(target)))== ...
                        qualified(2));
                end
            end
            missing=rows.qualname(~recognized);
            testCase.verifyTrue(all(recognized), ...
                "Unrecognized frozen phonon APIs: "+ ...
                strjoin(missing,", "));
        end
    end
end
