% resample the demand experiment data for the bootstrap

clear all;

rng('default')
rng(20190123)

%% number of bootstrap
BBB = 1000;
for bbb = 1: 1000
    %% data
    intensivetdata = readtable('../../temp/demand_exp_analysis_data.csv');
    intensivetdata = sortrows(intensivetdata, 1);
    %% randomly sample the data
    rng(20190123+bbb) % specific seed for each draw
    y = datasample(intensivetdata,size(intensivetdata,1));
    intensivetdata = sortrows(y,'mid'); % sort by market ID
    save(strcat('../../temp/bootstrap/resample_data/demand_data_',num2str(bbb)),'intensivetdata'); % only save the sampled data
end