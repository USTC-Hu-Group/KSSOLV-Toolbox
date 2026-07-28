classdef UCorrection < kssolv.analysis.matgenlab.analysis.compatibility.Correction
    %UCORRECTION Legacy GGA/GGA+U mixing correction.
    properties
        name (1,1) string
        input_set (1,1) string
        compat_type (1,1) string
        u_corrections struct
        u_errors struct = struct()
    end
    methods
        function obj=UCorrection(configFile,inputSet,compatType,varargin)
            if nargin<3,compatType="Advanced";end
            if ~any(string(compatType)==["GGA","Advanced"])
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Invalid compatibility type.");
            end
            options=struct(error_file="");
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            config=kssolv.analysis.matgenlab.util.yaml_load(configFile);
            obj.name=string(config.Name);obj.compat_type=string(compatType);
            if contains(upper(string(inputSet)),"MIT"),obj.input_set="MIT";
            else,obj.input_set="MP";end
            if obj.compat_type=="Advanced" %#ok<ALIGN>
                obj.u_corrections=config.Advanced.UCorrections;
            else,obj.u_corrections=struct();end
            if strlength(string(options.error_file))>0
                errors=kssolv.analysis.matgenlab.util.yaml_load(options.error_file);
                obj.u_errors=errors.Advanced.UCorrections;
            end
        end
        function value=get_correction(obj,entry)
            symbols=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.entry_symbols(entry);
            electroneg=arrayfun(@(item) ...
                kssolv.analysis.matgenlab.core.Element(item).X,symbols);
            [~,index]=max(electroneg);anion=symbols(index);
            expected=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.u_values(obj.input_set,anion);
            corrections=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.u_corrections,anion,struct());
            hubbards=kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                field_or(entry.parameters,"hubbards",struct());
            value=0;
            for symbol=symbols
                actual=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(hubbards,symbol,0);
                wanted=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(expected,symbol,0);
                if abs(actual-wanted)>1e-8
                    kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                        incompatible("Invalid U value of %.6g on %s.",actual,symbol);
                end
                correction=kssolv.analysis.matgenlab.analysis.compatibility. ...
                    internal.map_get(corrections,symbol,0);
                value=value+correction*entry.composition.amountOf(symbol);
            end
        end
        function value=get_uncertainty(obj,entry)
            symbols=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.entry_symbols(entry);
            electroneg=arrayfun(@(item) ...
                kssolv.analysis.matgenlab.core.Element(item).X,symbols);
            [~,index]=max(electroneg);anion=symbols(index);
            errors=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.map_get(obj.u_errors,anion,struct());
            variance=0;
            for symbol=symbols
                errorPerAtom=kssolv.analysis.matgenlab.analysis. ...
                    compatibility.internal.map_get(errors,symbol,0);
                variance=variance+(errorPerAtom* ...
                    entry.composition.amountOf(symbol))^2;
            end
            value=sqrt(variance);
        end
    end
end
