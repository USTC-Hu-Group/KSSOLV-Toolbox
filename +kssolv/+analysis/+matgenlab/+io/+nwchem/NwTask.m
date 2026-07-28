classdef NwTask < kssolv.analysis.matgenlab.util.MSONable
    %NWTASK One theory/operation task in an NWChem input.
    properties
        charge (1,1) double
        spin_multiplicity (1,1) double
        basis_set (1,1) struct
        basis_set_option (1,1) string = "cartesian"
        title (1,1) string
        theory (1,1) string = "dft"
        operation (1,1) string = "optimize"
        theory_directives (1,1) struct = struct()
        alternate_directives (1,1) struct = struct()
    end
    properties (Constant)
        theories = ["g3gn","scf","dft","esp","sodft","mp2", ...
            "direct_mp2","rimp2","ccsd","ccsd(t)", ...
            "ccsd+t(ccsd)","mcscf","selci","md","pspw","band", ...
            "tce","tddft"]
        operations = ["energy","gradient","optimize","saddle", ...
            "hessian","frequencies","freq","vscf","property", ...
            "dynamics","thermodynamics",""]
    end
    methods
        function obj=NwTask(charge,spinMultiplicity,basisSet, ...
                basisSetOption,title,theory,operation, ...
                theoryDirectives,alternateDirectives)
            if nargin<4||isempty(basisSetOption),basisSetOption="cartesian";end
            if nargin<5,title=[];end
            if nargin<6||isempty(theory),theory="dft";end
            if nargin<7||isempty(operation),operation="optimize";end
            if nargin<8||isempty(theoryDirectives),theoryDirectives=struct();end
            if nargin<9||isempty(alternateDirectives),alternateDirectives=struct();end
            theory=lower(string(theory));operation=lower(string(operation));
            if ~any(theory==obj.theories)
                throw(kssolv.analysis.matgenlab.io.nwchem. ...
                    NwInputError("Invalid theory='"+theory+"'"));
            elseif ~any(operation==obj.operations)
                throw(kssolv.analysis.matgenlab.io.nwchem. ...
                    NwInputError("Invalid operation='"+operation+"'"));
            end
            obj.charge=double(charge);
            obj.spin_multiplicity=double(spinMultiplicity);
            obj.basis_set=normalizeStruct(basisSet);
            obj.basis_set_option=string(basisSetOption);
            if isempty(title),title=theory+" "+operation;end
            obj.title=string(title);obj.theory=theory;
            obj.operation=operation;
            obj.theory_directives=normalizeStruct(theoryDirectives);
            obj.alternate_directives=normalizeStruct(alternateDirectives);
        end
        function value=char(obj)
            lines=["title """+obj.title+"""", ...
                "charge "+string(fix(obj.charge)), ...
                "basis "+obj.basis_set_option];
            elements=sort(string(fieldnames(obj.basis_set)));
            for element=reshape(elements,1,[])
                lines(end+1)=" "+element+" library """+ ...
                    string(obj.basis_set.(element))+""""; %#ok<AGROW>
            end
            lines(end+1)="end";
            names=sort(string(fieldnames(obj.theory_directives)));
            if ~isempty(names)
                lines(end+1)=obj.theory;
                for name=reshape(names,1,[])
                    lines(end+1)=" "+name+" "+directiveText( ...
                        name,obj.theory_directives.(name)); %#ok<AGROW>
                end
                lines(end+1)="end";
            end
            blocks=sort(string(fieldnames(obj.alternate_directives)));
            for block=reshape(blocks,1,[])
                lines(end+1)=block; %#ok<AGROW>
                content=obj.alternate_directives.(block);
                if isstruct(content)
                    names=sort(string(fieldnames(content)));
                    for name=reshape(names,1,[])
                        lines(end+1)=" "+name+" "+ ...
                            directiveText(name,content.(name)); %#ok<AGROW>
                    end
                end
                lines(end+1)="end"; %#ok<AGROW>
            end
            value=char(join(lines,newline)+newline);
            if ~isempty(obj.operation)
                value=[value,'task ',char(obj.theory),' ', ...
                    char(obj.operation)];
            end
        end
        function value=string(obj),value=string(char(obj));end
        function value=as_dict(obj)
            value=struct("x_module","pymatgen.io.nwchem", ...
                "x_class","NwTask","charge",obj.charge, ...
                "spin_multiplicity",obj.spin_multiplicity, ...
                "title",obj.title,"theory",obj.theory, ...
                "operation",obj.operation,"basis_set",obj.basis_set, ...
                "basis_set_option",obj.basis_set_option, ...
                "theory_directives",obj.theory_directives, ...
                "alternate_directives",obj.alternate_directives);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwTask( ...
                value.charge,value.spin_multiplicity,value.basis_set, ...
                value.basis_set_option,value.title,value.theory, ...
                value.operation,value.theory_directives, ...
                value.alternate_directives);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwTask.from_dict(value);
        end
        function obj=from_molecule(molecule,theory,varargin)
            options=struct("charge",[],"spin_multiplicity",[], ...
                "basis_set","6-31g","basis_set_option","cartesian", ...
                "title",[],"operation","optimize", ...
                "theory_directives",struct(), ...
                "alternate_directives",struct());
            options=parseOptions(options,varargin{:});
            formula=replace(string(molecule.formula)," ","");
            if isempty(options.title)
                options.title=formula+" "+string(theory)+" "+ ...
                    string(options.operation);
            end
            if isempty(options.charge),options.charge=molecule.charge;end
            electrons=-options.charge+molecule.charge+molecule.nelectrons;
            if ~isempty(options.spin_multiplicity)
                if mod(electrons+options.spin_multiplicity,2)~=1
                    error("KSSOLV:Matgenlab:NWChem:ChargeSpin", ...
                        "The requested charge and spin are not possible.");
                end
            elseif options.charge==molecule.charge
                options.spin_multiplicity=molecule.spin_multiplicity;
            elseif mod(electrons,2)==0
                options.spin_multiplicity=1;
            else
                options.spin_multiplicity=2;
            end
            basis=options.basis_set;
            if ischar(basis)||isstring(basis)
                expanded=struct();
                for symbol=reshape(string(molecule.symbol_set),1,[])
                    expanded.(symbol)=string(basis);
                end
                basis=expanded;
            end
            obj=kssolv.analysis.matgenlab.io.nwchem.NwTask( ...
                options.charge,options.spin_multiplicity,basis, ...
                options.basis_set_option,options.title,theory, ...
                options.operation,options.theory_directives, ...
                options.alternate_directives);
        end
        function obj=dft_task(molecule,varargin)
            options=struct("xc","b3lyp");
            [options,remaining]=extractOption(options,varargin{:});
            obj=kssolv.analysis.matgenlab.io.nwchem.NwTask. ...
                from_molecule(molecule,"dft",remaining{:});
            directives=obj.theory_directives;
            directives.xc=options.xc;
            directives.mult=obj.spin_multiplicity;
            obj.theory_directives=directives;
        end
        function obj=esp_task(molecule,varargin)
            obj=kssolv.analysis.matgenlab.io.nwchem.NwTask. ...
                from_molecule(molecule,"esp",varargin{:});
        end
    end
end

function value=normalizeStruct(value)
if isempty(value),value=struct();end
if ~isstruct(value)
    error("KSSOLV:Matgenlab:NWChem:Dictionary", ...
        "NWChem directive dictionaries must be structs.");
end
end

function text=directiveText(name,value)
if isnumeric(value)&&isscalar(value)
    if value==fix(value)&&string(name)=="dielec"
        text=string(sprintf("%.1f",value));
    else
        text=string(value);
    end
elseif ischar(value)||isstring(value)
    text=string(value);
else
    error("KSSOLV:Matgenlab:NWChem:Directive", ...
        "Directive values must be primitive scalars.");
end
end

function options=parseOptions(options,varargin)
for index=1:2:numel(varargin)
    field=char(string(varargin{index}));
    if isfield(options,field)
        options.(field)=varargin{index+1};
    else
        error("KSSOLV:Matgenlab:NWChem:Option", ...
            "Unknown option '%s'.",field);
    end
end
end

function [selected,remaining]=extractOption(selected,varargin)
remaining={};index=1;
while index<=numel(varargin)
    field=char(string(varargin{index}));
    if index==numel(varargin)
        error("KSSOLV:Matgenlab:NWChem:Arguments", ...
            "Name-value arguments must occur in pairs.");
    end
    if isfield(selected,field)
        selected.(field)=varargin{index+1};
    else
        remaining(end+1:end+2)=varargin(index:index+1);
    end
    index=index+2;
end
end
