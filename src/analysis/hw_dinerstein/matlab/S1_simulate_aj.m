function [NDdraws_r_j] = S1_simulate_aj(mu, sigma, int_data )
%% to simulate aj from truncated normal distribution

%% fixed draws
NDraws = int_data.NDraws;
UDraws = int_data.UDraws;

% moved normal distribution
NDdraws_r = mu+ sigma*NDraws;

% price lower bound
lb_price = int_data.lb_price;
% number of markets - rows of output vector
num_a = int_data.num_a;
% to store index from which on to sample aj
if_in_sim = nan(num_a,1);
% to store randomly drawn aj
NDdraws_r_j = nan(size(UDraws));
for i = 1: num_a
    % if larger than lower bound
    if_in_sim(i) = sum(NDdraws_r > lb_price(i)); % from x'th on to sample
    % random draws from in_sim vector
    NDdraws_r_j(i,:) = prctile(NDdraws_r((length(NDraws)- if_in_sim(i) +1):end) ,UDraws(i,:)*100);
end
end
