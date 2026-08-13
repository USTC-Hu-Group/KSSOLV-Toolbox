classdef ModelingLibraryBrowserTest < matlab.unittest.TestCase
    %MODELINGLIBRARYBROWSERTEST Library corruption stays visible and isolated.

    methods (Test)
        function allCorruptedLibraryKindsRemainVisible(testCase)
            root=string(tempname); presets=fullfile(root,"presets");
            recipes=fullfile(root,"recipes"); templates=fullfile(root,"templates");
            mkdir(presets); mkdir(recipes); mkdir(templates);
            rootCleanup=onCleanup(@()rmdir(root,"s"));
            writeInvalid(fullfile(presets,"damaged-preset.json"));
            writeInvalid(fullfile(recipes,"damaged-recipe.json"));
            writeInvalid(fullfile(templates,"damaged-template.json"));
            browser=kssolv.ui.features.modeling.ModelingLibraryBrowser( ...
                visible=false,presetDirectory=presets, ...
                recipeDirectory=recipes,templateDirectory=templates);
            browserCleanup=onCleanup(@()delete(browser));

            data=browser.Widgets.Table.Data;
            testCase.verifyEqual(height(data),3);
            testCase.verifyEqual(sort(data.Name),sort([ ...
                "damaged-preset";"damaged-recipe";"damaged-template"]));
            testCase.verifyTrue(all(contains(data.Detail,"Invalid") | ...
                contains(data.Detail,"无效")));
            testCase.verifyEqual(string(browser.Widgets.Table.ColumnName(1)), ...
                string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:LibraryColumnType")));
            clear browserCleanup rootCleanup
        end
    end
end

function writeInvalid(path)
file=fopen(path,"w"); fwrite(file,"not json"); fclose(file);
end
