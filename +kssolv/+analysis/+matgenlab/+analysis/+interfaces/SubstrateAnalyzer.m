classdef SubstrateAnalyzer < ...
        kssolv.analysis.matgenlab.analysis.interfaces.ZSLGenerator
    %SUBSTRATEANALYZER Search crystallographic faces for ZSL matches.
    properties
        film_max_miller (1,1) double = 1
        substrate_max_miller (1,1) double = 1
    end
    methods
        function obj=SubstrateAnalyzer(filmMaxMiller, ...
                substrateMaxMiller,varargin)
            obj@kssolv.analysis.matgenlab.analysis.interfaces. ...
                ZSLGenerator();
            if nargin>=1&&~isempty(filmMaxMiller)
                obj.film_max_miller=filmMaxMiller;
            end
            if nargin>=2&&~isempty(substrateMaxMiller)
                obj.substrate_max_miller=substrateMaxMiller;
            end
            if ~isempty(varargin),obj=obj.applyOptions(varargin);end
        end

        function vectorSets=generate_surface_vectors( ...
                obj,film,substrate,filmMillers,substrateMillers) %#ok<INUSL>
            filmCount=millerCount(filmMillers);
            substrateCount=millerCount(substrateMillers);
            vectorSets=cell( ...
                filmCount*substrateCount,4);
            next=1;
            for filmIndex=1:filmCount
                filmMiller=millerAt(filmMillers,filmIndex);
                generator=kssolv.analysis.matgenlab.core.SlabGenerator( ...
                    film,filmMiller,20,15, ...
                    "primitive",false);
                filmSlab=generator.get_slab();
                vectors=filmSlab.oriented_unit_cell.lattice.matrix;
                filmVectors=kssolv.analysis.matgenlab.analysis. ...
                    interfaces.reduce_vectors(vectors(1,:),vectors(2,:));
                for substrateIndex=1:substrateCount
                    substrateMiller=millerAt( ...
                        substrateMillers,substrateIndex);
                    generator=kssolv.analysis.matgenlab.core. ...
                        SlabGenerator(substrate, ...
                        substrateMiller,20,15, ...
                        "primitive",false);
                    substrateSlab=generator.get_slab();
                    vectors=substrateSlab.oriented_unit_cell.lattice.matrix;
                    substrateVectors= ...
                        kssolv.analysis.matgenlab.analysis.interfaces. ...
                        reduce_vectors(vectors(1,:),vectors(2,:));
                    vectorSets(next,:)={filmVectors,substrateVectors, ...
                        filmMiller,substrateMiller};
                    next=next+1;
                end
            end
        end

        function matches=calculate(obj,film,substrate, ...
                elasticityTensor,filmMillers,substrateMillers, ...
                groundStateEnergy,lowest)
            if nargin<4,elasticityTensor=[];end
            if nargin<5||isempty(filmMillers)
                filmMillers=kssolv.analysis.matgenlab.core. ...
                    get_symmetrically_distinct_miller_indices( ...
                    film,obj.film_max_miller,false);
                filmMillers=sortMillers(filmMillers);
            end
            if nargin<6||isempty(substrateMillers)
                substrateMillers=kssolv.analysis.matgenlab.core. ...
                    get_symmetrically_distinct_miller_indices( ...
                    substrate,obj.substrate_max_miller,false);
                substrateMillers=sortMillers(substrateMillers);
            end
            if nargin<7||isempty(groundStateEnergy),groundStateEnergy=0;end
            if nargin<8||isempty(lowest),lowest=false;end
            vectorSets=obj.generate_surface_vectors( ...
                film,substrate,filmMillers,substrateMillers);
            matches=cell(1,0);
            for setIndex=1:size(vectorSets,1)
                zslMatches=obj.call(vectorSets{setIndex,1}, ...
                    vectorSets{setIndex,2},lowest);
                for matchIndex=1:numel(zslMatches)
                    matches{end+1}= ...
                        kssolv.analysis.matgenlab.analysis.interfaces. ...
                        SubstrateMatch.from_zsl( ...
                        zslMatches{matchIndex},film, ...
                        vectorSets{setIndex,3}, ...
                        vectorSets{setIndex,4},elasticityTensor, ...
                        groundStateEnergy); %#ok<AGROW>
                end
            end
        end
    end

    methods (Access=private)
        function obj=applyOptions(obj,options)
            if mod(numel(options),2)~=0
                error("KSSOLV:Matgenlab:SubstrateAnalyzer:Options", ...
                    "Options must be name-value pairs.");
            end
            for index=1:2:numel(options)
                name=lower(string(options{index}));
                value=options{index+1};
                switch name
                    case "max_area_ratio_tol"
                        obj.max_area_ratio_tol=value;
                    case "max_area"
                        obj.max_area=value;
                    case "max_length_tol"
                        obj.max_length_tol=value;
                    case "max_angle_tol"
                        obj.max_angle_tol=value;
                    case "bidirectional"
                        obj.bidirectional=value;
                    otherwise
                        error( ...
                            "KSSOLV:Matgenlab:SubstrateAnalyzer:Option", ...
                            "Unknown option '%s'.",name);
                end
            end
        end
    end
end

function count=millerCount(values)
if iscell(values),count=numel(values);else,count=size(values,1);end
end

function value=millerAt(values,index)
if iscell(values),value=values{index};else,value=values(index,:);end
value=reshape(double(value),1,[]);
end

function values=sortMillers(values)
if iscell(values)
    rows=cell2mat(reshape(values,[],1));
else
    rows=double(values);
end
rows=sortrows(rows);
values=num2cell(rows,2).';
end
