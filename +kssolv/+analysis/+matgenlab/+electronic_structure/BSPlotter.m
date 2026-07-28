classdef BSPlotter < handle
    %BSPLOTTER Data extraction and native MATLAB plots for symmetry-line bands.
    properties (SetAccess=protected)
        bs cell=cell(1,0)
        nb_bands double=[]
    end
    methods
        function obj=BSPlotter(bs),obj.add_bs(bs);end
        function add_bs(obj,input)
            if ~iscell(input),input=num2cell(input);end
            for ii=1:numel(input)
                item=input{ii};
                if ~isa(item,"kssolv.analysis.matgenlab.electronic_structure.BandStructureSymmLine")
                    error("KSSOLV:Matgenlab:BSPlotter:Type", ...
                        "BSPlotter requires BandStructureSymmLine objects.");
                end
                if ~isempty(obj.bs)
                    reference=cellfun(@(x)string(x.name),obj.bs{1}.branches);
                    current=cellfun(@(x)string(x.name),item.branches);
                    if ~isequal(reference,current)
                        error("KSSOLV:Matgenlab:BSPlotter:KPath", ...
                            "All band structures must have the same k-path.");
                    end
                end
                obj.bs{end+1}=item;obj.nb_bands(end+1)=item.nb_bands;
            end
        end
        function data=bs_plot_data(obj,zeroToEfermi,bs,bsRef,splitBranches)
            if nargin<2||isempty(zeroToEfermi),zeroToEfermi=true;end
            if nargin<3||isempty(bs),bs=obj.bs{1};end
            if nargin<4,bsRef=[];end
            if nargin<5||isempty(splitBranches),splitBranches=true;end
            isMetal=bs.is_metal();vbm=[];cbm=[];zero=0;
            if ~isMetal
                vbm=bs.get_vbm();cbm=bs.get_cbm();
                if zeroToEfermi,zero=vbm.energy;end
            elseif zeroToEfermi
                zero=bs.efermi;
            end
            distances=bs.distance;
            if ~isempty(bsRef)&&~isequal(bsRef.branches,bs.branches)
                distances=rescaleDistances(bsRef,bs);
            end
            if splitBranches
                ends=cellfun(@(x)x.end_index,bs.branches);cuts=ends(1:end-1);
            else
                cuts=branchSteps(bs.branches);cuts=cuts(2:end-1)-1;
            end
            pieces=splitVector(distances,cuts);energy=struct();
            names=fieldnames(bs.bands);
            for ii=1:numel(names),energy.(names{ii})=splitMatrix(bs.bands.(names{ii})-zero,cuts);end
            vbmPlot=zeros(0,2);cbmPlot=zeros(0,2);gap="";
            if ~isMetal
                for idx=reshape(vbm.kpoint_index,1,[]),vbmPlot(end+1,:)=[bs.distance(idx),vbm.energy-zero];end %#ok<AGROW>
                for idx=reshape(cbm.kpoint_index,1,[]),cbmPlot(end+1,:)=[bs.distance(idx),cbm.energy-zero];end %#ok<AGROW>
                info=bs.get_band_gap();kind="Indirect";if info.direct,kind="Direct";end
                gap=sprintf("%s %s bandgap = %g",kind,string(info.transition),info.energy);
            end
            data=struct(ticks=obj.get_ticks(),distances={pieces},energy=energy, ...
                vbm=vbmPlot,cbm=cbmPlot,lattice=bs.lattice_rec.as_dict(), ...
                zero_energy=zero,is_metal=isMetal,band_gap=gap);
        end
        function ax=get_plot(obj,zeroToEfermi,ylim,smooth,vbmCbmMarker, ...
                smoothTol,smoothK,smoothNp,bsLabels)
            if nargin<2||isempty(zeroToEfermi),zeroToEfermi=true;end
            if nargin<3,ylim=[];end
            if nargin<4||isempty(smooth),smooth=false;end
            if nargin<5||isempty(vbmCbmMarker),vbmCbmMarker=false;end
            if nargin<6||isempty(smoothTol),smoothTol=0;end %#ok<NASGU>
            if nargin<7||isempty(smoothK),smoothK=3;end
            if nargin<8||isempty(smoothNp),smoothNp=100;end
            if nargin<9,bsLabels=[];end
            if isscalar(smooth),smooth=repmat(logical(smooth),1,numel(obj.bs));end
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");colors=lines(numel(obj.bs));
            for ii=1:numel(obj.bs)
                reference=[];if ii>1,reference=obj.bs{1};end
                data=obj.bs_plot_data(zeroToEfermi,obj.bs{ii},reference,~smooth(ii));
                names=fieldnames(data.energy);
                for jj=1:numel(names)
                    style="-";if strcmp(names{jj},"down"),style="--";end
                    pieces=data.energy.(names{jj});
                    for kk=1:numel(pieces)
                        x=data.distances{kk};y=pieces{kk};
                        if smooth(ii)&&numel(x)>1
                            xi=linspace(x(1),x(end),smoothNp);
                            method="spline";if numel(x)<=smoothK,method="pchip";end
                            y=interp1(x,y.',xi,method).';x=xi;
                        end
                        label="Band "+ii+" "+names{jj};
                        if ~isempty(bsLabels),label=string(bsLabels(ii))+" "+names{jj};end
                        plot(ax,x,y.',style,"Color",colors(ii,:),"HandleVisibility", ...
                            onOff(kk==1),"DisplayName",label);
                    end
                end
                if vbmCbmMarker&&~data.is_metal
                    scatter(ax,data.vbm(:,1),data.vbm(:,2),50,"g","filled");
                    scatter(ax,data.cbm(:,1),data.cbm(:,2),50,"r","filled");
                end
                if ~zeroToEfermi,yline(ax,obj.bs{ii}.efermi,"-.","Color",colors(ii,:));end
            end
            ticks=obj.get_ticks();[tickDistance,tickLabels]=uniqueTicks(ticks);
            set(ax,"XTick",tickDistance,"XTickLabel",tickLabels);
            uniqueDistances=unique(ticks.distance);
            if ~isempty(uniqueDistances)
                for x=reshape(uniqueDistances,1,[]),xline(ax,x,"k-");end
            end
            xlim(ax,[0,obj.bs{1}.distance(end)]);
            if isempty(ylim),ylim=[-4,4];end,set(ax,"YLim",reshape(double(ylim),1,2));
            xlabel(ax,"Wave Vector");if zeroToEfermi,ylabel(ax,"E - E_f (eV)");else,ylabel(ax,"Energy (eV)");end
            legend(ax,"show","Location","best");box(ax,"on");
        end
        function show(obj,varargin),ax=obj.get_plot(varargin{:});ax.Parent.Visible="on";end
        function save_plot(obj,filename,ylim,zeroToEfermi,smooth)
            if nargin<3,ylim=[];end
            if nargin<4,zeroToEfermi=true;end
            if nargin<5,smooth=false;end
            ax=obj.get_plot(zeroToEfermi,ylim,smooth);exportgraphics(ax,string(filename));close(ax.Parent);
        end
        function ticks=get_ticks(obj)
            band=obj.bs{1};labels=strings(1,0);distance=[];
            for ii=1:numel(band.branches)
                branch=band.branches{ii};parts=split(string(branch.name),"-");
                if numel(parts)<2||parts(1)==parts(end),continue,end
                current=[formatTick(parts(1)),formatTick(parts(end))];
                positions=[band.distance(branch.start_index),band.distance(branch.end_index)];
                if ~isempty(labels)&&current(1)~=labels(end)
                    labels(end)=labels(end)+"$\mid$"+current(1);labels(end+1)=current(2);distance(end+1)=positions(2); %#ok<AGROW>
                else
                    labels=[labels,current];distance=[distance,positions]; %#ok<AGROW>
                end
            end
            ticks=struct(distance=distance,label=labels);
        end
        function ticks=get_ticks_old(obj)
            band=obj.bs{1};distance=[];labels=strings(1,0);
            for ii=1:numel(band.kpoints)
                if ~isempty(band.kpoints{ii}.label)
                    distance(end+1)=band.distance(ii);labels(end+1)=string(band.kpoints{ii}.label); %#ok<AGROW>
                end
            end
            ticks=struct(distance=distance,label=labels);
        end
        function ax=plot_compare(obj,other,legendOn)
            if nargin<3||isempty(legendOn),legendOn=true;end
            combined=kssolv.analysis.matgenlab.electronic_structure.BSPlotter(obj.bs{1});
            combined.add_bs(other.bs);ax=combined.get_plot();
            if ~legendOn,legend(ax,"off");end
        end
        function value=plot_brillouin(obj)
            labels=containers.Map("KeyType","char","ValueType","any");band=obj.bs{1};
            for ii=1:numel(band.kpoints)
                point=band.kpoints{ii};if ~isempty(point.label),labels(char(point.label))=point.frac_coords;end
            end
            lines=cell(1,numel(band.branches));
            for ii=1:numel(lines),b=band.branches{ii};lines{ii}=[band.kpoints{b.start_index}.frac_coords;band.kpoints{b.end_index}.frac_coords];end
            value=kssolv.analysis.matgenlab.electronic_structure.plot_brillouin_zone( ...
                band.lattice_rec,"lines",lines,"labels",labels);
        end
    end
end
function pieces=splitVector(array,cuts),edges=[0,cuts,numel(array)];pieces=cell(1,numel(edges)-1);for ii=1:numel(pieces),pieces{ii}=array(edges(ii)+1:edges(ii+1));end,end
function pieces=splitMatrix(array,cuts),edges=[0,cuts,size(array,2)];pieces=cell(1,numel(edges)-1);for ii=1:numel(pieces),pieces{ii}=array(:,edges(ii)+1:edges(ii+1));end,end
function steps=branchSteps(branches)
steps=zeros(1,numel(branches)+1);steps(1)=1;count=1;
for ii=2:numel(branches)
    a=split(string(branches{ii-1}.name),"-");
    b=split(string(branches{ii}.name),"-");
    if b(1)~=a(end),count=count+1;steps(count)=branches{ii}.start_index;end
end
steps(count+1)=branches{end}.end_index+1;steps=steps(1:count+1);
end
function distances=rescaleDistances(ref,band)
pieces=cell(1,numel(ref.branches));
for ii=1:numel(ref.branches)
    a=ref.branches{ii};b=band.branches{ii};
    pieces{ii}=linspace(ref.distance(a.start_index), ...
        ref.distance(a.end_index),b.end_index-b.start_index+1);
end
distances=cell2mat(pieces);
end
function value=onOff(condition),if condition,value="on";else,value="off";end,end
function value=formatTick(input),value=string(input);if startsWith(value,"\")||contains(value,"_"),value="$"+value+"$";end,end
function [distance,labels]=uniqueTicks(ticks)
[distance,~,groups]=unique(ticks.distance,"stable");labels=strings(size(distance));
for ii=1:numel(distance)
    values=unique(ticks.label(groups==ii),"stable");labels(ii)=strjoin(values,"|");
end
end
