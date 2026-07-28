classdef NEBAnalysis
    %NEBANALYSIS Minimum-energy-path analysis for nudged elastic bands.
    properties
        r (1,:) double
        energies (1,:) double
        relative_energies (1,:) double
        forces (1,:) double
        structures cell
        zero_slope_saddle (1,1) logical = false
        spline
    end
    methods
        function obj=NEBAnalysis(r,energies,forces,structures, ...
                splineOptions,zeroSlopeSaddle)
            if nargin<5,splineOptions=[];end
            if nargin<6||isempty(zeroSlopeSaddle),zeroSlopeSaddle=false;end
            if ~isempty(splineOptions)
                zeroSlopeSaddle=isfield(splineOptions,"saddle_point")&& ...
                    string(splineOptions.saddle_point)=="zero_slope";
            end
            obj.r=reshape(double(r),1,[]);
            obj.energies=reshape(double(energies),1,[]);
            obj.forces=reshape(double(forces),1,[]);
            obj.structures=reshape(structures,1,[]);
            if any([numel(obj.energies),numel(obj.forces), ...
                    numel(obj.structures)]~=numel(obj.r))
                error("KSSOLV:Matgenlab:NEBAnalysis:DataSize", ...
                    "r, energies, forces and structures need equal length.");
            end
            obj.relative_energies=obj.energies-obj.energies(1);
            obj=obj.setup_spline([],zeroSlopeSaddle);
        end
        function obj=setup_spline(obj,splineOptions,zeroSlopeSaddle)
            if nargin<2,splineOptions=[];end
            if nargin<3||isempty(zeroSlopeSaddle),zeroSlopeSaddle=false;end
            if ~isempty(splineOptions)
                zeroSlopeSaddle=isfield(splineOptions,"saddle_point")&& ...
                    string(splineOptions.saddle_point)=="zero_slope";
            end
            obj.zero_slope_saddle=logical(zeroSlopeSaddle);
            splineFunction=str2func("spline");
            if obj.zero_slope_saddle
                [~,saddle]=max(obj.relative_energies);
                first=splineFunction(obj.r(1:saddle), ...
                    [0,obj.relative_energies(1:saddle),0]);
                second=splineFunction(obj.r(saddle:end), ...
                    [0,obj.relative_energies(saddle:end),0]);
                obj.spline=struct("piecewise",true, ...
                    "saddle",obj.r(saddle),"first",first,"second",second);
            else
                obj.spline=struct("piecewise",false, ...
                    "pp",splineFunction(obj.r, ...
                    [0,obj.relative_energies,0]));
            end
        end
        function [minima,maxima]=get_extrema(obj,normalize)
            if nargin<2||isempty(normalize),normalize=true;end
            x=sampleCoordinates(max(obj.r));
            y=obj.evaluateSpline(x)*1000;
            if normalize,scale=1/obj.r(end);else,scale=1;end
            minima=zeros(0,2);maxima=zeros(0,2);
            for index=2:numel(x)-1
                if y(index)<y(index-1)&&y(index)<y(index+1)
                    minima(end+1,:)=[x(index)*scale,y(index)]; %#ok<AGROW>
                elseif y(index)>y(index-1)&&y(index)>y(index+1)
                    maxima(end+1,:)=[x(index)*scale,y(index)]; %#ok<AGROW>
                end
            end
        end
        function axesHandle=get_plot(obj,normalize,labelBarrier)
            if nargin<2||isempty(normalize),normalize=true;end
            if nargin<3||isempty(labelBarrier),labelBarrier=true;end
            if normalize,scale=1/obj.r(end);else,scale=1;end
            x=sampleCoordinates(max(obj.r));
            y=obj.evaluateSpline(x)*1000;
            figureHandle=figure("Visible","off");
            axesHandle=axes(figureHandle);
            plot(axesHandle,obj.r*scale,obj.relative_energies*1000, ...
                "ro","MarkerSize",10);hold(axesHandle,"on");
            plot(axesHandle,x*scale,y,"k-","LineWidth",2);
            xlabel(axesHandle,"Reaction Coordinate");
            ylabel(axesHandle,"Energy (meV)");
            ylim(axesHandle,[min(y)-10,max(y)*1.02+20]);
            if labelBarrier
                [barrier,index]=max(y);
                plot(axesHandle,[0,x(index)*scale],[barrier,barrier], ...
                    "k--","LineWidth",.5);
                text(axesHandle,x(index)*scale/2,barrier*1.02, ...
                    sprintf("%.0f meV",max(obj.relative_energies*1000)), ...
                    "HorizontalAlignment","center","FontSize",18);
            end
        end
        function data=as_dict(obj)
            data=struct("x_module","pymatgen.analysis.transition_state", ...
                "x_class","NEBAnalysis","r",obj.r, ...
                "energies",obj.energies,"forces",obj.forces, ...
                "structures",{cellfun(@(value)value.as_dict(), ...
                obj.structures,"UniformOutput",false)});
        end
        function data=asDict(obj),data=obj.as_dict();end
        function values=evaluateSpline(obj,x)
            if obj.spline.piecewise
                values=zeros(size(x));
                first=x<=obj.spline.saddle;
                values(first)=ppval(obj.spline.first,x(first));
                values(~first)=ppval(obj.spline.second,x(~first));
            else
                values=ppval(obj.spline.pp,x);
            end
        end
    end
    methods (Static)
        function obj=from_outcars(outcars,structures,varargin)
            if numel(outcars)~=numel(structures)
                error("KSSOLV:Matgenlab:NEBAnalysis:DataSize", ...
                    "Number of Outcars must equal number of structures.");
            end
            distance=zeros(1,numel(structures));
            for index=2:numel(structures)
                previous=structures{index-1};
                current=structures{index};
                values=zeros(1,previous.num_sites);
                for site=1:previous.num_sites
                    values(site)=current(site).distance(previous(site));
                end
                distance(index)=sqrt(sum(values.^2));
            end
            coordinates=cumsum(distance);
            energies=zeros(size(coordinates));forces=zeros(size(coordinates));
            for index=1:numel(outcars)
                outcars{index}.read_neb();
                energies(index)=outcars{index}.data.energy;
                if index~=1&&index~=numel(outcars)
                    forces(index)=outcars{index}.data.tangent_force;
                end
            end
            obj=kssolv.analysis.matgenlab.analysis.NEBAnalysis( ...
                coordinates,energies,forces,structures,varargin{:});
        end
        function obj=from_dir(rootDirectory,relaxationDirectories,varargin)
            if nargin<2,relaxationDirectories=[];end
            entries=dir(rootDirectory);indices=[];paths=strings(1,0);
            for index=1:numel(entries)
                if entries(index).isdir&& ...
                        ~isnan(str2double(entries(index).name))
                    indices(end+1)=str2double(entries(index).name); %#ok<AGROW>
                    paths(end+1)=string(fullfile( ...
                        entries(index).folder,entries(index).name)); %#ok<AGROW>
                end
            end
            [~,order]=sort(indices);paths=paths(order);
            if isempty(paths)
                error("KSSOLV:Matgenlab:NEBAnalysis:NoImages", ...
                    "No numeric NEB image directories were found.");
            end
            outcars=cell(1,numel(paths));structures=cell(1,numel(paths));
            for index=1:numel(paths)
                terminal=index==1||index==numel(paths);
                if terminal
                    outcar=findTerminalOutcar(rootDirectory,paths, ...
                        index,relaxationDirectories);
                    structureFile=lastMatching(paths(index),"POSCAR*");
                else
                    outcar=lastMatching(paths(index),"OUTCAR*");
                    structureFile=lastMatching(paths(index),"CONTCAR*");
                end
                outcars{index}= ...
                    kssolv.analysis.matgenlab.io.vasp.Outcar(outcar);
                structures{index}= ...
                    kssolv.analysis.matgenlab.core.Structure. ...
                    from_file(structureFile);
            end
            obj=kssolv.analysis.matgenlab.analysis.NEBAnalysis. ...
                from_outcars(outcars,structures,varargin{:});
        end
        function obj=from_dict(data)
            raw=data.structures;
            if isstruct(raw),raw=num2cell(raw);end
            structures=cellfun(@(value) ...
                kssolv.analysis.matgenlab.core.Structure.from_dict(value), ...
                raw,"UniformOutput",false);
            obj=kssolv.analysis.matgenlab.analysis.NEBAnalysis( ...
                data.r,data.energies,data.forces,structures);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab. ...
                analysis.NEBAnalysis.from_dict(data);end
    end
end

function values=sampleCoordinates(maximum)
count=ceil(maximum/.01);
values=(0:count-1)*.01;
end
function file=lastMatching(directory,pattern)
entries=dir(fullfile(directory,pattern));
if isempty(entries)
    error("KSSOLV:Matgenlab:NEBAnalysis:MissingFile", ...
        "No %s file in %s.",pattern,directory);
end
[~,order]=sort({entries.name});entry=entries(order(end));
file=string(fullfile(entry.folder,entry.name));
end
function file=findTerminalOutcar(root,paths,index,relaxation)
candidates=strings(0,2);
if ~isempty(relaxation)
    candidates(end+1,:)=[string(relaxation{1}), ...
        string(relaxation{2})];
end
candidates(end+1,:)=[paths(1),paths(end)];
candidates(end+1,:)=[fullfile(root,"start"),fullfile(root,"end")];
candidates(end+1,:)=[fullfile(root,"initial"),fullfile(root,"final")];
column=1;if index==numel(paths),column=2;end
for row=1:size(candidates,1)
    entries=dir(fullfile(candidates(row,column),"OUTCAR*"));
    if ~isempty(entries)
        [~,order]=sort({entries.name});entry=entries(order(end));
        file=string(fullfile(entry.folder,entry.name));return
    end
end
error("KSSOLV:Matgenlab:NEBAnalysis:MissingOutcar", ...
    "OUTCAR cannot be found for terminal image.");
end
