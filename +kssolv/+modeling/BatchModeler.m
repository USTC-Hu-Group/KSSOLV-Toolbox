classdef BatchModeler
    %BATCHMODELER Isolated headless execution of versioned modeling requests.
    methods (Static)
        function report=run(models,requests,options)
            arguments
                models
                requests
                options.cancelFcn = @()false
                options.progressFcn = @(~,~)[]
            end
            if ~iscell(models), models=num2cell(models); end
            if isstruct(requests), requests=num2cell(requests); end
            if numel(models)~=numel(requests)
                error("KSSOLV:Modeling:BatchLength", ...
                    "models and requests must contain the same number of entries.");
            end
            entries=repmat(struct("success",false,"cancelled",false, ...
                "model",[],"response",struct(),"errorIdentifier","", ...
                "errorMessage",""),1,numel(models));
            completed=0; cancelled=false;
            for index=1:numel(models)
                if options.cancelFcn()
                    cancelled=true;
                    for remainder=index:numel(models), entries(remainder).cancelled=true; end
                    break
                end
                try
                    response=kssolv.api.v1.modeling.execute( ...
                        models{index},requests{index});
                    entries(index).success=true;
                    entries(index).model=response.model;
                    entries(index).response=rmfield(response,"model");
                catch exception
                    entries(index).errorIdentifier=string(exception.identifier);
                    entries(index).errorMessage=string(exception.message);
                end
                completed=index; options.progressFcn(index,numel(models));
            end
            report=struct("schemaVersion",1,"entries",entries, ...
                "requested",numel(models),"completed",completed, ...
                "succeeded",sum([entries.success]),"cancelled",cancelled);
        end
    end
end
