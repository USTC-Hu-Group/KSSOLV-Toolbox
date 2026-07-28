classdef XPS < kssolv.analysis.matgenlab.core.Spectrum
    %XPS X-ray photoelectron spectrum weighted by atomic cross sections.
    methods
        function obj=XPS(x,y)
            obj@kssolv.analysis.matgenlab.core.Spectrum(x,y);
        end
        function value=asDict(obj)
            value=asDict@kssolv.analysis.matgenlab.core.Spectrum(obj);
            value.x_module="pymatgen.analysis.xps";
            value.x_class="XPS";
        end
    end
    methods (Static)
        function obj=from_dos(dos)
            total=zeros(size(dos.energies));
            elements=dos.structure.composition.elements;
            for elementIndex=1:numel(elements)
                element=elements{elementIndex};
                projected=dos.get_element_spd_dos(element);
                orbitals=projected.keys;
                for orbitalIndex=1:numel(orbitals)
                    orbital=orbitals{orbitalIndex};
                    weight=crossSection(element,orbital);
                    if isempty(weight)
                        warning("KSSOLV:Matgenlab:XPS:CrossSection", ...
                            "No cross-section for %s%s.", ...
                            string(element),orbital);
                    else
                        total=total+ ...
                            projected(orbital).get_densities()*weight;
                    end
                end
            end
            maximum=max(total);
            if maximum>0,total=total/maximum;end
            obj=kssolv.analysis.matgenlab.analysis.XPS( ...
                -dos.energies,total);
        end
    end
    methods (Access = protected)
        function value=xLabel(~),value="Binding Energy (eV)";end
        function value=yLabel(~),value="Intensity";end
    end
end

function value=crossSection(element,orbitalType)
persistent sections
if isempty(sections),sections=loadCrossSections();end
symbol=char(string(element));
key=symbol+":"+string(orbitalType);
if isKey(sections,char(key)),value=sections(char(key));else,value=[];end
end

function sections=loadCrossSections()
path=fullfile(fileparts(mfilename("fullpath")),"+data", ...
    "atomic_subshell_photoionization_cross_sections.csv");
tableData=readtable(path,VariableNamingRule="preserve");
sections=containers.Map("KeyType","char","ValueType","double");
elements=unique(string(tableData.element),"stable");
for elementIndex=1:numel(elements)
    symbol=elements(elementIndex);
    element=kssolv.analysis.matgenlab.core.Element(symbol);
    if element.Z>92,continue,end
    rows=find(string(tableData.element)==symbol);
    configuration=element.full_electronic_structure;
    for row=reshape(rows,1,[])
        orbital=string(tableData.orbital{row});
        shell=str2double(extractBetween(orbital,1,1));
        orbitalType=extractBetween(orbital,2,2);
        occupancy=[];
        for configIndex=1:size(configuration,1)
            if configuration{configIndex,1}==shell&& ...
                    string(configuration{configIndex,2})==orbitalType
                occupancy=configuration{configIndex,3};
                break
            end
        end
        if ~isempty(occupancy)
            sections(char(symbol+":"+orbitalType))= ...
                tableData.weight(row)/occupancy;
        end
    end
end
end
