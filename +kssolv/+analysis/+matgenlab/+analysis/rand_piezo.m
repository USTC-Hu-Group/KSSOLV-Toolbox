function [randomBec,randomIst,randomFcm,piezo]=rand_piezo( ...
        structure,pointops,sharedops,bec,ist,fcm,acousticIterations)
%RAND_PIEZO Generate symmetry-constrained random microscopic tensors.
if nargin<7,acousticIterations=10;end
becObject=kssolv.analysis.matgenlab.analysis. ...
    BornEffectiveCharge(structure,bec,pointops);
becObject.get_BEC_operations();
randomBec=becObject.get_rand_BEC();
istObject=kssolv.analysis.matgenlab.analysis. ...
    InternalStrainTensor(structure,ist,pointops);
istObject.get_IST_operations();
randomIst=istObject.get_rand_IST();
fcmObject=kssolv.analysis.matgenlab.analysis. ...
    ForceConstantMatrix(structure,fcm,pointops,sharedops);
fcmObject.get_FCM_operations();
randomFcm=fcmObject.get_rand_FCM(acousticIterations);
piezo=kssolv.analysis.matgenlab.analysis.get_piezo( ...
    randomBec,randomIst,randomFcm)* ...
    16.0216559424/structure.volume;
end
