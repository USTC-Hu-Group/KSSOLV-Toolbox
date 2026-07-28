classdef VoronoiAnalyzer
    %VORONOIANALYZER Schlaefli-index statistics of Voronoi polyhedra.
    properties
        cutoff (1,1) double = 5
        qhull_options (1,1) string = "Qbb Qc Qz"
    end
    methods
        function obj=VoronoiAnalyzer(cutoff,qhullOptions)
            if nargin>=1&&~isempty(cutoff),obj.cutoff=cutoff;end
            if nargin>=2&&~isempty(qhullOptions)
                obj.qhull_options=string(qhullOptions);
            end
        end
        function index=analyze(obj,structure,siteIndex)
            if nargin<3||isempty(siteIndex),siteIndex=1;end
            strategy=kssolv.analysis.matgenlab.core.VoronoiNN( ...
                "cutoff",obj.cutoff,"allow_pathological",false);
            polyhedra=strategy.get_voronoi_polyhedra( ...
                structure,siteIndex);
            index=zeros(1,8);
            for facet=1:numel(polyhedra)
                vertices=polyhedra{facet}.n_verts;
                if vertices>=3&&vertices<=10
                    index(vertices-2)=index(vertices-2)+1;
                end
            end
        end
        function ensemble=analyze_structures( ...
                obj,structures,stepFrequency,mostFrequent)
            if nargin<3||isempty(stepFrequency),stepFrequency=10;end
            if nargin<4||isempty(mostFrequent),mostFrequent=15;end
            if ~iscell(structures),structures=num2cell(structures);end
            counts=containers.Map("KeyType","char","ValueType","double");
            for frame=stepFrequency:stepFrequency:numel(structures)
                structure=structures{frame};
                for site=1:structure.num_sites
                    key=formatIndex(obj.analyze(structure,site));
                    if isKey(counts,key),counts(key)=counts(key)+1;
                    else,counts(key)=1;end
                end
            end
            names=keys(counts);values_=cell2mat(values(counts));
            [~,order]=sortrows([-values_(:), ...
                (1:numel(values_)).']);
            order=order(1:min(mostFrequent,numel(order)));
            ensemble=cell(numel(order),2);
            for index=1:numel(order)
                ensemble{index,1}=names{order(index)};
                ensemble{index,2}=values_(order(index));
            end
        end
    end
    methods (Static)
        function axesHandle=plot_vor_analysis(ensemble)
            labels=string(ensemble(:,1));
            values_=cell2mat(ensemble(:,2));
            values_=values_/sum(values_);
            figureHandle=figure("Visible","off");
            axesHandle=axes(figureHandle);
            barh(axesHandle,(1:numel(values_))+.5,values_, ...
                "FaceAlpha",.5);
            axesHandle.YTick=(1:numel(values_))+.5;
            axesHandle.YTickLabel=labels;
            title(axesHandle,"Voronoi Spectra");
            xlabel(axesHandle,"Count");grid(axesHandle,"on");
        end
    end
end

function text=formatIndex(index)
text="["+strjoin(string(index)," ")+"]";
text=char(text);
end
