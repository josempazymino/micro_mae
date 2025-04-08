%% export bootstrap entry estimates

clearvars;

boot_para = zeros(1000,5);

for bbb=1:1000
load(strcat('../../temp/bootstrap/s2/entry_boot_',num2str(bbb)));
boot_para(bbb,:)  = para2';
end

save('../../temp/bootstrap/s2/entry_bootstrap_estimates');
csvwrite('../../temp/bootstrap/s2/entry_bootstrap_estimates.csv',boot_para);



for bbb=1:1000
delete(strcat('../../temp/bootstrap/s2/entry_boot_',num2str(bbb),'.mat'));
end