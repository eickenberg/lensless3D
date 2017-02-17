%Load impulse response stack, h
h_in = load('Y:\Grace\pco_color_dense\zstack.mat','zstackg');
%%
gputrue = 1;
ht = double(h_in.zstackg);
ds = 1/2;
dsz = 1/2;
start_plane = 1;
start_ds = ceil(start_plane*dsz);
P = floor(size(ht,3)*dsz*1);
htd = zeros(size(ht,1),size(ht,2),P-start_ds);
count = 0;
for k = 1:(P-start_ds)   %Downsample in z. This leaves of remainders intead of using them!
    for n = 1:1/dsz
        count = count+1;
        htd(:,:,k) = htd(:,:,k)+ht(:,:,count+start_plane)*ds;
    end
    
end


imtest = imresize(htd(:,:,1),ds,'box');
[M,N] = size(imtest);
h = zeros(M,N,size(htd,3));


for m = 1:P-start_ds;
    
    h(:,:,m) = imresize(htd(:,:,m),ds,'box')-100;
    %if m == 1
        divide_norm = norm(h(:,:,m),'fro');
    %end
    h(:,:,m) = h(:,:,m)/divide_norm;
    %imagesc(h(:,:,m))
    %axis image
    %caxis([0 2^13])
    %drawnow
   % nn(m) = sum(sum(h(:,:,m)));
end
%clear ht;
%clear htd;
%Subtract scmos camera bias
if gputrue  
    h = gpuArray(h);
else
    h = h;
end
%hn = norm(h(:,:,1),'fro');
%h = h./hn;
%z = h_in.z;

%%
%define problem size
NX = size(h,2);
NY = size(h,2);
NZ = size(h,3);

%define crop and pad operators to handle 2D fft convolution
pad = @(x)padarray(x,[size(h,1)/2,size(h,2)/2],0,'both');
if gputrue
    cc = gpuArray((size(h,2)/2+1):(3*size(h,2)/2));
    rc = gpuArray((size(h,1)/2+1):(3*size(h,1)/2));
else
    cc = (size(h,2)/2+1):(3*size(h,2)/2);
    rc = (size(h,1)/2+1):(3*size(h,1)/2);
end
crop = @(x)x(rc,cc);

% Define function handle for forward A(x)
A3d = @(x)A_lensless_3d(h,x,pad,crop,gputrue);

% Define handle for A adjoint
Aadj_3d = @(x)A_adj_lensless_3d(h,x,crop,pad,gputrue);

% Make or load sensor measurement
meas_type = 'measured';
switch lower(meas_type)
    case 'simulated'
        obj = gpuArray(zeros(size(h)));
        obj(270,320,10) = 1;
        obj(270,320,12) = 1;
        %obj(270/2,320/2,10) = 1;
        %obj(270/2,320/2,20) = 1;
        %obj(100,300,50) = 1;
        %obj(200,100,100)  = 1;
        %obj(250,400,20) = 1;
        b = A3d(obj);
        b = b + abs(randn(size(b)))*max(b(:))/100;
    case 'measured'
       % bin = double(imread('Y:Diffusers''nstuff\Color_pco_3d_images\microcontroller\microcontroller_1.png'));
       bin = double(imread('Y:\Grace\robin\fern4.png'));
        %bin = double(imread('Y:\Diffusers''nstuff\3d_images_to_process\succulant_2.png'));
        b = (imresize(bin,ds/2,'box'));
        if gputrue
            b = gpuArray(b);
        end
        %b = b/norm(b(:));
       % bin = load('Y:\Grace\simulated_data_better.mat');
        %b = gpuArray(imresize(double(bin.data1),1/2,'box'));
end

% Define gradient handle
GradErrHandle = @(x) linear_gradient(x,A3d,Aadj_3d,b);

% Prox handle
    tau = .0002;
    %good tau: .0005 for usaf targets
    %tau_final = .001
%prox_handle = @(x)soft_nonneg(x,tau);
niters = 4;
prox_handle = @(x)tvdenoise3d_wrapper(max(x-.01,0),tau,niters,0,inf);
%tvdenoise_handle = @(x)tvdenoise_dim3(x,2/tau,8,1,1);
%prox_handle = @(x)tvdenoise_dim3_wrapper(tvdenoise_handle,x);
%prox_handle = @(x)hard_3d(x,tau);

if ds == 1/5
    options.stepsize = 30e-6;
elseif ds == 1/4
    
    options.stepsize = 1e-6;
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
end

options.convTol = 8.2e-14;
%options.xsize = [256,256];
options.maxIter = 1000;
options.residTol = .2;
options.momentum = 'nesterov';
options.disp_figs = 1;
options.disp_fig_interval = 5;   %display image this often
options.xsize = size(h);
nocrop = @(x)x;
options.disp_crop = @(x)gather(real(sum(x,3)));
h1 = figure(1);
clf
options.fighandle = h1;
options.disp_gamma = 1/2.2;
options.known_input = 0;
options.force_real = 1;
init_style = 'xhat';


switch lower(init_style)
    case('zero')
        if gputrue
            [xhat, funvals] = proxMin(GradErrHandle,prox_handle,gpuArray(zeros(size(h))),b,options);
        else
            [xhat, funvals] = proxMin(GradErrHandle,prox_handle,(zeros(size(h))),b,options);
        end
    case('xhat')
        [xhat, funvals] = proxMin(GradErrHandle,prox_handle,xhat,b,options);
end

