try gpuDevice
    gputrue = 1;
catch
    gputrue = 0;
end
%

file_to_process = 'Y:\Diffusers''nstuff\3d_images_to_process\usaf_tilt_more_2.png';   %Image to process
impulse_stack = '../data/zstack_dense_pco_good.mat';   %Mat file of impulse response
stack_name = 'zstack';  %Variable name within impulse_stack
ds = 1/4;   %Lateral downsampling
dsz = 1/2;   %Axial downsampling
start_plane = 65;   %Which z plane to begin impulse response
end_plane = 128;
meas_type = 'measured';   %Measured or simulated data. If measured, 
                          %file_to_process will be loaded. if not, 
                          %data will be simulated.
                          
%Regularization parameters                          
tau = .0002;   %Regularization parameter
soft_tau = .005;
niters = 50;    %TV iterations

%Prox operator handle (returns denoised and norm)
%prox_handle = @(x)tvdenoise3d_wrapper(max(x-soft_tau,0),tau,niters,0,inf);
prox_handle = @(x)soft_nonneg(x,soft_tau);

demosaic_true = 1;   %Demosaic raw data or not. 

%----------------------------------------------------
%Options for proxMin
if ds == 1/5
    options.stepsize = 30e-6;
elseif ds == 1/4
    if dsz == 1/8
        options.stepsize = 1e-5;
    elseif dsz == 1/4
        options.stepsize = 1e-6;
    elseif dsz == 1/2
        options.stepsize = 1e-6;
    end
       
elseif ds == 1/8
    options.stepsize = 1e-4;
elseif ds == 1/10
    options.stepsize = 8e-5;
elseif ds == 1/2
    %options.stepsize = 1e-6;
    if dsz == 1/8
        options.stepsize = 1e-6;
    elseif dsz == 1/4
        options.stepsize = 1e-6;
    elseif dsz == 1/2
        options.stepsize = .5e-6;
    end
elseif ds == 1
    options.stepsize = 3e-7;
end


options.convTol = 8.2e-14;
%options.xsize = [256,256];
options.maxIter = 2000;
options.residTol = .2;
options.momentum = 'nesterov';
options.disp_figs = 1;
options.disp_fig_interval = 10;   %display image this often

nocrop = @(x)x;
options.disp_crop = @(x)gather(real(sum(x,3)));
h1 = figure(1);
clf
options.fighandle = h1;
options.disp_gamma = 1/2.2;
options.known_input = 0;
options.force_real = 1;
init_style = 'zero';   %Initialization
