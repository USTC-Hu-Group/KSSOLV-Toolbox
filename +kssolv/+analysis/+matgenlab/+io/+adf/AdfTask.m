classdef AdfTask < kssolv.analysis.matgenlab.util.MSONable
    %ADFTASK Molecule-independent settings for an ADF calculation.
    properties
        operation (1,1) string
        title (1,1) string
        basis_set
        xc
        units
        scf
        geo
        other_directives (1,:) cell = cell(1,0)
    end
    properties (Constant)
        operations = struct( ...
            "energy","Evaluate the single point energy.", ...
            "optimize","Minimize the energy by varying the molecular structure.", ...
            "frequencies","Compute molecular vibration frequencies.", ...
            "freq","Same as frequencies.", ...
            "numerical_frequencies","Compute numerical molecular frequencies.")
    end
    methods
        function obj=AdfTask(operation,basisSet,xc,title,units, ...
                geoSubkeys,scf,otherDirectives)
            if nargin<1||isempty(operation),operation="energy";end
            if nargin<2,basisSet=[];end
            if nargin<3,xc=[];end
            if nargin<4||isempty(title),title="ADF_RUN";end
            if nargin<5,units=[];end
            if nargin<6,geoSubkeys=[];end
            if nargin<7,scf=[];end
            if nargin<8||isempty(otherDirectives),otherDirectives={};end
            operation=string(operation);
            if ~isfield(obj.operations,char(operation))
                throw(kssolv.analysis.matgenlab.io.adf.AdfInputError( ...
                    sprintf("Invalid ADF task %s",operation)));
            end
            obj.operation=operation;obj.title=string(title);
            if isempty(basisSet),basisSet=obj.get_default_basis_set();end
            if isempty(xc),xc=obj.get_default_xc();end
            if isempty(units),units=obj.get_default_units();end
            if isempty(scf),scf=obj.get_default_scf();end
            if ~iscell(otherDirectives)
                otherDirectives=num2cell(otherDirectives);
            end
            obj.basis_set=basisSet;obj.xc=xc;obj.units=units;obj.scf=scf;
            obj.other_directives=reshape(otherDirectives,1,[]);
            obj=obj.setup_task(geoSubkeys);
        end
        function value=char(obj)
            value=char(sprintf("TITLE %s\n\n%s\n%s\n%s\n%s\n%s\n", ...
                char(obj.title),char(obj.units),char(obj.xc), ...
                char(obj.basis_set),char(obj.scf),char(obj.geo)));
            for index=1:numel(obj.other_directives)
                directive=obj.other_directives{index};
                if ~isa(directive, ...
                        "kssolv.analysis.matgenlab.io.adf.AdfKey")
                    error("KSSOLV:Matgenlab:ADF:DirectiveType", ...
                        "Every other directive must be an AdfKey.");
                end
                value=[value,char(directive),newline]; %#ok<AGROW>
            end
        end
        function value=string(obj),value=string(char(obj));end
        function value=as_dict(obj)
            value=struct("x_module","pymatgen.io.adf", ...
                "x_class","AdfTask","operation",obj.operation, ...
                "title",obj.title,"xc",obj.xc.as_dict(), ...
                "basis_set",obj.basis_set.as_dict(), ...
                "units",obj.units.as_dict(),"scf",obj.scf.as_dict(), ...
                "geo",obj.geo.as_dict(), ...
                "others",{cellfun(@(item)item.as_dict(), ...
                obj.other_directives,"UniformOutput",false)});
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
    methods (Static)
        function value=get_default_basis_set()
            value=kssolv.analysis.matgenlab.io.adf.AdfKey.from_str( ...
                "Basis"+newline+"type DZ"+newline+ ...
                "core small"+newline+"END");
        end
        function value=get_default_scf()
            value=kssolv.analysis.matgenlab.io.adf.AdfKey.from_str( ...
                "SCF"+newline+"iterations 300"+newline+"END");
        end
        function value=get_default_geo()
            value=kssolv.analysis.matgenlab.io.adf.AdfKey.from_str( ...
                "GEOMETRY SinglePoint"+newline+"END");
        end
        function value=get_default_xc()
            value=kssolv.analysis.matgenlab.io.adf.AdfKey.from_str( ...
                "XC"+newline+"GGA PBE"+newline+"END");
        end
        function value=get_default_units()
            value=kssolv.analysis.matgenlab.io.adf.AdfKey.from_str( ...
                "Units"+newline+"length angstrom"+newline+ ...
                "angle degree"+newline+"End");
        end
        function obj=from_dict(value)
            key=@(name)kssolv.analysis.matgenlab.io.adf.AdfKey. ...
                from_dict(value.(name));
            others={};
            if isfield(value,"others")
                raw=value.others;if ~iscell(raw),raw=num2cell(raw);end
                others=cellfun(@(item) ...
                    kssolv.analysis.matgenlab.io.adf.AdfKey. ...
                    from_dict(item),raw,"UniformOutput",false);
            end
            geo=key("geo");
            obj=kssolv.analysis.matgenlab.io.adf.AdfTask( ...
                value.operation,key("basis_set"),key("xc"), ...
                value.title,key("units"),geo.subkeys,key("scf"),others);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.io.adf.AdfTask.from_dict(value);
        end
    end
    methods (Access=private)
        function obj=setup_task(obj,geoSubkeys)
            obj.geo=kssolv.analysis.matgenlab.io.adf.AdfKey( ...
                "Geometry",[],geoSubkeys);
            switch lower(obj.operation)
                case "energy"
                    obj.geo=obj.geo.add_option("SinglePoint");
                    if obj.geo.has_subkey("Frequencies")
                        obj.geo=obj.geo.remove_subkey("Frequencies");
                    end
                case "optimize"
                    obj.geo=obj.geo.add_option("GeometryOptimization");
                    if obj.geo.has_subkey("Frequencies")
                        obj.geo=obj.geo.remove_subkey("Frequencies");
                    end
                case "numerical_frequencies"
                    obj.geo=obj.geo.add_subkey( ...
                        kssolv.analysis.matgenlab.io.adf.AdfKey( ...
                        "Frequencies"));
                otherwise
                    obj.other_directives{end+1}= ...
                        kssolv.analysis.matgenlab.io.adf.AdfKey( ...
                        "AnalyticalFreq");
                    if obj.geo.has_subkey("Frequencies")
                        obj.geo=obj.geo.remove_subkey("Frequencies");
                    end
            end
        end
    end
end
