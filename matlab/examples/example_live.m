%% Cleanup
clear all
close all

addpath(pwd)

%% Load sdk
sdk = ThorlabsCameraSDKLoader();

%% Create cameras
cam1 = ThorlabsCamera("05564", sdk, name='Near field');

%% Setup cameras
cam1.setup("ExposureTimeUs", 12000, ROISize=1024);

%% Arm cameras
cam1.run()

%%
for i=1:100
    disp(i)
    cam1.get_snapshot("DisplayTimer",true)
end

%%
cam1.get_snapshot("DisplayTimer",true);
imshow(cam1.lastFrame), colorbar, caxis([0, 1000]);

%% Change exposure on the fly and start live mode
% Close figure to stop live, or press stop button
cam1.set_exposure(1000);
cam1.live()

%% Change exposure on the fly and start live mode
% Close figure to stop live, or press stop button
cam1.set_exposure(1000000);
cam1.live()

%% Disarm and close cameras
delete(cam1)

%% Delete SDK
delete(sdk)
