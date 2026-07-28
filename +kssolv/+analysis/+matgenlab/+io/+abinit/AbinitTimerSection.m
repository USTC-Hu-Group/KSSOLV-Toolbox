classdef AbinitTimerSection
    properties
        name string
        cpu_time double
        cpu_fract double
        wall_time double
        wall_fract double
        ncalls double
        gflops double
    end
    methods
        function obj=AbinitTimerSection(name,cpu_time,cpu_fract,wall_time,wall_fract,ncalls,gflops)
            if nargin==0,return,end
            obj.name=strtrim(string(name));obj.cpu_time=str2double(string(cpu_time));obj.cpu_fract=str2double(string(cpu_fract));
            obj.wall_time=str2double(string(wall_time));obj.wall_fract=str2double(string(wall_fract));obj.ncalls=str2double(string(ncalls));obj.gflops=str2double(string(gflops));
        end
        function value=to_tuple(obj),value={obj.name,obj.wall_time,obj.wall_fract,obj.cpu_time,obj.cpu_fract,obj.ncalls,obj.gflops};end
        function value=as_dict(obj),value=struct("name",obj.name,"wall_time",obj.wall_time,"wall_fract",obj.wall_fract,"cpu_time",obj.cpu_time,"cpu_fract",obj.cpu_fract,"ncalls",obj.ncalls,"gflops",obj.gflops);end
        function value=to_dict(obj),value=obj.as_dict();end
        function value=to_csvline(obj,with_header)
            if nargin<2,with_header=false;end
            value="";if with_header,value="# name wall_time wall_fract cpu_time cpu_fract ncalls gflops"+newline;end
            value=char(value+join(string(obj.to_tuple()),", ")+newline);
        end
        function value=char(obj),value=char("name = "+obj.name+", cpu_time = "+string(obj.cpu_time)+", wall_time = "+string(obj.wall_time));end
    end
    methods(Static)
        function obj=fake(),obj=kssolv.analysis.matgenlab.io.abinit.AbinitTimerSection("fake",0,0,0,0,-1,0);end
    end
end
