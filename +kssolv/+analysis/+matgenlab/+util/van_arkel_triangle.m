function axesHandle=van_arkel_triangle(materials,annotate)
%VAN_ARKEL_TRIANGLE Plot electronegativity average versus difference.
if nargin<2,annotate=true;end
fluorine=kssolv.analysis.matgenlab.core.Element("F");
francium=kssolv.analysis.matgenlab.core.Element("Fr");
cesium=kssolv.analysis.matgenlab.core.Element("Cs");
oxygen=kssolv.analysis.matgenlab.core.Element("O");
corners=[(fluorine.X+francium.X)/2,abs(fluorine.X-francium.X); ...
    (cesium.X+francium.X)/2,abs(cesium.X-francium.X); ...
    (oxygen.X+fluorine.X)/2,abs(oxygen.X-fluorine.X)];
figureHandle=figure("Visible","off");axesHandle=axes(figureHandle);
patch(axesHandle,corners(:,1),corners(:,2),[1,.95,.4], ...
    "FaceAlpha",.5,"LineWidth",3);hold(axesHandle,"on");
for index=1:numel(materials)
    item=materials{index};
    if isa(item,"kssolv.analysis.matgenlab.core.ComputedEntry")
        elements=item.composition.elements;
        symbols=cellfun(@(element)element.symbol,elements);
        label=kssolv.analysis.matgenlab.util. ...
            format_formula(item.composition.reduced_formula);
    else
        symbols=string(item);
        label=join(symbols,"-");
    end
    if numel(symbols)~=2
        error("KSSOLV:Matgenlab:Plotting:BinaryMaterial", ...
            "van_arkel_triangle requires binary materials.");
    end
    first=kssolv.analysis.matgenlab.core.Element(symbols(1));
    second=kssolv.analysis.matgenlab.core.Element(symbols(2));
    x=(first.X+second.X)/2;y=abs(first.X-second.X);
    scatter(axesHandle,x,y,100,"b","filled");
    if annotate,text(axesHandle,x+.005,y,label,"FontSize",15);end
end
xlabel(axesHandle,"$\frac{\chi_{A}+\chi_{B}}{2}$", ...
    "Interpreter","latex");
ylabel(axesHandle,"$|\chi_{A}-\chi_{B}|$", ...
    "Interpreter","latex");
text(axesHandle,corners(1,1)-.3,corners(1,2)+.05,"Ionic");
text(axesHandle,corners(2,1)-.4,-.4,"Metallic");
text(axesHandle,corners(3,1)-.65,-.4,"Covalent");
hold(axesHandle,"off");axis(axesHandle,"tight");
end
