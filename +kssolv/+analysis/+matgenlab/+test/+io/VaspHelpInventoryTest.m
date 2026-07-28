classdef VaspHelpInventoryTest < matlab.unittest.TestCase
    properties
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "vasp_help_2026.7.24.json")));
            kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                set_transport(@frozenTransport);
        end
    end

    methods (TestMethodTeardown)
        function clearTransport(~)
            kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                set_transport([]);
            resetTransport();
        end
    end

    methods (Test)
        function textAndHtmlMatchFrozenOracle(testCase)
            text = kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                get_help("isym");
            html = kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                get_help("isym", "html");
            for token = reshape(string(testCase.oracle.text_contains), 1, [])
                testCase.verifyTrue(contains(text, token));
            end
            for token = reshape(string(testCase.oracle.html_contains), 1, [])
                testCase.verifyTrue(contains(html, token));
            end
            testCase.verifyFalse(contains(text, "<h1>"));
        end

        function paginationReturnsAllTags(testCase)
            tags = kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                get_incar_tags();
            testCase.verifyEqual(tags, ...
                reshape(string(testCase.oracle.tags), 1, []));
        end

        function printMethodsExposeContent(testCase)
            document = kssolv.analysis.matgenlab.io.vasp.help.VaspDoc();
            textOutput = evalc("document.print_help('ISYM')");
            htmlOutput = evalc("document.print_jupyter_help('ISYM')");
            testCase.verifyTrue(contains(textOutput, "ISYM"));
            testCase.verifyTrue(contains(htmlOutput, "<h1>ISYM</h1>"));
            testCase.verifyEqual(document.url_template, ...
                "https://www.vasp.at/wiki/index.php/%s");
        end

        function malformedDocumentIsRejected(testCase)
            kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                set_transport(@(~) "<html>missing content</html>");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                get_help("ISYM"), ...
                "KSSOLV:Matgenlab:VaspHelp:Content");
        end
    end
end

function text = frozenTransport(url)
persistent apiPage
if isempty(apiPage), apiPage = 0; end
if contains(url, "api.php")
    apiPage = apiPage + 1;
    if apiPage == 1
        payload.query.categorymembers = struct( ...
            "title", {"ENCUT", "ISMEAR"});
        payload.continue.cmcontinue = "page|2";
    else
        payload.query.categorymembers = struct("title", {"ISYM"});
    end
    text = jsonencode(payload);
else
    text = "<html><body><div id=""mw-content-text"">" + ...
        "<h1>ISYM</h1><p>ISYM controls the use of symmetry.</p>" + ...
        "<p>Default: 2</p></div><div class=""printfooter"">" + ...
        "footer</div></body></html>";
end
end

function resetTransport()
clear frozenTransport
end
