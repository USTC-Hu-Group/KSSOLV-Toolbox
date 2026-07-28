classdef SpinMode < kssolv.analysis.matgenlab.util.MSONable
    properties
        mode="polarized"; nsppol=2; nspinor=1; nspden=2
    end
    methods
        function obj=SpinMode(mode,nsppol,nspinor,nspden)
            if nargin>0, obj.mode=string(mode); obj.nsppol=nsppol; obj.nspinor=nspinor; obj.nspden=nspden; end
        end
        function d=to_abivars(obj), d=struct("nsppol",obj.nsppol,"nspinor",obj.nspinor,"nspden",obj.nspden); end
        function d=as_dict(obj), d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","SpinMode",struct("mode",char(obj.mode),"nsppol",obj.nsppol,"nspinor",obj.nspinor,"nspden",obj.nspden)); end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function obj=as_spinmode(value)
            if isa(value,"kssolv.analysis.matgenlab.io.abinit.SpinMode"),obj=value;return;end
            switch string(value)
                case "unpolarized", obj=kssolv.analysis.matgenlab.io.abinit.SpinMode("unpolarized",1,1,1);
                case "polarized", obj=kssolv.analysis.matgenlab.io.abinit.SpinMode("polarized",2,1,2);
                case "afm", obj=kssolv.analysis.matgenlab.io.abinit.SpinMode("afm",1,1,2);
                case "spinor", obj=kssolv.analysis.matgenlab.io.abinit.SpinMode("spinor",1,2,4);
                case "spinor_nomag", obj=kssolv.analysis.matgenlab.io.abinit.SpinMode("spinor_nomag",1,2,1);
                otherwise,error("KSSOLV:Matgenlab:Abinit:SpinMode","Unknown spin mode.");
            end
        end
        function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.abinit.SpinMode(d.mode,d.nsppol,d.nspinor,d.nspden);end
        function obj=fromDict(d),obj=kssolv.analysis.matgenlab.io.abinit.SpinMode.from_dict(d);end
    end
end
