classdef ModeledStructureData < handle
    %MODELEDSTRUCTUREDATA Persistable in-memory structure modeling result.

    properties (SetAccess = private)
        MatgenlabObject
        KSSOLVSetupObject struct
        rawFileContent string
        fileType string
        filePath string = ""
        sourceObjectName string
    end

    properties (Dependent, SetAccess = private)
        KSSOLVObject
    end

    methods
        function this = ModeledStructureData(model, name)
            arguments
                model
                name {mustBeTextScalar} = "Modeled structure"
            end
            this.sourceObjectName = string(name);
            this.updateMatgenlabObject(model);
        end

        function updateMatgenlabObject(this, model)
            if ~(isa(model, ...
                    "kssolv.analysis.matgenlab.core.IStructure") || ...
                    isa(model, ...
                    "kssolv.analysis.matgenlab.core.IMolecule"))
                error("KSSOLV:Modeling:ModeledDataType", ...
                    "Expected a matgenlab structure or molecule.");
            end
            this.MatgenlabObject = model.copy();
            this.KSSOLVSetupObject = ...
                kssolv.services.fileparser.StructureIO.toSetupObject( ...
                this.MatgenlabObject, name = this.sourceObjectName);
            if isa(this.MatgenlabObject, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                this.fileType = "cif";
            else
                this.fileType = "xyz";
            end
            if this.MatgenlabObject.num_sites == 0
                this.rawFileContent = "";
            else
                this.rawFileContent = ...
                    this.MatgenlabObject.to("", this.fileType);
            end
        end

        function value = get.KSSOLVObject(this)
            value = ...
                kssolv.services.fileparser.StructureIO.fromMatgenlab( ...
                this.MatgenlabObject, name = this.sourceObjectName);
        end

        function [content, format] = getDisplayData(this)
            content = this.rawFileContent;
            format = this.fileType;
        end

        function value = toInfoStruct(this)
            value = struct( ...
                "filePath", this.filePath, ...
                "KSSOLVSetupObject", this.KSSOLVSetupObject, ...
                "rawFileContent", this.rawFileContent);
        end
    end
end
