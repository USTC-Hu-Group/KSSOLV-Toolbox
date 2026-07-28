classdef SurfaceEnergyPlotter
    %SURFACEENERGYPLOTTER Analyze slab stability versus chemical potential.
    properties
        all_slab_entries
        ucell_entry
        ref_entries cell = cell(1,0)
        color_dict
        surfe_dict
        as_coeffs_dict
        list_of_chempots string = strings(1,0)
    end
    properties (Access=private)
        entries_ cell = cell(1,0)
        expressions_ cell = cell(1,0)
    end
    methods
        function obj=SurfaceEnergyPlotter(allSlabEntries,ucellEntry,refEntries)
            if nargin<3||isempty(refEntries),refEntries={};end
            if ~iscell(refEntries),refEntries=num2cell(refEntries);end
            obj.ucell_entry=ucellEntry;obj.ref_entries=refEntries;
            if isstruct(allSlabEntries)&&all(isfield(allSlabEntries, ...
                    ["hkl","clean","ads"]))
                obj.all_slab_entries=allSlabEntries;
            else
                obj.all_slab_entries=kssolv.analysis.matgenlab.analysis. ...
                    entry_dict_from_list(allSlabEntries);
            end
            entries={};expressions={};
            for facet=1:numel(obj.all_slab_entries)
                group=obj.all_slab_entries(facet);
                for clean=1:numel(group.clean)
                    entries{end+1}=group.clean{clean}; %#ok<AGROW>
                    expressions{end+1}=group.clean{clean}.surface_energy( ...
                        ucellEntry,refEntries); %#ok<AGROW>
                    for ads=1:numel(group.ads{clean})
                        entries{end+1}=group.ads{clean}{ads}; %#ok<AGROW>
                        expressions{end+1}=group.ads{clean}{ads}.surface_energy( ...
                            ucellEntry,refEntries); %#ok<AGROW>
                    end
                end
            end
            obj.entries_=entries;obj.expressions_=expressions;
            obj.surfe_dict=struct("entries",{entries},"values",{expressions});
            coefficients=cellfun(@fullCoefficientMap,expressions, ...
                "UniformOutput",false);
            obj.as_coeffs_dict=struct("entries",{entries},"values",{coefficients});
            names=strings(1,0);
            for index=1:numel(expressions)
                if isa(expressions{index},"kssolv.analysis.matgenlab.analysis.SurfaceEnergyExpression")
                    names=[names,expressions{index}.free_symbols]; %#ok<AGROW>
                end
            end
            obj.list_of_chempots=unique(names,"stable");
            obj.color_dict=obj.color_palette_dict();
        end
        function [entry,gamma]=get_stable_entry_at_u(obj,millerIndex,varargin)
            options=struct(delu_dict=struct(),delu_default=0, ...
                no_doped=false,no_clean=false);
            options=parseOptions(options,varargin{:});
            group=obj.groupFor(millerIndex);candidates={};
            for index=1:numel(group.clean)
                if ~options.no_clean,candidates{end+1}=group.clean{index};end %#ok<AGROW>
                if ~options.no_doped
                    candidates=[candidates,group.ads{index}]; %#ok<AGROW>
                end
            end
            if isempty(candidates)
                error("KSSOLV:Matgenlab:SurfaceEnergyPlotter:NoEntries", ...
                    "No entries remain after applying the filters.");
            end
            values=cellfun(@(x)obj.evaluateEntry(x,options.delu_dict, ...
                options.delu_default),candidates);
            [gamma,index]=min(values);entry=candidates{index};
        end
        function shape=wulff_from_chempot(obj,varargin)
            options=struct(delu_dict=struct(),delu_default=0,symprec=1e-5, ...
                no_clean=false,no_doped=false);
            options=parseOptions(options,varargin{:});
            facets=obj.all_slab_entries;hkl=zeros(numel(facets),3);
            energies=zeros(1,numel(facets));
            for index=1:numel(facets)
                hkl(index,:)=facets(index).hkl;
                [~,energies(index)]=obj.get_stable_entry_at_u( ...
                    facets(index).hkl,"delu_dict",options.delu_dict, ...
                    "delu_default",options.delu_default, ...
                    "no_clean",options.no_clean,"no_doped",options.no_doped);
            end
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.ucell_entry.structure,options.symprec);
            conventional=analyzer.get_conventional_standard_structure();
            shape=kssolv.analysis.matgenlab.analysis.WulffShape( ...
                conventional.lattice,hkl,energies,options.symprec);
        end
        function ax=area_frac_vs_chempot_plot(obj,refDelu,chempotRange,varargin)
            options=struct(delu_dict=struct(),delu_default=0,increments=10, ...
                no_clean=false,no_doped=false);
            options=parseOptions(options,varargin{:});
            x=linspace(min(chempotRange),max(chempotRange),options.increments);
            areas=zeros(numel(x),numel(obj.all_slab_entries));
            for point=1:numel(x)
                values=setValue(options.delu_dict,refDelu,x(point));
                shape=obj.wulff_from_chempot("delu_dict",values, ...
                    "delu_default",options.delu_default,"no_clean", ...
                    options.no_clean,"no_doped",options.no_doped);
                areas(point,:)=shape.area_fractions;
            end
            ax=axes("Parent",figure("Visible","off"));hold(ax,"on");
            for index=1:size(areas,2)
                plot(ax,x,areas(:,index),"DisplayName", ...
                    mat2str(obj.all_slab_entries(index).hkl));
            end
            xlabel(ax,char(string(refDelu)));ylabel(ax,"Fractional Wulff area");
        end
        function solution=get_surface_equilibrium(obj,slabEntries,deluDict)
            if nargin<3,deluDict=struct();end
            if ~iscell(slabEntries),slabEntries=num2cell(slabEntries);end
            expressions=cellfun(@(x)obj.expressionFor(x),slabEntries, ...
                "UniformOutput",false);
            names=strings(1,0);
            for index=1:numel(expressions)
                expression=subExpression(expressions{index},deluDict);
                expressions{index}=expression;
                if isa(expression,"kssolv.analysis.matgenlab.analysis.SurfaceEnergyExpression")
                    names=[names,expression.free_symbols]; %#ok<AGROW>
                end
            end
            names=unique(names,"stable");
            matrix=zeros(numel(expressions),numel(names)+1);
            right=zeros(numel(expressions),1);
            for row=1:numel(expressions)
                [constant,coefficients]=coefficientsOf(expressions{row});
                right(row)=-constant;matrix(row,end)=-1;
                for col=1:numel(names)
                    field=char(names(col));
                    if isfield(coefficients,field),matrix(row,col)=coefficients.(field);end
                end
            end
            values=matrix\right;
            if rank(matrix)<size(matrix,2)|| ...
                    norm(matrix*values-right)>1e-9*(1+norm(right))
                solution=[];return
            end
            solution=struct();
            for index=1:numel(names),solution.(names(index))=values(index);end
            solution.gamma=values(end);
        end
        function varargout=stable_u_range_dict(obj,chempotRange,refDelu,varargin)
            options=struct(no_doped=true,no_clean=false,delu_dict=struct(), ...
                miller_index=[],dmu_at_0=false,return_se_dict=false);
            options=parseOptions(options,varargin{:});
            ranges=struct("entry",{},"range",{});seValues=struct("entry",{},"values",{});
            facets=obj.all_slab_entries;
            for facet=1:numel(facets)
                if ~isempty(options.miller_index)&& ...
                        ~isequal(facets(facet).hkl,options.miller_index),continue,end
                candidates={};
                for clean=1:numel(facets(facet).clean)
                    if ~options.no_clean
                        candidates{end+1}=facets(facet).clean{clean}; %#ok<AGROW>
                    end
                    if ~options.no_doped
                        candidates=[candidates,facets(facet).ads{clean}]; %#ok<AGROW>
                    end
                end
                slopes=zeros(1,numel(candidates));intercepts=slopes;
                for index=1:numel(candidates)
                    atZero=setValue(options.delu_dict,refDelu,0);
                    atOne=setValue(options.delu_dict,refDelu,1);
                    intercepts(index)=obj.evaluateEntry(candidates{index},atZero,0);
                    slopes(index)=obj.evaluateEntry(candidates{index},atOne,0)- ...
                        intercepts(index);
                end
                breakpoints=sort(double(chempotRange));
                for first=1:numel(candidates)-1
                    for second=first+1:numel(candidates)
                        delta=slopes(first)-slopes(second);
                        if abs(delta)<1e-14,continue,end
                        crossing=(intercepts(second)-intercepts(first))/delta;
                        if crossing>=breakpoints(1)&&crossing<=breakpoints(end)
                            breakpoints(end+1)=crossing; %#ok<AGROW>
                        end
                    end
                end
                breakpoints=unique(sort(breakpoints));
                stable=false(numel(candidates),numel(breakpoints)-1);
                for interval=1:numel(breakpoints)-1
                    midpoint=mean(breakpoints(interval:interval+1));
                    gamma=intercepts+slopes*midpoint;
                    stable(:,interval)=abs(gamma-min(gamma))<=1e-10;
                end
                for index=1:numel(candidates)
                    intervals=find(stable(index,:));
                    if isempty(intervals),continue,end
                    range=[breakpoints(intervals(1)), ...
                        breakpoints(intervals(end)+1)];
                    values=intercepts(index)+slopes(index)*range;
                    if options.dmu_at_0&&prod(values)<0
                        range=sort([range,-intercepts(index)/slopes(index)]);
                        values=[values(1),0,values(2)];
                    end
                    ranges(end+1)=struct("entry",candidates{index},"range",range); %#ok<AGROW>
                    seValues(end+1)=struct("entry",candidates{index},"values",values); %#ok<AGROW>
                end
            end
            varargout{1}=ranges;
            if options.return_se_dict,varargout{2}=seValues;end
        end
        function colors=color_palette_dict(obj,alpha)
            if nargin<2,alpha=0.35;end
            colors=struct("entry",{},"rgba",{});
            facets=obj.all_slab_entries;
            for facet=1:numel(facets)
                base=hsv2rgb([mod((facet-1)/max(numel(facets),1),1),0.7,0.8]);
                for clean=1:numel(facets(facet).clean)
                    shade=base*(0.55+0.45*clean/numel(facets(facet).clean));
                    colors(end+1)=struct("entry",facets(facet).clean{clean}, ...
                        "rgba",[shade,1]); %#ok<AGROW>
                    for ads=1:numel(facets(facet).ads{clean})
                        colors(end+1)=struct("entry", ...
                            facets(facet).ads{clean}{ads}, ...
                            "rgba",[shade,alpha]); %#ok<AGROW>
                    end
                end
            end
        end
        function ax=chempot_vs_gamma_plot_one(obj,ax,entry,refDelu, ...
                chempotRange,varargin)
            options=struct(delu_dict=struct(),delu_default=0,label="",JPERM2=false);
            options=parseOptions(options,varargin{:});
            if isempty(ax),ax=axes("Parent",figure("Visible","off"));end
            x=sort(double(chempotRange));y=zeros(size(x));
            for index=1:numel(x)
                values=setValue(options.delu_dict,refDelu,x(index));
                y(index)=obj.evaluateEntry(entry,values,options.delu_default);
            end
            if options.JPERM2,y=y*16.0217656;end
            plot(ax,x,y,"DisplayName",options.label);
        end
        function ax=chempot_vs_gamma(obj,refDelu,chempotRange,varargin)
            options=struct(miller_index=[],delu_dict=struct(), ...
                delu_default=0,JPERM2=false,show_unstable=false,ylim=[], ...
                plt=[],no_clean=false,no_doped=false,use_entry_labels=false, ...
                no_label=false);
            options=parseOptions(options,varargin{:});
            if isempty(options.plt),ax=axes("Parent",figure("Visible","off"));
            else,ax=options.plt;end
            hold(ax,"on");facets=obj.all_slab_entries;
            for facet=1:numel(facets)
                if ~isempty(options.miller_index)&& ...
                        ~isequal(options.miller_index,facets(facet).hkl),continue,end
                if options.show_unstable
                    stableRanges=struct("entry",{},"range",{});
                else
                    stableRanges=obj.stable_u_range_dict(chempotRange, ...
                        refDelu,"no_doped",options.no_doped, ...
                        "no_clean",options.no_clean, ...
                        "delu_dict",options.delu_dict, ...
                        "miller_index",facets(facet).hkl);
                end
                candidates={};
                for clean=1:numel(facets(facet).clean)
                    if ~options.no_clean,candidates{end+1}=facets(facet).clean{clean};end %#ok<AGROW>
                    if ~options.no_doped,candidates=[candidates,facets(facet).ads{clean}];end %#ok<AGROW>
                end
                for index=1:numel(candidates)
                    plotRange=chempotRange;
                    if ~options.show_unstable
                        match=find(arrayfun(@(x)sameEntry( ...
                            x.entry,candidates{index}),stableRanges),1);
                        if isempty(match),continue,end
                        plotRange=stableRanges(match).range;
                    end
                    label="";
                    if ~options.no_label
                        if options.use_entry_labels&& ...
                                ~isempty(candidates{index}.label)
                            label=string(candidates{index}.label);
                        else
                            label=string(candidates{index}.create_slab_label);
                        end
                    end
                    obj.chempot_vs_gamma_plot_one(ax,candidates{index},refDelu, ...
                        plotRange,"delu_dict",options.delu_dict, ...
                        "delu_default",options.delu_default,"label",label, ...
                        "JPERM2",options.JPERM2);
                end
            end
            if ~isempty(options.ylim),ylim(ax,options.ylim);end
        end
        function ax=monolayer_vs_BE(obj,plotEads)
            if nargin<2,plotEads=false;end
            ax=axes("Parent",figure("Visible","off"));hold(ax,"on");
            for facet=1:numel(obj.all_slab_entries)
                group=obj.all_slab_entries(facet);
                for clean=1:numel(group.clean)
                    ads=group.ads{clean};
                    if isempty(ads),continue,end
                    x=cellfun(@(e)e.get_monolayer,ads);
                    y=cellfun(@(e)e.gibbs_binding_energy(plotEads),ads);
                    [x,~,groups]=unique(x);y=accumarray(groups(:),y(:),[],@min);
                    [x,order]=sort(x);y=y(order);
                    plot(ax,x,y,"o-");
                end
            end
            xlabel(ax,"Monolayer");ylabel(ax,"Binding energy (eV)");
        end
        function ax=BE_vs_clean_SE(obj,deluDict,varargin)
            options=struct(delu_default=0,plot_eads=false, ...
                annotate_monolayer=true,JPERM2=false);
            options=parseOptions(options,varargin{:});
            ax=axes("Parent",figure("Visible","off"));hold(ax,"on");
            for facet=1:numel(obj.all_slab_entries)
                group=obj.all_slab_entries(facet);
                for clean=1:numel(group.clean)
                    x=obj.evaluateEntry(group.clean{clean},deluDict,options.delu_default);
                    if options.JPERM2,x=x*16.0217656;end
                    for ads=1:numel(group.ads{clean})
                        entry=group.ads{clean}{ads};
                        y=entry.gibbs_binding_energy(options.plot_eads);
                        plot(ax,x,y,"o");
                        if options.annotate_monolayer
                            text(ax,x,y,sprintf("%.3f ML",entry.get_monolayer));
                        end
                    end
                end
            end
        end
        function ax=surface_chempot_range_map(obj,elements,millerIndex,ranges,varargin)
            options=struct(incr=50,no_doped=false,no_clean=false, ...
                delu_dict=struct(),ax=[],annotate=true, ...
                show_unphysical_only=false,fontsize=10);
            options=parseOptions(options,varargin{:});
            if isempty(options.ax),ax=axes("Parent",figure("Visible","off"));
            else,ax=options.ax;end
            names=string(elements);x=linspace(ranges(1,1),ranges(1,2),options.incr);
            y=linspace(ranges(2,1),ranges(2,2),options.incr);ids=zeros(numel(y),numel(x));
            entries={};
            for row=1:numel(y)
                for col=1:numel(x)
                    values=setValue(options.delu_dict,names(1),x(col));
                    values=setValue(values,names(2),y(row));
                    [entry,gamma]=obj.get_stable_entry_at_u(millerIndex, ...
                        "delu_dict",values,"no_doped",options.no_doped, ...
                        "no_clean",options.no_clean);
                    index=find(cellfun(@(z)sameEntry(z,entry),entries),1);
                    if isempty(index),entries{end+1}=entry;index=numel(entries);end %#ok<AGROW>
                    if options.show_unphysical_only&&gamma>=0,index=0;end
                    ids(row,col)=index;
                end
            end
            imagesc(ax,x,y,ids);axis(ax,"xy");
        end
        function values=set_all_variables(obj,deluDict,deluDefault)
            if nargin<2||isempty(deluDict),deluDict=struct();end
            if nargin<3,deluDefault=0;end
            values=deluDict;
            for index=1:numel(obj.list_of_chempots)
                name=char(obj.list_of_chempots(index));
                if ~hasValue(values,name),values=setValue(values,name,deluDefault);end
            end
            values=setValue(values,"constant",1);
        end
    end
    methods (Static)
        function chempot_plot_addons(ax,xrange,refEl,varargin)
            options=struct(pad=2.4,rect=[],ylim=[]);
            options=parseOptions(options,varargin{:});
            xlim(ax,sort(xrange));xlabel(ax,"\Delta\mu_"+string(refEl)+" (eV)");
            if ~isempty(options.ylim),ylim(ax,options.ylim);end
            if ~isempty(options.rect)&&numel(options.rect)==4
                set(ax,"Position",options.rect);
            end
            if options.pad<0
                error("KSSOLV:Matgenlab:SurfaceEnergyPlotter:Padding", ...
                    "Padding must be nonnegative.");
            end
            grid(ax,"on");
        end
    end
    methods (Access=private)
        function group=groupFor(obj,hkl)
            index=find(arrayfun(@(x)isequal(x.hkl,reshape(hkl,1,3)), ...
                obj.all_slab_entries),1);
            if isempty(index),error("KSSOLV:Matgenlab:SurfaceEnergyPlotter:Facet", ...
                    "Unknown Miller index.");end
            group=obj.all_slab_entries(index);
        end
        function expression=expressionFor(obj,entry)
            index=find(cellfun(@(x)sameEntry(x,entry),obj.entries_),1);
            if isempty(index),error("KSSOLV:Matgenlab:SurfaceEnergyPlotter:Entry", ...
                    "Entry is not registered with this plotter.");end
            expression=obj.expressions_{index};
        end
        function value=evaluateEntry(obj,entry,values,default)
            expression=obj.expressionFor(entry);
            if isnumeric(expression),value=expression;
            else,value=expression.evaluate(values,default);end
        end
    end
end
function options=parseOptions(options,varargin)
names=fieldnames(options);
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
function [constant,coefficients]=coefficientsOf(expression)
if isnumeric(expression),constant=double(expression);coefficients=struct();
else,constant=expression.constant;coefficients=expression.coefficients;end
end
function result=fullCoefficientMap(expression)
[constant,result]=coefficientsOf(expression);
result.constant=constant;
end
function result=subExpression(expression,values)
if isnumeric(expression),result=expression;else,result=expression.subs(values);end
end
function tf=sameEntry(first,second)
tf=first==second;
if isa(first,"kssolv.analysis.matgenlab.analysis.SlabEntry")&& ...
        isa(second,"kssolv.analysis.matgenlab.analysis.SlabEntry")
    tf=tf&&isequal(first.miller_index,second.miller_index);
end
end
function values=setValue(values,name,value)
name=char(string(name));
if startsWith(name,"Symbol(")
    token=regexp(name,'Symbol\\([''\"]?([^''\")]+)','tokens','once');
    if ~isempty(token),name=token{1};end
end
if isa(values,"containers.Map")
    values(name)=value;
elseif isempty(values)
    values=struct(matlab.lang.makeValidName(name),value);
else
    values.(matlab.lang.makeValidName(name))=value;
end
end
function tf=hasValue(values,name)
if isa(values,"containers.Map"),tf=isKey(values,char(name));
else,tf=isstruct(values)&&isfield(values,char(name));end
end
