function [q_next, v_next, x] = solver_convex(q_prev, v_prev, Fext, M, J, mu, psi, h)
% Input:
%   q_prev - pose [n x 1]
%   v_prev - velocity [n x 1]
%   Fext - gravitational and other forces [n x 1]
%   M - inertia matrix [n x n]
%   J - contact Jacobian [2*nc x n]
%   mu - coefficients of friction [nc x 1]
%   psi - contact gap distances [nc x 1]
%   h - time step
% Output:
%   q_next - pose [n x 1]
%   v_prev - velocity [n x 1]
%   x - contact impulses [nc x 1]

%% Setup
nc = size(mu,1); % number of contacts

% Inverse inertia matrix in the contact frame
A = J*(M\J');
A = (A + A')/2; % should be symmetric

% Resulting contact velocities if all contact impulses are 0
c = J*(v_prev + M\Fext*h);

% Baumgarte stabilization
b = c + [psi/h; zeros(nc,1)];

%% Convex Quadratic Program

% Contact smoothing
Rmax = 100;
Rmin = 0.01;
wmax = 0.1;
R = diag((Rmin + (Rmax - Rmin)*[psi; psi]/wmax));

% Constraints
U = diag(mu);
Ac = [A(1:nc,:);... % no penetration
       U       -eye(nc);... % friction cone
       U        eye(nc);... % friction cone
       eye(nc)  zeros(nc)]; % no attractive contact forces
bc = [-b(1:nc); zeros(3*nc,1)];

% The substitutions A+R=>A and c=>b improve agreement with LCP

% Solve for contact impulses (Interior-point)
x = interior_point(A + R, c, Ac, bc);
% x = quadprog(A + R, c, -Ac, -bc, [], [], [], [], [], ...
%     optimset('Algorithm', 'interior-point-convex', 'Display', 'off'));
% x = sqopt('contact', @(x) (A + R)*x, c, zeros(size(c)), [], [], -Ac, [], -bc);

%% Integrate velocity and pose
v_next = v_prev + M\(J'*x + Fext*h);
q_next = q_prev + h*v_next;

end