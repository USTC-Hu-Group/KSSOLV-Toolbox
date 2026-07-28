classdef LammpsDump < kssolv.analysis.matgenlab.util.MSONable
    properties
        timestep (1,1) double
        natoms (1,1) double
        box
        data table
    end
    methods
        function obj=LammpsDump(timestep,natoms,box,data)
            obj.timestep=timestep; obj.natoms=natoms; obj.box=box; obj.data=data;
        end
        function d=as_dict(obj)
            s=struct("columns",{obj.data.Properties.VariableNames}, ...
                "index",(0:height(obj.data)-1)',"data",table2array(obj.data));
            d=kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.lammps.outputs","LammpsDump", ...
                struct("timestep",obj.timestep,"natoms",obj.natoms, ...
                "box",obj.box.as_dict(),"data",jsonencode(s)));
        end
        function d=asDict(obj), d=obj.as_dict(); end
    end
    methods (Static)
        function obj=from_str(text)
            lines=splitlines(string(text)); lines(lines=="")=[];
            timestep=str2double(lines(2)); natoms=str2double(lines(4));
            boxArray=sscanf(join(lines(6:8),newline),"%f");
            ncols=numel(sscanf(lines(6),"%f")); boxArray=reshape(boxArray,ncols,3)';
            bounds=boxArray(:,1:2); tilt=[];
            if contains(lines(5),"xy xz yz")
                tilt=boxArray(:,3)';
                x=[0 tilt(1) tilt(2) tilt(1)+tilt(2)]; y=[0 tilt(3)];
                bounds=bounds-[min(x) max(x);min(y) max(y);0 0];
            end
            box=kssolv.analysis.matgenlab.io.lammps.LammpsBox(bounds,tilt);
            names=cellstr(split(strtrim(erase(lines(9),"ITEM: ATOMS"))));
            vals=sscanf(join(lines(10:end),newline),"%f");
            vals=reshape(vals,numel(names),[])';
            data=array2table(vals,"VariableNames",names);
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsDump( ...
                timestep,natoms,box,data);
        end
        function obj=from_dict(d)
            box=kssolv.analysis.matgenlab.io.lammps.LammpsBox.from_dict(d.box);
            if ischar(d.data)||isstring(d.data), s=jsondecode(d.data); else, s=d.data; end
            names=s.columns; if isstring(names), names=cellstr(names); end
            data=array2table(s.data,"VariableNames",names);
            obj=kssolv.analysis.matgenlab.io.lammps.LammpsDump( ...
                d.timestep,d.natoms,box,data);
        end
    end
end
