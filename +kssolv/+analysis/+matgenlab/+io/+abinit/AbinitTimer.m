classdef AbinitTimer
    properties
        sections cell={}
        section_names string=strings(0,1)
        info struct=struct()
        cpu_time double=0
        wall_time double=0
        mpi_nprocs double=1
        omp_nthreads double=1
        mpi_rank string="0"
        fname string=""
    end
    properties(Dependent),ncpus,end
    methods
        function obj=AbinitTimer(sections,info,cpu_time,wall_time)
            if nargin==0,return,end
            obj.sections=sections;obj.section_names=cellfun(@(s)s.name,sections);
            obj.info=info;obj.cpu_time=cpu_time;obj.wall_time=wall_time;
            obj.mpi_nprocs=str2double(string(info.mpi_nprocs));obj.omp_nthreads=str2double(string(info.omp_nthreads));
            obj.mpi_rank=strtrim(string(info.mpi_rank));obj.fname=strtrim(string(info.fname));
        end
        function value=get.ncpus(obj),value=obj.mpi_nprocs*obj.omp_nthreads;end
        function value=get_section(obj,name)
            idx=find(obj.section_names==string(name),1);if isempty(idx),error("KSSOLV:Matgenlab:Abinit:TimerSection","Section %s not found.",name);end;value=obj.sections{idx};
        end
        function to_csv(obj,fileobj)
            if nargin<2,fileobj=1;end
            closeIt=false;if ischar(fileobj)||isstring(fileobj),fileobj=fopen(fileobj,"w");closeIt=true;end
            for i=1:numel(obj.sections),fprintf(fileobj,"%s",obj.sections{i}.to_csvline(i==1));end
            if closeIt,fclose(fileobj);end
        end
        function value=to_table(obj,sort_key,stop)
            if nargin<2,sort_key="wall_time";end;if nargin<3,stop=[];end
            ordered=obj.order_sections(sort_key);if ~isempty(stop),ordered=ordered(1:min(stop,numel(ordered)));end
            value=cell(numel(ordered)+1,7);value(1,:)={"name","wall_time","wall_fract","cpu_time","cpu_fract","ncalls","gflops"};
            for i=1:numel(ordered),value(i+1,:)=ordered{i}.to_tuple();end
        end
        function value=totable(obj,varargin),value=obj.to_table(varargin{:});end
        function value=get_dataframe(obj,sort_key,varargin)
            if nargin<2,sort_key="wall_time";end
            ordered=obj.order_sections(sort_key);n=numel(ordered);
            name=strings(n,1);wall_time=zeros(n,1);wall_fract=zeros(n,1);cpu_time=zeros(n,1);cpu_fract=zeros(n,1);ncalls=zeros(n,1);gflops=zeros(n,1); %#ok<PROP>
            for i=1:n,s=ordered{i};name(i)=s.name;wall_time(i)=s.wall_time;wall_fract(i)=s.wall_fract;cpu_time(i)=s.cpu_time;cpu_fract(i)=s.cpu_fract;ncalls(i)=s.ncalls;gflops(i)=s.gflops;end %#ok<PROP>
            value=table(name,wall_time,wall_fract,cpu_time,cpu_fract,ncalls,gflops); %#ok<PROP>
        end
        function value=get_values(obj,keys)
            keys=string(keys);
            if isscalar(keys)
                if keys=="name",value=cellfun(@(s)s.name,obj.sections);else,value=cellfun(@(s)s.(char(keys)),obj.sections);end
            else
                value=cell(1,numel(keys));for i=1:numel(keys),value{i}=obj.get_values(keys(i));end
            end
        end
        function [names,values]=names_and_values(obj,key,varargin)
            minval=[];minfract=[];doSort=true;
            for i=1:2:numel(varargin),switch string(varargin{i}),case "minval",minval=varargin{i+1};case "minfract",minfract=varargin{i+1};case "sorted",doSort=varargin{i+1};end,end
            names=obj.get_values("name");values=obj.get_values(key);keep=true(size(values));label="";
            if ~isempty(minval),keep=values>=minval;label="below minval "+string(minval);
            elseif ~isempty(minfract),keep=values/sum(values)>=minfract;label="below minfract "+string(minfract);end
            if ~all(keep),names=[names(keep),label];values=[values(keep),sum(values(~keep))];end
            if doSort,[values,idx]=sort(values);names=names(idx);end
        end
        function value=sum_sections(obj,keys),value=sum(obj.get_values(keys));end
        function value=order_sections(obj,key,reverse)
            if nargin<3,reverse=true;end;values=obj.get_values(key);
            if reverse,[~,idx]=sort(values,"descend");else,[~,idx]=sort(values,"ascend");end;value=obj.sections(idx);
        end
        function fig=cpuwall_histogram(obj,varargin)
            ax=timerAxes(varargin{:});x=1:numel(obj.sections);bar(ax,x,[obj.get_values("cpu_time").',obj.get_values("wall_time").']);ylabel(ax,"Time (s)");legend(ax,["CPU","Wall"]);fig=ancestor(ax,"figure");
        end
        function fig=pie(obj,key,minfract,varargin)
            if nargin<2||isempty(key),key="wall_time";end;if nargin<3||isempty(minfract),minfract=.05;end
            ax=timerAxes(varargin{:});[names,values]=obj.names_and_values(key,"minfract",minfract);pie(ax,values,names);fig=ancestor(ax,"figure");
        end
        function fig=scatter_hist(obj,varargin)
            ax=timerAxes(varargin{:});scatter(ax,obj.get_values("cpu_time"),obj.get_values("wall_time"),"filled");xlabel(ax,"CPU time");ylabel(ax,"Wall time");grid(ax,"on");fig=ancestor(ax,"figure");
        end
    end
end
function ax=timerAxes(varargin)
ax=[];for i=1:2:numel(varargin),if string(varargin{i})=="ax",ax=varargin{i+1};end,end
if isempty(ax),f=figure("Visible","off");ax=axes(f);end
end
