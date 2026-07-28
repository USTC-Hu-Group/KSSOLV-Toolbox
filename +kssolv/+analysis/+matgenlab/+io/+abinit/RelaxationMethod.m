classdef RelaxationMethod < kssolv.analysis.matgenlab.util.MSONable
    properties,abivars=struct();end
    properties (Dependent),move_atoms;move_cell;end
    methods
        function obj=RelaxationMethod(varargin),obj.abivars=struct("ionmov",3,"optcell",0,"ntime",80,"dilatmx",1.05,"ecutsm",.5,"strfact",[],"tolmxf",[],"strtarget",[],"atoms_constraints",[]);for i=1:2:numel(varargin),obj.abivars.(char(varargin{i}))=varargin{i+1};end,end
        function v=get.move_atoms(obj),v=obj.abivars.ionmov~=0;end
        function v=get.move_cell(obj),v=obj.abivars.optcell~=0;end
        function d=to_abivars(obj),d=struct("ionmov",obj.abivars.ionmov,"optcell",obj.abivars.optcell,"ntime",obj.abivars.ntime);if obj.move_atoms,d.tolmxf=obj.abivars.tolmxf;end;if obj.move_cell,d.dilatmx=obj.abivars.dilatmx;d.ecutsm=obj.abivars.ecutsm;d.strfact=obj.abivars.strfact;d.strtarget=obj.abivars.strtarget;end,end
        function d=as_dict(obj),d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","RelaxationMethod",obj.abivars);end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function o=atoms_only(c),if nargin<1,c=[];end;o=kssolv.analysis.matgenlab.io.abinit.RelaxationMethod("ionmov",3,"optcell",0,"atoms_constraints",c);end
        function o=atoms_and_cell(c),if nargin<1,c=[];end;o=kssolv.analysis.matgenlab.io.abinit.RelaxationMethod("ionmov",3,"optcell",2,"atoms_constraints",c);end
        function o=from_dict(d),n=fieldnames(d);a={};for i=1:numel(n),if ~startsWith(n{i},"x_"),a(end+1:end+2)={n{i},d.(n{i})};end,end;o=kssolv.analysis.matgenlab.io.abinit.RelaxationMethod(a{:});end
        function o=fromDict(d),o=kssolv.analysis.matgenlab.io.abinit.RelaxationMethod.from_dict(d);end
    end
end
