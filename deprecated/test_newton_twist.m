%clear;
%rng(0);

addpath('lie_group');

% Load simulation data:
load('simulation/sim_01_cardioid/sim_01.mat');

j = 1;

sdv_r = 0.05;
sdv_t = 0.05;
sigma = blkdiag(sdv_r^2*eye(3), sdv_t^2*eye(3));
delta_x = sqrt(sigma)*randn(6,1);

rx = screw_log(screw_exp(delta_x(1:3))*trajectory.R(:,:,j));
cx = delta_x(4:6) + trajectory.t(:, j); 

gt_rx = screw_log(trajectory.R(:,:,j));
gt_cx = trajectory.t(:, j);

% Solve for the correct pose using Gauss Newton:
ftr_j = features.where(:, measurements.feature_tags{j});
% assume we can measure the 3D points directly:
obs_j = features.where(:, measurements.feature_tags{j});
% then add some Gaussian noise
N = size(obs_j,2);
obs_j = 0.05*randn(3, N) + obs_j;


% Gauss Newton:
z = obs_j(:);

rx0 = gt_rx; cx0 = gt_cx;
max_iter = 200;
min_norm = 1e-7;
converge_flag = false;
for i=1:max_iter
   
    h = zeros(3*N, 1);
    H = zeros(3*N, 6);
    
    fR = screw_exp(rx);
    ft = cx;
    for j = 1:N
        xyz = ftr_j(:, j);
        
        xyz_h = fR*xyz + ft;
        
        h(3*j-2 :3*j, :) = xyz_h;
        
        H(3*j-2 :3*j, :) = [so3_alg(-fR*xyz) eye(3)];        
    end
    
    y = z - h;
    dx = (H'*H)\H'*y;
    
    if norm(dx) < min_norm
       converge_flag = 1;
       break;
    end
    
    rx = screw_log(screw_exp(dx(1:3))*screw_exp(rx));
    cx = cx + dx(4:6);
end
if converge_flag
    fprintf('Converged after %d iterations\n', i);
else
    fprintf('Failed to converged after %d iterations\n', max_iter);
end

gt_rx = gt_rx'
rx    = rx'

gt_cx = gt_cx'
cx    = cx'

% Calculate RMS:
fR = screw_exp(rx);
ft = cx';
fR_gt = screw_exp(gt_rx);
ft_gt = gt_cx';
h_gt = zeros(3*N, 1);
for j = 1:N
    xyz = ftr_j(:, j);
    
    uvw = camera.K*(fR*xyz + ft);
    uv  = uvw(1:2)./uvw(3);
    
    uvw_gt = camera.K*(fR_gt*xyz + ft_gt);
    uv_gt = uvw_gt(1:2)./uvw_gt(3);
    
    h(2*j-1 :2*j) = uv;
    h_gt(2*j-1 :2*j) = uv_gt;
end

rms_est = norm(z-h)
rms_gt  = norm(z-h_gt)

