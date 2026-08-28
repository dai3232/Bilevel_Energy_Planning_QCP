%%      HΔξ+ATΔy+GTΔz=−rdual    对偶可行性驻点方程
%   H∈Rnξ​×nξ​：        是拉格朗日函数关于原始变量 ξ 的 Hessian；
%   A∈Rneq​×nξ​v        是等式约束 Jacobian；
%   G∈Rnineq​×nξ​       是不等式约束 Jacobian
%   rdual​              是当前迭代点的驻点残差。

%%      AΔξ=−req​                   等式约束线性化方程  （不涉及Δl 和 Δz）不发生变化

%%      GΔξ+Δl=−rineq​  得到Δl=−rineq​−GΔξ      消去Δl
%%      Δl=−rineq​−GΔξ              （4）

%%      L=diag(l)   Z=diag(z)       l 是松弛变量，z 是不等式乘子
%%      ZΔl+LΔz=−rcomp​              互补条件线性化方程（5）        
%%      逐元素形式zi​Δli​+li​Δzi​=−rcomp,i​

%% 2. 先消去 Δl
    %%  由式（4）代入互补条件式（5）：Z(−rineq​−GΔξ)+LΔz=−rcomp​
    %%  移项后：LΔz=−rcomp​+Zrineq​+ZGΔξ
    %%  Δz=−L−1(rcomp​−Zrineq​)+L−1ZGΔξ
function reduced = eliminate_stage_a_multiday_inequality_directions(lin)
%ELIMINATE_STAGE_A_MULTIDAY_INEQUALITY_DIRECTIONS Exact diagonal elimination.

arguments
    lin (1,1) struct
end

contract = rkkt.solver.stage_a_multiday_linearization_contract(lin);
%%  因为后面必须除以 li。  只要有一个 li≤0，对角矩阵 L 就不再满足当前内点消元要求。
if any(contract.l<=0)
    row = find(contract.l<=0,1,"first");
    error("stageAMultiday:solver:NonpositiveSlack", ...
        "Inequality row %d has nonpositive slack %.17g.",row,contract.l(row));
end
if any(contract.z<=0)
    row = find(contract.z<=0,1,"first");
    error("stageAMultiday:solver:NonpositiveMultiplier", ...
        "Inequality row %d has nonpositive multiplier %.17g.", ...
        row,contract.z(row));
end
%%逐元素相除，得到θ
%% Θ=L−1Z
theta = contract.z./contract.l; %./这个符号就是每个元素逐个相除

%%  ϕ=L−1(rcomp​−Zrineq​)
phi = (contract.r_comp-contract.z.*contract.r_ineq)./contract.l;


weightedG = spdiags(theta,0,contract.nineq,contract.nineq)*sparse(lin.G);
W = sparse(lin.H)+sparse(lin.G.')*weightedG;
bXi = -contract.r_dual+sparse(lin.G.')*phi;
assert(all(isfinite(nonzeros(W))) && all(isfinite(bXi)), ...
    "stageAMultiday:solver:EliminationNonfinite", ...
    "Inequality elimination produced NaN or Inf.");

%把结果放到reduced结构体中
reduced = struct();
reduced.stage_id = contract.stage_id;
reduced.linearization_identity = contract.identity;
reduced.theta = theta;
reduced.phi = phi;
reduced.W = W;
reduced.b_xi = bXi;
reduced.A = sparse(lin.A);
reduced.saddle = [W,sparse(lin.A.'); ...
    sparse(lin.A),sparse(contract.neq,contract.neq)];
reduced.rhs = [bXi;-contract.r_eq];
reduced.symmetry_relative = norm(W-W.',"fro")/max(1,norm(W,"fro"));
reduced.nnz_W = nnz(W);
reduced.recovery_contract = ...
    "dl=-r_ineq-G*dxi; dz=(-r_comp+z.*r_ineq+z.*(G*dxi))./l";
end
