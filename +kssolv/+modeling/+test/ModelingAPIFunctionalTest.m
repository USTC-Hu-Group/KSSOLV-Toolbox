classdef ModelingAPIFunctionalTest < matlab.unittest.TestCase
    methods (Test)
        function tenStepRecipeReplaysToIdenticalHash(testCase)
            initial=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
            recorder=kssolv.modeling.provenance.OperationRecorder();
            model=initial;
            for step=1:10
                [result,~]=recorder.execute(model,"translate_atoms", ...
                    struct("indices",1,"vector",[.01*step,0,0], ...
                    "fractional",false));
                model=result.model;
            end
            [replayed,report]=kssolv.modeling.provenance. ...
                OperationRecorder.replay(initial,recorder.recipe());
            testCase.verifyTrue(report.verified);
            testCase.verifyEqual(report.operationCount,10);
            testCase.verifyEqual( ...
                kssolv.modeling.provenance.CanonicalHash.of(model), ...
                kssolv.modeling.provenance.CanonicalHash.of(replayed));
        end

        function schemaErrorsAndTamperingArePrecise(testCase)
            initial=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
            testCase.verifyError(@()kssolv.api.v1.modeling.execute( ...
                initial,struct("schemaVersion",2,"commandId","add_atom")), ...
                "KSSOLV:API:ModelingSchema");
            recorder=kssolv.modeling.provenance.OperationRecorder();
            recorder.execute(initial,"translate_atoms",struct( ...
                "indices",1,"vector",[.1,0,0],"fractional",false));
            recipe=recorder.recipe(); recipe.operations.resultHash="bad";
            testCase.verifyError(@()kssolv.modeling.provenance. ...
                OperationRecorder.replay(initial,recipe), ...
                "KSSOLV:Modeling:RecipeResultHash");
        end

        function batchOneHundredIsIsolatedAndCancellationIsClean(testCase)
            model=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
            request=struct("schemaVersion",1,"commandId","translate_atoms", ...
                "parameters",struct("indices",1,"vector",[.1,0,0], ...
                "fractional",false));
            report=kssolv.modeling.BatchModeler.run( ...
                repmat({model},1,100),repmat({request},1,100));
            testCase.verifyEqual(report.succeeded,100);
            hashes=arrayfun(@(entry)string(entry.response.resultHash), ...
                report.entries);
            testCase.verifyEqual(numel(unique(hashes)),1);
            counter=0;
            cancelled=kssolv.modeling.BatchModeler.run( ...
                repmat({model},1,10),repmat({request},1,10), ...
                cancelFcn=@cancelAfterThree);
            testCase.verifyTrue(cancelled.cancelled);
            testCase.verifyEqual(cancelled.completed,3);
            testCase.verifyEqual(sum([cancelled.entries.cancelled]),7);
            function value=cancelAfterThree()
                counter=counter+1; value=counter>3;
            end
        end

        function recipeLibraryRoundTripsWithoutGUIState(testCase)
            directory=string(tempname); mkdir(directory);
            cleanup=onCleanup(@()rmdir(directory,"s"));
            initial=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
            recorder=kssolv.modeling.provenance.OperationRecorder();
            recorder.execute(initial,"translate_atoms",struct( ...
                "indices",1,"vector",[.1,0,0],"fractional",false));
            path=kssolv.modeling.provenance.RecipeLibrary.save( ...
                "translation",recorder.recipe(),directory=directory);
            testCase.verifyTrue(isfile(path));
            testCase.verifyEqual(kssolv.modeling.provenance. ...
                RecipeLibrary.list(directory=directory),"translation");
            loaded=kssolv.modeling.provenance.RecipeLibrary.load( ...
                "translation",directory=directory);
            [~,report]=kssolv.modeling.provenance.OperationRecorder. ...
                replay(initial,loaded);
            testCase.verifyTrue(report.verified);
        end

        function presetsAndProjectTemplatesAreVersioned(testCase)
            directory=string(tempname); mkdir(directory);
            cleanup=onCleanup(@()rmdir(directory,"s"));
            presetPath=kssolv.modeling.provenance.ParameterPresetLibrary. ...
                save("translate_atoms","small step",struct( ...
                "indices",1,"vector",[.1,0,0],"fractional",false), ...
                directory=directory);
            testCase.verifyTrue(isfile(presetPath));
            preset=kssolv.modeling.provenance.ParameterPresetLibrary. ...
                load("translate_atoms","small step",directory=directory);
            testCase.verifyEqual(reshape(preset.parameters.vector,1,[]), ...
                [.1,0,0]);
            listed=kssolv.modeling.provenance.ParameterPresetLibrary. ...
                list("translate_atoms",directory=directory);
            testCase.verifyEqual(listed.name,"small step");

            templateDirectory=fullfile(directory,"templates");
            path=kssolv.modeling.provenance.ProjectTemplateLibrary.save( ...
                "screening",struct("recipeName","translation", ...
                "inputFormat","xyz","outputFormat","mol", ...
                "projectMetadata",struct("owner","test")), ...
                directory=templateDirectory);
            testCase.verifyTrue(isfile(path));
            template=kssolv.modeling.provenance.ProjectTemplateLibrary. ...
                load("screening",directory=templateDirectory);
            testCase.verifyEqual(template.schemaVersion,1);
            testCase.verifyEqual(string(template.projectMetadata.owner),"test");
            testCase.verifyError(@()kssolv.modeling.provenance. ...
                ParameterPresetLibrary.save("translate_atoms","   ", ...
                struct(),directory=directory), ...
                "KSSOLV:Modeling:PresetName");
            testCase.verifyError(@()kssolv.modeling.provenance. ...
                RecipeLibrary.save("   ",struct("schemaVersion",1, ...
                "operations",struct([])), ...
                directory=directory),"KSSOLV:Modeling:RecipeName");
            testCase.verifyError(@()kssolv.modeling.provenance. ...
                ProjectTemplateLibrary.save("   ",struct(), ...
                directory=templateDirectory), ...
                "KSSOLV:Modeling:ProjectTemplateName");
        end

        function fileBatchImportsValidatesExportsAndSummarizesErrors(testCase)
            root=string(tempname); inputDirectory=fullfile(root,"in");
            outputDirectory=fullfile(root,"out"); mkdir(inputDirectory);
            cleanup=onCleanup(@()rmdir(root,"s"));
            molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                ["O","H","H"],[0,0,0;.9572,0,0;-.239,.927,0], ...
                charge_spin_check=false);
            valid=fullfile(inputDirectory,"water.xyz");
            molecule.to(valid,"xyz");
            invalid=fullfile(inputDirectory,"broken.xyz");
            file=fopen(invalid,"w"); fwrite(file,"not xyz"); fclose(file);
            request=struct("schemaVersion",1, ...
                "commandId","translate_atoms", ...
                "parameters",struct("indices",1, ...
                "vector",[.1,0,0],"fractional",false));
            report=kssolv.modeling.FileBatchModeler.run( ...
                [valid,invalid],request,outputDirectory);
            testCase.verifyEqual(report.succeeded,1);
            testCase.verifyEqual(report.failed,1);
            testCase.verifyTrue(isfile(report.entries(1).outputPath));
            testCase.verifyNotEmpty(report.entries(2).errorIdentifier);
            testCase.verifyNotEmpty(report.entries(1).parentHash);
            testCase.verifyNotEmpty(report.entries(1).resultHash);
        end

        function persistentFileJobResumesFromAtomicCheckpoint(testCase)
            root=string(tempname); inputDirectory=fullfile(root,"in");
            outputDirectory=fullfile(root,"out");
            jobDirectory=fullfile(root,"jobs"); mkdir(inputDirectory);
            cleanup=onCleanup(@()rmdir(root,"s"));
            molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                "He",[0,0,0],charge_spin_check=false);
            paths=strings(1,2);
            for index=1:2
                paths(index)=fullfile(inputDirectory,"helium"+index+".xyz");
                molecule.to(paths(index),"xyz");
            end
            request=struct("schemaVersion",1,"commandId","move_atoms", ...
                "parameters",struct("indices",1,"vector",[.1,0,0], ...
                "fractional",false));
            id=kssolv.modeling.ModelingJobStore.createFileBatch( ...
                paths,request,outputDirectory,directory=jobDirectory);
            calls=0;
            testCase.verifyError(@()kssolv.modeling.ModelingJobStore.run( ...
                id,directory=jobDirectory,progressFcn=@interruptOnce), ...
                "KSSOLV:Test:Interrupt");
            interrupted=kssolv.modeling.ModelingJobStore.get( ...
                id,directory=jobDirectory);
            testCase.verifyEqual(string(interrupted.status),"interrupted");
            testCase.verifyEqual(interrupted.completed,1);
            completed=kssolv.modeling.ModelingJobStore.run( ...
                id,directory=jobDirectory);
            testCase.verifyEqual(string(completed.status),"complete");
            testCase.verifyEqual(completed.succeeded,2);
            testCase.verifyEqual(completed.completed,2);
            function interruptOnce(~,~)
                calls=calls+1;
                if calls==1
                    error("KSSOLV:Test:Interrupt","Simulated process loss.");
                end
            end
        end

        function corruptedJobRemainsVisibleWithDiagnostic(testCase)
            directory=string(tempname); mkdir(directory);
            cleanup=onCleanup(@()rmdir(directory,"s")); %#ok<NASGU>
            path=fullfile(directory,"damaged-job.json");
            file=fopen(path,"w"); fwrite(file,"not json"); fclose(file);
            jobs=kssolv.modeling.ModelingJobStore.list(directory=directory);
            testCase.verifyNumElements(jobs,1);
            testCase.verifyEqual(string(jobs.id),"damaged-job");
            testCase.verifyEqual(string(jobs.status),"invalid");
            testCase.verifyFalse(jobs.recoverable);
            testCase.verifyNotEmpty(jobs.error);
        end

        function emptyFileJobIsRejectedBeforeJournalCreation(testCase)
            directory=string(tempname);
            cleanup=onCleanup(@()rmdirIfPresent(directory)); %#ok<NASGU>
            testCase.verifyError(@() ...
                kssolv.modeling.ModelingJobStore.createFileBatch( ...
                strings(0,1),cell(0,1),tempdir,directory=directory), ...
                "KSSOLV:Modeling:EmptyJob");
            testCase.verifyFalse(isfolder(directory));
        end

        function recoveryJournalIsAtomicAndDiagnosesCorruption(testCase)
            directory=string(tempname); mkdir(directory);
            cleanup=onCleanup(@()rmdir(directory,"s"));
            model=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
            journal=kssolv.modeling.provenance.RecoveryJournal( ...
                "fixture",directory=directory);
            journal.checkpoint(model,7,struct("cause","test"));
            snapshot=journal.recover();
            testCase.verifyEqual(snapshot.revision,7);
            testCase.verifyEqual(snapshot.modelHash, ...
                kssolv.modeling.provenance.CanonicalHash.of(model));
            entries=kssolv.modeling.provenance.RecoveryJournal.scan( ...
                directory=directory);
            testCase.verifyTrue(entries.valid);
            file=fopen(journal.Path,"w"); fwrite(file,"corrupt"); fclose(file);
            entries=kssolv.modeling.provenance.RecoveryJournal.scan( ...
                directory=directory);
            testCase.verifyFalse(entries.valid);
            testCase.verifyNotEmpty(entries.error);
            testCase.verifyError(@()journal.recover(), ...
                "KSSOLV:Modeling:RecoveryCorrupt");
        end

        function sharedAtomicJsonHandlesSpecialAndFailedPaths(testCase)
            root=string(tempname)+" atomic's root";
            cleanup=onCleanup(@()removeIfPresent(root)); %#ok<NASGU>
            path=fullfile(root,"nested folder","state's file.json");
            first=struct("schemaVersion",1,"value","first");
            second=struct("schemaVersion",1,"value","second");
            kssolv.modeling.internal.AtomicJsonFile.write(path,first);
            kssolv.modeling.internal.AtomicJsonFile.write(path,second);
            actual=jsondecode(fileread(path));
            testCase.verifyEqual(string(actual.value),"second");
            testCase.verifyEmpty(dir(path+".*.tmp"));

            blockingPath=fullfile(root,"not-a-folder");
            file=fopen(blockingPath,"w"); fwrite(file,"block"); fclose(file);
            testCase.verifyError(@() ...
                kssolv.modeling.internal.AtomicJsonFile.write( ...
                fullfile(blockingPath,"value.json"),first, ...
                "KSSOLV:Test:AtomicJson"),"KSSOLV:Test:AtomicJson");
            testCase.verifyEmpty(dir(fullfile(root,"**","*.tmp")));
        end
    end
end

function rmdirIfPresent(path)
if isfolder(path), rmdir(path,"s"); end
end

function removeIfPresent(path)
if isfolder(path), rmdir(path,"s"); end
end
