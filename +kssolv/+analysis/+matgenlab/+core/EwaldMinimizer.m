classdef EwaldMinimizer < handle
    %EWALDMINIMIZER Branch-and-bound minimization of an Ewald interaction matrix.
    properties (Constant)
        ALGO_FAST=0
        ALGO_COMPLETE=1
        ALGO_BEST_FIRST=2
        ALGO_TIME_LIMIT=3
    end
    properties (Access=private)
        matrix_
        m_list_
        current_minimum_=Inf
        num_to_return_=1
        algo_=0
        output_lists_=cell(0,2)
        finished_=false
        start_time_
        best_m_list_={}
        minimized_sum_=Inf
    end
    properties (Dependent,SetAccess=private)
        best_m_list
        minimized_sum
        output_lists
    end
    methods
        function obj=EwaldMinimizer(matrix,m_list,num_to_return,algo)
            if nargin<3||isempty(num_to_return),num_to_return=1;end
            if nargin<4||isempty(algo),algo=obj.ALGO_FAST;end
            obj.matrix_=(double(matrix)+double(matrix).')/2;
            obj.m_list_=obj.normalizeManipulations(m_list);
            counts=zeros(1,numel(obj.m_list_));
            for index=1:numel(obj.m_list_)
                manipulation=obj.m_list_{index};
                if manipulation{1}>1
                    error("KSSOLV:Matgenlab:EwaldMinimizer:Fraction", ...
                        "Multiplication fractions must be <= 1.");
                end
                counts(index)=nchoosek(numel(manipulation{3}),manipulation{2});
            end
            [~,order]=sort(counts,"descend");obj.m_list_=obj.m_list_(order);
            obj.num_to_return_=num_to_return;obj.algo_=algo;
            if algo==obj.ALGO_COMPLETE
                error("KSSOLV:Matgenlab:EwaldMinimizer:Complete", ...
                    "Complete algorithm is not implemented.");
            end
            obj.start_time_=tic;
            obj.minimize_matrix();
            if ~isempty(obj.output_lists_)
                obj.minimized_sum_=obj.output_lists_{1,1};
                obj.best_m_list_=obj.output_lists_{1,2};
            end
        end
        function minimize_matrix(obj)
            if ismember(obj.algo_,[obj.ALGO_FAST,obj.ALGO_BEST_FIRST,obj.ALGO_TIME_LIMIT])
                obj.recurse(obj.matrix_,obj.m_list_,1:size(obj.matrix_,1),{});
            end
        end
        function add_m_list(obj,matrix_sum,m_list)
            obj.output_lists_(end+1,:)={matrix_sum,m_list};
            [~,order]=sort(cell2mat(obj.output_lists_(:,1)));
            obj.output_lists_=obj.output_lists_(order,:);
            if obj.algo_==obj.ALGO_BEST_FIRST&& ...
                    size(obj.output_lists_,1)==obj.num_to_return_
                obj.finished_=true;
            end
            if size(obj.output_lists_,1)>obj.num_to_return_
                obj.output_lists_(end,:)=[];
            end
            if size(obj.output_lists_,1)==obj.num_to_return_
                obj.current_minimum_=obj.output_lists_{end,1};
            end
        end
        function value=best_case(obj,matrix,m_list,indices_left)
            m_list=obj.normalizeManipulations(m_list);
            indices_left=obj.normalizeIndices(indices_left,size(matrix,1));
            mIndices=[];fractions=[];
            for index=1:numel(m_list)
                m=m_list{index};mIndices=[mIndices,m{3}]; %#ok<AGROW>
                fractions=[fractions,repmat(m{1},1,m{2})]; %#ok<AGROW>
            end
            indices=intersect(indices_left,mIndices);
            interaction=matrix(indices,indices);
            fractionValues=ones(1,numel(indices));
            fractionValues(1:numel(fractions))=fractions;
            fractionValues=sort(fractionValues);
            sums=sort(2*sum(matrix(indices,:),2));
            step1=sort(interaction,1).*(1-fractionValues);
            step2=sort(sum(step1,2));
            interactionCorrection=sum(step2.*(1-fractionValues(:)));
            if obj.algo_==obj.ALGO_TIME_LIMIT
                speed=min(toc(obj.start_time_)/1800,1);
                average=sum(interaction,"all")* ...
                    mean((1-fractionValues(:))*(1-fractionValues(:)).',"all");
                interactionCorrection=average*speed+interactionCorrection*(1-speed);
            end
            value=sum(matrix,"all")+dot(flip(sums),fractionValues(:)-1)+ ...
                interactionCorrection;
        end
        function index=get_next_index(obj,matrix,manipulation,indices_left)
            values=obj.normalizeManipulations({manipulation});m=values{1};
            indices_left=obj.normalizeIndices(indices_left,size(matrix,1));
            indices=intersect(indices_left,m{3});sums=sum(matrix(indices,:),2);
            if m{1}<1,[~,which]=max(sums);else,[~,which]=min(sums);end
            index=indices(which)-1; % pymatgen-compatible public zero-based index
        end
        function value=get.best_m_list(obj),value=obj.best_m_list_;end
        function value=get.minimized_sum(obj),value=obj.minimized_sum_;end
        function value=get.output_lists(obj),value=obj.output_lists_;end
    end
    methods (Access=private)
        function recurse(obj,matrix,m_list,indices,output)
            if obj.finished_,return,end
            while ~isempty(m_list)&&m_list{end}{2}==0
                m_list(end)=[];
                if isempty(m_list)
                    matrixSum=sum(matrix,"all");
                    if matrixSum<obj.current_minimum_,obj.add_m_list(matrixSum,output);end
                    return
                end
            end
            manipulation=m_list{end};
            if manipulation{2}>numel(intersect(indices,manipulation{3})),return,end
            if (isscalar(m_list)||manipulation{2}>1)&& ...
                    obj.bestCaseInternal(matrix,m_list,indices)>obj.current_minimum_
                return
            end
            candidates=intersect(indices,manipulation{3});
            sums=sum(matrix(candidates,:),2);
            if manipulation{1}<1,[~,which]=max(sums);else,[~,which]=min(sums);end
            selected=candidates(which);
            manipulation{3}(manipulation{3}==selected)=[];
            m_list{end}=manipulation;
            matrix2=matrix;matrix2(selected,:)=matrix2(selected,:)*manipulation{1};
            matrix2(:,selected)=matrix2(:,selected)*manipulation{1};
            m_list2=obj.deepCopyManipulations(m_list);
            m_list2{end}{2}=m_list2{end}{2}-1;
            output2=output;
            output2(end+1,:)={selected-1,manipulation{4}};
            indices2=indices(indices~=selected);
            obj.recurse(matrix2,m_list2,indices2,output2);
            obj.recurse(matrix,m_list,indices,output);
        end
        function value=bestCaseInternal(~,matrix,m_list,indices)
            mIndices=[];fractions=[];
            for ii=1:numel(m_list)
                m=m_list{ii};mIndices=[mIndices,m{3}]; %#ok<AGROW>
                fractions=[fractions,repmat(m{1},1,m{2})]; %#ok<AGROW>
            end
            selected=intersect(indices,mIndices);
            interaction=matrix(selected,selected);
            f=ones(1,numel(selected));f(1:numel(fractions))=fractions;f=sort(f);
            sums=sort(2*sum(matrix(selected,:),2));
            step1=sort(interaction,1).*(1-f);
            step2=sort(sum(step1,2));
            correction=sum(step2.*(1-f(:)));
            value=sum(matrix,"all")+dot(flip(sums),f(:)-1)+correction;
        end
        function result=normalizeManipulations(~,input)
            if isempty(input),result={};return,end
            if ~iscell(input),error("KSSOLV:Matgenlab:EwaldMinimizer:Manipulations", ...
                    "Manipulations must be a cell array.");end
            if size(input,2)==4&&~iscell(input{1})
                rows=cell(1,size(input,1));
                for ii=1:size(input,1),rows{ii}=input(ii,:);end
                input=rows;
            end
            result=cell(1,numel(input));
            for ii=1:numel(input)
                m=input{ii};
                if ~iscell(m)||numel(m)~=4
                    error("KSSOLV:Matgenlab:EwaldMinimizer:Manipulations", ...
                        "Each manipulation must contain four items.");
                end
                m=reshape(m,1,4);m{3}=reshape(double(m{3}),1,[])+1;
                result{ii}=m;
            end
        end
        function values=normalizeIndices(~,values,n)
            values=reshape(double(values),1,[]);
            if any(values==0)
                values=values+1;
            elseif any(values>n)
                error("KSSOLV:Matgenlab:EwaldMinimizer:Index", ...
                    "Index exceeds matrix size.");
            end
        end
        function result=deepCopyManipulations(~,input)
            result=cell(size(input));
            for ii=1:numel(input),result{ii}=input{ii};end
        end
    end
end
