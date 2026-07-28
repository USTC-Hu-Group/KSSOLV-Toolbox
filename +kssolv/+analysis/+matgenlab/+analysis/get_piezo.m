function piezo=get_piezo(bec,ist,fcm,rcondValue)
%GET_PIEZO Compute the ionic piezoelectric tensor from BEC/IST/FCM data.
if nargin<4,rcondValue=1e-4;end
bec=double(bec);ist=double(ist);fcm=double(fcm);
count=size(bec,1);matrix=zeros(3*count);
for first=1:count
    rows=(3*first-2):(3*first);
    for second=1:count
        columns=(3*second-2):(3*second);
        matrix(rows,columns)=squeeze(fcm(first,second,:,:));
    end
end
eigenvalues=eig(matrix);
[~,order]=sort(abs(eigenvalues));
relative=abs(eigenvalues(order(3)))/ ...
    abs(eigenvalues(order(end)))+rcondValue;
singular=svd(matrix);
tolerance=relative*max(singular);
inverse=pinv(-matrix,tolerance);
piezo=zeros(3,3,3);
for first=1:count
    firstRows=(3*first-2):(3*first);
    born=squeeze(bec(first,:,:));
    for second=1:count
        secondRows=(3*second-2):(3*second);
        coupling=inverse(firstRows,secondRows);
        strain=squeeze(ist(second,:,:,:));
        for chargeDirection=1:3
            for strainFirst=1:3
                for strainSecond=1:3
                    piezo(chargeDirection,strainFirst,strainSecond)= ...
                        piezo(chargeDirection,strainFirst,strainSecond)+ ...
                        sum(born(chargeDirection,:)*coupling.* ...
                        strain(:,strainFirst,strainSecond).',"all");
                end
            end
        end
    end
end
piezo=piezo*16.0216559424;
end
