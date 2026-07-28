function efficiency=slme(materialEnergy,materialAbsorbance, ...
        directGap,indirectGap,thickness,temperature, ...
        inverseCentimeters,cutOffBelowGap,plotCurrentVoltage)
%SLME Spectroscopic limited maximum photovoltaic efficiency (percent).
if nargin<5||isempty(thickness),thickness=50e-6;end
if nargin<6||isempty(temperature),temperature=293.15;end
if nargin<7||isempty(inverseCentimeters),inverseCentimeters=false;end
if nargin<8||isempty(cutOffBelowGap),cutOffBelowGap=true;end
if nargin<9||isempty(plotCurrentVoltage),plotCurrentVoltage=false;end
c=299792458;
h=6.62607015e-34;
elementaryCharge=1.602176634e-19;
boltzmann=1.380649e-23;
hEv=h/elementaryCharge;
kEv=boltzmann/elementaryCharge;
absorbance=double(materialAbsorbance(:));
if inverseCentimeters,absorbance=absorbance*100;end
dataPath=fullfile(fileparts(mfilename("fullpath")),"am1.5G.dat");
solar=readmatrix(dataPath,FileType="text",NumHeaderLines=2);
wavelengthNm=solar(:,1);
irradiance=solar(:,2);
wavelengthMeters=wavelengthNm*1e-9;
fractionRadiative=exp(-(directGap-indirectGap)/(kEv*temperature));
solarPhotonFlux=irradiance.*wavelengthMeters/(h*c);
powerIn=simpsonIntegral(irradiance,wavelengthNm);
blackbodyIrradiance=(2*h*c^2./wavelengthMeters.^5)./ ...
    (exp(h*c./(wavelengthMeters*boltzmann*temperature))-1);
blackbodyPhotonFlux= ...
    blackbodyIrradiance.*wavelengthMeters/(h*c);
materialWavelength=(c*hEv./(double(materialEnergy(:))+1e-8))*1e9;
[materialWavelength,order]=sort(materialWavelength);
absorbance=absorbance(order);
interpolated=interp1(materialWavelength,absorbance, ...
    wavelengthNm,"spline");
interpolated(wavelengthNm<materialWavelength(1))=absorbance(1);
interpolated(wavelengthNm>materialWavelength(end))=absorbance(end);
if cutOffBelowGap
    threshold=1e9*c*hEv/directGap;
    interpolated(wavelengthNm>=threshold)=0;
end
absorbed=1-exp(-2*interpolated*thickness);
j0Radiative=elementaryCharge*pi*simpsonIntegral( ...
    blackbodyPhotonFlux.*absorbed,wavelengthMeters);
j0=j0Radiative/fractionRadiative;
jsc=elementaryCharge*simpsonIntegral( ...
    solarPhotonFlux.*absorbed,wavelengthNm);
current=@(voltage)jsc-j0*( ...
    exp(elementaryCharge*voltage/(boltzmann*temperature))-1);
power=@(voltage)current(voltage).*voltage;
voltage=0;step=.001;
while power(voltage+step)>power(voltage)
    voltage=voltage+step;
end
efficiency=100*power(voltage)/powerIn;
if plotCurrentVoltage
    sample=linspace(0,voltage+.1,200);
    figureHandle=figure(Visible="off");
    plot(sample,current(sample),sample,power(sample),"--");
    xlabel("Voltage (V)");
    ylabel("Current / Power Density");
    legend("Current Density","Power Density");
    saveas(figureHandle,"pp.png");
    close(figureHandle);
end
end

function result=simpsonIntegral(values,coordinates)
values=double(values(:));coordinates=double(coordinates(:));
count=numel(values);
if count~=numel(coordinates)||count<2
    error("KSSOLV:Matgenlab:SLME:Integration", ...
        "Integration arrays must have equal length of at least two.");
end
if count==2
    result=(coordinates(2)-coordinates(1))* ...
        (values(1)+values(2))/2;
    return
end
if mod(count,2)==0
    stop=count-3;
else
    stop=count-2;
end
result=0;
for first=1:2:stop
    h0=coordinates(first+1)-coordinates(first);
    h1=coordinates(first+2)-coordinates(first+1);
    hsum=h0+h1;
    result=result+hsum/6*( ...
        values(first)*(2-h1/h0)+ ...
        values(first+1)*hsum^2/(h0*h1)+ ...
        values(first+2)*(2-h0/h1));
end
if mod(count,2)==0
    h0=coordinates(end-1)-coordinates(end-2);
    h1=coordinates(end)-coordinates(end-1);
    alpha=(2*h1^2+3*h0*h1)/(6*(h1+h0));
    beta=(h1^2+3*h0*h1)/(6*h0);
    eta=h1^3/(6*h0*(h0+h1));
    result=result+alpha*values(end)+ ...
        beta*values(end-1)-eta*values(end-2);
end
end
