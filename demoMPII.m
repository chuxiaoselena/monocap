% This script demonstrates how to use:
% the proposed EM algorithm + pose dictionary learned from Human3.6M
% + the most recent CNN based 2D detector "Hourglass network"
% (https://github.com/anewell/pose-hg-demo)
% We use the first image in the validation set of MPII as example

clear

datapath = 'data/mpii/';

% list of validation images in MPII
fileID = fopen([datapath 'annot/valid_images.txt']);
imgList = textscan(fileID,'%s');
fclose(fileID);

% load dictionary learned from Human3.6M
dict = load('dict/poseDict-all-K128');
dictDataset = 'hm36m';

% convert dictionary format 
% because the joint order in MPII is different from that in Human3.6M
dict = getMPIIdict(dict,dictDataset);
numKp = length(dict.skel.tree);

% read MPII annotation
h5File = [datapath 'annot/valid.h5'];
scales = hdf5read(h5File,'scale');
centers = hdf5read(h5File,'center');
parts = hdf5read(h5File,'part');

%% process the first image
i = 1;

% read heatmaps generated by the Hourglass model
% see data/mpii/main-heatmaps.lua for how to run Hourglass on MPII and save heatmaps
% if you are processing a seqeunce, stack the heatmaps of all frames see demoHG for example
heatmap = hdf5read(sprintf('%s/test-valid/valid%d.h5',datapath,i),'heatmaps');
% transpose heatmaps to make it consistent with the MATLAB x-y directions
heatmap = permute(heatmap,[2,1,3]);

% EM
% set beta and gamma to be zero because you are processing single images
output = PoseFromVideo('heatmap',heatmap,'dict',dict,'InitialMethod','convex+robust+refine',...
    'alpha',0.5,'beta',0,'gamma',0,'sigma',0.5,'MaxIterAltern',10,'MaxIterEM',20,'verb',false);
% get estimated poses coordinates for EM output
% the estimated 2D joint location is w.r.t. the bounding box
% need to be converted to the original image coordinates
preds_2d = transformMPII(output.W_final,centers(:,i),scales(i),[size(heatmap,1) size(heatmap,2)],1);
preds_3d = output.S_final;


%% visualize

nPlot = 4;
figure('position',[300 300 200*nPlot 200]);

subplot(1,nPlot,1);
I = imread(sprintf('%s/images/%s',datapath,imgList{1}{i}));
imshow(I); hold on
vis2Dmarker(parts(:,:,i));
title('image+gt')

subplot(1,nPlot,2);
imagesc(mat2gray(sum(heatmap,3)));
axis equal off
title('heatmap')

subplot(1,nPlot,3);
imshow(I);
vis2Dskel(preds_2d,dict.skel);
title('2D estimates')

subplot(1,nPlot,4);
vis3Dskel(preds_3d(:,:,i),dict.skel,'viewpoint',[-90 0]);
title('3D (novel view)')

