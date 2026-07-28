classdef AbinitTimerParser < handle
    properties(SetAccess=private)
        filenames string=strings(0,1)
    end
    properties(Access=private)
        records struct=struct()
    end
    methods
        function obj=AbinitTimerParser()
        end
        function value=length(obj),value=numel(obj.filenames);end
        function ok=parse(obj,filenames)
            filenames=string(filenames);ok=strings(0,1);
            for filename=reshape(filenames,1,[])
                if ~isfile(filename),continue,end
                try
                    timers=obj.parseFile(filename);
                    key=matlab.lang.makeValidName("f_"+string(numel(obj.filenames)+1));
                    obj.records.(key)=timers;obj.filenames(end+1)=filename;ok(end+1)=filename; %#ok<AGROW>
                catch
                end
            end
        end
        function value=timers(obj,filename,mpi_rank)
            if nargin<3,mpi_rank="0";end
            if nargin>=2&&~isempty(filename),idx=find(obj.filenames==string(filename),1);else,idx=1:numel(obj.filenames);end
            value=cell(1,numel(idx));
            for j=1:numel(idx),key=matlab.lang.makeValidName("f_"+string(idx(j)));rankKey=matlab.lang.makeValidName("r_"+string(mpi_rank));value{j}=obj.records.(key).(rankKey);end
        end
        function value=section_names(obj,ordkey)
            if nargin<2,ordkey="wall_time";end;t=obj.timers();if isempty(t),value=strings(0,1);else,s=t{1}.order_sections(ordkey);value=cellfun(@(x)x.name,s);end
        end
        function value=get_sections(obj,name)
            timers=obj.timers();value=cell(size(timers));
            for i=1:numel(timers),try,value{i}=timers{i}.get_section(name);catch,value{i}=kssolv.analysis.matgenlab.io.abinit.AbinitTimerSection.fake();end,end %#ok<NOCOMMA>
        end
        function value=pefficiency(obj)
            timers=obj.timers();ncpus=cellfun(@(t)t.ncpus,timers);[mincpu,ref]=min(ncpus);data=struct();
            totalCpu=cellfun(@(t)(mincpu*timers{ref}.cpu_time)/(t.cpu_time*t.ncpus),timers);
            totalWall=cellfun(@(t)(mincpu*timers{ref}.wall_time)/(t.wall_time*t.ncpus),timers);
            data.total=struct("cpu_time",totalCpu,"wall_time",totalWall,"cpu_fract",100*ones(size(totalCpu)),"wall_fract",100*ones(size(totalWall)));
            for name=reshape(obj.section_names(),1,[])
                secs=obj.get_sections(name);r=secs{ref};
                cpu=zeros(size(secs));wall=zeros(size(secs));
                for j=1:numel(secs)
                    if secs{j}.cpu_time==0,cpu(j)=-1;else,cpu(j)=mincpu*r.cpu_time/(secs{j}.cpu_time*ncpus(j));end
                    if secs{j}.wall_time==0,wall(j)=-1;else,wall(j)=mincpu*r.wall_time/(secs{j}.wall_time*ncpus(j));end
                end
                key=matlab.lang.makeValidName(name);data.(key)=struct("cpu_time",cpu,"wall_time",wall,"cpu_fract",cellfun(@(s)s.cpu_fract,secs),"wall_fract",cellfun(@(s)s.wall_fract,secs));
            end
            value=kssolv.analysis.matgenlab.io.abinit.ParallelEfficiency(obj.filenames,ref,data);
        end
        function value=summarize(obj,varargin)
            timers=obj.timers();n=numel(timers);fname=strings(n,1);wall_time=zeros(n,1);cpu_time=zeros(n,1);mpi_nprocs=zeros(n,1);omp_nthreads=zeros(n,1);mpi_rank=strings(n,1);
            for i=1:n,t=timers{i};fname(i)=t.fname;wall_time(i)=t.wall_time;cpu_time(i)=t.cpu_time;mpi_nprocs(i)=t.mpi_nprocs;omp_nthreads(i)=t.omp_nthreads;mpi_rank(i)=t.mpi_rank;end
            tot_ncpus=mpi_nprocs.*omp_nthreads;[refcpus,idx]=min(tot_ncpus);peff=refcpus*wall_time(idx)./(wall_time.*tot_ncpus);
            value=table(fname,wall_time,cpu_time,mpi_nprocs,omp_nthreads,mpi_rank,tot_ncpus,peff);
        end
        function fig=plot_efficiency(obj,varargin)
            pe=obj.pefficiency();ax=parserAxes(varargin{:});names=pe.good_sections("wall_time","mean",5);hold(ax,"on");
            for name=reshape(names,1,[]),plot(ax,pe.data.(char(name)).wall_time,"-o","DisplayName",name);end
            plot(ax,pe.data.total.wall_time,"r-","DisplayName","total");legend(ax,"show");grid(ax,"on");fig=ancestor(ax,"figure");
        end
        function fig=plot_pie(obj,varargin)
            timers=obj.timers();f=figure("Visible","off");for i=1:numel(timers),ax=subplot(numel(timers),1,i,"Parent",f);timers{i}.pie("wall_time",.05,"ax",ax);end;fig=f;
        end
        function fig=plot_stacked_hist(obj,varargin)
            timers=obj.timers();ax=parserAxes(varargin{:});names=obj.section_names();n=min(5,numel(names));data=zeros(numel(timers),n);
            for i=1:n,s=obj.get_sections(names(i));data(:,i)=cellfun(@(x)x.wall_time,s);end
            bar(ax,data,"stacked");legend(ax,names(1:n));fig=ancestor(ax,"figure");
        end
        function value=plot_all(obj,varargin),value={obj.plot_stacked_hist(varargin{:}),obj.plot_efficiency(varargin{:}),obj.plot_pie(varargin{:})};end
    end
    methods(Static)
        function [parser,paths,ok]=walk(top,ext)
            if nargin<1,top=".";end;if nargin<2,ext=".abo";end
            entries=dir(fullfile(top,"**","*"+string(ext)));paths=string(fullfile({entries.folder},{entries.name}));parser=kssolv.analysis.matgenlab.io.abinit.AbinitTimerParser();ok=parser.parse(paths);
        end
    end
    methods(Access=private)
        function result=parseFile(~,filename)
            lines=splitlines(string(fileread(filename)));result=struct();i=1;found=false;
            while i<=numel(lines)
                if startsWith(lines(i),"-<BEGIN_TIMER")
                    found=true;header=extractBetween(lines(i),strlength("-<BEGIN_TIMER")+1,strlength(lines(i))-1);info=kvInfo(header);info.fname=string(filename);
                    i=i+1;times=kvInfo(extractAfter(lines(i),1));cpu=str2double(times.cpu_time);wall=str2double(times.wall_time);sections={};i=i+1;
                    while i<=numel(lines)&&~startsWith(lines(i),"-<END_TIMER")
                        line=char(lines(i));tok=regexp(line,'^-\s*(.*?)\s+([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+(-?\d+)\s+([-+]?\d+\.\d+)(?:\s+.*)?$','tokens','once');
                        if ~isempty(tok),sections{end+1}=kssolv.analysis.matgenlab.io.abinit.AbinitTimerSection(tok{:});end %#ok<AGROW>
                        i=i+1;
                    end
                    timer=kssolv.analysis.matgenlab.io.abinit.AbinitTimer(sections,info,cpu,wall);result.(matlab.lang.makeValidName("r_"+string(info.mpi_rank)))=timer;
                end
                i=i+1;
            end
            if ~found,error("KSSOLV:Matgenlab:Abinit:TimerParse","No timer section found.");end
        end
    end
end
function d=kvInfo(text)
d=struct();parts=split(string(text),",");for p=reshape(parts,1,[]),kv=split(p,"=");if numel(kv)==2,d.(char(strtrim(kv(1))))=strtrim(kv(2));end,end
end
function ax=parserAxes(varargin)
ax=[];for i=1:2:numel(varargin),if string(varargin{i})=="ax",ax=varargin{i+1};end,end;if isempty(ax),f=figure("Visible","off");ax=axes(f);end
end
