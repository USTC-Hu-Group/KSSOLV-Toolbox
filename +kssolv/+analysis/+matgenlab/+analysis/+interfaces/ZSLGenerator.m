classdef ZSLGenerator
    %ZSLGENERATOR Zur-McGill coincident superlattice search.
    properties
        max_area_ratio_tol (1,1) double = 0.09
        max_area (1,1) double = 400
        max_length_tol (1,1) double = 0.03
        max_angle_tol (1,1) double = 0.01
        bidirectional (1,1) logical = false
    end
    methods
        function obj=ZSLGenerator(maxAreaRatioTol,maxArea, ...
                maxLengthTol,maxAngleTol,bidirectional)
            if nargin>=1&&~isempty(maxAreaRatioTol)
                obj.max_area_ratio_tol=maxAreaRatioTol;
            end
            if nargin>=2&&~isempty(maxArea),obj.max_area=maxArea;end
            if nargin>=3&&~isempty(maxLengthTol)
                obj.max_length_tol=maxLengthTol;
            end
            if nargin>=4&&~isempty(maxAngleTol)
                obj.max_angle_tol=maxAngleTol;
            end
            if nargin>=5&&~isempty(bidirectional)
                obj.bidirectional=bidirectional;
            end
        end

        function sets=generate_sl_transformation_sets( ...
                obj,filmArea,substrateArea)
            maximumFilm=ceil(obj.max_area/filmArea)-1;
            maximumSubstrate=ceil(obj.max_area/substrateArea)-1;
            indices=zeros(0,2);
            for first=1:maximumFilm
                for second=1:maximumSubstrate
                    forward=abs(filmArea/substrateArea-second/first);
                    reverse=abs(substrateArea/filmArea-first/second);
                    if forward<obj.max_area_ratio_tol|| ...
                            reverse<obj.max_area_ratio_tol
                        indices(end+1,:)=[first,second]; %#ok<AGROW>
                    end
                end
            end
            indices=unique(indices,"rows");
            [~,order]=sort(indices(:,1).*indices(:,2));
            indices=indices(order,:);
            sets=cell(size(indices,1),2);
            for index=1:size(indices,1)
                sets{index,1}=kssolv.analysis.matgenlab.analysis. ...
                    interfaces.gen_sl_transform_matrices(indices(index,1));
                sets{index,2}=kssolv.analysis.matgenlab.analysis. ...
                    interfaces.gen_sl_transform_matrices(indices(index,2));
            end
        end

        function matches=get_equiv_transformations( ...
                obj,sets,filmVectors,substrateVectors)
            matches=cell(0,4);
            for setIndex=1:size(sets,1)
                filmTransforms=sets{setIndex,1};
                substrateTransforms=sets{setIndex,2};
                films=cell(size(filmTransforms));
                substrates=cell(size(substrateTransforms));
                for index=1:numel(filmTransforms)
                    vectors=filmTransforms{index}*filmVectors;
                    films{index}=kssolv.analysis.matgenlab.analysis. ...
                        interfaces.reduce_vectors( ...
                        vectors(1,:),vectors(2,:));
                end
                for index=1:numel(substrateTransforms)
                    vectors=substrateTransforms{index}*substrateVectors;
                    substrates{index}= ...
                        kssolv.analysis.matgenlab.analysis.interfaces. ...
                        reduce_vectors(vectors(1,:),vectors(2,:));
                end
                for filmIndex=1:numel(films)
                    for substrateIndex=1:numel(substrates)
                        if kssolv.analysis.matgenlab.analysis.interfaces. ...
                                is_same_vectors( ...
                                films{filmIndex},substrates{substrateIndex}, ...
                                obj.bidirectional,obj.max_length_tol, ...
                                obj.max_angle_tol)
                            matches(end+1,:)={films{filmIndex}, ...
                                substrates{substrateIndex}, ...
                                filmTransforms{filmIndex}, ...
                                substrateTransforms{substrateIndex}}; %#ok<AGROW>
                        end
                    end
                end
            end
        end

        function matches=call(obj,filmVectors,substrateVectors,lowest)
            if nargin<4||isempty(lowest),lowest=false;end
            filmArea=kssolv.analysis.matgenlab.analysis.interfaces. ...
                vec_area(filmVectors(1,:),filmVectors(2,:));
            substrateArea=kssolv.analysis.matgenlab.analysis.interfaces. ...
                vec_area(substrateVectors(1,:),substrateVectors(2,:));
            sets=obj.generate_sl_transformation_sets( ...
                filmArea,substrateArea);
            equivalent=obj.get_equiv_transformations( ...
                sets,filmVectors,substrateVectors);
            if lowest&&~isempty(equivalent),equivalent=equivalent(1,:);end
            matches=cell(1,size(equivalent,1));
            for index=1:size(equivalent,1)
                matches{index}= ...
                    kssolv.analysis.matgenlab.analysis.interfaces. ...
                    ZSLMatch(equivalent{index,1},equivalent{index,2}, ...
                    filmVectors,substrateVectors,equivalent{index,3}, ...
                    equivalent{index,4});
            end
        end

        function value=as_dict(obj)
            value=struct("x_module","pymatgen.analysis.interfaces.zsl", ...
                "x_class","ZSLGenerator", ...
                "max_area_ratio_tol",obj.max_area_ratio_tol, ...
                "max_area",obj.max_area, ...
                "max_length_tol",obj.max_length_tol, ...
                "max_angle_tol",obj.max_angle_tol, ...
                "bidirectional",obj.bidirectional);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
end
