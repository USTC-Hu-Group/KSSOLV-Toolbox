classdef ParallelEfficiency
    properties
        filenames string
        ref_idx double
        data struct
    end
    methods
        function obj=ParallelEfficiency(filenames,ref_idx,data),obj.filenames=string(filenames);obj.ref_idx=ref_idx;obj.data=data;end
        function value=totable(obj,stop,reverse)
            if nargin<2,stop=[];end;if nargin<3,reverse=true;end
            names=string(fieldnames(obj.data));scores=zeros(size(names));
            for i=1:numel(names),scores(i)=mean(obj.data.(names(i)).wall_time);end
            if reverse,[~,idx]=sort(scores,"descend");else,[~,idx]=sort(scores);end;names=names(idx);
            if ~isempty(stop),names=names(1:min(stop,numel(names)));end
            value=cell(numel(names)+1,1+2*numel(obj.filenames));value(1,1)={"AbinitTimerSection"};
            for i=1:numel(names),value{i+1,1}=names(i);entry=obj.data.(names(i));row=kssolv.analysis.matgenlab.io.abinit.alternate(num2cell(entry.wall_time),num2cell(entry.wall_fract));value(i+1,2:end)=row;end
        end
        function value=good_sections(obj,key,criterion,nmax)
            if nargin<2,key="wall_time";end;if nargin<3,criterion="mean";end;if nargin<4,nmax=5;end
            value=obj.ordered(key,criterion,true,nmax);
        end
        function value=bad_sections(obj,key,criterion,nmax)
            if nargin<2,key="wall_time";end;if nargin<3,criterion="mean";end;if nargin<4,nmax=5;end
            value=obj.ordered(key,criterion,false,nmax);
        end
        function value=subsref(obj,s)
            if strcmp(s(1).type,"()"),name=char(string(s(1).subs{1}));value=obj.data.(name);if numel(s)>1,value=builtin("subsref",value,s(2:end));end
            else,value=builtin("subsref",obj,s);end
        end
    end
    methods(Access=private)
        function value=ordered(obj,key,criterion,reverse,nmax)
            names=string(fieldnames(obj.data));scores=zeros(size(names));
            for i=1:numel(names)
                v=obj.data.(names(i)).(char(key));v(obj.ref_idx)=[];
                if isempty(v),scores(i)=1;
                elseif string(criterion)=="min",scores(i)=min(v);
                elseif string(criterion)=="max",scores(i)=max(v);
                else,scores(i)=mean(v);
                end
            end
            if reverse,[~,idx]=sort(scores,"descend");else,[~,idx]=sort(scores);end;value=names(idx(1:min(nmax,numel(idx))));
        end
    end
end
